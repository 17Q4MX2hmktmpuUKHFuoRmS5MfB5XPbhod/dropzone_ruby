module Dropzone
  class BitcoinConnection
    class WalletFundsTooLowOrNoUTXOs < StandardError; end

    SATOSHIS_IN_BTC = 100_000_000

    TXO_DUST = 5430 # 0.0000543 BTC

    PREFIX = 'DZ'

    attr_reader :bitcoin

    def initialize(network, options = {})
      @network = network
      @bitcoin = options[:bitcoin] if options.has_key? :bitcoin
      @is_testing = (/\Atestnet/.match network.to_s) ? true : false
      @bitcoin ||= BlockrIo.new is_testing?
    end

    def is_testing?; @is_testing; end

    def privkey_to_addr(key) 
      set_network_mode!
      Bitcoin::Key.from_base58(key).addr
    end

    def hash160_to_address(hash160) 
      set_network_mode!
      Bitcoin.hash160_to_address hash160
    end

    def hash160_from_address(addr)
      set_network_mode!
      Bitcoin.hash160_from_address addr
    end

    def valid_address?(addr) 
      set_network_mode!
      Bitcoin.valid_address? addr
    end

    # NOTE: 
    #  - This needs to return the messages in Descending order by block
    #    In the case that two transactions are in the same block, it goes by time
    #  - This should only 'valid' return messages. Not transactions
    def messages_by_addr(addr, options = {})
      ret = cache.listtransactions addr, true, is_testing? if cache

      unless ret
        ret = bitcoin.listtransactions addr, true
        cache.listtransactions! addr, true, ret, is_testing? if cache
      end

      ret = ret.collect{ |tx_h|
        begin
          msg = Dropzone::MessageBase.new_message_from tx_by_id(tx_h['tx'])

          (msg && msg.valid?) ? msg : nil
        rescue Counterparty::TxDecode::InvalidOutput,
          Counterparty::TxDecode::MultisigUnsupported
          next
        end
      }.compact

      filter_messages ret, options
    end

    def messages_in_block(at_height, options = {})
      ret = bitcoin.getblock(at_height).collect{ |tx_h|

        # This is a speed hack that drastically reduces query times:
        next if options[:type] == 'ITCRTE' && !tx_h_create?(tx_h)

        begin
          msg = Dropzone::MessageBase.new_message_from tx_by_id( tx_h['tx'], 
            block_height: at_height )

          (msg && msg.valid?) ? msg : nil
        rescue Counterparty::TxDecode::InvalidOutput,
          Counterparty::TxDecode::MultisigUnsupported,
          Counterparty::TxDecode::UndefinedBehavior,
          Counterparty::TxDecode::InvalidOpReturn
          next
        end
      }.compact

      filter_messages ret, options
    end

    def send_value(from_key, to_addr, send_satoshis, tip_satoshis)
      set_network_mode!

      new_tx = create_tx(from_key, send_satoshis+tip_satoshis){ |tx, allocated|
        [ [send_satoshis, Bitcoin.hash160_from_address(to_addr)],
          [(allocated-send_satoshis-tip_satoshis), from_key.hash160]
        ].each do |(amt, to)|
          tx.add_out Bitcoin::P::TxOut.new( amt,
            Bitcoin::Script.to_hash160_script(to) )
        end
      }

      sign_and_send new_tx, from_key
    end

    def sign_tx(tx, key)
      set_network_mode!

      # Sign the transaction:
      tx.inputs.length.times do |i|
        # Fetch the previous input:
        prev_out_tx_hash = tx.inputs[i].prev_out.reverse.unpack('H*').first
        prev_tx_raw = bitcoin.getrawtransaction(prev_out_tx_hash)['hex']
        prev_tx = Bitcoin::P::Tx.new [prev_tx_raw].pack('H*')
        
        # Now we actually sign
        sig = Bitcoin.sign_data Bitcoin.open_key(key.priv), 
          tx.signature_hash_for_input(i, prev_tx)
        tx.in[i].script_sig = Bitcoin::Script.to_signature_pubkey_script( sig, 
          [key.pub].pack("H*"))
      end
      tx
    end

    def tx_by_id(id, options = {})
      set_network_mode!

      ret = cache.tx_by_id id, is_testing? if cache

      unless ret
        tx_h = bitcoin.getrawtransaction(id)
        tx = Bitcoin::P::Tx.new [tx_h['hex']].pack('H*')
    
        if tx_h.has_key? 'blockhash'
          options[:block_height] = bitcoin.getblockinfo(tx_h['blockhash'])['nb']
        end

        record = Counterparty::TxDecode.new tx,
          prefix: Dropzone::BitcoinConnection::PREFIX

        ret = options.merge({ data: record.data, 
          receiver_addr: record.receiver_addr, 
          txid: id,
          sender_addr: record.sender_addr})

        # NOTE that in the case of a reorg, this might have incorrect block
        # heights cached. It's probable that we can/should cache these, and 
        # merely set the block height when it's confirmed, and/or set the
        # height to current_height+1
        cache.tx_by_id! id, ret, is_testing? if cache && options[:block_height]
      end

      ret
    end

    def save!(data, private_key_wif)
      set_network_mode!

      from_key = Bitcoin::Key.from_base58 private_key_wif
      
      # We need to know how many transactions we'll have in order to know how
      # many satoshi's to allocate. We start with 1, since that's the return
      # address of the allocated input satoshis
      data_outputs_needed = 1

      bytes_in_output = Counterparty::TxEncode::BYTES_IN_MULTISIG

      # 3 is for the two-byte DZ prefix, and the 1-byte length
      data_outputs_needed += ((data[:data].length+3) / bytes_in_output).ceil

      # We'll need a P2PSH for the destination if that applies
      data_outputs_needed += 1 if data.has_key? :receiver_addr
      tip = data[:tip] || 0

      new_tx = create_tx(from_key,data_outputs_needed * TXO_DUST+tip) do |tx, amount_allocated|
        outputs = Counterparty::TxEncode.new( 
          [tx.inputs[0].prev_out.reverse_hth].pack('H*'),
          data[:data], receiver_addr: data[:receiver_addr],
          sender_pubkey: from_key.pub, prefix: PREFIX).to_opmultisig

        outputs.each_with_index do |output,i|
          tx.add_out Bitcoin::P::TxOut.new( (i == (outputs.length-1)) ? 
            (amount_allocated - tip - TXO_DUST*(outputs.length - 1)) : TXO_DUST,
            Bitcoin::Script.binary_from_string(output) )
        end
      end

      sign_and_send new_tx, from_key
    end

    def block_height
      bitcoin.getblockinfo('last')['nb']
    end

    private

    def filter_messages(messages, options = {})
      messages = messages.find_all{|msg| 
        msg.block_height.nil? || (msg.block_height >= options[:start_block])
      } if options[:start_block]

      messages = messages.find_all{|msg| 
        msg.block_height.nil? || (msg.block_height <= options[:end_block])
      } if options[:end_block]

      if messages && options.has_key?(:type)
        messages = messages.find_all{|msg| msg.message_type == options[:type]} 
      end

      if options.has_key?(:between)
        messages = messages.find_all{|c|
          [c.receiver_addr, c.sender_addr].all?{|a| options[:between].include?(a) } }
      end

      (messages) ? messages : []
    end


    # This is a speed hack which keeps us from traversing through entire blocks
    # by filtering based on the destination addresses
    def tx_h_create?(tx_h)
      address = tx_h['out'][0]['addr'] if [ 
        tx_h.has_key?('out'), tx_h['out'][0], tx_h['out'][0]['addr'] ].all?

      (address && Dropzone::Item::HASH_160_PARTS.match(address)) ? true : false
    end

    # Since the Bitcoin object is a singleton, and we'll be working alongside
    # testnet, we need to start our methods by setting the correct network mode
    def set_network_mode!
      Bitcoin.network = @network
    end

    def sign_and_send(tx, key)
      signed_hex = sign_tx(tx, key).to_payload.unpack('H*')[0]

      bitcoin.sendrawtransaction signed_hex
    end

    def create_tx(key, allocate, &block)
      # create a new transaction (and sign the inputs)
      tx = Bitcoin::P::Tx.new(nil)
      tx.ver, tx.lock_time = 1, 0

      # allocate some inputs here:
      amount_allocated = 0
      allocate_inputs_for(key.addr, allocate).each do |unspent|
        amount_allocated += to_satoshis(unspent['amount'])
        tx.add_in Bitcoin::P::TxIn.new [unspent['tx'] ].pack('H*').reverse, 
          unspent['n'].to_i
      end

      block.call(tx, amount_allocated)

      tx
    end

    # We expect the amount to be in satoshis. As-is this method does not allocate
    # mempool utxos for a spend.
    def allocate_inputs_for(addr, amount)
      allocated = 0

      # NOTE: I think we're issuing more queries here than we should be due to a
      # fetch for every utxo, instead of one fetch for every transaction. 
      # (Which may have many utxo's per transaction.)
      mempooled_utxos = bitcoin.listunconfirmed(addr).collect{|tx|
        # Note that some api's may not retrieve the contents of an unconfirmed
        # raw transaction.
        unconfirmed_tx = bitcoin.getrawtransaction(tx['tx'])['hex']

        if unconfirmed_tx
          tx = Bitcoin::P::Tx.new [unconfirmed_tx].pack('H*')
          tx.inputs.collect{|input| input.prev_out.reverse.unpack('H*').first}
        else
          nil
        end
      }.compact.flatten.uniq

      utxos = []
      bitcoin.listunspent(addr).sort_by{|utxo| utxo['confirmations']}.each{|utxo|
        next if mempooled_utxos.include? utxo['tx'] 
        utxos << utxo
        allocated += to_satoshis(utxo['amount'])
        break if allocated >= amount
      }

      raise WalletFundsTooLowOrNoUTXOs if allocated < amount

      utxos
    end

    def to_satoshis(string)
      self.class.to_satoshis string
    end

    def is_opreturn?(output)
      /\AOP_RETURN/.match output
    end

    def self.to_satoshis(string)
      (BigDecimal.new(string) * SATOSHIS_IN_BTC).to_i
    end

    def cache
      self.class.cache
    end

    class << self
      # This is a hook to speed up some operations via a local cache
      attr_accessor :cache
    end
  end
end
