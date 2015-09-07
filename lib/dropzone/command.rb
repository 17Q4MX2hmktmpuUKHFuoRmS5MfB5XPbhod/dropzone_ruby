require 'sequel'

# This speeds up the CLI considerably, without any opportunity cost, so it's 
# included for the sake of convenience
class LocalConnectionCache
  def initialize
    config_dir = File.join(Dir.home, ".dropzone")
    Dir.mkdir config_dir, 0700 unless Dir.exists? config_dir

    @persistence = Sequel.connect 'sqlite://%s/cache.db' % config_dir
    
    @persistence.create_table :transactions do
      primary_key :id
      String :txid
      String :receiver_addr
      String :sender_addr
      File :data
      Boolean :is_testing
      Integer :block_height
    end unless @persistence.table_exists?(:transactions)

    @transactions = @persistence[:transactions]
    @listtransactions = {}
  end

  def tx_by_id(id, is_testing)
    record_to_tx transactions.where(txid: id, is_testing: is_testing).first
  end

  def tx_by_id!(id, hash, is_testing)
    transactions.insert(hash.tap{ |et| 
      et[:data] = Sequel.blob et[:data] 
      et[:txid] = id
      et[:is_testing] = is_testing
    }).to_s
  end

  def listtransactions(*key)
    @listtransactions.has_key?(key) ? @listtransactions[key] : nil
  end

  def listtransactions!(addr, is_confirmed, value, is_testing)
    @listtransactions[ [addr, is_confirmed, is_testing] ] = value
  end

  def invalidate_listtransactions!
    @listtransactions = {}
  end

  private

  def record_to_tx(record)
    record.tap{|r| r.delete(:id) } if record
  end

  def transactions
    @transactions
  end
end

