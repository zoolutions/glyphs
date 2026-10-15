# frozen_string_literal: true

# A cache hit applies the caller's attributes to the cached SVG in plain Ruby.
# Every case here must come out byte-identical to what the icons gem renders
# from scratch (Icons::Icon#svg, a File.read and a Nokogiri pass per call).
RSpec.describe Glyphs::SvgTemplate do
  def svg_for(name: "house", library: :lucide, variant: nil, **attributes)
    Glyphs.svg_for(name:, library:, variant:, attributes:)
  end

  def uncached(name: "house", library: :lucide, variant: nil, **attributes)
    Icons::Icon.new(name:, library:, variant:, arguments: attributes).svg
  end

  # Renders from a warm cache (both the plain and the data: template), and
  # fails if that touched the file: a silent fall back to the icons gem would
  # match it trivially.
  def from_cache(name: "house", library: :lucide, **attributes)
    svg_for(name:, library:, class: "warm")
    svg_for(name:, library:, data: { warm: true })
    allow(File).to receive(:read).and_call_original
    svg_for(name:, library:, **attributes).tap { expect(File).not_to have_received(:read) }
  end

  {
    "a class string" => { class: "size-4 text-primary" },
    "a class token list" => { class: ["a", { b: true, c: false }, nil, [:d]] },
    "a class hash" => { class: { active: true, hidden: false } },
    "a nil class" => { class: nil },
    "an underscored key" => { stroke_width: 2 },
    "the dashed default key" => { "stroke-width": "3" },
    "a data hash" => { data: { controller: "icon", menu_target: "toggle" } },
    "data and class" => { class: "size-4", data: { action: "click->menu#toggle" } },
    "data overriding a source attribute" => { data: { glyph: "replaced" } },
    "a non-hash data value" => { data: "raw" },
    "an empty data hash" => { data: {} },
    "an aria hash" => { aria: { hidden: true, label: "Home" } },
    "a nested hash value" => { data: { config: { a: 1 } } },
    "escaped characters" => { id: "a&b<c>d" },
    "a double quote only" => { title: 'say "hi" & <go>' },
    "a single quote only" => { title: "it's" },
    "both quotes" => { title: %(it's "quoted") },
    "whitespace" => { title: "line\nnext\tcol\rend" },
    "non-ASCII" => { title: "Héllo wörld   😀" },
    "symbols, numbers and booleans" => { role: :img, width: 24, focusable: false, hidden_flag: true },
    "a nil value" => { height: nil },
    "a mixed-case name" => { viewBox: "0 0 1 1" },
    "a string key next to a symbol key" => { :class => "q", "class" => %w[a b] },
    "a data-* key and a data hash" => { "data-x": "1", data: { x: "2" } }
  }.each do |label, attributes|
    it "matches the icons gem for #{label}" do
      expected = uncached(**attributes)

      expect(from_cache(**attributes)).to eq(expected)
    end
  end

  it "matches the icons gem on a library with a default stroke width" do
    expected = uncached(name: "check", library: :heroicons, class: "size-5", data: { x: 1 })

    expect(from_cache(name: "check", library: :heroicons, class: "size-5", data: { x: 1 })).to eq(expected)
  end

  it "matches the icons gem on an animated icon" do
    expected = uncached(name: "faded-spinner", library: :animated, class: "size-8")

    expect(from_cache(name: "faded-spinner", library: :animated, class: "size-8")).to eq(expected)
  end

  it "replaces, not merges, a library's configured default data, as the icons gem does" do
    defaults = Icons.config.libraries.dig(:lucide, :outline, :default)
    original = defaults.data
    defaults.data = { controller: "icon" }
    expected = [uncached(class: "a"), uncached(data: { action: "x" })]

    expect([from_cache(class: "a"), from_cache(data: { action: "x" })]).to eq(expected)
  ensure
    defaults.data = original
  end

  {
    "an HTML boolean attribute" => { disabled: "disabled" },
    "a URI attribute" => { href: "/a b/é" },
    "an upper-case boolean attribute" => { Disabled: "x" },
    "a control character" => { title: "a\u0001b" }
  }.each do |label, attributes|
    it "renders #{label} through the icons gem, uncached" do
      svg_for
      allow(File).to receive(:read).and_call_original

      expect(svg_for(**attributes)).to eq(uncached(**attributes))
      expect(File).to have_received(:read).twice # once here, once in uncached
    end
  end

  it "returns the cached bytes, frozen, when there are no attributes" do
    first = svg_for

    expect(svg_for).to be(first).and be_frozen
  end

  it "is Ractor-shareable" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)

    template = described_class.new(uncached)

    expect(Ractor.shareable?(template)).to be(true)
  end
end
