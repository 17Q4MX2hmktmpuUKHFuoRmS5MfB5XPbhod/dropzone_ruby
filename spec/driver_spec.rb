#encoding: utf-8
require_relative 'spec_helper'

describe BlockCypher do
  MUTABLE_ITEM_ID = 'bf01750dab74209fb93e51c659504bb3d155eba7301467f4304e73766881b793'
  GENESIS_ITEM_TXID = '6a9013b8684862e9ccfb527bf8f5ea5eb213e77e3970ff2cd8bbc22beb7cebfb'
  GENESIS_ITEM_DESC = ('One Bible in fair condition. Conveys the truth of the' +
    ' word of God with little difficulty, even still. Secrets within. Conveys' +
    ' messages of love, peace, self-control, and all the fruits of the Holy' +
    " Spirit. A copy of the divine revelation, it is this seller\xE2\x80\x99s sincere" +
    ' belief that this book will keep you from suffering for eternity at the' +
    ' hands of evil. A perfect purchase for the person who already has' +
    ' "everything."').force_encoding('ASCII-8BIT')
  MAX_ADDR = '17Q4MX2hmktmpuUKHFuoRmS5MfB5XPbhod'

  before(:all) do
    @old_blockchain = Dropzone::RecordBase.blockchain
  end

  after(:all) do
    Dropzone::RecordBase.blockchain = @old_blockchain
  end

  let(:mainnet){ 
    Dropzone::BitcoinConnection.new :bitcoin, :bitcoin => BlockCypher.new
  }

  let(:testnet){ 
    Dropzone::BitcoinConnection.new :testnet3, :bitcoin => BlockCypher.new(true)
  }

  it 'fetches immutable item by id' do
    Dropzone::RecordBase.blockchain = mainnet

    genesis_item = Dropzone::Item.find GENESIS_ITEM_TXID

    expect(genesis_item.txid).to eq(GENESIS_ITEM_TXID)
    expect(genesis_item.block_height).to eq(371812)
    expect(genesis_item.description).to eq(GENESIS_ITEM_DESC)
    expect(genesis_item.price_currency).to eq('BTC')
    expect(genesis_item.price_in_units).to eq(1000000000)
    expect(genesis_item.expiration_in).to be_nil
    expect(genesis_item.latitude).to eq(37.774836)
    expect(genesis_item.longitude).to eq(-122.224081)
    expect(genesis_item.radius).to eq(100)
    expect(genesis_item.receiver_addr).to eq(
      '1DZ127774836X57775919XXX1XXXXGEZDD')
    expect(genesis_item.sender_addr).to eq(
      '17Q4MX2hmktmpuUKHFuoRmS5MfB5XPbhod')
  end

  it 'fetches mutable item by id' do
    Dropzone::RecordBase.blockchain = testnet

    item = Dropzone::Item.find MUTABLE_ITEM_ID

    expect(item.txid).to eq(MUTABLE_ITEM_ID)
    expect(item.description).to eq('Item Description')
    expect(item.price_currency).to eq('BTC')
    expect(item.price_in_units).to eq(100000000)
    expect(item.expiration_in).to eq(6)
    expect(item.latitude).to eq(51.500782)
    expect(item.longitude).to eq(-0.124669)
    expect(item.radius).to eq(1000)
    expect(item.receiver_addr).to eq(
      'mfZ1415XX782179875331XX1XXXXXgtzWu')
    expect(item.sender_addr).to eq('mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw')
  end

  it 'fetches messagesByAddr' do
    Dropzone::RecordBase.blockchain = mainnet

    max_profile = Dropzone::SellerProfile.new MAX_ADDR

    expect(max_profile.valid?).to be_truthy
    expect(max_profile.description).to eq("Creator of the Protocol.")
    expect(max_profile.alias).to eq("Miracle Max")
    expect(max_profile.communications_pkey).to eq('mw8Ge8HDBStKyn8u4LTkUwueheFNhuo7Ch')
    expect(max_profile.addr).to eq(MAX_ADDR)
    expect(max_profile.active?).to be_truthy
  end

  it 'fetches messagesInBlock' do
    Dropzone::RecordBase.blockchain = mainnet

    items = Dropzone::Item.find_creates_since_block 371812, 0

    expect(items.length).to eq(1)
    expect(items[0].txid).to eq(GENESIS_ITEM_TXID)
    expect(items[0].block_height).to eq(371812)
    expect(items[0].description).to eq(GENESIS_ITEM_DESC)
    expect(items[0].price_currency).to eq('BTC')
    expect(items[0].price_in_units).to eq(1000000000)
    expect(items[0].expiration_in).to be_nil
    expect(items[0].latitude).to eq(37.774836)
    expect(items[0].longitude).to eq(-122.224081)
    expect(items[0].radius).to eq(100)
    expect(items[0].receiver_addr).to eq(
      '1DZ127774836X57775919XXX1XXXXGEZDD')
    expect(items[0].sender_addr).to eq(
      '17Q4MX2hmktmpuUKHFuoRmS5MfB5XPbhod')
  end

  it 'gets the address balance' do
    puts BlockCypher.new.getbalance(MAX_ADDR).inspect
  end
end
