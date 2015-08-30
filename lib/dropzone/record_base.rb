module Dropzone
  class ValidatorBase
    IS_STRING = /\A.+\Z/

    include Veto.validator

    def self.validates_if_present(attr, options)
      validates attr, options.merge({unless: "self.%s.nil?" % attr.to_s})
    end
  end

  # This lets us set connection parameters across the entire library. 
  # A cattr_inheritable-esque implementation  might be worth adding at some point.
  class RecordBase
    def blockchain; 
      RecordBase.blockchain
    end

    def valid?; validator.valid? self; end

    def errors
      validator.valid? self
      validator.errors
    end

    private 

    def validator; @validator ||= self.class.const_get(:Validator).new; end

    class << self
      attr_accessor :blockchain
    end
  end
end
