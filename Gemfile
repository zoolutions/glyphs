# frozen_string_literal: true

source "https://rubygems.org"
gemspec

group :development do
  gem "async", require: false # runs conformance-kit's "fiber-safe under an Async reactor" example
  gem "benchmark-ips", require: false # bench/svg_for.rb
  gem "conformance-kit", "~> 0.4", require: false # concurrency conformance gates (zoolutions/phlex-reactive#363)
  gem "debug"
  gem "gem-release"
  gem "lint_roller"
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "rubocop-thread_safety", ">= 0.8", require: false # for conformance-kit's config/rubocop.yml
end
