# frozen_string_literal: true

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

  it "names an on_missing_icon that cannot be shared" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)
    described_class.configure { |config| config.on_missing_icon = ->(error, **) { warn error.message } }

    expect { described_class.finalize! }
      .to raise_error(ArgumentError, /Glyphs.finalize!: on_missing_icon is not Ractor-shareable/)
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
