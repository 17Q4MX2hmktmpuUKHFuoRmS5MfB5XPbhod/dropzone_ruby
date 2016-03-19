#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/item'

describe Dropzone::Item do
  include_context 'globals'

  describe "defaults" do
    it "has accessors" do
      item = Dropzone::Item.sham!(:build)

      expect(item.description).to eq("Item Description")
      expect(item.price_currency).to eq('BTC')
      expect(item.price_in_units).to eq(100_000_000)
      expect(item.expiration_in).to eq(6)
      expect(item.latitude).to eq(51.500782)
      expect(item.longitude).to eq(-0.124669)
      expect(item.radius).to eq(1000)
      expect(item.receiver_addr).to eq('mfZ1415XX782179875331XX1XXXXXgtzWu')
      expect(Bitcoin.valid_address?(item.receiver_addr)).to be_truthy
      expect(item.sender_addr).to eq(nil)
    end
  end

  describe "burn addresses" do 
    it "supports 6 digit distances" do
      [90, 0, -90, 51.500782,-51.500782].each do |lat|
        [180, 0, -180, -0.124669,0.124669].each do |lon|
          [9,8,5,2,0,101,11010,999999,100000].each do |radius|
            addr = Dropzone::Item.sham!(:build, :radius => radius, 
              :latitude => lat, :longitude => lon).receiver_addr

            /\AmfZ([0-9X]{9})([0-9X]{9})([0-9X]{6})/.match addr

            expect(addr.length).to eq(34)
            expect($1.tr('X','0').to_i).to eq(((lat+90) * 1_000_000).floor)
            expect($2.tr('X','0').to_i).to eq(((lon+180) * 1_000_000).floor)
            expect($3.tr('X','0').to_i).to eq(radius)
            
          end
        end
      end

    end
  end

  describe "serialization" do 
    it "serializes to_transaction" do
      expect(Dropzone::Item.sham!(:build).to_transaction).to eq({ tip: 20000,
        receiver_addr: "mfZ1415XX782179875331XX1XXXXXgtzWu", 
        data: "ITCRTE\x01d\x10Item Description\x01c\x03BTC\x01p\xFE\x00\xE1\xF5\x05\x01e\x06".force_encoding('ASCII-8BIT') })
    end
  end

  describe "database" do
    after{ clear_blockchain! }

    it ".save() and .find()" do
      item_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      expect(item_id).to be_kind_of(String)

      item = Dropzone::Item.find(item_id)

      expect(item.description).to eq("Item Description")
      expect(item.price_currency).to eq('BTC')
      expect(item.price_in_units).to eq(100_000_000)
      expect(item.expiration_in).to eq(6)
      expect(item.latitude).to eq(51.500782)
      expect(item.longitude).to eq(-0.124669)
      expect(item.radius).to eq(1000)
      expect(item.receiver_addr).to eq('mfZ1415XX782179875331XX1XXXXXgtzWu')
      expect(Bitcoin.valid_address?(item.receiver_addr)).to be_truthy
      expect(item.sender_addr).to eq(test_pubkey)
    end

    it "updates must be addressed to self" do
      item_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      update_id = Dropzone::Item.new(create_txid: item_id,
        description: 'xyz').save! test_privkey

      update_item = Dropzone::Item.find update_id

      expect(update_item.description).to eq("xyz")
      expect(update_item.message_type).to eq('ITUPDT')
      expect(update_item.sender_addr).to eq(test_pubkey)
      expect(update_item.receiver_addr).to eq(test_pubkey)
    end
  end

  describe "validations" do 
    it "validates default build" do
      expect(Dropzone::Item.sham!(:build).valid?).to eq(true)
    end

    it "validates minimal item" do
      minimal_item = Dropzone::Item.new radius: 1, latitude: 51.500782, 
        longitude: -0.124669

      expect(minimal_item.valid?).to eq(true)
    end

    it "requires output address" do
      no_address = Dropzone::Item.sham! latitude: nil, longitude: nil, radius: nil

      expect(no_address.valid?).to eq(false)
      expect(no_address.errors.count).to eq(4)
      expect(no_address.errors.on(:receiver_addr)).to eq(['is not present'])
    end

    it "requires latitude" do
      item = Dropzone::Item.sham! latitude: nil

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(2)
      expect(item.errors.on(:latitude)).to eq(['is not a number'])
    end

    it "requires latitude is gte -90" do
      item = Dropzone::Item.sham! latitude: -90.000001

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:latitude)).to eq(['must be greater than or equal to -90'])
    end

    it "requires latitude is lte 90" do
      item = Dropzone::Item.sham! latitude: 90.000001

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:latitude)).to eq(['must be less than or equal to 90'])
    end

    it "requires longitude" do
      item = Dropzone::Item.sham! longitude: nil

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(2)
      expect(item.errors.on(:longitude)).to eq(['is not a number'])
    end

    it "requires longitude is gte -180" do
      item = Dropzone::Item.sham! longitude: -180.000001

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:longitude)).to eq(['must be greater than or equal to -180'])
    end

    it "requires longitude is lte 180" do
      item = Dropzone::Item.sham! longitude: 180.000001

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:longitude)).to eq(['must be less than or equal to 180'])
    end

    it "requires radius" do
      item = Dropzone::Item.sham! radius: nil

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(2)
      expect(item.errors.on(:radius)).to eq(['is not a number'])
    end

    it "requires radius is gte 0" do
      item = Dropzone::Item.sham! radius: -1

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:radius)).to eq(['must be greater than or equal to 0'])
    end

    it "requires radius is lt 1000000" do
      item = Dropzone::Item.sham! radius: 1000000

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:radius)).to eq(['must be less than 1000000'])
    end

    it "requires message_type" do
      item = Dropzone::Item.sham! message_type: 'INVALD'

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:message_type)).to eq(['is not valid'])
    end

    it "descriptions must be text" do
      item = Dropzone::Item.sham! description: 5

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:description)).to eq(['is not a string'])
    end

    it "price_in_units must be numeric" do
      item = Dropzone::Item.sham! price_in_units: 'abc', 
        price_currency: 'USD'

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(2)
      expect(item.errors.on(:price_in_units)).to eq(['is not a number',
        "must be greater than or equal to 0"])
    end

    it "expiration_in must be numeric" do
      item = Dropzone::Item.sham! expiration_in: 'abc'

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(2)
      expect(item.errors.on(:expiration_in)).to eq(['is not a number',
        "must be greater than or equal to 0"])
    end

    it "price_currency must be present if price is present" do
      item = Dropzone::Item.sham! price_in_units: 100, price_currency: nil

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(1)
      expect(item.errors.on(:price_currency)).to eq(['is required if price is specified'])
    end

  end

  describe "distance calculations" do 
    it "calculates distance in meters between two points" do 
       # New York to London:
       nyc_to_london = Dropzone::Item.distance_between 40.712784, -74.005941, 
         51.507351, -0.127758
       texas = Dropzone::Item.distance_between 31.428663, -99.096680, 
         36.279707, -102.568359
       hong_kong = Dropzone::Item.distance_between 22.396428, 114.109497,
        22.408489, 113.906937

       expect(nyc_to_london.round).to eq(5570224)
       expect(texas.round).to eq(627363)
       expect(hong_kong.round).to eq(20867)
    end
  end

  describe 'finders' do 
    after{ clear_blockchain! }

    before do
      # < 20 km from shinjuku
      fuchu_id = Dropzone::Item.sham!(:build, :description => 'Fuchu', 
        :radius => 20_000, :latitude => 35.688533, 
        :longitude => 139.471436).save! test_privkey

      increment_block_height!

      # 36 km from shinjuku
      Dropzone::Item.sham!(:build, :description => 'Abiko', :radius => 20_000,
        :latitude => 35.865683, :longitude => 140.031738).save! TESTER2_PRIVATE_KEY

      # 3 km from shinjuku 
      Dropzone::Item.sham!(:build, :description => 'Nakano', :radius => 20_000,
        :latitude => 35.708050, :longitude => 139.664383).save! TESTER3_PRIVATE_KEY

      increment_block_height!

      # 38.5 km from shinjuku 
      Dropzone::Item.sham!(:build, :description => 'Chiba', :radius => 20_000,
        :latitude => 35.604835, :longitude => 140.105209).save! test_privkey

      # This shouldn't actually be returned, since it's an update, and
      # find_creates_since_block only looks for creates:
      Dropzone::Item.new(create_txid: fuchu_id, 
        description: 'xyz').save! test_privkey
    end

    it ".find_creates_since_block()" do
      items = Dropzone::Item.find_creates_since_block block_height, block_height

      expect(items.length).to eq(4)
      expect(items.collect(&:description)).to eq(['Chiba', 'Nakano', 'Abiko', 
        'Fuchu'])
    end

    it ".find_in_radius()" do
      # Twenty km around Shinjuku:
      items = Dropzone::Item.find_in_radius block_height, block_height,
        35.689487, 139.691706, 20_000
      expect(items.length).to eq(2)
      expect(items.collect(&:description)).to eq(['Nakano', 'Fuchu'])
    end
  end

  describe "problematic decodes" do
    # @Junseth Issue #18:
    # txid: 73cfb35e1e6bb31b3ddffb41322c46f155970bfae3c40385b171ba02f88985a0
    it "Fails to decode invalid radius transaction" do
      tx_id = '73cfb35e1e6bb31b3ddffb41322c46f155970bfae3c40385b171ba02f88985a0'
      tx_hex = '01000000017ecf3bcdd734881a466b2fcb8ff9c602ff96190ecbda86fadd2'+
        'f907bfeb7f22a020000006b4830450221008b343292dbc140379bdcdad613fd8bd2b'+
        'e739147a10f57b5dd3f6c23afe818e402201edbe946b27a0183a3d98ce61f0f88872'+
        '1330c8694f8b700448d8c902317db4c0121031bf0b235cb0cefcf8c9c299f3009257'+
        '04d6da7e6b448bd185c80d28f1216ef44ffffffff0536150000000000001976a9141'+
        'f319c85b0cb2667e09fc4388dc209b0c4a240d388ac3615000000000000695121039'+
        'fb679314a062d887537ad75b6e056bd4020807e56d742cd0aa77bf890aea5e121027'+
        'fdb01ce03a72c67551b80e18a612a4789a6b3d168e4ca883dd7236d2c19b60f21031'+
        'bf0b235cb0cefcf8c9c299f300925704d6da7e6b448bd185c80d28f1216ef4453ae3'+
        '615000000000000695121039fb679166a6b5f8f5951a77ef1a258a50368c22f5dd15'+
        '9dc07a824a29dacaa0a21026bdb01e004a62f2f7b1cceecde622814d2fdb4d63ca5c'+
        '8d1668e2d78263defb421031bf0b235cb0cefcf8c9c299f300925704d6da7e6b448b'+
        'd185c80d28f1216ef4453ae361500000000000069512103aeb679311f267c896372c'+
        '86b8b823adc234ba05d34b631a868c61794bdcdc48221030ffb228a71c85c4a0f74e'+
        'e84aa16582efdd2d6bf488ba4a849bf464d4a6bd93021031bf0b235cb0cefcf8c9c2'+
        '99f300925704d6da7e6b448bd185c80d28f1216ef4453ae2cf41100000000001976a'+
        '9142bb8d14d65d316483e24da5512bfd2a977da85ea88ac00000000'

      tx = Bitcoin::P::Tx.new [tx_hex].pack('H*')

      record = Counterparty::TxDecode.new tx,
        prefix: Dropzone::BitcoinConnection::PREFIX

      item = Dropzone::Item.new(data: record.data, 
        receiver_addr: record.receiver_addr, 
        txid: tx_id, sender_addr: record.sender_addr)

      expect(item.valid?).to eq(false)
      expect(item.errors.count).to eq(3)
      expect(item.errors.on(:latitude)).to eq(['is not a number'])
      expect(item.errors.on(:longitude)).to eq(['is not a number'])
      expect(item.errors.on(:radius)).to eq(['is not a number'])

    end
  end

  describe "versioning" do
    ITEM_UPDATE_ATTRS = {description: 'xyz', create_txid: 
      'e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3'}

    # The max specification encoded transaction ID's as hex-strings which was
    # a poor use of space, and confusing. Nonetheless, legacy data should be
    # supported:
    it 'encodes v0 payments with string transaction ids' do
      block_height = Dropzone::MessageBase::ENCODING_VERSION_1_BLOCK-1

      item = Dropzone::Item.new(ITEM_UPDATE_ATTRS.merge(
        block_height: block_height))

      data = item.to_transaction[:data].bytes
      
      expect(data.shift(6).collect(&:chr).join).to eq('ITUPDT')
      expect(data.shift(2).collect(&:chr).join).to eq("\x01d")
      expect(data.shift(4).collect(&:chr).join).to eq("\x03xyz")
      expect(data.shift(2).collect(&:chr).join).to eq("\x01t")
      expect(data.shift(1).first).to eq(64)
      # This was the problem (at 64 bytes instead of 32): 
      expect(data.shift(64).collect(&:chr).join).to eq(
        "e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3")

      #  Now decode this payment:
      item = Dropzone::Item.new data: item.to_transaction[:data], 
        block_height: block_height,
        receiver_addr: ITEM_UPDATE_ATTRS[:receiver_addr]
      expect(item.description).to eq(ITEM_UPDATE_ATTRS[:description])
      expect(item.create_txid).to eq(ITEM_UPDATE_ATTRS[:create_txid])
    end

    it 'encodes v1 payments with string transaction ids' do
      item = Dropzone::Item.new(ITEM_UPDATE_ATTRS)

      data = item.to_transaction[:data].bytes
      
      expect(data.shift(6).collect(&:chr).join).to eq('ITUPDT')
      expect(data.shift(2).collect(&:chr).join).to eq("\x01d")
      expect(data.shift(4).collect(&:chr).join).to eq("\x03xyz")
      expect(data.shift(2).collect(&:chr).join).to eq("\x01t")
      expect(data.shift(1).first).to eq(32)
      # This was the problem (at 64 bytes instead of 32): 
      expect(data.shift(32).collect(&:chr).join).to eq([
        'e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3'
        ].pack('H*'))

      #  Now decode this payment:
      item = Dropzone::Item.new data: item.to_transaction[:data], 
        block_height: block_height,
        receiver_addr: ITEM_UPDATE_ATTRS[:receiver_addr]
      expect(item.description).to eq(ITEM_UPDATE_ATTRS[:description])
      expect(item.create_txid).to eq(ITEM_UPDATE_ATTRS[:create_txid])
    end
  end
end