# This is mostly intended for use by the CLI client, though it's conceivable
# that others may find it useful in some contexts.
class DropZoneCommand
  MAX_TABLE_WIDTH = 80

  class << self
    def create_command(action, klass, label, *attributes, &block)
      define_method(action) do |args, options|
        privkey = privkey_from args

        params = parameterize options, *attributes

        block.call privkey, args, params if block_given?

        message = klass.new params

        txid = message.save! privkey.to_base58

        puts_object '%s: %s' % [label, message.receiver_addr], 'Tx: %s' % txid, attributes, 
          message
      end
    end

    def show_command(action, klass, label, finder, *attributes, &block)
      define_method(action) do |args, options|
        id = self.send finder,  args
        
        record = (block_given?) ? block.call(klass, id) : klass.new(id)

        if record.respond_to?(:found?) and !record.found?
          puts "%s Not Found" % label
        else
          params = attributes.collect{|attr| [attr,record.send(attr)]}.to_h

          puts_object '%s: %s' % [label, id], nil, attributes, record
        end
      end
    end
  end

  LISTING_ATTRS = [ :latitude, :longitude, :radius, :price_currency, 
    :price_in_units, :description, :expiration_in ]
  PROFILE_ATTRS = [ :alias, :description ]
  INVOICE_ATTRS = [ :amount_due, :expiration_in ]
  PAYMENT_ATTRS = [:description, :delivery_quality, :product_quality, 
    :communications_quality, :invoice_txid ]

  ADDRESS_TO_SELF = lambda{|privkey, args, params|
    params.merge!(receiver_addr: privkey.addr) }

  RECORD_BY_FIND = lambda{|klass, id| klass.find id }

  show_command :listing_show, Dropzone::Listing, 'Listing', :by_txid, 
    *LISTING_ATTRS+[:addr]

  show_command :profile_buyer_show, Dropzone::BuyerProfile, 'Buyer', :by_addr,
    *PROFILE_ATTRS

  show_command :profile_seller_show, Dropzone::SellerProfile, 'Seller',:by_addr,
    *(PROFILE_ATTRS+[:communications_pkey] )

  show_command :invoice_show, Dropzone::Invoice, 'Invoice', :by_txid,
    *INVOICE_ATTRS+[:sender_addr, :receiver_addr], &RECORD_BY_FIND

  show_command :review_show, Dropzone::Payment, 'Review',:by_txid,
    *PAYMENT_ATTRS+[:sender_addr, :receiver_addr], &RECORD_BY_FIND

  create_command :profile_buyer_create, Dropzone::Buyer, 'Buyer', 
    *(PROFILE_ATTRS+[:transfer_pkey] ), &ADDRESS_TO_SELF

  create_command :profile_seller_create, Dropzone::Seller, 'Seller',
    *(PROFILE_ATTRS+[:transfer_pkey, :communications_pkey] ), &ADDRESS_TO_SELF

  create_command(:invoice_create, Dropzone::Invoice, 'Invoice',
    *INVOICE_ATTRS) do |privkey, args, params|
    receiver_addr = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, 'receiver_addr' unless (
      receiver_addr && Bitcoin.valid_address?(receiver_addr) )

    params.merge! receiver_addr: receiver_addr
  end

  create_command(:review_create, Dropzone::Payment, 'Review',
    *PAYMENT_ATTRS ) do |privkey, args, params|
    invoice_txid = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, 'invoice_txid' unless invoice_txid

    invoice = Dropzone::Invoice.find invoice_txid

    raise 'Invoice Not Found' unless invoice

    params.merge! receiver_addr: invoice.sender_addr, invoice_txid: invoice_txid
  end

  create_command( :listing_create, Dropzone::Item, 'Listing', 
    *LISTING_ATTRS) do |privkey, args, params|
    %w(longitude latitude radius).each do |attr|
      raise OptionParser::MissingArgument, attr unless params[attr.to_sym]
    end
  end

  create_command( :listing_update, Dropzone::Item, 'Listing', 
    :description, :price_currency, :price_in_units, 
    :expiration_in ) do |privkey, args, params|

    create_txid = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, 'create_txid' unless create_txid

    params.merge! receiver_addr: privkey.addr, create_txid: create_txid
  end

  def initialize(is_spec = false)
    @is_spec = is_spec
    network! Bitcoin.network_name
  end

  attr_reader :connection

  def network!(network_name)
    unless @is_spec
      Bitcoin.network = network_name
      @connection = Dropzone::BitcoinConnection.new network_name
      Dropzone::RecordBase.blockchain = @connection
    end
  end

  def chat_new(args, options)
    network! :testnet3

    privkey = privkey_from args, :testnet3

    receiver_addr = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, 'addr' unless (
      receiver_addr && Bitcoin.valid_address?(receiver_addr) )

    session = Dropzone::Session.new privkey.to_base58,
      secret_for(privkey.addr, receiver_addr),
      receiver_addr: receiver_addr 

    txid = session.authenticate!

    puts_table '%s: %s' % ['Session', txid], nil, [ 
      [:sender_addr, privkey.addr], [:receiver_addr, receiver_addr] ]
  end

  def chat_list(args, options)
    network! :testnet3

    privkey = privkey_from args, :testnet3

    Dropzone::Session.all(privkey.addr).each do |init|
      session = session_for privkey, init

      chat_with = [init.sender_addr, init.receiver_addr].find{|a| a != privkey.addr}

      chats_cache = local_persistence[:chats].first(session_txid: init.txid)
      read_messages = (chats_cache) ? chats_cache[:last_read_message_count] : 0
      total_messages = session.communications.length
      unread_messages = (total_messages-read_messages)

      puts_table '%s: %s' % ['Session', init.txid], nil, [ 
        ['Address', chat_with], 
        ['Messages', '%d Unread / %d Total' % [unread_messages, total_messages ] ] ]
    end
  end

  def chat_say(args, options)
    network! :testnet3

    privkey = privkey_from args, :testnet3

    txid = args[1]  if args.length > 1
    message = args[2]  if args.length > 2

    raise OptionParser::MissingArgument, 'txid' unless txid
    raise OptionParser::MissingArgument, 'message' unless message

    comm_init = Dropzone::Communication.find txid

    raise "Invalid Session" unless comm_init && comm_init.is_init?

    session = session_for privkey, comm_init

    if !session.authenticated?
      if comm_init.sender_addr == privkey.addr
        raise "The receiver has not yet authenticated your request"
      else
        session.authenticate!

        # This allows us to re-query the the session communications, and 
        # retrive the auth_message we just created.
        # NOTE: We nonetheless fail (sometimes) with a 
        #  Dropzone::Session::Unauthenticated message as it takes a bit of time to 
        #  populate the authentication relay into the mempool:
        if Dropzone::BitcoinConnection.cache
          Dropzone::BitcoinConnection.cache.invalidate_listtransactions!

          puts "Waiting 10 seconds for authorization to propagate to the mempool..."
          sleep 10
        end
      end
    end

    comm_txid = session << message

    puts_table '%s: %s' % ['Chat', comm_txid], nil, [ 
      ['Session', txid], 
      [:sender_addr, privkey.addr], 
      [:message, message] ]
  end

  def chat_show(args, options)
    network! :testnet3

    privkey = privkey_from args, :testnet3

    txid = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, 'txid' unless txid

    comm_init = Dropzone::Communication.find txid

    raise "Invalid Session" unless comm_init && comm_init.is_init?

    session = session_for privkey, comm_init

    update_attrs = {last_read_message_count: session.communications.length}

    cache = local_persistence[:chats]
    unless 1 == cache.where(session_txid: txid).update(update_attrs)
      cache.insert update_attrs.merge(session_txid: txid)
    end

    puts_table '%s: %s' % ['Chat', txid], nil,
     session.communications.reverse.collect{|comm|
      [comm.sender_addr, comm.contents_plain] }

    # TODO: Determine how many messages to show here, instead of 'all'
  end

  def listing_find(args, options)
    block_depth = args[0]  if args.length > 0

    raise OptionParser::MissingArgument, "block_depth" unless block_depth

    block_depth = block_depth.to_i

    raise OptionParser::InvalidArgument, "block_depth" unless block_depth >= 0

    location_attrs = [:latitude, :longitude, :radius]

    params = parameterize options, *location_attrs+[:start_at]

    via_location = location_attrs.collect{|k| params[k]}

    raise "missing one or more of: latitude, longitude, or radius."  if (
      via_location.any? && !via_location.all? )

    start_at = params[:start_at] ? params[:start_at].to_i : connection.block_height

    finder_method = (via_location.all?) ? 
      [ :find_in_radius, start_at, block_depth, *via_location] :
      [ :find_creates_since_block, start_at, block_depth] 

    Dropzone::Item.send(*finder_method) do |item|
      puts_object '%s: %s' % ['Listing', item.txid], nil, LISTING_ATTRS, item
    end
  end

  def send_value(args, options)
    dest_addr = args[1]  if args.length > 1

    raise OptionParser::MissingArgument, "dest_addr" unless dest_addr

    network! (/\A1/.match dest_addr) ? :bitcoin : :testnet3

    raise OptionParser::InvalidArgument, "dest_addr" unless Bitcoin.valid_address? dest_addr

    amnt_btc = args[2] if args.length > 2

    raise OptionParser::MissingArgument, "amnt_btc" unless amnt_btc

    amnt_btc = BigDecimal.new amnt_btc

    raise OptionParser::InvalidArgument, "amnt_btc" unless amnt_btc > 0

    amnt_satoshis = (amnt_btc * Dropzone::BitcoinConnection::SATOSHIS_IN_BTC).to_i

    privkey = privkey_from args, Bitcoin.network_name

    txid = connection.send_value privkey, dest_addr, amnt_satoshis, 
      Dropzone::MessageBase.default_tip

    puts_table '%s: %s' % ['Transaction', txid], nil, [
      ['From', privkey.addr ] ,
      ['To', dest_addr ] ,
      ['Amount (BTC)', amnt_btc.to_s('F').to_s ] 
    ]
  end

  def balance(args, options)
    addr = args.first

    raise OptionParser::MissingArgument, "addr" unless addr
     
    network! (/\A1/.match addr) ? :bitcoin : :testnet3

    raise OptionParser::InvalidArgument, "addr" unless Bitcoin.valid_address? addr

    balance = connection.bitcoin.getbalance addr

    puts_table '%s: %s' % ['Address', addr], nil, [
      ['Balance', balance ] ]
  end

  private

  def secret_for(sender_addr, receiver_addr)
    record = local_persistence[:communication_keys].where( 
      Sequel.expr(receiver_addr: receiver_addr) & 
      Sequel.expr(sender_addr: sender_addr) ).first

    if record
      record[:secret]
    else
      secret = SecureRandom.random_bytes(128).unpack('H*').first

      local_persistence[:communication_keys].insert sender_addr: sender_addr, 
        receiver_addr: receiver_addr, secret: secret

      secret
    end
  end

  def local_persistence
    unless @local_persistence
      config_dir = File.join(Dir.home, ".dropzone")
      Dir.mkdir config_dir, 0700 unless Dir.exists? config_dir

      @local_persistence = Sequel.connect 'sqlite://%s/dropzone.db' % config_dir
    end

    @local_persistence.create_table :communication_keys do
      primary_key :id
      String :sender_addr
      String :receiver_addr
      String :secret
    end unless @local_persistence.table_exists? :communication_keys

    @local_persistence.create_table :chats do
      primary_key :id
      String :session_txid
      Integer :last_read_message_count
    end unless @local_persistence.table_exists? :chats

    @local_persistence.create_table :addresses do
      primary_key :id
      String :addr
      String :label
    end unless @local_persistence.table_exists? :addresses

    @local_persistence
  end

  def session_for(privkey, comm_init)
    receiver_addr = (comm_init.receiver_addr == privkey.addr) ?
      comm_init.sender_addr : comm_init.receiver_addr

    Dropzone::Session.new privkey.to_base58, 
      secret_for(privkey.addr, receiver_addr),
      (comm_init.sender_addr == privkey.addr) ? 
        {receiver_addr: receiver_addr} : {with: comm_init}
  end

  def parameterize(options,*valid_params)
    options.__hash__.find_all{|(k,v)| valid_params.include? k}.to_h
  end

  def privkey_from(args, network = nil)
    start_network = Bitcoin.network_name if network

    privkey = args.first

    raise OptionParser::MissingArgument, "private_key" unless privkey

    begin
      Bitcoin.network = network if network
      Bitcoin::Key.from_base58 privkey
    rescue
      raise OptionParser::InvalidArgument, "private_key"
    ensure
      Bitcoin.network = start_network if start_network
    end
  end

  def by_txid(args)
    txid = args.first

    raise OptionParser::MissingArgument, "txid" unless txid

    txid
  end

  def by_addr(args)
    addr = args.first
    raise OptionParser::MissingArgument, "addr" unless addr

    raise OptionParser::InvalidArgument, "addr" unless Bitcoin.valid_address? addr

    addr
  end

  def puts_object(header, footer, attributes, object)
    puts_table header, footer, attributes.collect{|attr| 
      value = object.send(attr)
      [attr, value] if value
    }.compact
  end

  def puts_table(header, footer, pairs)
    pairs_h = pairs.to_h
    widest_key = pairs_h.keys.sort_by{|k| k.to_s.length}.last.to_s.length
    widest_value = pairs_h.values.sort_by{|v| v.to_s.length}.last.to_s.length

    widest_header = (footer.nil? || (header.length > footer.length) ) ? 
      header.length : footer.length

    content_width = ((widest_key+widest_value) > widest_header) ?
      (widest_key+widest_value + 2) : widest_header

    content_width = MAX_TABLE_WIDTH if content_width > MAX_TABLE_WIDTH

    endcap = "+%s+" % [ '-'*(content_width+2)] 

    puts [ endcap, "| %-#{content_width}s |" % [header], endcap,
      pairs.collect{|k,v| 
        if (k.to_s.length+v.to_s.length+2) > content_width
          data_width = content_width-widest_key-3
          sentence_splitter = /(.{1,#{data_width}})( +|$\n?)|(.{1,#{data_width}})/m
          v.scan(sentence_splitter).each_with_index.collect{|l,i|
          "| %-#{content_width}s |" % [ 
            ("%-#{widest_key}s: %s" % [(i == 0) ? k : '',l.first||l.last]) ]
          }
        else
          "| %-#{content_width}s |" % ["%-#{widest_key}s: %s" % [k,v]]
        end
      },
      endcap, 
      (footer) ? ["| %-#{content_width}s |" % [footer], endcap] : nil
    ].flatten.join("\n")
  end

end

