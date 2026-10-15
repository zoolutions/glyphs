# frozen_string_literal: true

require "logger"
require "stringio"

RSpec.describe Glyphs, ".finalize!" do
  it_behaves_like "a boot-finalized configuration",
    readers: [described_class.method(:configuration), Glyphs::IconReference.method(:component_to_library)],
    finalize: -> { described_class.finalize! }

  it "deep-freezes the configuration" do
    described_class.configure { |config| config.keep_icons = { lucide: %w[menu] } }

    described_class.finalize!

    configuration = described_class.configuration
    expect([configuration, configuration.fallback_icons, configuration.keep_icons, configuration.keep_icons[:lucide]])
      .to all(be_frozen)
  end

  it "is idempotent" do
    described_class.finalize!

    expect { described_class.finalize! }.not_to raise_error
  end

  it "leaves reset_configuration! a fresh, writable configuration" do
    described_class.finalize!

    described_class.reset_configuration!
    described_class.configure { |config| config.cache_svgs = false }

    expect(described_class.configuration.cache_svgs).to be(false)
  end

  it "keeps an on_missing_icon that cannot be shared as is, and freezes the rest" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)
    hook = ->(error, **) { warn error.message } # closes over the example: unshareable
    described_class.configure { |config| config.on_missing_icon = hook }

    expect { described_class.finalize! }.not_to raise_error

    configuration = described_class.configuration
    expect(configuration.on_missing_icon).to be(hook)
    expect([configuration, configuration.fallback_icons]).to all(be_frozen)
    expect(Ractor.shareable?(configuration.fallback_icons)).to be(true)
    expect(Ractor.shareable?(configuration)).to be(false) # main Ractor only, as documented
  end

  it "never freezes an object of the app's, even one it cannot share" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)
    logger = Logger.new(StringIO.new) # its LogDevice holds a Monitor: unshareable
    hook = Struct.new(:logger) { def call(error, **) = logger.warn(error.message) }.new(logger)
    described_class.configure { |config| config.on_missing_icon = hook }

    described_class.finalize!

    expect(described_class.configuration.on_missing_icon).to be(hook)
    expect([hook, logger, logger.instance_variable_get(:@logdev)].select(&:frozen?)).to be_empty
    expect { hook.call(StandardError.new("gone")) }.not_to raise_error
  end

  it "freezes a copy of a collection the app passed, never the app's own" do
    names = %w[menu palette]
    described_class.configure { |config| config.keep_icons = names }

    described_class.finalize!

    expect(described_class.configuration.keep_icons).to eq(%w[menu palette]).and be_frozen
    expect(names).not_to be_frozen
  end

  it "shares a copy of a capture-free on_missing_icon lambda, leaving the app's own unfrozen" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)
    hook = Module.new.instance_exec { ->(error, **) { error.message } } # self is a module: shareable
    described_class.configure { |config| config.on_missing_icon = hook }

    described_class.finalize!

    shared = described_class.configuration.on_missing_icon
    expect(Ractor.shareable?(described_class.configuration)).to be(true)
    expect(hook).not_to be_frozen
    expect([shared.lambda?, shared.call(StandardError.new("gone"))]).to eq([true, "gone"])
  end

  it "accepts a shareable on_missing_icon" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)
    hook = Class.new { def call(error, **) = warn(error.message) }.new.freeze
    described_class.configure { |config| config.on_missing_icon = hook }

    described_class.finalize!

    expect(described_class.configuration.on_missing_icon).to be(hook)
  end

  it "accepts a Ractor.shareable_proc on_missing_icon" do
    skip "Ractor.shareable_proc needs Ruby 4.0+" unless defined?(Ractor) && Ractor.respond_to?(:shareable_proc)
    hook = Ractor.shareable_proc { |error, **| warn error.message }
    described_class.configure { |config| config.on_missing_icon = hook }

    expect { described_class.finalize! }.not_to raise_error
  end
end
