#encoding: utf-8
require_relative 'spec_helper'

describe SoChain do
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
    Dropzone::BitcoinConnection.new :bitcoin, :bitcoin => SoChain.new
  }

  let(:testnet){ 
    Dropzone::BitcoinConnection.new :testnet3, :bitcoin => SoChain.new(true)
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
    expect(SoChain.new.getbalance(MAX_ADDR)).to eq("0.28642221")
  end

  it 'gets the utxos' do
    utxos = SoChain.new.listunspent(MAX_ADDR)
    utxos.each{|u| u.delete('confirmations') }

    expect(utxos).to eq([ 
      {"amount"=>"0.00500000", "n"=>0,
       "tx"=>"620254a9f73580e7c47341b7d2271f5bfdf9888db83840f2c934feb057b3b27f"}, 
      {"amount"=>"0.00103648", "n"=>0,
       "tx"=>"2bad8be67ca4c9d92acd8cc41b241c0a3658aa1899f6b71bde7db4498c8e632f"},
      {"amount"=>"0.00005430", "n"=>0,
       "tx"=>"3fa7a0d2d2913b15335827334e18c2980bfe86d5ef30302565569ef0b021e575"},
      {"amount"=>"0.00005430", "n"=>0,
       "tx"=>"8442b2b772a2aad035755a92769bca097c013d2dd4785590168f4579bfca9804"}, 
      {"amount"=>"0.00005430", "n"=>0,
       "tx"=>"5d8430ff52b93ac65b131d605cfde188c8dfb246ffff6dc8462e9c616fbec36f"}, 
      {"amount"=>"0.01838550", "n"=>2,
       "tx"=>"5d8430ff52b93ac65b131d605cfde188c8dfb246ffff6dc8462e9c616fbec36f"}, 
      {"amount"=>"0.26183733", "n"=>0,
       "tx"=>"9cd36b5cb5adc8b22c1aee82937c7bff71db0dff2ef94c136ca13afc6016fb1e"}
      ])
  end
end
