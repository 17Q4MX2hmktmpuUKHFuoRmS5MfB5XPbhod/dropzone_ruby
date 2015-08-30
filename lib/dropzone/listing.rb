module Dropzone
  class Listing < RecordBase
    include StateAccumulator

    attr_reader :txid, :create_item

    self.message_types = 'ITUPDT'

    state_attr :description, :price_currency, :price_in_units, :expiration_in

    def initialize(txid)
      @txid = txid

      item = Item.find txid
      @create_item = item if item && item.valid? && item.message_type == 'ITCRTE'

      if create_item
        attrs_from create_item

        messages(start_block: create_item.block_height).reverse.each{ |item| 
          attrs_from item if item.create_txid == txid}
      end
    end

    def found?
      !@create_item.nil?
    end

    def expiration_at
      create_item.block_height+expiration_in
    end
    
    def addr; from_create :sender_addr; end
    def latitude; from_create :latitude; end
    def longitude; from_create :longitude; end
    def radius; from_create :radius; end

    def seller_profile
      @seller_profile ||= SellerProfile.new addr if addr
    end

    private

    def from_create(attr)
      create_item.send attr if create_item
    end
  end

  class Listing::Validator < ValidatorBase
    validate :must_have_active_seller
    validate :must_have_created_item

    def must_have_active_seller(listing)
      errors.add :seller_profile, "invalid or missing" if ( 
        listing.seller_profile.nil? || !listing.seller_profile.valid? || 
        !listing.seller_profile.active? )
    end

    def must_have_created_item(listing)
      errors.add :create_item, "invalid or missing" unless (
        listing.create_item && listing.create_item.valid? )
    end
  end
end
