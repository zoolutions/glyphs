# frozen_string_literal: true

RSpec.describe Glyphs::MainRactor do
  let(:arguments) { { name: "house", library: :lucide, variant: nil, attributes: { class: "size-4" } } }

  describe ".current?" do
    it "is true on the main Ractor" do
      expect(described_class.current?).to be(true)
    end
  end

  describe ".render" do
    it "returns the markup the main Ractor renders" do
      skip "ractor-dispatch needs Ruby 4.0+ (Ractor::Port)" unless defined?(Ractor::Port)

      Glyphs.configure { |config| config.cache_svgs = false }

      expect(described_class.render(**arguments)).to eq(Glyphs.svg_for(**arguments))
    end

    it "names the icon and the gem to add when ractor-dispatch cannot load" do
      allow(described_class).to receive(:require).with("ractor/dispatch").and_raise(LoadError)

      expect { described_class.render(**arguments) }
        .to raise_error(described_class::Unavailable, %r{lucide/house.*ractor-dispatch}m)
    end
  end
end
