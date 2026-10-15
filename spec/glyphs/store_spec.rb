# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe Glyphs::Store do
  it "builds a value once per key and returns it after" do
    first = described_class.fetch(:glyphs_store_spec) { Object.new }

    expect(described_class.fetch(:glyphs_store_spec) { raise "rebuilt" }).to be(first)
  end

  it "uses Ractor.store_if_absent on CRuby" do
    skip "no Ractor.store_if_absent on #{RUBY_ENGINE} #{RUBY_VERSION}" unless defined?(Ractor)

    expect(described_class.native?).to be(true)
  end

  # The fallback is set up at load, so it runs in a Ruby whose Ractor lacks
  # store_if_absent, as on an engine without Ractor.
  it "falls back to a locked Hash without Ractor.store_if_absent" do
    script = <<~RUBY
      Ractor.singleton_class.send(:remove_method, :store_if_absent) if defined?(Ractor)
      require "glyphs"
      first = Glyphs::Store.fetch(:key) { Object.new }
      print [Glyphs::Store.native?, Glyphs::Store.fetch(:key) { raise "rebuilt" }.equal?(first),
             Glyphs.svg_cache.class].inspect
    RUBY
    lib = File.expand_path("../../lib", __dir__)

    output, status = Open3.capture2e(RbConfig.ruby, "-rbundler/setup", "-I", lib, "-W0", "-e", script)

    expect([status.success?, output]).to eq([true, "[false, true, Glyphs::SvgCache]"])
  end
end
