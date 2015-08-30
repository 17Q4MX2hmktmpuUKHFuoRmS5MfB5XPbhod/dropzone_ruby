#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/buyer'

describe Dropzone::Buyer do
  include_context 'globals'

  describe "defaults" do
    it "has accessors" do
      buyer = Dropzone::Buyer.sham!(:build)

      expect(buyer.description).to eq("abc")
      expect(buyer.alias).to eq("Satoshi")
      expect(buyer.transfer_pkey).to be_nil
      expect(buyer.receiver_addr).to eq(test_pubkey)
      expect(buyer.sender_addr).to eq(nil)
    end
  end

  describe "serialization" do 
    it "serializes to_transaction" do
      expect(Dropzone::Buyer.sham!.to_transaction).to eq({
        tip: 20000,
        receiver_addr: test_pubkey, 
        data: "BYUPDT\u0001d\u0003abc\u0001a\aSatoshi".force_encoding('ASCII-8BIT') })
    end
  end

  describe "database" do
    after{ clear_blockchain! }

    it ".save() and .find()" do
      buyer = Dropzone::Buyer.sham!(:build).save!(test_privkey)
      expect(buyer).to be_kind_of(String)

      buyer = Dropzone::Buyer.find buyer
      expect(buyer.description).to eq("abc")
      expect(buyer.alias).to eq("Satoshi")
      expect(buyer.transfer_pkey).to be_nil
      expect(buyer.receiver_addr).to eq(test_pubkey)
      expect(buyer.sender_addr).to eq(test_pubkey)
    end
  end

  describe "validations" do 
    it "validates default build" do
      expect(Dropzone::Buyer.sham!(:build).valid?).to eq(true)
    end

    it "validates minimal buyer" do
      buyer = Dropzone::Buyer.new receiver_addr: test_pubkey

      expect(buyer.valid?).to eq(true)
    end

    it "validates output address must be present" do
      buyer = Dropzone::Buyer.sham! receiver_addr: nil

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(1)
      expect(buyer.errors.on(:receiver_addr)).to eq(['is not present'])
    end

    it "description must be string" do
      buyer = Dropzone::Buyer.sham! description: 1

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(1)
      expect(buyer.errors.on(:description)).to eq(['is not a string'])
    end

    it "alias must be string" do
      buyer = Dropzone::Buyer.sham! alias: 1

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(1)
      expect(buyer.errors.on(:alias)).to eq(['is not a string'])
    end

    it "transfer_pkey must be pkey" do
      buyer = Dropzone::Buyer.sham! transfer_pkey: 'bad-key'

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(2)
      expect(buyer.errors.on(:transfer_pkey)).to eq(['does not match receiver_addr',
        'is not a public key' ])
    end

    it "transfer_pkey must be receiver_addr" do
      buyer = Dropzone::Buyer.sham! transfer_pkey: TESTER2_PUBLIC_KEY

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(1)
      expect(buyer.errors.on(:transfer_pkey)).to eq(['does not match receiver_addr'])
    end

    it "declaration must be addressed to self" do
      id = Dropzone::Buyer.sham!(receiver_addr: TESTER2_PUBLIC_KEY).save! test_privkey

      buyer = Dropzone::Buyer.find id

      expect(buyer.valid?).to eq(false)
      expect(buyer.errors.count).to eq(1)
      expect(buyer.errors.on(:receiver_addr)).to eq(['does not match sender_addr'])
    end
  end

  
end
