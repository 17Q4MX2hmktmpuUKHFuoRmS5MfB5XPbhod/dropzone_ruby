#encoding: utf-8
require_relative 'spec_helper'
require_relative '../lib/dropzone/command'

class Hash
  alias :__hash__ :to_h
end

describe DropZoneCommand do
  include_context 'globals'

  before(:all) do
    clear_blockchain! 
    
    # This allows us to preserve the transaction ids regardless of what tests
    # ran before us.
    db = FakeBitcoinConnection::DB.execute(
      "UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='transactions';" )

   DropZoneCommand.local_persistence = Sequel.sqlite
  end

  def to_out(string)
    string.strip.gsub(/^[ ]+/,'')+"\n"
  end

  it "creates buyers" do
    expect{ DropZoneCommand.new(true).profile_buyer_create(
      [test_privkey],
      alias: "Miracle Max", 
      description: "First Buyer on DropZone"
    )}.to output(to_out(<<-eos)).to_stdout
    +-------------------------------------------+
    | Buyer: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    +-------------------------------------------+
    | alias      : Miracle Max                  |
    | description: First Buyer on DropZone      |
    +-------------------------------------------+
    | Tx: 01                                    |
    +-------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).profile_buyer_show(
      [test_pubkey], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +-------------------------------------------+
    | Buyer: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    +-------------------------------------------+
    | alias      : Miracle Max                  |
    | description: First Buyer on DropZone      |
    +-------------------------------------------+
    eos
  end

  it "creates sellers" do
    expect{ DropZoneCommand.new(true).profile_seller_create(
      [TESTER2_PRIVATE_KEY],
      alias: "Miracle Max", 
      description: "First Seller on DropZone",
      communications_pkey: TESTER2_PUBLIC_KEY
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------------------+
    | Seller: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp              |
    +---------------------------------------------------------+
    | alias              : Miracle Max                        |
    | description        : First Seller on DropZone           |
    | communications_pkey: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +---------------------------------------------------------+
    | Tx: 02                                                  |
    +---------------------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).profile_seller_show(
      [TESTER2_PUBLIC_KEY], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------------------+
    | Seller: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp              |
    +---------------------------------------------------------+
    | alias              : Miracle Max                        |
    | description        : First Seller on DropZone           |
    | communications_pkey: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +---------------------------------------------------------+
    eos
  end

  it "creates listings" do
    expect{ DropZoneCommand.new(true).listing_create(
      [TESTER2_PRIVATE_KEY],
      latitude: "51.500782", longitude: "-0.124669", radius: 1000, 
      price_currency: 'USD', price_in_units: 100, 
      description: "Test Description" 
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------+
    | Listing: mfZ1415XX782179875331XX1XXXXXgtzWu |
    +---------------------------------------------+
    | latitude      : 51.500782                   |
    | longitude     : -0.124669                   |
    | radius        : 1000                        |
    | price_currency: USD                         |
    | price_in_units: 100                         |
    | description   : Test Description            |
    +---------------------------------------------+
    | Tx: 03                                      |
    +---------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).listing_show(
      ['03'], {} )}.to output(to_out(<<-eos)).to_stdout
    +----------------------------------------------------+
    | Listing: 03                                        |
    +----------------------------------------------------+
    | latitude      : 51.500782                          |
    | longitude     : -0.124669                          |
    | radius        : 1000                               |
    | price_currency: USD                                |
    | price_in_units: 100                                |
    | description   : Test Description                   |
    | addr          : mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +----------------------------------------------------+
    eos
  end

  it "updates listings" do
    expect{ DropZoneCommand.new(true).listing_update(
      [TESTER2_PRIVATE_KEY, '03'],
      description: "Second Description"
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------+
    | Listing: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +---------------------------------------------+
    | description: Second Description             |
    +---------------------------------------------+
    | Tx: 04                                      |
    +---------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).listing_show(
      ['03'], {} )}.to output(to_out(<<-eos)).to_stdout
    +----------------------------------------------------+
    | Listing: 03                                        |
    +----------------------------------------------------+
    | latitude      : 51.500782                          |
    | longitude     : -0.124669                          |
    | radius        : 1000                               |
    | price_currency: USD                                |
    | price_in_units: 100                                |
    | description   : Second Description                 |
    | addr          : mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +----------------------------------------------------+
    eos
  end

  it "creates invoices" do
    expect{ DropZoneCommand.new(true).invoice_create(
      [TESTER2_PRIVATE_KEY, test_pubkey],
      amount_due: 50_000_000, expiration_in: 6
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------+
    | Invoice: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    +---------------------------------------------+
    | amount_due   : 50000000                     |
    | expiration_in: 6                            |
    +---------------------------------------------+
    | Tx: 05                                      |
    +---------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).invoice_show(
      ['5'], {} )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------------+
    | Invoice: 5                                        |
    +---------------------------------------------------+
    | amount_due   : 50000000                           |
    | expiration_in: 6                                  |
    | sender_addr  : mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    | receiver_addr: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    +---------------------------------------------------+
    eos
  end

  it "creates reviews" do
    expect{ DropZoneCommand.new(true).review_create(
      [test_privkey, '05'],
      description: 'Fair exchange', 
      delivery_quality: 8, 
      product_quality: 8, 
      communications_quality: 4
    )}.to output(to_out(<<-eos)).to_stdout
    +--------------------------------------------+
    | Review: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +--------------------------------------------+
    | description           : Fair exchange      |
    | delivery_quality      : 8                  |
    | product_quality       : 8                  |
    | communications_quality: 4                  |
    | invoice_txid          : 05                 |
    +--------------------------------------------+
    | Tx: 06                                     |
    +--------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).review_show(
      ['06'], {} )}.to output(to_out(<<-eos)).to_stdout
    +------------------------------------------------------------+
    | Review: 06                                                 |
    +------------------------------------------------------------+
    | description           : Fair exchange                      |
    | delivery_quality      : 8                                  |
    | product_quality       : 8                                  |
    | communications_quality: 4                                  |
    | invoice_txid          : 05                                 |
    | sender_addr           : mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    | receiver_addr         : mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +------------------------------------------------------------+
    eos
  end

  it "converses" do
    expect{ DropZoneCommand.new(true).chat_new(
      [test_privkey, TESTER2_PUBLIC_KEY], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +---------------------------------------------------+
    | Session: 07                                       |
    +---------------------------------------------------+
    | sender_addr  : mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    | receiver_addr: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    +---------------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_list(
      [test_privkey], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +----------------------------------------------+
    | Session: 07                                  |
    +----------------------------------------------+
    | Address : mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    | Messages: 0 Unread / 0 Total                 |
    +----------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_list(
      [TESTER2_PRIVATE_KEY], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +----------------------------------------------+
    | Session: 07                                  |
    +----------------------------------------------+
    | Address : mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    | Messages: 0 Unread / 0 Total                 |
    +----------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_say(
      [TESTER2_PRIVATE_KEY, '07', 'Greetings Initiator'], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +-------------------------------------------------+
    | Chat: 09                                        |
    +-------------------------------------------------+
    | Session    : 07                                 |
    | sender_addr: mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp |
    | message    : Greetings Initiator                |
    +-------------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_say(
      [test_privkey, '07', 'Conversation Initiated'], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +-------------------------------------------------+
    | Chat: 10                                        |
    +-------------------------------------------------+
    | Session    : 07                                 |
    | sender_addr: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw |
    | message    : Conversation Initiated             |
    +-------------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_show(
      [test_privkey, '07'], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +------------------------------------------------------------+
    | Chat: 07                                                   |
    +------------------------------------------------------------+
    | mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp: Greetings Initiator    |
    | mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw: Conversation Initiated |
    +------------------------------------------------------------+
    eos

    expect{ DropZoneCommand.new(true).chat_show(
      [TESTER2_PRIVATE_KEY, '07'], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +------------------------------------------------------------+
    | Chat: 07                                                   |
    +------------------------------------------------------------+
    | mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp: Greetings Initiator    |
    | mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw: Conversation Initiated |
    +------------------------------------------------------------+
    eos
  end

  it "wraps exceedingly long table values" do
    abstract = (<<-eos).tr("\n", " ")
Abstract. Drop Zone is a solution to the problem of restricted sales in censored markets.
The proposal is for the design of a protocol and reference client that encodes the location
and a brief description of a good onto The Blockchain. Those wishing to purchase the
good can search for items within a user-requested radius. Sellers list a good as available
within a geographic region, subject to some degree of precision, for the purpose of
obfuscating their precise location. Goods are announced next to an expiration, a hashtag,
and if space permits, a description. Once a buyer finds a good in a defined relative
proximity, a secure communication channel is opened between the parties on the Bitcoin
test network ("testnet"). Once negotiations are complete, the buyer sends payment to the
seller via the address listed on the Bitcoin mainnet. This spend action establishes
reputation for the buyer, and potentially for the seller. Once paid, the seller is to furnish
the exact GPS coordinates of the good to the buyer (alongside a small note such as
"Check in the crevice of the tree"). When the buyer successfully picks up the item at the
specified location, the buyer then issues a receipt with a note by spending flake to the
address of the original post. In this way, sellers receive a reputation score. The solution
is akin to that of Craigslist.org or Uber, but is distributed and as such provides nearly
risk-free terms to contraband sellers, and drastically reduced risk to contraband buyers.
    eos

    expect{ DropZoneCommand.new(true).chat_say(
      [test_privkey, '7', abstract], {}
    )}.to output(to_out(<<-eos)).to_stdout
    +----------------------------------------------------------------------------------+
    | Chat: 11                                                                         |
    +----------------------------------------------------------------------------------+
    | Session    : 7                                                                   |
    | sender_addr: mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw                                  |
    | message    : Abstract. Drop Zone is a solution to the problem of restricted      |
    |            : sales in censored markets. The proposal is for the design of a      |
    |            : protocol and reference client that encodes the location and a       |
    |            : brief description of a good onto The Blockchain. Those wishing to   |
    |            : purchase the good can search for items within a user-requested      |
    |            : radius. Sellers list a good as available within a geographic        |
    |            : region, subject to some degree of precision, for the purpose of     |
    |            : obfuscating their precise location. Goods are announced next to an  |
    |            : expiration, a hashtag, and if space permits, a description. Once a  |
    |            : buyer finds a good in a defined relative proximity, a secure        |
    |            : communication channel is opened between the parties on the Bitcoin  |
    |            : test network ("testnet"). Once negotiations are complete, the       |
    |            : buyer sends payment to the seller via the address listed on the     |
    |            : Bitcoin mainnet. This spend action establishes reputation for the   |
    |            : buyer, and potentially for the seller. Once paid, the seller is to  |
    |            : furnish the exact GPS coordinates of the good to the buyer          |
    |            : (alongside a small note such as "Check in the crevice of the        |
    |            : tree"). When the buyer successfully picks up the item at the        |
    |            : specified location, the buyer then issues a receipt with a note by  |
    |            : spending flake to the address of the original post. In this way,    |
    |            : sellers receive a reputation score. The solution is akin to that    |
    |            : of Craigslist.org or Uber, but is distributed and as such provides  |
    |            : nearly risk-free terms to contraband sellers, and drastically       |
    |            : reduced risk to contraband buyers.                                  |
    +----------------------------------------------------------------------------------+
    eos
  end
end
