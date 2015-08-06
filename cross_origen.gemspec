# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = "rosetta_stone"
  spec.version       = RosettaStone::VERSION
  spec.authors       = ["Stephen McGinty"]
  spec.email         = ["r49409@freescale.com"]
  spec.summary       = "Translators for importing and exporting RGen data to/from 3rd party formats"
  spec.homepage      = "http://rgen.freescale.net/rosetta_stone"

  spec.required_ruby_version     = '>= 1.9.3'
  spec.required_rubygems_version = '>= 1.8.11'

  # Only the files that are hit by these wildcards will be included in the
  # packaged gem, the default should hit everything in most cases but this will
  # need to be added to if you have any custom directories
  spec.files         = Dir["lib/**/*.rb", "templates/**/*", "config/**/*.rb",
                           "bin/*", "lib/tasks/**/*.rake", "pattern/**/*.rb",
                           "program/**/*.rb"
                          ]
  spec.executables   = []
  spec.require_paths = ["lib"]

  # Add any gems that your plugin needs to run within a host application
  spec.add_runtime_dependency "rgen_core", ">= 2.5.0.pre84"
  spec.add_runtime_dependency "nokogiri-happymapper", "~>0.5"
  spec.add_runtime_dependency "axlsx", "~>2.0.1"
  spec.add_runtime_dependency "sanitize", "~>3.0"
  spec.add_runtime_dependency "spreadsheet", "~>1.0"
  spec.add_runtime_dependency "roo", ">= 1.13.2"
  spec.add_runtime_dependency "fastimage", ">=1.6.6"
  if RUBY_VERSION < "2.0.0"
    spec.add_runtime_dependency "scrub_rb", "~>1.0"
  end

  # Add any gems that your plugin needs for its development environment only
  spec.add_development_dependency "doc_helpers", ">= 1.7.0"
end
