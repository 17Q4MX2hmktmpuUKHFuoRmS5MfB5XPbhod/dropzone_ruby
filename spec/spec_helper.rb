# encoding: ascii-8bit

require 'socksify'

require 'yaml'
require 'sham'
require 'logger'
require_relative '../lib/dropzone_ruby'
require_relative 'lib/fake_connection'

def config_yaml(file = 'config.yml') 
  YAML.load File.open([File.dirname(__FILE__),file].join('/')).read
end

TESTER_PRIVATE_KEY = "92UvdTpmxA6cvD6YeJZSiHW8ff8DsZXL2PHZu9Mg7JY3zbaETJw"
TESTER_PUBLIC_KEY = "mi37WkBomHJpUghCn7Vgh3ah33h6L9Nkqw"

TESTER2_PRIVATE_KEY = '92thgQGx77ihBaA56W7B1Qm8nhYHRERo1UqrgT2p6P6QTqkRhRB'
TESTER2_PUBLIC_KEY = 'mqVRfjepJTxxoDgDt892tCybhmjfKCFNyp'

TESTER3_PRIVATE_KEY = '92fRkALwcDiqz3WRJKYXUhAw4L1HCdbe1bPeCLbG3W7jjaw4h5j'
TESTER3_PUBLIC_KEY = 'mwX5BdTN843WtnSA1yEUuFYBd9cCiaoVam'

shared_context 'globals' do
  let(:test_privkey){ TESTER_PRIVATE_KEY }
  let(:test_pubkey){ TESTER_PUBLIC_KEY }
end

RSpec.configure do |config|
  config.before(:suite) do
    Bitcoin.network = :testnet3

    # Makes testing easier:
    Dropzone::RecordBase.blockchain = FakeBitcoinConnection.new height: 
      Dropzone::MessageBase::ENCODING_VERSION_1_BLOCK
  end
end

def clear_blockchain!
  Dropzone::RecordBase.blockchain.clear_transactions!
end

def block_height
  Dropzone::RecordBase.blockchain.height
end


def increment_block_height!
  Dropzone::RecordBase.blockchain.increment_block_height!
end
