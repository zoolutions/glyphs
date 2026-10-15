# frozen_string_literal: true

RSpec.describe Glyphs::Icon do
  describe "rendering" do
    it "renders the icon svg" do
      html = Glyphs::LucideIcon.new(:house).call

      expect(html).to include("<svg")
      expect(html).to include('data-glyph="lucide-house"')
    end

    it "applies passed attributes" do
      html = Glyphs::LucideIcon.new(:house, class: "size-4 text-primary").call

      expect(html).to include("size-4 text-primary")
    end

    it "dasherizes underscored names" do
      html = Glyphs::LucideIcon.new(:circle_check).call

      expect(html).to include('data-glyph="lucide-circle-check"')
    end

    it "accepts string names" do
      html = Glyphs::LucideIcon.new("triangle-alert").call

      expect(html).to include('data-glyph="lucide-triangle-alert"')
    end

    it "honors an explicit variant" do
      html = Glyphs::HeroIcon.new(:check, variant: :solid).call

      expect(html).to include('data-glyph="hero-check-solid"')
    end

    it "falls back to the library default variant" do
      html = Glyphs::HeroIcon.new(:check).call

      expect(html).to include('data-glyph="hero-check-outline"')
    end

    it "resolves the phosphor default variant from the icons gem" do
      html = Glyphs::PhosphorIcon.new(:lock).call

      expect(html).to include('data-glyph="phosphor-lock"')
    end

    it "renders animated icons bundled with the icons gem" do
      html = Glyphs::AnimatedIcon.new("faded-spinner").call

      expect(html).to include("<svg")
    end

    it "renders the generic component with an explicit library" do
      html = described_class.new(:house, library: :lucide).call

      expect(html).to include('data-glyph="lucide-house"')
    end

    it "requires a library on the generic component" do
      expect { described_class.new(:house) }.to raise_error(ArgumentError, /library is required/)
    end
  end

  describe "missing icons" do
    it "raises when raise_on_missing is true" do
      Glyphs.configure { |config| config.raise_on_missing = true }

      expect { Glyphs::LucideIcon.new(:does_not_exist).call }.to raise_error(Icons::IconNotFound)
    end

    it "renders the fallback icon and notifies the hook when not raising" do
      notified = []
      Glyphs.configure do |config|
        config.raise_on_missing = false
        config.on_missing_icon = lambda { |error, name:, library:, variant:|
          notified << [error.class, name, library, variant]
        }
      end

      html = Glyphs::LucideIcon.new(:does_not_exist).call

      expect(html).to include('data-glyph="lucide-fallback"')
      expect(notified).to eq([[Icons::IconNotFound, "does-not-exist", :lucide, nil]])
    end

    it "re-raises when the library has no fallback icon" do
      Glyphs.configure do |config|
        config.raise_on_missing = false
        config.fallback_icons = {}
      end

      expect { Glyphs::LucideIcon.new(:does_not_exist).call }.to raise_error(Icons::IconNotFound)
    end

    it "re-raises the original error when the fallback icon is missing too" do
      Glyphs.configure do |config|
        config.raise_on_missing = false
        config.fallback_icons = { lucide: "also-missing" }
      end

      expect { Glyphs::LucideIcon.new(:does_not_exist).call }.to raise_error(Icons::IconNotFound, /does-not-exist/)
    end
  end

  describe "svg caching" do
    it "reads the svg file once when caching is enabled" do
      allow(File).to receive(:read).and_call_original

      Glyphs::LucideIcon.new(:house).call
      Glyphs::LucideIcon.new(:house).call

      expect(File).to have_received(:read).once
    end

    it "reads the svg file on every render when caching is disabled" do
      Glyphs.configure { |config| config.cache_svgs = false }
      allow(File).to receive(:read).and_call_original

      Glyphs::LucideIcon.new(:house).call
      Glyphs::LucideIcon.new(:house).call

      expect(File).to have_received(:read).twice
    end

    it "reads the svg file once across attribute sets" do
      allow(File).to receive(:read).and_call_original

      small = Glyphs::LucideIcon.new(:house, class: "size-4").call
      large = Glyphs::LucideIcon.new(:house, class: "size-6").call

      expect(File).to have_received(:read).once
      expect([small, large]).to all(include('data-glyph="lucide-house"'))
      expect(large).to include('class="size-6"')
    end
  end
end
