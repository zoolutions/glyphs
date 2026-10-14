# frozen_string_literal: true

require "bundler/setup"

require "glyphs"
require "conformance_kit/rspec"
require "rubocop"
require "rubocop/rspec/support"
require "glyphs/rubocop"

Icons.configure do |config|
  config.base_path = File.expand_path("fixtures", __dir__)
  config.icons_path = "svg/icons"
end

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense, type: :cop_spec

  config.define_derived_metadata(file_path: %r{/spec/rubocop/}) do |metadata|
    metadata[:type] = :cop_spec
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.before do
    Glyphs.reset_configuration!
    Glyphs.reset_cache!
  end
end
