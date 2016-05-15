require 'time' 

class BlockCypher
  class ResponseError < StandardError; end

  def initialize(is_testing = false)
    @is_testing = is_testing
  end

  def is_testing?
    @is_testing
  end

  def api_url
    'https://api.blockcypher.com/v1/btc/%s' % [(is_testing?) ? 'test3' : 'main']
  end

  def getrawtransaction(tx_id)
    Hash[ json_get('txs',  [tx_id.to_s, '?includeHex=1'].join).find_all{|k, v| 
      %w(hex block_height).include? k } ]
  end

  def getblockinfo(hash)
    puts 'TODO' if hash == 'last'

    Hash[ json_get('blocks', hash).find_all{|k,v| %w(hash height).include? k} ]
  end

  # NOTE: The blockcypher Api only shows the most recent 2000 transactions on an 
  # address. Either this method should use the non-API query mode, or an 
  # alternate API driver will be needed to properly support this method.
  #
  # Additionally, this api call returns the block times, but not the relay times
  # A better api would sort these by relay times.
  def listtransactions(addr, include_unconfirmed = false)
    params = ['addrs', [addr, 
      '?limit=2000&confirmations=%d', (include_unconfirmed) ? 0 : 1].join]

    json_get(*params)['txrefs'].sort_by{|t| t['confirmations'] }.collect{|tx|
      {'tx' => tx['tx_hash'] } }
  end

  def getbalance(addr)
    json_get('addrs', addr, 'balance')['balance']
  end

########################

  def listunspent(addr, include_unconfirmed = false)
    query = [addr,(include_unconfirmed) ? '?unconfirmed=1' : nil ].join
    json_get('address', 'unspent', query)['data']['unspent']
  end

  # Shows all the transactions that are unconfirmed for the provided address:
  def listunconfirmed(addr)
    json_get('address','unconfirmed',addr)['data']['unconfirmed']
  end

  def sendrawtransaction(raw_tx)
    # It seems as if blockr stopped relaying transactions with too many sigopps
    # so, we'll use Blockcypher instead:
    # TODO: use the getaddress or req for this...
    url = 'https://api.blockcypher.com/v1/btc/%s/txs/push' % [
      (is_testing?) ? 'test3' : 'main']

    begin
      response = RestClient.post url, {"tx" => raw_tx}.to_json, 
        accept: 'json', content_type: "json"

      JSON.parse(response)['tx']['hash']
    rescue => e
      raise ResponseError.new JSON.parse(e.response)['error']
    end
  end

  # The blockr.io block/txs method appears to omit some transactions. As such, 
  # we'll be using blockchain.info for this query.
  # Ideally, this would work: json_get('block', 'txs', number.to_s)['data']['txs']
  def getblock(number)
    if is_testing?
      # Use toshi if we're on testnet:
      per_page = 1000

      resource_for_page = lambda do |page| 
        url = ['https://testnet3.toshi.io/api/v0/blocks/', number, 
          '/transactions?limit=', per_page, '&offset=', page*per_page].join

        resp = RestClient::Resource.new(url).get(content_type: 'json')

        raise ResponseError if resp.code != 200

        JSON.parse resp
      end

      first_page = resource_for_page.call(0)
      total_transactions = first_page['transactions_count']

      transactions = ([first_page]+1.upto(total_transactions/per_page).collect{ |i|
        resource_for_page.call(i)}).collect{|page| page['transactions']}.flatten

      transactions.collect do |tx| 
        outs = tx['outputs'].collect{|out| out.merge({'addr' => out['addresses'][0]})}
        {'tx' => tx['hash'], 'out' => outs}
      end
    else
      # We use blockchain.info for mainnet, per the max implementation:
      # TODO: Let's move this over?
      block_hash = getblockinfo(number)['hash']

      resp  = RestClient::Resource.new( [ 'https://blockchain.info', 'block-index', 
        block_hash ].join('/')+'?format=json' ).get(content_type: 'json')

      # TODO: Handle 429
      raise ResponseError if resp.code != 200

      JSON.parse(resp)['tx'].collect do |tx, i| 
        {'tx' => tx['hash'], 'out' => tx['out']}
      end
    end
  end
  
  private 

  def request(*path, &block)
    JSON.parse(block.call(client(*path)))
  end

  def client(*path_parts)
    RestClient::Resource.new( ([api_url]+path_parts).join('/') )
  end

  def json_get(*path)
    request(*path) do |req| 
      begin
        request_count = 0
        req.get :content_type => :json, :accept => :json
      rescue => e
        # Rate limit hit:
        if e.http_code == 429 && request_count < 3
          request_count += 1
          sleep 3
          retry
        end
        raise ResponseError.new JSON.parse(e.response)['error']
      end
    end
  end
end
