module Dropzone
  class Session
    CIPHER_ALGORITHM = 'AES-256-CBC'

    class Unauthenticated < StandardError; end
    class MissingReceiver < StandardError; end
    class InvalidWithReceiver < StandardError; end
    class DerAlreadyExists < StandardError; end
    class InvalidCommunication < StandardError; end
    class SessionInvalid < StandardError; end

    attr_accessor :priv_key, :receiver_addr, :session_key, :with, :end_block

    def initialize(priv_key, session_secret, options = {})
      @priv_key, @session_key = priv_key, OpenSSL::BN.new(session_secret, 16)
      @end_block = options[:end_block] if options.has_key? :end_block

      # Either you attach to an existing session, or create a new one
      case 
        when options.has_key?(:receiver_addr)
          # New Session:
          @receiver_addr = options[:receiver_addr]
        when options.has_key?(:with)
          # Existing Session:
          raise InvalidWithReceiver unless options[:with].receiver_addr == sender_addr
          @with = options[:with]
          @receiver_addr = @with.sender_addr
        else
          raise MissingReceiver
      end
    end

    def blockchain; self.class.blockchain; end
    def sender_addr; blockchain.privkey_to_addr priv_key; end

    # Iv passing is supported only for the purpose of making tests completely 
    # deterministic
    def send(contents, iv = nil)
      raise Unauthenticated unless authenticated?
 
      # Cipher Setup:
      aes = OpenSSL::Cipher::Cipher.new CIPHER_ALGORITHM
      aes.encrypt
      
      iv ||= aes.random_iv
      aes.iv = iv

      aes.key = symm_key

      # Encrypt Time:
      cipher = aes.update contents
      cipher << aes.final

      communicate! contents: cipher.to_s, iv: iv
    end

    alias :<< :send

    def authenticate!(der = nil)
      is_init = (communication_init.nil? || authenticated?)

      # If we're already authenticated, we'll try to re-initialize. Presumably
      # one would want to do this if they lost a secret key, or that key were
      # somehow compromised
      if is_init
        dh = OpenSSL::PKey::DH.new(der || 1024)
     else
        raise DerAlreadyExists unless der.nil?
        dh = OpenSSL::PKey::DH.new with.der
      end

      dh.priv_key = session_key
      dh.generate_key! 

      communicate! session_pkey: [dh.pub_key.to_s(16)].pack('H*'),
        der: (is_init) ? dh.public_key.to_der : nil
    end

    def symm_key
      return @symm_key if @symm_key

      # If we can't compute, then it's ok to merely indicate this:
      return nil unless communication_init && communication_auth

      dh = OpenSSL::PKey::DH.new communication_init.der
      dh.priv_key = session_key
      dh.generate_key!

      @symm_key = dh.compute_key OpenSSL::BN.new(
        their_pkey.session_pkey.unpack('H*').first, 16)
    end

    def authenticated?
      communication_init && communication_auth
    end

    def communication_init
      # NOTE that this returns the newest initialization
      commun_messages.find(&:is_init?)
    end

    # This is the response to the init
    def communication_auth
      # NOTE that this returns the newest auth, or nil if we encounter an init
      commun_messages.find{|c| 
        break if c.is_init?
        c.is_auth? }
    end

    def their_pkey
      [communication_init, communication_auth].find{|c| 
        c.sender_addr == receiver_addr && c.receiver_addr == sender_addr }
    end

    def communications
      if authenticated?
        communications = commun_messages(
          start_block: communication_init.block_height ).reject(&:is_auth?)
        communications
          .each{|c| c.symm_key = symm_key}
          .sort_by{|c| [c.block_height, c.time_utc]}
      else
        []
      end
    end

    private

    # Addr's of who this conversation is between
    def between
      [sender_addr, receiver_addr]
    end

    def commun_messages(options = {})
      options[:type] = 'COMMUN'
      options[:end_block] = @end_block if @end_block
      options[:between] = between
      blockchain.messages_by_addr(sender_addr, options)
    end

    def communicate!(attrs)
      comm = Communication.new( {receiver_addr: receiver_addr, 
        sender_addr: sender_addr}.merge(attrs) )

      raise InvalidCommunication unless comm.valid?
      
      comm.save! priv_key
    end

    class << self
      attr_writer :blockchain 

      def blockchain
        @blockchain || Dropzone::RecordBase.blockchain
      end

      def all(addr)
        blockchain.messages_by_addr(addr, type: 'COMMUN').find_all(&:is_init?)
      end
    end
  end
end
