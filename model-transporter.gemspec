# -*- encoding: utf-8 -*-
require File.expand_path('lib/transporter/version', File.dirname(__FILE__))

Gem::Specification.new do |gem|
  gem.authors       = ["Harrison Strowd"]
  gem.email         = ["harrison@bellycard.com"]
  gem.description   = %q{A helper for migrating ActiveRecord model data between two databases}
  gem.summary       = %q{Walks the ActiveRecord associations for a model, migrating all associated records from a source database to a target database.}
  gem.homepage      = "https://github.com/bellycard/model-transporter"
  gem.licenses      = ['MIT']

  gem.files         = `git ls-files`.split($\)
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "model-transporter"
  gem.require_paths = ["lib"]
  gem.version       = Transporter::VERSION
  gem.required_ruby_version = '>= 2.0'

  gem.add_dependency 'sneaky-save', '~> 0'

  gem.add_development_dependency 'activerecord', '~> 4.2'
  gem.add_development_dependency 'rspec', '~> 3.2'
  gem.add_development_dependency 'pry', '~> 0.10.1'
end
