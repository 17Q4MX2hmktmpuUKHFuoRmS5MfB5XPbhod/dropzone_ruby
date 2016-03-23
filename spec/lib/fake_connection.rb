require 'sequel'

class FakeBitcoinConnection
  attr_accessor :height, :transactions

  DB ||= Sequel.sqlite # logger: Logger.new(STDOUT)

  def initialize(options = {})
    DB.create_table :transactions do
      primary_key :id
      File :data
      String :receiver_addr
      String :sender_addr
      Integer :tip
      Integer :block_height
    end unless DB.table_exists?(:transactions)

    @height = @starting_height = options[:height] || 0
    @transactions = DB[:transactions]
    @is_testing = (options.has_key? :is_testing) ? options[:is_testing] : true
  end

  def is_testing?; @is_testing; end
  def privkey_to_addr(key); Bitcoin::Key.from_base58(key).addr; end
  def hash160_to_address(hash160); Bitcoin.hash160_to_address hash160; end
  def hash160_from_address(addr); Bitcoin.hash160_from_address addr; end
  def valid_address?(addr); Bitcoin.valid_address? addr; end

  # NOTE: 
  #  - This needs to return the messages in Descending order by block
  #    In the case that two transactions are in the same block, it goes by time
  #  - This should return only 'valid' messages. Not all transactions
  def messages_by_addr(addr, options = {})
    filter_messages transactions.where(
      Sequel.expr(receiver_addr: addr) | Sequel.expr(sender_addr: addr) ), 
      options
  end

  def messages_in_block(block_height, options = {})
    filter_messages transactions.where(
      Sequel.expr(block_height: block_height) ), options
  end

  def tx_by_id(id)
    record_to_tx transactions[id: id.to_i]
  end

  # We ignore the private key in this connection. We return the database id 
  # in lieue of transaction id.
  def save!(tx, private_key)
    '%02d' % transactions.insert(tx.tap{ |et| 
      et[:block_height] = @height
      et[:sender_addr] = privkey_to_addr(private_key)
      et[:data] = Sequel.blob et[:data] 
    }).to_s
  end

  # This aids test mode:
  def clear_transactions!
    transactions.delete
    @height = @starting_height
  end

  def increment_block_height!
    @height += 1
  end

  private

  def record_to_tx(record)
    # Since we often encode these in bytes, and the H* is high nibble first,
    # we need to prepend a 0 on anything under 10:
    record.tap{|r| r[:txid] = '%02d' % r.delete(:id).to_s } if record
  end

  def filter_messages(messages, options = {})
    if options.has_key?(:start_block)
      messages = messages.where{block_height >= options[:start_block]} 
    end
    if options.has_key?(:end_block)
      messages = messages.where{block_height <= options[:end_block]} 
    end
    
    ret = messages.order(Sequel.desc(:block_height)).order(Sequel.desc(:id)).to_a
    ret = ret.collect{ |tx| 
      msg = Dropzone::MessageBase.new_message_from record_to_tx(tx)
      msg.valid? ? msg : nil
    }.compact

    ret = ret.find_all{|msg| msg.message_type == options[:type]} if ret && options.has_key?(:type)

    if options.has_key?(:between)
      ret = ret.find_all{|c|
        [c.receiver_addr, c.sender_addr].all?{|a| options[:between].include?(a) } }
    end

    (ret) ? ret : []
  end
end

