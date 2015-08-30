#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/invoice'
require_relative 'sham/payment'

describe Dropzone::Invoice do
  include_context 'globals'

  describe "defaults" do
    it "has accessors" do
      invoice = Dropzone::Invoice.sham!(:build)

      expect(invoice.expiration_in).to eq(6)
      expect(invoice.amount_due).to eq(100_000_000)
      expect(invoice.receiver_addr).to eq(test_pubkey)
    end
  end

  describe "serialization" do 
    it "serializes to_transaction" do
      expect(Dropzone::Invoice.sham!(:build).to_transaction).to eq({
        tip: 20000, receiver_addr: test_pubkey, 
        data: "INCRTE\x01p\xFE\x00\xE1\xF5\x05\x01e\x06".force_encoding('ASCII-8BIT') })
    end
  end

  describe "database" do
    after{ clear_blockchain! }

    it ".save() and .find()" do
      invoice_id = Dropzone::Invoice.sham!(:build).save!(test_privkey)
      expect(invoice_id).to be_kind_of(String)
      
      invoice = Dropzone::Invoice.find invoice_id

      expect(invoice.expiration_in).to eq(6)
      expect(invoice.amount_due).to eq(100_000_000)
      expect(invoice.receiver_addr).to eq(test_pubkey)
    end
  end

  describe "associations" do
    # It's a bit obtuse that there can be support for multiple payments
    # but this should nonetheless be support to aid with reputation analysis
    it "has_many payments" do 
      invoice_id = Dropzone::Invoice.sham!(:build, 
        receiver_addr: TESTER2_PUBLIC_KEY).save!(test_privkey)

      Dropzone::Payment.sham!(:build, invoice_txid: invoice_id,
        description: 'abc', receiver_addr: test_pubkey ).save! TESTER2_PRIVATE_KEY

      increment_block_height!

      Dropzone::Payment.sham!(:build, invoice_txid: invoice_id, 
        description: 'xyz', receiver_addr: test_pubkey ).save! TESTER2_PRIVATE_KEY

      invoice = Dropzone::Invoice.find invoice_id
      expect(invoice.payments.length).to eq(2)
      expect(invoice.payments.collect(&:description)).to eq(['xyz','abc'])
    end
  end

  describe "validations" do 
    it "validates default build" do
      expect(Dropzone::Invoice.sham!(:build).valid?).to eq(true)
    end

    it "validates minimal invoice" do
      invoice = Dropzone::Invoice.new receiver_addr: test_pubkey

      expect(invoice.valid?).to eq(true)
    end

    it "expiration_in must be numeric" do
      invoice = Dropzone::Invoice.sham! expiration_in: 'abc'

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(2)
      expect(invoice.errors.on(:expiration_in)).to eq(
        ['is not a number', "must be greater than or equal to 0"])
    end

    it "expiration_in must be gt 0" do
      invoice = Dropzone::Invoice.sham! expiration_in: -1

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(1)
      expect(invoice.errors.on(:expiration_in)).to eq(
        ['must be greater than or equal to 0'])
    end

    it "amount_due must be numeric" do
      invoice = Dropzone::Invoice.sham! amount_due: 'abc'

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(2)
      expect(invoice.errors.on(:amount_due)).to eq(
        ['is not a number', "must be greater than or equal to 0"])
    end

    it "amount_due must be gt 0" do
      invoice = Dropzone::Invoice.sham! amount_due: -1

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(1)
      expect(invoice.errors.on(:amount_due)).to eq(
        ['must be greater than or equal to 0'])
    end

    it "validates output address must be present" do
      invoice = Dropzone::Invoice.sham! receiver_addr: nil

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(1)
      expect(invoice.errors.on(:receiver_addr)).to eq(['is not present'])
    end

    it "declaration must not be addressed to self" do
      id = Dropzone::Invoice.sham!(receiver_addr: test_pubkey).save! test_privkey

      invoice = Dropzone::Invoice.find id

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(1)
      expect(invoice.errors.on(:receiver_addr)).to eq(['matches sender_addr'])
    end

  end
end
