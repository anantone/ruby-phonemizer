# frozen_string_literal: true

require_relative 'lib/phonemizer/version'

Gem::Specification.new do |spec|
  spec.name          = 'phonemizer'
  spec.version       = Phonemizer::VERSION
  spec.executables = ["phonemize"]  
  spec.authors       = 'anantone'
  spec.email         = 'self@anantone.me'

  spec.summary       = 'Minimal espeak-ng wrapper for multilingual phonemization'
  spec.description   = 'A thin Ruby wrapper around espeak-ng CLI for simple ' \
                       'word-to-IPA phonemization with caching and parallelism.'
  spec.homepage      = 'https://github.com/anantone/ruby-phonemizer'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  # Metadata read notably by rubydoc.info (which builds the docs with YARD
  # from the source repo) and by rubygems.org.
  spec.metadata      = {
    'source_code_uri'   => 'https://github.com/anantone/ruby-phonemizer',
    'changelog_uri'     => 'https://github.com/anantone/ruby-phonemizer/blob/main/CHANGELOG.md',
    'bug_tracker_uri'   => 'https://github.com/anantone/ruby-phonemizer/issues',
    'documentation_uri' => 'https://rubydoc.info/gems/phonemizer'
  }

  spec.files         = Dir['lib/**/*.rb', 'README.md', 'LICENSE', 'CHANGELOG.md', '.yardopts']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rdoc'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'kramdown' # YARD markdown provider
end
