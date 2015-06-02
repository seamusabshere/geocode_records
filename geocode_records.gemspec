# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'geocode_records/version'

Gem::Specification.new do |spec|
  spec.name          = "geocode_records"
  spec.version       = GeocodeRecords::VERSION
  spec.authors       = ["Seamus Abshere"]
  spec.email         = ["seamus@abshere.net"]
  spec.summary       = %q{Geocode an ActiveRecord::Relation with node_smartystreets}
  spec.description   = %q{A quick way to re-geocode a table}
  spec.homepage      = "https://github.com/seamusabshere/geocode_records"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activerecord', '~>4.1.9'
  spec.add_runtime_dependency 'pg'
  spec.add_runtime_dependency 'attr_extras'
  spec.add_runtime_dependency 'zaru'
  spec.add_runtime_dependency 'upsert'
  spec.add_runtime_dependency 'pasqual'
  
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
