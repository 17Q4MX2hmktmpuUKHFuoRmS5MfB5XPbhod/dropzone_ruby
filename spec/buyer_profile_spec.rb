#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/buyer'

describe Dropzone::BuyerProfile do
  include_context 'globals'

  describe "accessors" do
    after{ clear_blockchain! }

    it "compiles a simple profile" do
      Dropzone::Buyer.sham!(:build).save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("abc")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(test_pubkey)
      expect(profile.active?).to be_truthy
    end

    it "combines attributes from mulitple messages" do
      Dropzone::Buyer.sham!(:build).save! test_privkey
      Dropzone::Buyer.sham!(:build, :description => 'xyz').save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("xyz")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(test_pubkey)
      expect(profile.active?).to be_truthy
    end

    it "supports profile transfers" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Buyer Transfer to Tester2: 
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY).save! test_privkey

      # And let's update Tester2 for some added complexity:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY, 
        :alias => 'New Alias' ).save! TESTER2_PRIVATE_KEY

      profile = Dropzone::BuyerProfile.new TESTER2_PUBLIC_KEY

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("abc")
      expect(profile.alias).to eq("New Alias")
      expect(profile.addr).to eq(TESTER2_PUBLIC_KEY)
      expect(profile.active?).to be_truthy
    end

    it "supports a transfer in and transfer out" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 transfers to Address 2:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY).save! test_privkey

      # Address 2 transfers to Address 3:
      Dropzone::Buyer.new( receiver_addr: TESTER3_PUBLIC_KEY,
        transfer_pkey: TESTER3_PUBLIC_KEY).save! TESTER2_PRIVATE_KEY

      profile = Dropzone::BuyerProfile.new TESTER3_PUBLIC_KEY

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("abc")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(TESTER3_PUBLIC_KEY)
      expect(profile.active?).to be_truthy
    end

    it "only supports a single transfer in" do
      # Address 1 Declaration:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 2 Declaration:
      Dropzone::Buyer.new( description: 'xyz', alias: 'New Alias', 
       receiver_addr: TESTER2_PUBLIC_KEY ).save! TESTER2_PRIVATE_KEY

      # Address 1 transfers to Address 3:
      Dropzone::Buyer.new( receiver_addr: TESTER3_PUBLIC_KEY,
        transfer_pkey: TESTER3_PUBLIC_KEY).save! test_privkey
      
      # Address 2 transfers to Address 3:
      Dropzone::Buyer.new( receiver_addr: TESTER3_PUBLIC_KEY,
        transfer_pkey: TESTER3_PUBLIC_KEY).save! TESTER2_PRIVATE_KEY

      profile = Dropzone::BuyerProfile.new TESTER3_PUBLIC_KEY

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("abc")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(TESTER3_PUBLIC_KEY)
      expect(profile.transfer_pkey).to be_nil
      expect(profile.active?).to be_truthy
    end

    it "supports deactivation" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Buyer Deactivates his account:
      Dropzone::Buyer.new( receiver_addr: test_pubkey,
        transfer_pkey: 0).save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.transfer_pkey).to eq(0)
      expect(profile.active?).to be_falsey
      expect(profile.closed?).to be_truthy
    end

    it "will stop merging attributes after a transfer out" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 transfers to Address 2:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY).save! test_privkey

      # Address 1 changes description:
      Dropzone::Buyer.new( description: 'xyz' ).save! test_privkey

      profile1 = Dropzone::BuyerProfile.new test_pubkey
      profile2 = Dropzone::BuyerProfile.new TESTER2_PUBLIC_KEY

      expect(profile1.description).to eq("abc")
      expect(profile1.alias).to eq("Satoshi")
      expect(profile1.addr).to eq(test_pubkey)
      expect(profile1.transfer_pkey).to eq(TESTER2_PUBLIC_KEY)
      expect(profile1.active?).to be_falsey
      expect(profile1.closed?).to be_falsey

      expect(profile2.description).to eq("abc")
      expect(profile2.alias).to eq("Satoshi")
      expect(profile2.addr).to eq(TESTER2_PUBLIC_KEY)
      expect(profile2.active?).to be_truthy
      expect(profile2.closed?).to be_falsey
    end

    it "will stop merging attributes after a cancellation" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 closes its account:
      Dropzone::Buyer.new( receiver_addr: test_pubkey,
        transfer_pkey: 0 ).save! test_privkey

      # Address 1 changes description:
      Dropzone::Buyer.new( description: 'xyz' ).save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("abc")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(test_pubkey)
      expect(profile.transfer_pkey).to eq(0)
      expect(profile.active?).to be_falsey
    end

    it "will merge attributes in a cancellation message" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 closes its account:
      Dropzone::Buyer.new( receiver_addr: test_pubkey, description: 'xyz',
        transfer_pkey: 0 ).save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("xyz")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(test_pubkey)
      expect(profile.transfer_pkey).to eq(0)
      expect(profile.active?).to be_falsey
    end

    it "will merge attributes in a transfer message" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 closes its account:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY, description: 'xyz',
        transfer_pkey: TESTER2_PUBLIC_KEY ).save! test_privkey

      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("xyz")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.addr).to eq(test_pubkey)
      expect(profile.transfer_pkey).to eq(TESTER2_PUBLIC_KEY)
      expect(profile.active?).to be_falsey
    end

    it "won't compile a deactivated transfer" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 closes its account:
      Dropzone::Buyer.new( receiver_addr: test_pubkey,
        transfer_pkey: 0 ).save! test_privkey
      
      # Address 1 transfers its account:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY ).save! test_privkey

      profile = Dropzone::BuyerProfile.new TESTER2_PUBLIC_KEY

      expect(profile.valid?).to be_falsey
    end
  end

  describe "validations" do
    after{ clear_blockchain! }

    it "requires a valid buyer message" do
      # No messages have been created here yet:
      profile = Dropzone::BuyerProfile.new test_pubkey

      expect(profile.valid?).to be_falsey
      expect(profile.errors.count).to eq(1)
      expect(profile.errors.on(:addr)).to eq(['profile not found'])
    end

    it "won't accept a closed account transfer" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 closes its account:
      Dropzone::Buyer.new( receiver_addr: test_pubkey,
        transfer_pkey: 0 ).save! test_privkey
      
      # Address 1 transfers its account:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY ).save! test_privkey

      profile = Dropzone::BuyerProfile.new TESTER2_PUBLIC_KEY
      expect(profile.valid?).to be_falsey
      expect(profile.errors.count).to eq(1)
      expect(profile.errors.on(:prior_profile)).to eq(['invalid transfer or closed'])
    end

    it "won't accept a second transfer out" do
      # Standard Buyer:
      Dropzone::Buyer.sham!(:build).save! test_privkey 

      # Address 1 transfers to address 2:
      Dropzone::Buyer.new( receiver_addr: TESTER2_PUBLIC_KEY,
        transfer_pkey: TESTER2_PUBLIC_KEY ).save! test_privkey
      
      # Address 1 transfers to address 3:
      Dropzone::Buyer.new( receiver_addr: TESTER3_PUBLIC_KEY,
        transfer_pkey: TESTER3_PUBLIC_KEY ).save! test_privkey

      profile2 = Dropzone::BuyerProfile.new TESTER2_PUBLIC_KEY
      profile3 = Dropzone::BuyerProfile.new TESTER3_PUBLIC_KEY

      expect(profile2.valid?).to be_truthy
      expect(profile2.description).to eq("abc")
      expect(profile2.alias).to eq("Satoshi")
      expect(profile2.addr).to eq(TESTER2_PUBLIC_KEY)
      expect(profile2.active?).to be_truthy

      expect(profile3.valid?).to be_falsey
      expect(profile3.errors.count).to eq(1)
      expect(profile3.errors.on(:prior_profile)).to eq(['invalid transfer or closed'])
    end

  end
end
