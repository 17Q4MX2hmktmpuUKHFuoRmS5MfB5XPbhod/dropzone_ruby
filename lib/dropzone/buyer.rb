module Dropzone
  class Buyer < MessageBase
    attr_message d: :description, a: :alias

    attr_message_pkey t: :transfer_pkey

    message_type 'BYUPDT'
  end

  class Buyer::Validator < ValidatorBase
    include MessageValidations
    include ProfileValidations

    validates :message_type, format: /\ABYUPDT\Z/

    validates_if_present :description, is_string: true
    validates_if_present :alias, is_string: true

    validates_if_present :transfer_pkey, is_pkey: true
  end
end
