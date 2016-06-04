module Dropzone

  # This is a self contained class designed to vet whether or not the provided
  # transaction will mine. I contained it this way mostly so that testing is 
  # easier, and also because it's likely that this will change often.
  class TransactionValidator
    MAX_BLOCK_SIZE = 1000000
    MAX_BLOCK_SIGOPS = MAX_BLOCK_SIZE/50
    MAX_STANDARD_TX_SIGOPS = MAX_BLOCK_SIGOPS/5
    MAX_PUBKEYS_PER_MULTISIG = 20
    DEFAULT_BYTES_PER_SIGOP = 20

    attr_reader :tx, :bitcoin

    def initialize(tx, bitcoin)
      @tx, @bitcoin = tx, bitcoin
    end

    def is_relayable?
      nBytesPerSigOp = DEFAULT_BYTES_PER_SIGOP
      nSize = tx.to_payload.bytesize
      nSigOps = legacy_sig_op_count(tx)
      nSigOps += get_p2sh_sig_op_count(tx)

      # This was the reason for creating this code:
      # https://github.com/bitcoin/bitcoin/pull/7081/files
      if ( (nSigOps > MAX_STANDARD_TX_SIGOPS) || 
        (nBytesPerSigOp && nSigOps > nSize / nBytesPerSigOp))
        return false
      end

      true
    end

    # A ruby implementation of:
    #   unsigned int GetLegacySigOpCount(const CTransaction& tx)
    def legacy_sig_op_count(tx)
      [tx.inputs, tx.outputs].flatten.collect{|i| 
        get_op_count i.parsed_script}.reduce(&:+)
    end

    # A ruby implementation of:
    #   unsigned int CScript::GetSigOpCount(bool fAccurate) const
    def get_op_count(scriptOp, is_accurate = false)
      n = 0
      case scriptOp.to_string
        when /OP_CHECK(?:SIG|SIGVERIFY)\Z/
          n += 1
        when /OP_CHECK(?:MULTISIG|MULTISIGVERIFY)\Z/
          if is_accurate
            raise StandardError, "Path unimplemented"
          else
            n += MAX_PUBKEYS_PER_MULTISIG
          end
        else
          0
      end
    end

    # A ruby implementation of:
    #   unsigned int GetP2SHSigOpCount(const CTransaction& tx, const CCoinsViewCache& inputs)
    def get_p2sh_sig_op_count(tx)
      return 0 if tx.is_coinbase?

      nSigOps = 0

      tx.inputs.each do |i|
        # Now we load that input: 
        prev_tx_raw = bitcoin.getrawtransaction(
          i.prev_out_hash.reverse_hth)['hex']
        prev_tx = Bitcoin::P::Tx.new [prev_tx_raw].pack('H*')

        prevout = prev_tx.outputs[i.prev_out_index].parsed_script
        nSigOps += get_op_count(prevout, true) if prevout.is_p2sh?
      end

      nSigOps
    end
  end
end
