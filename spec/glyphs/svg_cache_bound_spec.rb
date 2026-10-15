# frozen_string_literal: true

RSpec.describe Glyphs, ".svg_for cache bound" do
  def svg_for(name = "house", library: :lucide, variant: nil, **attributes)
    described_class.svg_for(name:, library:, variant:, attributes:)
  end

  def uncached(name = "house", library: :lucide, variant: nil, **attributes)
    Icons::Icon.new(name:, library:, variant:, arguments: attributes).svg
  end

  it "defaults to 1024 entries" do
    expect(described_class.configuration.svg_cache_size).to eq(1024)
  end

  it "rejects a size that is not a positive Integer" do
    expect { described_class.configure { |config| config.svg_cache_size = 0 } }
      .to raise_error(ArgumentError, /svg_cache_size must be a positive Integer, got 0/)
  end

  it "keeps the cache at or below its size across 10k distinct class: values" do
    described_class.configure { |config| config.svg_cache_size = 2 }
    icons = %w[house circle-check triangle-alert]

    10_000.times { |i| svg_for(icons[i % icons.size], class: "size-#{i}") }

    expect(described_class.svg_cache.size).to be <= 2
  end

  it "holds one entry per icon, whatever attributes render it" do
    1_000.times { |i| svg_for(class: "size-#{i}", id: "icon-#{i}") }

    expect(described_class.svg_cache.size).to eq(1)
  end

  it "evicts the least recently used icon first" do
    described_class.configure { |config| config.svg_cache_size = 2 }
    svg_for("house")
    svg_for("circle-check")
    svg_for("house")
    svg_for("triangle-alert") # evicts circle-check, the least recently used
    allow(File).to receive(:read).and_call_original

    svg_for("house")
    expect(File).not_to have_received(:read)

    svg_for("circle-check")
    expect(File).to have_received(:read).once
  end

  it "merges a hit's different attributes onto the cached SVG without reading the file again" do
    expected = uncached(class: "size-6 text-primary", id: "nav-home")
    svg_for(class: "size-4")
    allow(File).to receive(:read).and_call_original

    expect(svg_for(class: "size-6 text-primary", id: "nav-home")).to eq(expected)
    expect(File).not_to have_received(:read)
  end

  it "keys variants apart" do
    solid = svg_for("check", library: :heroicons, variant: :solid)
    outline = svg_for("check", library: :heroicons, variant: :outline)

    expect(solid).to eq(uncached("check", library: :heroicons, variant: :solid))
    expect(outline).to eq(uncached("check", library: :heroicons, variant: :outline))
  end

  it "is cleared by reset_cache!" do
    svg_for

    described_class.reset_cache!

    expect(described_class.svg_cache.size).to eq(0)
  end
end
