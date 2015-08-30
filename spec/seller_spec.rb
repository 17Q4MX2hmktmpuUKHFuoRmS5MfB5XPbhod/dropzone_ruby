#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/seller'

describe Dropzone::Seller do
  include_context 'globals'

  describe "defaults" do
    it "has accessors" do
      seller = Dropzone::Seller.sham!(:build)

      expect(seller.description).to eq("abc")
      expect(seller.alias).to eq("Satoshi")
      expect(seller.communications_pkey).to eq('n3EMs5L3sHcZqRy35cmoPFgw5AzAtWSDUv')
      expect(seller.transfer_pkey).to be_nil
      expect(seller.receiver_addr).to eq(test_pubkey)
      expect(seller.sender_addr).to eq(nil)
    end
  end

  describe "serialization" do 
    it "serializes to_transaction" do
      expect(Dropzone::Seller.sham!.to_transaction).to eq({
        tip: 20000,
        receiver_addr: test_pubkey, 
        data: "SLUPDT\x01d\x03abc\x01a\aSatoshi\x01p\x14\xEE/^\xDE\x81(1\x8F-\x8C3S_\x95\xEB\xD0\xB13\xB0F".force_encoding('ASCII-8BIT') })
    end
  end

  describe "database" do
    after{ clear_blockchain! }

    it ".save() and .find()" do
      seller_id = Dropzone::Seller.sham!(:build).save!(test_privkey)
      expect(seller_id).to be_kind_of(String)

      seller = Dropzone::Seller.find seller_id
      expect(seller.description).to eq("abc")
      expect(seller.alias).to eq("Satoshi")
      expect(seller.communications_pkey).to eq('n3EMs5L3sHcZqRy35cmoPFgw5AzAtWSDUv')
      expect(seller.transfer_pkey).to be_nil
      expect(seller.receiver_addr).to eq(test_pubkey)
      expect(seller.sender_addr).to eq(test_pubkey)
    end
  end

  describe "validations" do 
    it "validates default build" do
      expect(Dropzone::Seller.sham!(:build).valid?).to eq(true)
    end

    it "validates minimal seller" do
      seller = Dropzone::Seller.new( 
        receiver_addr: test_pubkey)

      expect(seller.valid?).to eq(true)
    end

    it "validates output address must be present" do
      seller = Dropzone::Seller.sham! receiver_addr: nil

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:receiver_addr)).to eq(['is not present'])
    end

    it "description must be string" do
      seller = Dropzone::Seller.sham! description: 1

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:description)).to eq(['is not a string'])
    end

    it "alias must be string" do
      seller = Dropzone::Seller.sham! alias: 1

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:alias)).to eq(['is not a string'])
    end

    it "communications_pkey must be public_key" do
      seller = Dropzone::Seller.sham! communications_pkey: 'Not-a-key'

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:communications_pkey)).to eq(['is not a public key'])
    end

    it "transfer_pkey must be public_key" do
      seller = Dropzone::Seller.sham! transfer_pkey: 'Not-a-key'

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(2)
      expect(seller.errors.on(:transfer_pkey)).to eq(["does not match receiver_addr",
        'is not a public key' ])
    end

    it "transfer_pkey must be receiver_addr" do
      seller = Dropzone::Seller.sham! transfer_pkey: TESTER2_PUBLIC_KEY

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:transfer_pkey)).to eq(['does not match receiver_addr'])
    end

    it "declaration must be addressed to self" do
      id = Dropzone::Seller.sham!(receiver_addr: TESTER2_PUBLIC_KEY).save! test_privkey

      seller = Dropzone::Seller.find id

      expect(seller.valid?).to eq(false)
      expect(seller.errors.count).to eq(1)
      expect(seller.errors.on(:receiver_addr)).to eq(['does not match sender_addr'])
    end

  end
  
end
