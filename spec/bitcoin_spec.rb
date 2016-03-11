#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/item'

describe Dropzone do
  describe "scratch" do
    PRIVATE_KEY_WIF = "92UvdTpmxA6cvD6YeJZSiHW8ff8DsZXL2PHZu9Mg7JY3zbaETJw"
    # Public Address: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw

    before(:all) do
      Bitcoin.network = :testnet3
      #TCPSocket::socks_server = "127.0.0.1"
      #TCPSocket::socks_port = 9050
      # Socksify::debug = true
      #RestClient.log = Logger.new STDOUT

      connection = Dropzone::BitcoinConnection.new :testnet3
      Dropzone::RecordBase.blockchain = connection
    end

    let(:connection){ 
      Dropzone::BitcoinConnection.new :testnet3
    }
    let(:genesis_intro) {
      'In the beginning God created the heavens and the earth. Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters. And God said, "Let there be light," and there was light. God saw that the light was good, and he separated the light from the darkness. God called the light "day," and the darkness he called "night." And there was evening, and there was morning-the first day. And God said, "Let there be a vault between the waters to separate water from water." So God made the vault and separated the water under the vault from the water above it. And it was so. God called the vault "sky." And there was evening, and there was morning-the second day. And God said, "Let the water under the sky be gathered to one place, and let dry ground appear." And it was so. God called the dry ground "land," and the gathered waters he called "seas." And God saw that it was good. Then God said, "Let the land produce vegetation: seed-bearing plants and trees on the land that bear fruit with seed in it, according to their various kinds." And it was so. The land produced vegetation: plants bearing seed according to their kinds and trees bearing fruit with seed in it according to their kinds. And God saw that it was good. And there was evening, and there was morning-the third day. And God said, "Let there be lights in the vault of the sky to separate the day from the night, and let them serve as signs to mark sacred times, and days and years, and let them be lights in the vault of the sky to give light on the earth." And it was so. God made two great lights-the greater light to govern the day and the lesser light to govern the night. He also made the stars. God set them in the vault of the sky to give light on the earth, to govern the day and the night, and to separate light from darkness. And God saw that it was good. And there was evening, and there was morning-the fourth day.'}

    it "Goes through tor" do
      ret = RestClient.get 'http://www.ipchicken.com/'
      parts = /([\d]+\.[\d]+\.[\d]+\.[\d]+)/.match ret
      puts "Running from:"+parts[1].inspect
    end

    it "issues a spend" do
      # let's parse the keys:
      to = "msj42CCGruhRsFrGATiUuh25dtxYtnpbTx"
      satoshis =  1_000_000 # 0.01 BTC in satoshis
      tip =         500_000 # 0.005 BTC

      from_key = Bitcoin::Key.from_base58 PRIVATE_KEY_WIF

      #ret = connection.send_value from_key, to, satoshis, tip
      #puts "Spend Ret: #{ret.inspect}"
    end

    it "persists a large item" do
      Dropzone::MessageBase.blockchain = connection

      item = Dropzone::Item.sham!(:build, description: genesis_intro)
      #ret = item.save!(PRIVATE_KEY_WIF)
      #puts ret.inspect
    end

    it "decodes a large transaction" do
      Dropzone::Item.blockchain = Dropzone::BitcoinConnection.new :testnet3

      item = Dropzone::Item.find '0b2772eab7823a14fe5d369d3534d4a9d19b19ac0a44855b0aaf9cefcbfe49c7'

      expect(item.description).to eq(genesis_intro)
      expect(item.price_currency).to eq('BTC')
      expect(item.price_in_units).to eq(100_000_000)
      expect(item.expiration_in).to eq(6)
      expect(item.latitude).to eq(51.500782)
      expect(item.longitude).to eq(-0.124669)
      expect(item.radius).to eq(1000)
      expect(item.receiver_addr).to eq('mfZ1415XX782179875331XX1XXXXXgtzWu')
      expect(item.block_height).to eq(533721)
    end

    it "enumerates messages by address for a seller" do 
      profile = Dropzone::SellerProfile.new 'mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw'

      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("Test Description")
      expect(profile.alias).to eq("Satoshi")
      expect(profile.communications_pkey).to eq('n3EMs5L3sHcZqRy35cmoPFgw5AzAtWSDUv')
      expect(profile.addr).to eq('mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw')
      expect(profile.active?).to be_truthy
    end

    it "enumerates messages by address for a buyer" do 
      profile = Dropzone::BuyerProfile.new 'mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp'
      expect(profile.valid?).to be_truthy
      expect(profile.description).to eq("Test Buyer Description")
      expect(profile.alias).to eq("Test Buyer")
      expect(profile.addr).to eq('mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp')
      expect(profile.active?).to be_truthy
    end

    it "finds invoices and payments" do 
      invoice = Dropzone::Invoice.find '070288a455f14966d77f3877cd21befbd000f23ff3f190e2eb9c1fbbd7d5ac08'

      expect(invoice.expiration_in).to eq(6000)
      expect(invoice.amount_due).to eq(1000)
      expect(invoice.receiver_addr).to eq('mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp')
      expect(invoice.sender_addr).to eq('mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw')
      
      payment = Dropzone::Payment.find 'a2598c76593b17c698e4b58637ae4193a27df4c43b8c3b6d3d1e26cc10602325'

      expect(payment.description).to eq("Fair Exchange")
      expect(payment.invoice_txid).to be_kind_of(String)
      expect(payment.delivery_quality).to eq(8)
      expect(payment.product_quality).to eq(8)
      expect(payment.communications_quality).to eq(4)
      expect(payment.sender_addr).to eq('mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp')
      expect(payment.receiver_addr).to eq('mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw')
      expect(payment.block_height).to eq(533725)
    end

    it "Enumerates through listings via Item" do 
      # This is diffucult ATM due to blockchain.info not supporting testnet
      # and blockr.io's implementation not including all transactions
      pending 
      
    end

    it "decodes a 1.0 seller profile" do
      connection = Dropzone::BitcoinConnection.new :bitcoin
      Dropzone::RecordBase.blockchain = connection

      junseth = Dropzone::Seller.find '3d2b3339855e1244fbef627f374e2bba888c1a706f9e9b5c4a59f49cb268f074'

      expect(junseth.description).to eq(
        'junseth here, making modest amounts of moolah.')
      expect(junseth.alias).to eq('junseth')
      expect(junseth.transfer_pkey).to be_nil
      expect(junseth.communications_pkey).to eq('mjuNSeTHvjiwTXfaSABHenKdAE85pCiM64')
      expect(junseth.receiver_addr).to eq('14zBTbnhzHjdAKkaR4J9kCPiyVyNoaqoti')
      expect(junseth.block_height).to eq(388933)
    end

    # This is mostly the result of an investigation that was prompted by loon3
    # over the (potential) double-encoding of transactions
    it "Encodes addresses as expected" do
      # This is tx: 
      # 3d2b3339855e1244fbef627f374e2bba888c1a706f9e9b5c4a59f49cb268f074
      junseth_seller_hex = "0100000001a08589f802ba71b18503c4e3fa0b9755f1462c32"+
        "41fbdf3d1bb36b1e5eb3cf73040000006a47304402205c474b5738de9c12889a0137c"+
        "def48fdfe7e13391d8f5ab4a5aca562d86f653f02201f49b7728225c17ca41ed81a74"+
        "9be17dd192790bed6e5e3d46482248195d683d0121031bf0b235cb0cefcf8c9c299f3"+
        "00925704d6da7e6b448bd185c80d28f1216ef44ffffffff0436150000000000001976"+
        "a9142bb8d14d65d316483e24da5512bfd2a977da85ea88ac361500000000000069512"+
        "10303f2d3ec6902ceba50630236a01f09a29e18fb4690ad4aeb32fa964beed6407b21"+
        "028784f2f482488a153322789d4f6cbffc9b41d13284fe8182b72ecf8fde91fcb4210"+
        "31bf0b235cb0cefcf8c9c299f300925704d6da7e6b448bd185c80d28f1216ef4453ae"+
        "36150000000000006951210221f2d3ca4b24fb8a6c63160cfa77a838c795d99844000"+
        "7329a35894e7fe9d86a210304a49f9be62df961134315f23a02cb8fbb2eb712e991ee"+
        "eed646e18ebf9696ba21031bf0b235cb0cefcf8c9c299f300925704d6da7e6b448bd1"+
        "85c80d28f1216ef4453ae6a661100000000001976a9142bb8d14d65d316483e24da55"+
        "12bfd2a977da85ea88ac00000000"

      tx = Bitcoin::P::Tx.new [junseth_seller_hex].pack('H*')

      record = Counterparty::TxDecode.new tx,
        prefix: Dropzone::BitcoinConnection::PREFIX

      expect(record.prefix).to eq('DZ')
      expect(record.receiver_addr).to eq('mjW8kesgoKAswSEC8dGXa7c3qVa5ixiG4M')
      expect(record.sender_addr).to eq('mjW8kesgoKAswSEC8dGXa7c3qVa5ixiG4M')
      expect(record.decrypt_key.unpack('H*').first).to eq(
        '73cfb35e1e6bb31b3ddffb41322c46f155970bfae3c40385b171ba02f88985a0')
      expect(record.data.unpack('H*').first).to eq(
        '534c5550445401642e6a756e7365746820686572652c206d616b696e67206d6f64657'+
        '37420616d6f756e7473206f66206d6f6f6c61682e0161076a756e7365746801701430'+
        '1dcfe93cf94afebcc83fbc84ef7264fa56f6e4')
      
      record_bytes = record.data.bytes
      expect(record_bytes.shift(6).collect(&:chr).join).to eq('SLUPDT')
      expect(record_bytes.shift(49).collect(&:chr).join).to eq(
        "\x01d.junseth here, making modest amounts of moolah.")
      expect(record_bytes.shift(10).collect(&:chr).join).to eq(
        "\x01a\ajunseth")

      # Here's the nature of the bug in 1.0 encoding:
      expect(record_bytes.shift(2).collect(&:chr).join).to eq("\x01p")
      # This length should be
      expect(record_bytes.shift(1).first).to eq(20)

      communications_value = record_bytes.shift(20).collect(&:chr).join
      expect(communications_value).to eq(
        ['301dcfe93cf94afebcc83fbc84ef7264fa56f6e4'].pack('H*'))

      expect(record_bytes.length).to eq(0)
    end

    it 'encodes reviews with binary transaction ids' do
      hex = '0100000001309ab7c3ed6adbee0bd99632e7963e08f9536e71a55246164166e5b'+
         '8c986c445000000008b483045022100b33969420513204d7c49122178cf2b7134d1c'+
         '653cf977ba96488278ddc7f33c102201dbb9be43443d2301242db395278c406c8020'+
         'b53a54c7754df4ad758203bf98a014104ab937a60d8f052a7df5f1400c1ff8ec9bd6'+
         '4eda9107901ddf9ee5f64fe26e58aa31fe454cda94c56b9ba4c6f045763b6aac0890'+
         '8e2ef1f601e4a8ccbfa54be82ffffffff0636150000000000001976a9142bb8d14d6'+
         '5d316483e24da5512bfd2a977da85ea88ac36150000000000008951210277bad52da'+
         'd98a0a4506f66252989eed89f4770097aed3e8327663272dcd80e122103f5b197f13'+
         'c5facf5f6412b2e0db88b12eaa77021decfe470ef71c6a5ba23350f4104ab937a60d'+
         '8f052a7df5f1400c1ff8ec9bd64eda9107901ddf9ee5f64fe26e58aa31fe454cda94'+
         'c56b9ba4c6f045763b6aac08908e2ef1f601e4a8ccbfa54be8253ae3615000000000'+
         '0008951210277bad50b8aab84c334226d29058fefdb9f42701660f9228e6473293bd'+
         '4d35aaa2102f6b18dfe3c44a8edb404182b06d5ca32fbeb682b8cade255eb30c2b0e'+
         '57927b44104ab937a60d8f052a7df5f1400c1ff8ec9bd64eda9107901ddf9ee5f64f'+
         'e26e58aa31fe454cda94c56b9ba4c6f045763b6aac08908e2ef1f601e4a8ccbfa54b'+
         'e8253ae36150000000000008951210377bad551d7a983d4700b37760885b7d9dd452'+
         'b5520ae69d37565717ed18e48dc2102baec81fb794fa8aaae1c6b634cced953fdb63'+
         '62dcfcfa625bb35c2e0e04c20624104ab937a60d8f052a7df5f1400c1ff8ec9bd64e'+
         'da9107901ddf9ee5f64fe26e58aa31fe454cda94c56b9ba4c6f045763b6aac08908e'+
         '2ef1f601e4a8ccbfa54be8253ae36150000000000008951210249bad56ce3c8e1ed1'+
         '46e02466ee681bcbf241f64179850ea4407461bb3b62ebd210382d8e3991c2cc9999'+
         'a2459002dfeea619e87044efeac96158e05a385d34d43154104ab937a60d8f052a7d'+
         'f5f1400c1ff8ec9bd64eda9107901ddf9ee5f64fe26e58aa31fe454cda94c56b9ba4'+
         'c6f045763b6aac08908e2ef1f601e4a8ccbfa54be8253ae72ce0000000000001976a'+
         '914bce6181b66ce5ab5ca854feb00995f14fc07308588ac00000000'

      record = Counterparty::TxDecode.new Bitcoin::P::Tx.new([hex].pack('H*')),
        prefix: Dropzone::BitcoinConnection::PREFIX

      expect(record.prefix).to eq('DZ')
      expect(record.receiver_addr).to eq('mjW8kesgoKAswSEC8dGXa7c3qVa5ixiG4M')
      expect(record.sender_addr).to eq('mxjkyLk6sybkRWSYw2WRMrX7S3VNaQYXFv')
      expect(record.decrypt_key.unpack('H*').first).to eq(
        '45c486c9b8e56641164652a5716e53f9083e96e73296d90beedb6aedc3b79a30')
      expect(record.data.unpack('H*').first).to eq(
        '494e50414944016463476f6f6420636f6d6d756e69636174696f6e207769746820736'+
        '56c6c65722e204661737420746f2063726561746520696e766f6963652e204c6f6f6b'+
        '696e6720666f727761726420746f2067657474696e67206861742e20412b2b2b20536'+
        '56c6c6572017440653561353634643534616239646535306663366562613431373639'+
        '393162376562386638346262656361333438326361303332633132633163303035306'+
        '16533016308')
      
      data = record.data.bytes
      
      data = record.data.bytes
      expect(data.shift(6).collect(&:chr).join).to eq('INPAID')
      expect(data.shift(102).collect(&:chr).join).to eq(
        "\x01dcGood communication with seller. Fast to create invoice. Looking"+
        " forward to getting hat. A+++ Seller")
      expect(data.shift(2).collect(&:chr).join).to eq("\x01t")
      expect(data.shift(1).first).to eq(64)

      # TODO: This is the problem (64 bytes): 
      expect(data.shift(64).collect(&:chr).join).to eq(
        "e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3")
      # TODO: This is what it should be, at 32 bytes:
      ['e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3'].pack('H*').length

      expect(data.shift(3).collect(&:chr).join).to eq("\x01c\b")
    end

  end
end
