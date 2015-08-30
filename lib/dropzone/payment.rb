module Dropzone
  class Payment < MessageBase
    attr_message d: :description, t: :invoice_txid
    attr_message_int q: :delivery_quality,  p: :product_quality, 
      c: :communications_quality

    def invoice
      @invoice ||= Invoice.find invoice_txid if invoice_txid
    end

    message_type 'INPAID'
  end

  class Payment::Validator < ValidatorBase
    include MessageValidations
    include BillingValidations

    validates :message_type, format: /\AINPAID\Z/

    validates_if_present :description, is_string: true
    validates_if_present :invoice_txid, is_string: true

    [:delivery_quality,:product_quality,:communications_quality ].each do |attr|
      validates_if_present attr, integer: true, inclusion: 0..8
    end
    
    validate :must_have_corresponding_invoice

    def must_have_corresponding_invoice(payment)
      invoice = payment.invoice

      errors.add :invoice_txid, "can't be found" if ( invoice.nil? || 
        !invoice.valid? || (invoice.sender_addr != payment.receiver_addr) )
    end
  end
end
