# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Build gem and verify contents"
task :build do
  sh("gem build glyphs.gemspec --strict")
  gem_file = Dir["glyphs-*.gem"].first
  abort "Gem file not found after build" unless gem_file

  sh("gem unpack #{gem_file} --target /tmp/gem-verify")
  puts "\n=== Gem contents ==="
  sh("find /tmp/gem-verify -type f | sort")
  sh("rm -rf /tmp/gem-verify #{gem_file}")
end

# `rake release[X.Y.Z]` lives in rakelib/release.rake (the zoolutions release
# kit, shared across the gems); `bin/release` is its interactive front door.

task default: %i[spec rubocop]
