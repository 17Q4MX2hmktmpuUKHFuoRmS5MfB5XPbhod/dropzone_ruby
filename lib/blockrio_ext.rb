require 'time' 

class BlockrIo
  # NOTE: The blockr Api only shows the most recent 200 transactions on an 
  # address. Either this method should use the non-API query mode, or an 
  # alternate API driver will be needed to properly support this method.
  #
  # Additionally, this api call returns the block times, but not the relay times
  # A better api would sort these by relay times.
  def listtransactions(addr, include_unconfirmed = false)
    # Confirmed Transactions:
    ret = json_get('address', 'txs', addr)['data']['txs'].sort_by{|t| 
      t['confirmations'] }

    if include_unconfirmed
      unconfirmed = json_get('address', 'unconfirmed', addr)['data']['unconfirmed']
      # We don't need every output listed, just the tx:
      unconfirmed.uniq!{|tx_h| tx_h['tx']}
      ret.unshift(*unconfirmed.sort_by{|t| Time.parse t['time_utc']}.reverse)
    end

    ret
  end

  # The blockr.io block/txs method appears to omit some transactions. As such, 
  # we'll be using blockchain.info for this query.
  # Ideally, this would work: json_get('block', 'txs', number.to_s)['data']['txs']
  def getblock(number)
    block_hash = getblockinfo(number)['hash']
    
    resp  = RestClient::Resource.new( [ 'https://blockchain.info', 'block-index', 
      block_hash ].join('/')+'?format=json' ).get(content_type: 'json')

    raise ResponseError if resp.code != 200

    JSON.parse(resp)['tx'].collect do |tx, i| 
      {'tx' => tx['hash'], 'out' => tx['out']}
    end
  end

  def getbalance(addr)
    json_get('address', 'balance', addr)['data']['balance']
  end

  def getrawtransaction(tx_id)
    json_get('tx', 'raw', tx_id.to_s)['data']['tx']
  end

  def getblockinfo(hash)
    json_get('block', 'info', hash)['data']
  end
end
