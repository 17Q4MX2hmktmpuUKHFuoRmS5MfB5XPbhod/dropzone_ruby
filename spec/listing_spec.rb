#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/item'
require_relative 'sham/seller'

describe Dropzone::Listing do
  include_context 'globals'

  describe "accessors" do
    after{ clear_blockchain! }

    it "compiles a simple profile" do
      Dropzone::Seller.sham!(:build).save!(test_privkey)

      # Block height is now 1:
      increment_block_height!

      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      # Block height is now 2:
      increment_block_height!

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_truthy
      expect(listing.description).to eq("Item Description")
      expect(listing.price_currency).to eq('BTC')
      expect(listing.price_in_units).to eq(100_000_000)
      expect(listing.expiration_in).to eq(6)
      expect(listing.expiration_at).to eq(
        Dropzone::MessageBase::ENCODING_VERSION_1_BLOCK+7)
      expect(listing.latitude).to eq(51.500782)
      expect(listing.longitude).to eq(-0.124669)
      expect(listing.radius).to eq(1000)
      expect(listing.addr).to eq(test_pubkey)
    end

    it "combines attributes from mulitple messages" do
      Dropzone::Seller.sham!(:build).save!(test_privkey)

      increment_block_height!

      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      increment_block_height!

      Dropzone::Item.new(create_txid: tx_id, receiver_addr: test_pubkey,
        description: 'xyz', price_in_units: 99_999_999, expiration_in: 12
       ).save!(test_privkey)

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_truthy
      expect(listing.description).to eq("xyz")
      expect(listing.price_currency).to eq('BTC')
      expect(listing.price_in_units).to eq(99_999_999)
      expect(listing.expiration_in).to eq(12)
      expect(listing.expiration_at).to eq(
        Dropzone::MessageBase::ENCODING_VERSION_1_BLOCK+13)
      expect(listing.latitude).to eq(51.500782)
      expect(listing.longitude).to eq(-0.124669)
      expect(listing.radius).to eq(1000)
      expect(listing.addr).to eq(test_pubkey)
    end

    it "ignores incorrect txid's" do
      Dropzone::Seller.sham!(:build).save!(test_privkey)

      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      Dropzone::Item.new(create_txid: tx_id, receiver_addr: test_pubkey,
        description: 'xyz' ).save!(test_privkey)

      Dropzone::Item.new(create_txid: 'non-existing-txid', 
        receiver_addr: test_pubkey, description: '123' ).save!(test_privkey)

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_truthy
      expect(listing.description).to eq("xyz")
    end

    it "ignores messages from invalid senders" do
      Dropzone::Seller.sham!(:build).save!(test_privkey)

      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      Dropzone::Item.new(create_txid: tx_id, receiver_addr: test_pubkey,
        description: 'xyz' ).save!(TESTER2_PRIVATE_KEY)

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_truthy
      expect(listing.description).to eq("Item Description")
    end
  end

  describe "validations" do
    after{ clear_blockchain! }

    it "Cannot be created from nonsense" do
      listing = Dropzone::Listing.new 'non-existing-txid'

      expect(listing.valid?).to be_falsey
      expect(listing.errors.count).to eq(2)
      expect(listing.errors.on(:create_item)).to eq(['invalid or missing'])
      expect(listing.errors.on(:seller_profile)).to eq(['invalid or missing'])
    end

    it "Cannot be created from an update" do
      Dropzone::Seller.sham!(:build).save!(test_privkey)

      tx_id = Dropzone::Item.new(create_txid: 'non-existing-txid', 
        receiver_addr: test_pubkey, description: '123' ).save!(test_privkey)

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_falsey
      expect(listing.errors.count).to eq(2)
      expect(listing.errors.on(:create_item)).to eq(['invalid or missing'])
      expect(listing.errors.on(:seller_profile)).to eq(['invalid or missing'])
    end

    it "requires seller declaration" do
      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_falsey
      expect(listing.errors.count).to eq(1)
      expect(listing.errors.on(:seller_profile)).to eq(['invalid or missing'])
    end

    it "requires active seller" do
      # Standard Seller:
      Dropzone::Seller.sham!(:build).save! test_privkey 

      tx_id = Dropzone::Item.sham!(:build).save!(test_privkey)

      # Seller Deactivates his account:
      Dropzone::Seller.new( receiver_addr: test_pubkey,
        transfer_pkey: 0).save! test_privkey

      listing = Dropzone::Listing.new tx_id

      expect(listing.valid?).to be_falsey
      expect(listing.errors.count).to eq(1)
      expect(listing.errors.on(:seller_profile)).to eq(['invalid or missing'])
    end

  end
end
