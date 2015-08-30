module Dropzone
  class Seller < MessageBase
    message_type 'SLUPDT'

    attr_message d: :description, a: :alias
    attr_message_pkey t: :transfer_pkey, p: :communications_pkey
  end

  class Seller::Validator < ValidatorBase
    include MessageValidations
    include ProfileValidations

    validates :message_type, format: /\ASLUPDT\Z/

    validates_if_present :description, is_string: true
    validates_if_present :alias, is_string: true

    validates_if_present :communications_pkey, is_pkey: true
    validates_if_present :transfer_pkey, is_pkey: true
  end
end
