# frozen_string_literal: true

require_relative "lib/phonemizer/version"

Gem::Specification.new do |spec|
  spec.name          = "phonemizer"
  spec.version       = Phonemizer::VERSION
  spec.authors       = ["[anantone]"]
  spec.email         = ["[self@anantone.me]"]

  spec.summary       = "Minimal espeak-ng wrapper for phonemization"
  spec.description   = "A thin Ruby wrapper around espeak-ng CLI for simple " \
                       "word-to-IPA phonemization with caching and parallelism."
  spec.homepage      = "https://github.com/anantone/ruby-phonemizer.git"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
end
