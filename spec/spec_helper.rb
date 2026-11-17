# frozen_string_literal: true

require 'phonemizer'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # The module caches across calls; reset between examples so one test's
  # cache never leaks into another's assertions.
  config.before { Phonemizer.clear_cache }
end

# Helper for the integration specs: true when the espeak-ng binary is on PATH.
def espeak_available?
  return @espeak_available if defined?(@espeak_available)

  @espeak_available = system('espeak-ng', '--version',
                             out: File::NULL, err: File::NULL)
end
