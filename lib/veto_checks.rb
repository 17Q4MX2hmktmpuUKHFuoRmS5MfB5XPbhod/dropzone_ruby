module Veto
  module AgainstAttributeCco
    MSG_MISSING_ATTR = "missing required option :attribute"

    def call(cco)
      raise StandardError, MSG_MISSING_ATTR unless @options[:attribute]

      value = cco.entity.public_send(@attribute_name)
      value_against = cco.entity.public_send(@options[:attribute])

      check @attribute_name, value, value_against, cco.errors, @options
    end
  end

  class IsStringCheck < AttributeCheck
    MSG = "is not a string"

    def check(attribute, value, errors, options={})
      on = options.fetch(:on, attribute)
      errors.add(on, options[:message] || MSG) unless value.is_a? String
    end
  end

  class IsPkeyCheck < AttributeCheck
    MSG = "is not a public key"

    def call(cco)
      @blockchain = cco.entity.blockchain
      super(cco)
    end

    def check(attribute, value, errors, options={})
      on = options.fetch(:on, attribute)
      unless value == 0 || anynet_valid_address?(value)
        errors.add(on, options[:message] || MSG) 
      end
    end

    def anynet_valid_address?(addr)
      start_network = Bitcoin.network_name

      begin
        Bitcoin.network = (/\A1/.match addr) ? :bitcoin : :testnet3

        return Bitcoin.valid_address?(addr)
      ensure
        Bitcoin.network = start_network
      end
    end
  end

  class EqualsAttributeCheck < AttributeCheck
    include AgainstAttributeCco

    MSG = "does not match %s"

    def check(attribute, value, against, errors, options={})
      errors.add(options.fetch(:on, attribute), 
        (options[:message] || MSG) % options[:attribute] ) unless value == against
    end
  end

  class DoesntEqualAttributeCheck < AttributeCheck
    include AgainstAttributeCco

    MSG = "matches %s"

    def check(attribute, value, against, errors, options={})
      errors.add(options.fetch(:on, attribute), 
        (options[:message] || MSG) % options[:attribute] ) if value == against
    end
  end

end
