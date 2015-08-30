module Dropzone
  class Profile < RecordBase
    include StateAccumulator

    attr_reader :addr, :transfer_pkey, :prior_profile

    def initialize(addr)
      @addr = addr

      messages.reverse.each_with_index do |seller, i|
        # There is a bit of extra logic if the seller profile was transferred
        # from elsewhere
        if i == 0 && seller.transfer_pkey
          # Load the profile from the prior address and pop it off the stack
          @prior_profile = self.class.new seller.sender_addr

          # It's possible the prior profile was invalid
          break unless @prior_profile.valid?

          # And it's possible the prior profile was deactivated or not
          # transferred to us:
          break unless @prior_profile.transfer_pkey == addr

          attrs_from @prior_profile
        else
          # This prevents a second inbound transfer from happening:
          next if seller.transfer_pkey == addr 

          # In case they transferred away :
          @transfer_pkey = seller.transfer_pkey

          attrs_from seller
        end

        break if @transfer_pkey
      end
    end

    def closed?; (@transfer_pkey == 0); end
    def active?; @transfer_pkey.nil? end
    def found?; messages.length > 0; end
  end

  module ValidateProfile
    def self.included(base)
      base.validate :must_have_declaration
      base.validate :prior_profile_is_valid
      base.validate :prior_profile_transferred_to_us
    end

    def must_have_declaration(profile)
      errors.add :addr, "profile not found" unless profile.messages.length > 0
    end

    def prior_profile_is_valid(profile)
      if profile.prior_profile && !profile.prior_profile.valid?
        errors.add :prior_profile, "invalid"
      end 
    end

    def prior_profile_transferred_to_us(profile)
      if profile.prior_profile && profile.prior_profile.transfer_pkey != profile.addr
        errors.add :prior_profile, "invalid transfer or closed"
      end 
    end
  end

  # A profile is different than a Seller message, as it's the concatenation of
  # Seller messages, and is missing the transfer and sender_addr. 
  class SellerProfile < Profile
    self.message_types = 'SLUPDT'

    state_attr :description, :alias, :communications_pkey

    class Validator < ValidatorBase; include ValidateProfile; end
  end

  class BuyerProfile < Profile
    self.message_types = 'BYUPDT'

    state_attr :description, :alias

    class Validator < ValidatorBase; include ValidateProfile; end
  end

end
