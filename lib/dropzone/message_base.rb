module Dropzone
  module MessageValidations
    def self.included(base)
      base.validates :receiver_addr, presence: true
    end
  end

  module ProfileValidations
    def self.included(base)
      base.validates :receiver_addr, equals_attribute: { attribute: :sender_addr }, 
        unless: "self.transfer_pkey", if: "self.sender_addr"

      base.validates :transfer_pkey, equals_attribute: { attribute: :receiver_addr,
        unless: "self.transfer_pkey.nil? || self.transfer_pkey == 0" }
    end
  end

  module BillingValidations
    def self.included(base)
      base.validates :receiver_addr, doesnt_equal_attribute: { attribute: :sender_addr }, 
        if: "self.sender_addr"
    end
  end

  class MessageBase < RecordBase
    DEFAULT_TIP = 20_000

    ENCODING_VERSION_1_BLOCK = 300_000 # TODO: When should we kick this into gear?

    attr_reader :receiver_addr, :sender_addr, :message_type, :block_height, :txid

    def initialize(attrs = {})
      data = attrs.delete(:data)

      attrs.merge(data_hash_from_hex(data)).each do |attr, value|
        instance_variable_set '@%s' % attr, value
      end
    end

    def save!(private_key)
      self.blockchain.save! to_transaction, private_key
    end

    # This returns the version of the current message, based on its block_height.
    # If the block_height is omitted, it returns the 'latest' version
    def encoding_version
      if block_height && (block_height < ENCODING_VERSION_1_BLOCK)
        0
      else
        1
      end
    end

    def to_transaction
      {receiver_addr: receiver_addr, data: data_to_hex, 
        tip: MessageBase.default_tip }
    end

    def data_to_hex
      data_to_hash.inject(message_type.dup) do |ret, (key, value)|
        value_hex = case
          when value.nil?
            nil
          when self.class.is_attr_int?(key)
            Bitcoin::Protocol.pack_var_int(value.to_i)
          when self.class.is_attr_binary?(key)
            # TODO:
            if encoding_version < 1
              Bitcoin::Protocol.pack_var_string([value.to_s].pack('a*'))
            else
              Bitcoin::Protocol.pack_var_string([value.to_s].pack('H*'))
            end
          when self.class.is_attr_pkey?(key)
            Bitcoin::Protocol.pack_var_string(
              (value == 0) ? 0.chr : 
                [anynet_for_address(:hash160_from_address, value)].pack('H*'))
          else
            Bitcoin::Protocol.pack_var_string([value.to_s].pack('a*'))
        end 

        (value_hex.nil?) ? ret : 
          ret << Bitcoin::Protocol.pack_var_string(key.to_s) << value_hex
      end
    end

    def data_to_hash
      self.class.message_attribs.inject({}) do |ret , (short, full)|
        ret.merge(short => self.send(full))
      end
    end

    private

    def anynet_for_address(method, addr)
      start_network = Bitcoin.network_name

      begin
        Bitcoin.network = (/\A1/.match addr) ? :bitcoin : :testnet3

        return Bitcoin.send(method, addr)
      ensure
        Bitcoin.network = start_network
      end
    end

    def data_hash_from_hex(data)
      return {} unless /\A(.{6})(.*)/m.match data

      message_type, pairs, data = $1, $2, {}

      while(pairs.length > 0) do 
        short_key, pairs = Bitcoin::Protocol.unpack_var_string(pairs)

        value, pairs = (self.class.is_attr_int? short_key.to_sym) ? 
          Bitcoin::Protocol.unpack_var_int(pairs) :
          Bitcoin::Protocol.unpack_var_string(pairs)

        if self.class.is_attr_pkey?(short_key.to_sym) && value
          value = (value == 0.chr) ? 0 : 
            anynet_for_address(:hash160_to_address, value.unpack('H*')[0])
        end

        full_key = self.class.message_attribs[short_key.to_sym]
        data[full_key] = value
      end

      data
    end

    class << self
      attr_writer :default_tip

      def default_tip
        @default_tip || DEFAULT_TIP
      end

      def message_attribs
        @message_attribs
      end

      def is_attr_int?(attr)
        @message_integers && @message_integers.include?(attr)
      end

      def is_attr_binary?(attr)
        @message_binaries && @message_binaries.include?(attr)
      end

      def is_attr_pkey?(attr)
        @message_pkeys && @message_pkeys.include?(attr)
      end

      def message_type(type)
        @types_include ||= [type]

        define_method(:message_type){ type }
      end

      def attr_message(attribs)
        @message_attribs ||= {}
        @message_attribs.merge! attribs 

        attribs.each{ |short_attr, full_attr| attr_reader full_attr }
      end

      def attr_message_int(attribs)
        @message_integers ||= []
        @message_integers += attribs.keys

        attr_message attribs
      end

      def attr_message_binary(attribs)
        @message_binaries ||= []
        @message_binaries += attribs.keys

        attr_message attribs
      end

      def attr_message_pkey(attribs)
        @message_pkeys ||= []
        @message_pkeys += attribs.keys

        attr_message attribs
      end

      def find(txid)
        tx = RecordBase.blockchain.tx_by_id txid
        tx ? self.new(tx) : nil
      end

      def types_include?(type)
        @types_include && @types_include.include?(type)
      end

      def new_message_from(tx)
        @messages ||= ObjectSpace.each_object(Class).select {|klass| 
          klass < Dropzone::MessageBase }

        if /\A([a-z0-9]{6})/i.match tx[:data]
          message_klass = @messages.find{|klass| klass.types_include? $1}
          (message_klass) ? message_klass.new(tx) : nil
        end
      end

    end
  end
end
