# frozen_string_literal: true

RSpec.describe Glyphs::Configuration do
  describe "defaults" do
    subject(:configuration) { described_class.new }

    it "raises on missing icons outside Rails" do
      expect(configuration.raise_on_missing).to be(true)
    end

    it "does not guard renders against the prune by default" do
      expect(configuration.raise_on_prunable).to be(false)
    end

    it "has no missing icon hook by default" do
      expect(configuration.on_missing_icon).to be_nil
    end

    it "ships fallback icons for lucide, phosphor and heroicons" do
      expect(configuration.fallback_icons).to eq(
        lucide: "circle-question-mark",
        phosphor: "question",
        heroicons: "question-mark-circle"
      )
    end

    it "caches svgs" do
      expect(configuration.cache_svgs).to be(true)
    end

    it "keeps no extra icons by default" do
      expect(configuration.keep_icons).to eq([])
    end

    it "has no extra prune source globs by default" do
      expect(configuration.prune_source_globs).to be_nil
    end
  end

  describe "prune settings" do
    subject(:configuration) { described_class.new }

    it "accepts a flat keep_icons list" do
      configuration.keep_icons = %w[menu palette]

      expect(configuration.keep_icons).to eq(%w[menu palette])
    end

    it "accepts a per-library keep_icons hash" do
      configuration.keep_icons = { lucide: %w[menu], phosphor: %w[lock] }

      expect(configuration.keep_icons).to eq(lucide: %w[menu], phosphor: %w[lock])
    end
  end

  describe "Glyphs.configure" do
    it "yields the memoized configuration" do
      Glyphs.configure { |config| config.cache_svgs = false }

      expect(Glyphs.configuration.cache_svgs).to be(false)
    end

    it "can be reset" do
      Glyphs.configure { |config| config.cache_svgs = false }
      Glyphs.reset_configuration!

      expect(Glyphs.configuration.cache_svgs).to be(true)
    end
  end
end
