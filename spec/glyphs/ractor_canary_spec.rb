# frozen_string_literal: true

# The blocks run inside the Ractor, so they name Glyphs, not described_class.
RSpec.describe "Glyphs.svg_for in a non-main Ractor" do
  before do
    Glyphs.finalize!
    Glyphs.svg_cache # loads Store, SvgCache and SvgTemplate before the Ractor needs them
    Glyphs::SvgTemplate.new("<svg></svg>").render(class: "x")
    Glyphs::MainRactor.current?
  end

  # Markup handed over from the main Ractor renders through the cache hit.
  context "with an icon preloaded in that Ractor" do
    let(:subject_call) do
      proc do |attributes|
        svg = '<svg viewbox="0 0 24 24" class="size-6"><path d="M3 12h18"></path></svg>'
        Glyphs.preload_svg(name: "house", library: :lucide, svg:)
        [Glyphs.svg_for(name: "house", library: :lucide, variant: nil, attributes:), Glyphs.svg_cache.size]
      end
    end

    it_behaves_like "runs inside a non-main Ractor",
      inputs: [{ class: "size-4", id: "nav-home", aria: { hidden: true } }.freeze]
  end

  # A miss renders on the main Ractor (Glyphs::MainRactor), so the markup is
  # the main Ractor's, byte for byte, and the Ractor's own cache keeps it.
  context "with an icon that Ractor has not cached" do
    let(:subject_call) do
      proc do |name, attributes|
        [Glyphs.svg_for(name:, library: :lucide, variant: nil, attributes:), Glyphs.svg_cache.size]
      end
    end

    context "with attributes the cache applies" do
      it_behaves_like "runs inside a non-main Ractor",
        inputs: ["house", { class: "size-4", aria: { hidden: true } }.freeze]
    end

    context "with data: attributes" do
      it_behaves_like "runs inside a non-main Ractor", inputs: ["house", { data: { controller: "nav" } }.freeze]
    end

    context "with an attribute that renders uncached" do
      it_behaves_like "runs inside a non-main Ractor", inputs: ["house", { href: "#home" }.freeze]
    end

    context "when the icon is missing and the library has a fallback" do
      before do
        Glyphs.reset_configuration!
        Glyphs.configure { |config| config.raise_on_missing = false }
        Glyphs.finalize!
      end

      it_behaves_like "runs inside a non-main Ractor", inputs: ["does-not-exist", {}.freeze]
    end

    context "when the icon is missing and raise_on_missing is set" do
      let(:subject_call) do
        proc do |name|
          Glyphs.svg_for(name:, library: :lucide, variant: nil, attributes: {})
        rescue Icons::IconNotFound => e
          [e.class, e.message]
        end
      end

      it_behaves_like "runs inside a non-main Ractor", inputs: ["does-not-exist"]
    end
  end
end
