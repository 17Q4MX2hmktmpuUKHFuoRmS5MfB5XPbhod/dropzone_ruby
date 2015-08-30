module Dropzone
  class Communication < MessageBase
    class NoSymmKey < StandardError; end

    attr_message i: :iv, c: :contents, d: :der, p: :session_pkey

    message_type 'COMMUN'

    attr_accessor :symm_key

    def contents_plain
      raise NoSymmKey unless symm_key

      aes = OpenSSL::Cipher::Cipher.new Session::CIPHER_ALGORITHM
      aes.decrypt
      aes.key = symm_key
      aes.iv = iv

      aes.update(contents) + aes.final
    end

    def is_init?; (der && session_pkey); end
    def is_auth?; !session_pkey.nil?; end
  end

  class Communication::Validator < ValidatorBase
    validates :message_type, format: /\ACOMMUN\Z/

    validates_if_present :der, is_string: true
    validates_if_present :session_pkey, is_string: true
    validates_if_present :contents, is_string: true
    validates_if_present :iv, is_string: true

    # Ders always need session_pkey:
    validates :session_pkey, not_null: true, unless: 'self.der.nil?'

    # Content always needs an iv:
    validates :iv, not_null: true, unless: 'self.contents.nil?'

    # We should always have either contents or a pkey:
    validates :contents, not_null: true, if: 'self.session_pkey.nil?'
  end
end
