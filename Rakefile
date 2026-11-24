# frozen_string_literal: true

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rdoc/task'

RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include('lib/**/*.rb', 'README.md', 'CHANGELOG.md')
  rdoc.options << '--charset' << 'utf-8'
end

# YARD — used by rubydoc.info for the gem's online documentation (see
# .yardopts). `rake yard` generates the docs into doc/.
require 'yard'
YARD::Rake::YardocTask.new(:yard)
task doc: :yard

task default: :spec
