module Dropzone
  class Invoice < MessageBase
    attr_message_int p: :amount_due, e: :expiration_in

    message_type 'INCRTE'

    def payments
      blockchain.messages_by_addr(sender_addr, type: 'INPAID', 
        start_block: block_height).find_all{|p| p.invoice_txid == txid }
    end
  end

  class Invoice::Validator < ValidatorBase
    include MessageValidations
    include BillingValidations

    validates :message_type, format: /\AINCRTE\Z/

    [:amount_due, :expiration_in].each do |attr|
      validates_if_present attr, integer: true, greater_than_or_equal_to: 0
    end
  end
end
