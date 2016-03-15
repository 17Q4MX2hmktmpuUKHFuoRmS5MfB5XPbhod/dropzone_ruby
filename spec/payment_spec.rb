#encoding: utf-8
require_relative 'spec_helper'
require_relative 'sham/payment'

describe Dropzone::Payment do
  include_context 'globals'

  describe "defaults" do
    it "has accessors" do
      payment = Dropzone::Payment.sham!(:build)

      expect(payment.description).to eq("abc")
      expect(payment.invoice_txid).to be_kind_of(String)
      expect(payment.delivery_quality).to eq(8)
      expect(payment.product_quality).to eq(8)
      expect(payment.communications_quality).to eq(8)
      expect(payment.receiver_addr).to eq(TESTER2_PUBLIC_KEY)
      expect(payment.sender_addr).to eq(nil)
    end
  end

  describe "serialization" do 
    it "serializes to_transaction" do
      expect(Dropzone::Payment.sham!(invoice_txid: '2').to_transaction).to eq({
        tip: 20000, receiver_addr: TESTER2_PUBLIC_KEY, 
        data: "INPAID\u0001d\u0003abc\u0001t\u00012\u0001q\b\u0001p\b\u0001c\b".force_encoding('ASCII-8BIT') })
    end
  end

  describe "database" do
    after{ clear_blockchain! }

    it ".save() and .find()" do
      payment_id = Dropzone::Payment.sham!(:build).save! test_privkey
      expect(payment_id).to be_kind_of(String)

      payment = Dropzone::Payment.find payment_id

      expect(payment.description).to eq("abc")
      expect(payment.invoice_txid).to be_kind_of(String)
      expect(payment.delivery_quality).to eq(8)
      expect(payment.product_quality).to eq(8)
      expect(payment.communications_quality).to eq(8)
      expect(payment.receiver_addr).to eq(TESTER2_PUBLIC_KEY)
      expect(payment.sender_addr).to eq(test_pubkey)
    end
  end

  describe "associations" do
    it "has_one invoice" do 
      payment_id = Dropzone::Payment.sham!(:build).save! test_privkey

      payment = Dropzone::Payment.find payment_id
      expect(payment.invoice.expiration_in).to eq(6)
      expect(payment.invoice.amount_due).to eq(100_000_000)
      expect(payment.invoice.receiver_addr).to eq(test_pubkey)
    end
  end

  describe "validations" do 
    after{ clear_blockchain! }

    it "validates default build" do
      expect(Dropzone::Payment.sham!(:build).valid?).to eq(true)
    end

    it "validates minimal payment" do
      invoice_id = Dropzone::Invoice.sham!(:build).save! TESTER2_PRIVATE_KEY

      payment = Dropzone::Payment.new receiver_addr: TESTER2_PUBLIC_KEY, 
        invoice_txid: invoice_id

      expect(payment.valid?).to eq(true)
    end

    it "validates output address must be present" do
      payment = Dropzone::Payment.sham! receiver_addr: nil

      expect(payment.valid?).to eq(false)
      expect(payment.errors.count).to eq(2)
      expect(payment.errors.on(:receiver_addr)).to eq(['is not present'])
      expect(payment.errors.on(:invoice_txid)).to eq(["can't be found"])
    end

    it "description must be string" do
      payment = Dropzone::Payment.sham! description: 1

      expect(payment.valid?).to eq(false)
      expect(payment.errors.count).to eq(1)
      expect(payment.errors.on(:description)).to eq(['is not a string'])
    end

    it "invoice_txid must be string" do
      payment = Dropzone::Payment.sham! invoice_txid: 500

      expect(payment.valid?).to eq(false)
      expect(payment.errors.count).to eq(2)
      expect(payment.errors.on(:invoice_txid)).to eq(['is not a string', 
        "can't be found"])
    end
    
    [:delivery_quality,:product_quality,:communications_quality ].each do |rating_attr|
      it "%s must be numeric" % rating_attr.to_s do
        payment = Dropzone::Payment.sham! rating_attr => 'abc'

        expect(payment.valid?).to eq(false)
        expect(payment.errors.count).to eq(2)
        expect(payment.errors.on(rating_attr)).to eq(
          ['is not a number', "is not in set: 0..8"])
      end

      it "%s must be between 0 and 8" % rating_attr.to_s do
        payment = Dropzone::Payment.sham! rating_attr => 9

        expect(payment.valid?).to eq(false)
        expect(payment.errors.count).to eq(1)
        expect(payment.errors.on(rating_attr)).to eq(['is not in set: 0..8'])
      end
    end

    it "validates invoice existence" do
      payment = Dropzone::Payment.sham! invoice_txid: 'non-existant-id'
      
      expect(payment.valid?).to eq(false)
      expect(payment.errors.count).to eq(1)
      expect(payment.errors.on(:invoice_txid)).to eq(["can't be found"])
    end

    it "declaration must not be addressed to self" do
      id = Dropzone::Invoice.sham!(receiver_addr: test_pubkey).save! test_privkey

      invoice = Dropzone::Invoice.find id

      expect(invoice.valid?).to eq(false)
      expect(invoice.errors.count).to eq(1)
      expect(invoice.errors.on(:receiver_addr)).to eq(['matches sender_addr'])
    end

    it "must be addressed to transaction_id owner" do
      # The sham'd Invoice is addressed to TESTER2_PUBLIC_KEY
      payment_id = Dropzone::Payment.sham!(
        receiver_addr: TESTER_PUBLIC_KEY).save! TESTER3_PRIVATE_KEY

      payment = Dropzone::Payment.find payment_id

      expect(payment.valid?).to eq(false)
      expect(payment.errors.count).to eq(1)
      expect(payment.errors.on(:invoice_txid)).to eq(["can't be found"])
    end
  end

  describe "versioning" do
    JUNSETH_PAYMENT_ATTRS = {communications_quality: 8,
        receiver_addr: 'mjW8kesgoKAswSEC8dGXa7c3qVa5ixiG4M',
        description: 
          "Good communication with seller. Fast to create invoice. Looking "+
          "forward to getting hat. A+++ Seller",
        invoice_txid: 
          "e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3"}

    it 'encodes v0 payments with string transaction ids' do
      # TODO: Grab the actual block this was on:
      block_height = Dropzone::MessageBase::ENCODING_VERSION_1_BLOCK-1

      payment = Dropzone::Payment.new JUNSETH_PAYMENT_ATTRS.merge({
        block_height: block_height})

      data = payment.to_transaction[:data].bytes
      
      expect(data.shift(6).collect(&:chr).join).to eq('INPAID')
      expect(data.shift(102).collect(&:chr).join).to eq(
        "\x01dcGood communication with seller. Fast to create invoice. Looking"+
        " forward to getting hat. A+++ Seller")
      expect(data.shift(2).collect(&:chr).join).to eq("\x01t")
      expect(data.shift(1).first).to eq(64)

      # This was the problem (at 64 bytes instead of 32): 
      expect(data.shift(64).collect(&:chr).join).to eq(
        "e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3")

      expect(data.shift(3).collect(&:chr).join).to eq("\x01c\b")

      #  Now decode this payment:
      payment = Dropzone::Payment.new data: payment.to_transaction[:data], 
        block_height: block_height,
        receiver_addr: JUNSETH_PAYMENT_ATTRS[:receiver_addr]
      expect(payment.description).to eq(JUNSETH_PAYMENT_ATTRS[:description])
      expect(payment.invoice_txid).to eq(JUNSETH_PAYMENT_ATTRS[:invoice_txid])
      expect(payment.receiver_addr).to eq(JUNSETH_PAYMENT_ATTRS[:receiver_addr])
    end

    it 'encodes v1 payments with string transaction ids' do
      payment = Dropzone::Payment.new JUNSETH_PAYMENT_ATTRS

      data = payment.to_transaction[:data].bytes
      
      expect(data.shift(6).collect(&:chr).join).to eq('INPAID')
      expect(data.shift(102).collect(&:chr).join).to eq(
        "\x01dcGood communication with seller. Fast to create invoice. Looking"+
        " forward to getting hat. A+++ Seller")
      expect(data.shift(2).collect(&:chr).join).to eq("\x01t")
      expect(data.shift(1).first).to eq(32)

      # This is the more efficient format (32 bytes): 
      expect(data.shift(32).collect(&:chr).join).to eq([
        'e5a564d54ab9de50fc6eba4176991b7eb8f84bbeca3482ca032c12c1c0050ae3'
        ].pack('H*'))

      expect(data.shift(3).collect(&:chr).join).to eq("\x01c\b")
      
      #  Now decode this payment:
      payment = Dropzone::Payment.new data: payment.to_transaction[:data], 
        receiver_addr: JUNSETH_PAYMENT_ATTRS[:receiver_addr]
      expect(payment.description).to eq(JUNSETH_PAYMENT_ATTRS[:description])
      expect(payment.invoice_txid).to eq(JUNSETH_PAYMENT_ATTRS[:invoice_txid])
      expect(payment.receiver_addr).to eq(JUNSETH_PAYMENT_ATTRS[:receiver_addr])
    end
  end
end
