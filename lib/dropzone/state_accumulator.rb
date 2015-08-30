module Dropzone
  module StateAccumulator
    # NOTE: This includes only the valid() messages sent/received on this address
    def messages(options = {})
      @messages ||= blockchain.messages_by_addr addr, 
        {type: self.class.message_types}.merge(options)
    end

    def blockchain
      Dropzone::RecordBase.blockchain
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def state_attr(*attrs)
        attr_reader *attrs
        @state_attributes ||= []
        @state_attributes += attrs
      end

      def message_types=(type); @message_types = type; end
      def message_types; @message_types; end
      def state_attributes; @state_attributes; end
    end

    private

    def attrs_from(message)
      self.class.state_attributes.each do |attr|
        value = message.send attr
        self.instance_variable_set '@%s' % attr, value if value
      end
    end
  end

end
