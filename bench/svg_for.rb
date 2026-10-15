# frozen_string_literal: true

# Micro bench of Glyphs.svg_for, the per-render hot path. Run it on the same
# machine before and after a change and report both:
#
#   bundle exec ruby bench/svg_for.rb
#
# Per call, not per request: a page with N icons pays N of these.
require "bundler/setup"
require "benchmark/ips"
require "glyphs"

Icons.configure do |config|
  config.base_path = File.expand_path("../spec/fixtures", __dir__)
  config.icons_path = "svg/icons"
end

def svg_for(**attributes)
  Glyphs.svg_for(name: "house", library: :lucide, variant: nil, attributes:)
end

def allocations_per_call(call, calls = 1_000)
  call.call # warm the cache
  before = GC.stat(:total_allocated_objects)
  calls.times { call.call }
  (GC.stat(:total_allocated_objects) - before) / calls.to_f
end

counter = 0
cases = {
  "hit, no attributes" => -> { svg_for },
  "hit, same class:" => -> { svg_for(class: "size-4") },
  "distinct id: per call" => -> { svg_for(class: "size-4", id: "icon-#{counter += 1}") },
  "uncached (cache_svgs = false)" => lambda {
    Glyphs.configuration.cache_svgs = false
    svg_for(class: "size-4")
  }
}

puts "#{RUBY_DESCRIPTION}\n\nallocations per call:"
cases.each do |label, call|
  Glyphs.reset_configuration!
  Glyphs.reset_cache!
  puts "  #{label.ljust(32)} #{allocations_per_call(call).round(1).to_s.rjust(8)}"
end
puts

Benchmark.ips do |x|
  x.config(warmup: 1, time: 3)
  cases.each do |label, call|
    x.report(label) do |times|
      Glyphs.reset_configuration!
      times.times { call.call }
    end
  end
end
