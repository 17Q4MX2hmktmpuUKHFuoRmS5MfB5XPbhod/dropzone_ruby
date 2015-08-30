# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dropzone/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Miracle Max"]
  gem.email         = ["17Q4MX2hmktmpuUKHFuoRmS5MfB5XPbhod@mail2tor.com"]
  gem.summary       = "An Anonymous Peer-To-Peer Local Contraband Marketplace"
  gem.description   = 'Drop Zone is a solution to the problem of restricted sales in censored markets. The proposal is for the design of a protocol and reference client that encodes the location and a brief description of a good onto The Blockchain. Those wishing to purchase the good can search for items within a user-requested radius. Sellers list a good as available within a geographic region, subject to some degree of precision, for the purpose of obfuscating their precise location. Goods are announced next to an expiration, a hashtag, and if space permits, a description. Once a buyer finds a good in a defined relative proximity, a secure communication channel is opened between the parties on the Bitcoin test network ("testnet"). Once negotiations are complete, the buyer sends payment to the seller via the address listed on the Bitcoin mainnet. This spend action establishes reputation for the buyer, and potentially for the seller. Once paid, the seller is to furnish the exact GPS coordinates of the good to the buyer (alongside a small note such as "Check in the crevice of the tree"). When the buyer successfully picks up the item at the specified location, the buyer then issues a receipt with a note by spending flake to the address of the original post. In this way, sellers receive a reputation score. The solution is akin to that of Craigslist.org or Uber, but is distributed and as such provides nearly risk-free terms to contraband sellers, and drastically reduced risk to contraband buyers.'
  gem.homepage      = "https://github.com/17Q4MX2hmktmpuUKHFuoRmS5MfB5XPbhod/dropzone_ruby.git"
  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "dropzone_ruby"
  gem.require_paths = ["lib"]
  gem.version       = Dropzone::VERSION
  gem.required_ruby_version = '>= 1.9'
  gem.license       = 'LGPL'

  gem.add_runtime_dependency 'counterparty_ruby', '~> 1.2'
  gem.add_runtime_dependency 'commander', '~> 4.3'
  gem.add_runtime_dependency 'sequel', '~> 4.21'
  gem.add_runtime_dependency 'sqlite3', '~> 1.3'
  gem.add_runtime_dependency 'veto', '~> 1.0'
  gem.add_runtime_dependency 'socksify', '~> 1.7'

  gem.add_development_dependency 'rspec', '~> 3.2'
  gem.add_development_dependency 'rake', '~> 10.4'
  gem.add_development_dependency 'rdoc', '~> 4.2'
  gem.add_development_dependency 'sham', '~> 1.1'
end

