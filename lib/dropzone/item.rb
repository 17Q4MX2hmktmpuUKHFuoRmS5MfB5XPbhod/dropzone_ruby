module Dropzone
  class Item < MessageBase
    EARTH_RADIUS_IN_METERS = 6_371_000

    HASH_160_PARTS = /\A(?:mfZ|1DZ)([1-9X]{9})([1-9X]{9})([1-9X]{6}).+/

    attr_message d: :description, c: :price_currency
    attr_message_binary t: :create_txid
    attr_message_int p: :price_in_units, e: :expiration_in

    # These are receiver address attributes, not message attribs:
    attr_reader :latitude, :longitude, :radius

    @types_include = ['ITUPDT', 'ITCRTE']

    def latitude
      (@receiver_addr) ? 
        integer_to_latlon( address_parts(@receiver_addr, 0) ) : 
        @latitude
    end

    def longitude
      (@receiver_addr) ? 
        integer_to_latlon( address_parts(@receiver_addr, 1), 180 ) : 
        @longitude
    end

    def radius
      (@receiver_addr) ? 
        address_parts(@receiver_addr, 2) : 
        @radius
    end

    def message_type
      return @message_type if @message_type 

      create_txid ? 'ITUPDT' : 'ITCRTE'
    end

    # This is an easy guide to what we're doing here:
    # http://www.reddit.com/r/Bitcoin/comments/2ss3en/calculating_checksum_for_bitcoin_address/
    #
    # NOTE: There was a digit off in the reference spec, this radius is a seven
    #       digit number, not an eight digit number.
    def receiver_addr
      case 
        when @receiver_addr then @receiver_addr
        when create_txid then @sender_addr
        when latitude && longitude && radius
          receiver_addr_base = ('%s%09d%09d%06d' % [
            (blockchain.is_testing?) ? 'mfZ' : ('1' + BitcoinConnection::PREFIX),
            latlon_to_integer(latitude.to_f), 
            latlon_to_integer(longitude.to_f, 180), 
            radius.abs ]).tr('0','X')

          # The x's pad the checksum component for us to ensure the base conversion
          # produces the correct output. Similarly, we ignore them after the decode:
          hex_address = Bitcoin.decode_base58(receiver_addr_base+'XXXXXXX')[0...42]

          hash160 = [hex_address].pack('H*')
           
          # Bitcoin-ruby has a method to do much of this for us, but it is 
          # broken in that it only supports main-net addresses, and not testnet3
          checksum = Digest::SHA256.digest(Digest::SHA256.digest(hash160))[0,4]
       
          # Return the checksum'd receiver_addr
          Bitcoin.encode_base58((hash160 + checksum).unpack('H*').first)
        else 
          nil
      end
    end

    def self.blockchain
      Dropzone::RecordBase.blockchain
    end

    # Returns all *Items created* since (and including) the provided block
    # These are items and not listings, so as to query faster.
    # Items are returned in the order of newest to oldest
    def self.find_creates_since_block(starting_at, block_depth, &block)
      starting_at.downto(starting_at-block_depth).collect{|i|
        blockchain.messages_in_block(i, type: 'ITCRTE').collect do |item|
          (block_given?) ? block.call(item, i) : item
        end
      }.flatten.compact
    end

    def self.find_in_radius(starting_at, block_depth, lat, long, in_meters, &block)
      find_creates_since_block(starting_at, block_depth) do |item, nb|
        if distance_between(item.latitude, item.longitude, lat, long) <= in_meters 
          (block_given?) ? block.call(item, nb) : item
        end
      end
    end

    # haversine formula, pulled from :
    # http://www.movable-type.co.uk/scripts/latlong.html
    def self.distance_between(lat1, lon1, lat2, lon2)
      delta_phi = to_rad(lat2-lat1)
      delta_lamba = to_rad(lon2-lon1)

      a = Math.sin(delta_phi/2) ** 2 + [ Math.cos(to_rad(lat1)), 
        Math.cos(to_rad(lat2)), Math.sin(delta_lamba/2), 
        Math.sin(delta_lamba/2) ].reduce(:*)

      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

      EARTH_RADIUS_IN_METERS * c
    end

    def self.to_rad(angle)
      angle.to_f / 180 * Math::PI
    end

    private

    def address_parts(addr, part)
      parts = HASH_160_PARTS.match(addr)
      (parts && parts.length > 0) ? parts[part+1].tr('X','0').to_i : nil
    end

    def latlon_to_integer(lat_or_lon, unsigned_offset = 90)
      ((lat_or_lon + unsigned_offset) * 1_000_000).floor.abs unless lat_or_lon.nil?
    end

    def integer_to_latlon(lat_or_lon, unsigned_offset = 90)
      (BigDecimal.new(lat_or_lon) / 1_000_000 - unsigned_offset).to_f unless lat_or_lon.nil?
    end
  end

  class Item::Validator < ValidatorBase
    include MessageValidations

    validates :receiver_addr, equals_attribute: { attribute: :sender_addr }, 
      if: "self.sender_addr && self.create_txid"

    validates :latitude, numeric: true, unless: 'create_txid'
    validates_if_present :latitude, greater_than_or_equal_to: -90, if: 'create_txid.nil?'
    validates_if_present :latitude, less_than_or_equal_to: 90, if: 'create_txid.nil?'

    validates :longitude, numeric: true, unless: 'create_txid'
    validates_if_present :longitude, greater_than_or_equal_to: -180, if: 'create_txid.nil?'
    validates_if_present :longitude, less_than_or_equal_to: 180, if: 'create_txid.nil?'

    validates :radius, integer: true, unless: 'create_txid'
    validates_if_present :radius, greater_than_or_equal_to: 0, if: 'create_txid.nil?'
    validates_if_present :radius, less_than: 1000000, if: 'create_txid.nil?'

    validates :message_type, format: /\AIT(?:CRTE|UPDT)\Z/

    validates :price_currency, is_string: { 
      message: 'is required if price is specified' },
      unless: "price_in_units.nil? || create_txid"

    validates_if_present :description, is_string: true
    validates_if_present :price_in_units, integer: true, 
      greater_than_or_equal_to: 0
    validates_if_present :expiration_in, integer: true, 
      greater_than_or_equal_to: 0
  end
end
