# frozen_string_literal: true

# The icons gem cannot run in a non-main Ractor (its Icons.configuration is an
# unshareable module ivar, and Nokogiri is Ractor-unsafe), so the Ractor seeds
# its own cache from a literal SVG, as the main Ractor would hand it one, and
# the canary renders through Glyphs.svg_for's cache hit there. The block runs
# inside the Ractor, so it names Glyphs, not described_class.
RSpec.describe "Glyphs.svg_for in a non-main Ractor" do
  before do
    Glyphs.finalize!
    Glyphs.svg_cache # loads Store, SvgCache and SvgTemplate before the Ractor needs them
    Glyphs::SvgTemplate.new("<svg></svg>").render(class: "x")
  end

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
