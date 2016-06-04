require 'time' 

class SoChain
  class ResponseError < StandardError; end

  def initialize(is_testing = false)
    @is_testing = is_testing
  end

  def is_testing?
    @is_testing
  end

  def api_url
    'https://chain.so/api/v2'
  end

  def chainnet
    (is_testing?) ? 'BTCTEST' : 'BTC'
  end

  def getrawtransaction(txid)
    data = json_get('tx', chainnet, txid)['data']
    {'hex' => data['tx_hex'], 'block_height' => data['block_no']}
  end

  def getblockinfo(hash)
    puts 'TODO' if hash == 'last'

    data = json_get('get_block', chainnet, hash)['data']
    {'hash' => data['blockhash'], 'height' => data['block_no']}
  end

  # NOTE: The SoChain Api only shows the most recent 50 transactions on an 
  # address. Either this method should use the non-API query mode, or an 
  # alternate API driver will be needed to properly support this method.
  # Also, SoChain doesn't support the include_unconfirmed mechansim atm.
  #
  # Additionally, this api call returns the block times, but not the relay times
  # A better api would sort these by relay times.
  def listtransactions(addr, include_unconfirmed = false)
    params = ['address', chainnet, addr]

    json_get(*params)['data']['txs'].sort_by{|t| t['confirmations'] }.collect{|tx| 
      {'tx' => tx['txid'] } }
  end

  def getbalance(addr)
    json_get('get_address_balance', chainnet, addr)['data']['confirmed_balance']
  end

  def getblock(number)
    json_get('block', chainnet, number)['data']['txs'].collect{|tx|
      {'receiver_addr' => tx['outputs'][0]['address'], 'tx' => tx['txid']} }
  end

  def listunspent(addr, include_unconfirmed = false)
    json_get('get_tx_unspent', chainnet, addr)['data']['txs'].collect do |tx|
      {'confirmations' => tx['confirmations'], 'tx' => tx['txid'], 
       'amount' => tx['value'], 'n' => tx['output_no']}
    end
  end
  
  def sendrawtransaction(raw_tx)
    begin
      # So Chain:
      url = [api_url, 'send_tx', chainnet].join '/'
      response = RestClient.post url, {"tx_hex" => raw_tx}.to_json, 
        accept: 'json', content_type: "json"
      JSON.parse(response)['data']['txid']

    rescue => e
      raise ResponseError.new JSON.parse(e.response)['error']
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
      request_count = 0
      begin
        req.get :content_type => :json, :accept => :json
      rescue => e
        # Rate limit hit:
        if e.http_code == 429 && request_count < 4
          request_count += 1
          sleep 12
          retry
        end
        raise ResponseError.new JSON.parse(e.response)['error']
      end
    end
  end
end
