#encoding: utf-8
require_relative 'spec_helper'

describe Dropzone::Session do
  include_context 'globals'

  SESSION_DER = "30818702818100e655cc9e04f3bebae76ecca77143ef5c4451876615a9f8b4f712b8f3bdf47ee7f717c09bb5b2b66450831367d9dcf85f9f0528bcd5318fb1dab2f23ce77c48b6b7381eed13e80a14cca6b30b5e37ffe53db15e2d6b727a2efcee51893678d50e9a89166a359e574c4c3ca5e59fae79924fe6f186b36a2ebde9bf09fe4de50453020102"

  BUYER_SESSION_SECRET = "6d6a8a364e604e43380653497b153015476e4254d5b4d79f695cf28cd5ad479a511b6cb5251ab258aa474b56b58a087ccc66acb4d067826a19d16c5f9611b573e8978e09baf36e4e8f08413acc5e21fa6e1c06783396d6ebeba3f34e96a5d35ed820d5d4306ceeed524cd55990d41d5ed8d0bd84922ddef9f861a54aa337abeb"

  BUYER_SESSION_PUBKEY = "2ae9b83b42fe22615e5d378737a6ff883c87bf4eb1e513cde77a2ed557c6e7c3fd37e19d69d55ffbd5d6000a90e94a07abc094139456f82a015640610698ffdf96ca3026fc378653e32974e8fa364f7edb3affc225fe1869aae1f4015c4cb792f3eb88e672aeb860be1a019178ec20268eef1fffe9f8c01abb9da2deeebee757"

  SELLER_SESSION_SECRET = "44d3075ced3cb24f84101e3c0a0d23115638c2730d87b93429147181ae381b09420a155c3b6c03c4b323ea99e72c65851bde0f952ac66b2f950dc0e4bffe5238ab17372e62abe2c2e353b4a8b431aa78661f7379750a6602266705ada943d9f34a5de90892253ad802b8b4a8d6ec71b73d647570ce6f59b6576b6337b8913243"

  SELLER_SESSION_PUBKEY = "ad0588a0cdc2f2b21a296bed80fc303a72e1222e2adc50f2fc2d041f834c5ddf4c0abc79d76d2faece62d547094fd6a1c9017adaf965209616c3b11d35ba577bb9196d1a52fdf89c3f3e8a89fd61749a2b911cb101c7633fad9335f2b1a989ed92784af4fba749dd6c3de1e1aa5a693c6c2d0089ce2287f317ec1d7b55b6bd91"

  SYMM_KEY = "80cacfadf10361f1dff7ce87d257a91b5eddd1e41d17f36c9c4b89fb132a7c2b9d570827283afc928d2c4fb99b1210d34140efdbe7e4ed4fdd9ea5f750b57efffb3fd89625458dd6cbba06fdf9ecdc0ab12d73a746613fc25ecead056ea362f68cd05bcbb4ac8a627b7c973863ec162e995134d1fc4a0b2fcd3b1c88dfbd173a"

  def random_secret
    SecureRandom.random_bytes(128).unpack('H*').first
  end

  after{ clear_blockchain! }

  it "simple non-deterministic chat test (v1/original)" do
    # Note that Der's and IV's are generated randomly on every iteration of this
    # test, which is unlike the extended test.

    buyer_to_seller = Dropzone::Session.new test_privkey,
      BUYER_SESSION_SECRET, receiver_addr: TESTER2_PUBLIC_KEY 

    buyer_to_seller.authenticate!

    seller_to_buyer = Dropzone::Session.new TESTER2_PRIVATE_KEY, SELLER_SESSION_SECRET,
      with: Dropzone::Session.all(TESTER2_PUBLIC_KEY).first 

    seller_to_buyer.authenticate! 

    seller_to_buyer << "Hello Buyer"
    buyer_to_seller << "Hello Seller"

    expect(seller_to_buyer.communications.collect(&:contents_plain)).to eq([
      "Hello Seller", "Hello Buyer" ])
    expect(buyer_to_seller.communications.collect(&:contents_plain)).to eq([
      "Hello Seller", "Hello Buyer" ])
  end

  it "simple non-deterministic chat test (v2)" do
    # Note that Der's and IV's are generated randomly on every iteration of this
    # test, which is unlike the extended test.

    buyer_to_seller = Dropzone::Session.new test_privkey,
      BUYER_SESSION_SECRET, receiver_addr: TESTER2_PUBLIC_KEY 

    buyer_to_seller.authenticate!

    seller_to_buyer = Dropzone::Session.new TESTER2_PRIVATE_KEY, SELLER_SESSION_SECRET,
      with: Dropzone::Session.all(TESTER2_PUBLIC_KEY).first 

    # NOTE: This is removed, and should not be necessary: seller_to_buyer.authenticate! 

    seller_to_buyer << "Hello Buyer"
    buyer_to_seller << "Hello Seller"
    seller_to_buyer << "Hello Buyer 2"
    buyer_to_seller << "Hello Seller 2"

    expect(seller_to_buyer.communications.collect(&:contents_plain)).to eq([
      "Hello Seller 2", "Hello Buyer 2", "Hello Seller", "Hello Buyer" ])
    expect(buyer_to_seller.communications.collect(&:contents_plain)).to eq([
      "Hello Seller 2", "Hello Buyer 2", "Hello Seller", "Hello Buyer" ])
  end

  it "extended deterministic chat test" do
    buyer_to_seller = Dropzone::Session.new TESTER2_PRIVATE_KEY,
      BUYER_SESSION_SECRET, receiver_addr: test_pubkey 

    expect(buyer_to_seller.sender_addr).to eq(TESTER2_PUBLIC_KEY)
    expect(buyer_to_seller.priv_key).to eq(TESTER2_PRIVATE_KEY)

    ## Step One: Buyer initializes channel.

    # Der is not actually required, but since we're keeping the tests 
    # deterministic, I'm passing it here. Additionally, this speeds up testing:
    buyer_auth_id = buyer_to_seller.authenticate! [SESSION_DER].pack('H*')

    # Test the initialization:
    buyer_init_comm = Dropzone::Communication.find buyer_auth_id

    expect(buyer_init_comm.valid?).to be_truthy
    expect(buyer_init_comm.receiver_addr).to eq(test_pubkey)
    expect(buyer_init_comm.sender_addr).to eq(TESTER2_PUBLIC_KEY)
    expect(buyer_init_comm.der.unpack('H*').first).to eq(SESSION_DER)
    expect(buyer_init_comm.session_pkey.unpack('H*').first).to eq(BUYER_SESSION_PUBKEY)
    expect(buyer_init_comm.iv).to eq(nil)
    expect(buyer_init_comm.contents).to eq(nil)

    expect(buyer_to_seller.authenticated?).to be_falsey

    ## Step Two: Seller authenticates request.
    seller_sessions = Dropzone::Session.all(test_pubkey)

    expect(seller_sessions.length).to eq(1)

    seller_to_buyer = Dropzone::Session.new test_privkey, SELLER_SESSION_SECRET,
      with: seller_sessions.first 

    expect(seller_to_buyer.authenticated?).to be_falsey
    expect(buyer_to_seller.authenticated?).to be_falsey

    seller_auth_id = seller_to_buyer.authenticate! 

    # Test the communication:
    seller_init_comm = Dropzone::Communication.find seller_auth_id

    expect(seller_init_comm.valid?).to be_truthy
    expect(seller_init_comm.receiver_addr).to eq(TESTER2_PUBLIC_KEY)
    expect(seller_init_comm.sender_addr).to eq(test_pubkey)
    expect(seller_init_comm.der).to be_nil
    expect(seller_init_comm.session_pkey.unpack('H*').first).to eq(SELLER_SESSION_PUBKEY)
    expect(seller_init_comm.iv).to eq(nil)
    expect(seller_init_comm.contents).to eq(nil)
    
    # Now test the shared secrets:
    expect(buyer_to_seller.communications.length).to eq(0)
    expect(seller_to_buyer.communications.length).to eq(0)

    # And ensure that we authenticated:
    expect(buyer_to_seller.symm_key.unpack('H*').first).to eq(SYMM_KEY)
    expect(buyer_to_seller.authenticated?).to be_truthy
    expect(seller_to_buyer.symm_key.unpack('H*').first).to eq(SYMM_KEY)
    expect(seller_to_buyer.authenticated?).to be_truthy

    ## Step Three: Seller Says Hi To Buyer.
    seller_hello_id = seller_to_buyer.send( "Hello Buyer", 
      ['4941fbbf24517885502b85a0f3285659'].pack('H*') )

    seller_hello_comm = Dropzone::Communication.find seller_hello_id

    expect(seller_hello_comm.valid?).to be_truthy
    expect(seller_hello_comm.receiver_addr).to eq(TESTER2_PUBLIC_KEY)
    expect(seller_hello_comm.sender_addr).to eq(test_pubkey)
    expect(seller_hello_comm.der).to be_nil
    expect(seller_hello_comm.session_pkey).to be_nil
    expect(seller_hello_comm.iv.unpack('H*').first).to eq(
      '4941fbbf24517885502b85a0f3285659')
    expect(seller_hello_comm.contents.unpack('H*').first).to eq(
      '2924a61b305a8070c0c41496482d1a3a')
    
    ## Step Four: Buyer Says Hello to Seller.
    buyer_hello_id = buyer_to_seller.send "Hello Seller", 
      ['02ff94080d10f3361d69e9770dca9982'].pack('H*')

    buyer_hello_comm = Dropzone::Communication.find buyer_hello_id

    expect(buyer_hello_comm.valid?).to be_truthy
    expect(buyer_hello_comm.receiver_addr).to eq(test_pubkey)
    expect(buyer_hello_comm.sender_addr).to eq(TESTER2_PUBLIC_KEY)
    expect(buyer_hello_comm.der).to be_nil
    expect(buyer_hello_comm.session_pkey).to be_nil
    expect(buyer_hello_comm.iv.unpack('H*').first).to eq(
      '02ff94080d10f3361d69e9770dca9982')
    expect(buyer_hello_comm.contents.unpack('H*').first).to eq(
      'fa753c555ae1d87b22ee40d0879d0ee0')

    # Now test the shared secrets:
    expect(seller_to_buyer.communications.collect(&:contents_plain)).to eq([
      "Hello Seller", "Hello Buyer" ])
    expect(buyer_to_seller.communications.collect(&:contents_plain)).to eq([
      "Hello Seller", "Hello Buyer" ])
  end

  it "Requires that session must authenticate before chatting" do
    # Create a session, authenticate it, and then try opening it with a bad pass
    buyer_to_seller = Dropzone::Session.new test_privkey,
      BUYER_SESSION_SECRET, receiver_addr: TESTER2_PUBLIC_KEY 

    expect{buyer_to_seller << "Hello Buyer"}.to raise_error(
      Dropzone::Session::Uninitialized )

    buyer_to_seller.authenticate!

    expect{buyer_to_seller << "Hello Buyer"}.to raise_error(
      Dropzone::Session::Unauthenticated )
  end
    
  it "supports multiple chats sessions by a seller" do
    ## Buyers Say hello:
    buyer1_to_seller = Dropzone::Session.new TESTER2_PRIVATE_KEY,
      random_secret, receiver_addr: test_pubkey 
    buyer1_to_seller.authenticate!

    buyer2_to_seller = Dropzone::Session.new TESTER3_PRIVATE_KEY,
      random_secret, receiver_addr: test_pubkey 
    buyer2_to_seller.authenticate!

    ## Seller Authenticates:
    seller_sessions = Dropzone::Session.all(test_pubkey)

    expect(seller_sessions.length).to eq(2)

    seller_to_buyer2 = Dropzone::Session.new test_privkey, random_secret,
      with: seller_sessions.first 

    seller_to_buyer1 = Dropzone::Session.new test_privkey, random_secret,
      with: seller_sessions.last

    seller_to_buyer1.authenticate!
    seller_to_buyer2.authenticate!

    ## Chats commence:
    seller_to_buyer1 << "Hello Buyer1"
    buyer1_to_seller << "Hello from Buyer1"

    seller_to_buyer2 << "Hello Buyer2"
    buyer2_to_seller << "Hello from Buyer2"

    # Test:
    expect(seller_to_buyer1.communications.collect(&:contents_plain)).to eq([
      "Hello from Buyer1", "Hello Buyer1" ])
    expect(buyer1_to_seller.communications.collect(&:contents_plain)).to eq([
      "Hello from Buyer1", "Hello Buyer1" ])
    expect(seller_to_buyer2.communications.collect(&:contents_plain)).to eq([
      "Hello from Buyer2", "Hello Buyer2" ])
    expect(buyer2_to_seller.communications.collect(&:contents_plain)).to eq([
      "Hello from Buyer2", "Hello Buyer2" ])
  end

  it "supports multiple chat sessions by a buyer" do
    ## Buyers Say hello:
    buyer_to_seller1 = Dropzone::Session.new test_privkey, random_secret, 
      receiver_addr: TESTER2_PUBLIC_KEY 
    buyer_to_seller1.authenticate!

    buyer_to_seller2 = Dropzone::Session.new test_privkey, random_secret, 
      receiver_addr: TESTER3_PUBLIC_KEY 
    buyer_to_seller2.authenticate!

    ## Sellers Authenticate:
    seller1_to_buyer = Dropzone::Session.new TESTER2_PRIVATE_KEY, random_secret,
      with: Dropzone::Session.all(TESTER2_PUBLIC_KEY).first
    seller1_to_buyer.authenticate!

    seller2_to_buyer = Dropzone::Session.new TESTER3_PRIVATE_KEY, random_secret,
      with: Dropzone::Session.all(TESTER3_PUBLIC_KEY).first
    seller2_to_buyer.authenticate!
    
    ## Chats commence:
    buyer_to_seller1 << "Hello Seller1"
    seller1_to_buyer << "Hello from Seller1"

    buyer_to_seller2 << "Hello Seller2"
    seller2_to_buyer << "Hello from Seller2"

    # Now test:
    expect(seller1_to_buyer.communications.collect(&:contents_plain)).to eq([
      "Hello from Seller1", "Hello Seller1" ])
    expect(buyer_to_seller1.communications.collect(&:contents_plain)).to eq([
      "Hello from Seller1", "Hello Seller1" ])
    expect(seller2_to_buyer.communications.collect(&:contents_plain)).to eq([
      "Hello from Seller2", "Hello Seller2" ])
    expect(buyer_to_seller2.communications.collect(&:contents_plain)).to eq([
      "Hello from Seller2", "Hello Seller2" ])
  end

  it "supports multiple chat sessions between two users" do
    ## Session One:
    buyer_to_seller1_secret = random_secret
    seller_to_buyer1_secret = random_secret

    buyer_to_seller1 = Dropzone::Session.new test_privkey,
      buyer_to_seller1_secret, receiver_addr: TESTER2_PUBLIC_KEY 

    buyer_to_seller1.authenticate!

    seller_to_buyer1 = Dropzone::Session.new TESTER2_PRIVATE_KEY, 
      seller_to_buyer1_secret,
      with: Dropzone::Session.all(TESTER2_PUBLIC_KEY).first 

    seller_to_buyer1.authenticate! 


    seller_to_buyer1 << "Hello Buyer S1"
    buyer_to_seller1 << "Hello Seller S1"

    increment_block_height!

    ## Session Two:
    buyer_to_seller2 = Dropzone::Session.new test_privkey, random_secret, 
      receiver_addr: TESTER2_PUBLIC_KEY 

    buyer_to_seller2.authenticate!

    seller_to_buyer2 = Dropzone::Session.new TESTER2_PRIVATE_KEY, random_secret,
      with: Dropzone::Session.all(TESTER2_PUBLIC_KEY).first 
      
    expect(seller_to_buyer2.authenticated?).to be_falsey

    seller_to_buyer2.authenticate!

    increment_block_height!
    
    seller_sessions = Dropzone::Session.all(TESTER2_PUBLIC_KEY)

    expect(seller_sessions.length).to eq(2)

    # Ensure that we authenticated:
    expect(buyer_to_seller2.symm_key).to eq(seller_to_buyer2.symm_key)
    expect(buyer_to_seller1.symm_key).to_not eq(seller_to_buyer2.symm_key)
    expect(seller_to_buyer2.authenticated?).to be_truthy

    seller_to_buyer2 << "Hello Buyer S2"
    buyer_to_seller2 << "Hello Seller S2"

    # Now test the shared secrets:
    expect(seller_to_buyer2.communications.collect(&:contents_plain)).to eq([
      "Hello Seller S2", "Hello Buyer S2" ])
    expect(buyer_to_seller2.communications.collect(&:contents_plain)).to eq([
      "Hello Seller S2", "Hello Buyer S2" ])
  end

end
