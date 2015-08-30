#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/item'

describe Dropzone do
  describe "scratch" do
    PRIVATE_KEY_WIF = "92UvdTpmxA6cvD6YeJZSiHW8ff8DsZXL2PHZu9Mg7JY3zbaETJw"
    # Public Address: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw

    before(:all) do
      Bitcoin.network = :testnet3
      TCPSocket::socks_server = "127.0.0.1"
      TCPSocket::socks_port = 9050
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
    end

    it "Enumerates through listings via Item" do 
      # This is diffucult ATM due to blockchain.info not supporting testnet
      # and blockr.io's implementation not including all transactions
      pending 
      
    end

  end
end
