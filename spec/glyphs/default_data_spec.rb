# frozen_string_literal: true

# config.merge_default_data: a caller's data: is merged over the library's
# configured default data instead of replacing it. The cached path (a hit on
# the data: template) and the uncached path (the icons gem) must agree byte for
# byte, and both must equal the icons gem given the pre-merged hash.
RSpec::Matchers.define_negated_matcher :not_include, :include

RSpec.describe Glyphs::DefaultData do
  def svg_for(name: "house", library: :lucide, variant: nil, **attributes)
    Glyphs.svg_for(name:, library:, variant:, attributes:)
  end

  # The icons gem rendering exactly these arguments, defaults replaced as it does.
  def icons_gem(name: "house", library: :lucide, variant: nil, **attributes)
    Icons::Icon.new(name:, library:, variant:, arguments: attributes).svg
  end

  # Renders from a warm cache (the plain and the data: template), failing if
  # that touched the file. Counts its own reads, so an example may call it twice.
  def from_cache(name: "house", library: :lucide, variant: nil, **attributes)
    svg_for(name:, library:, variant:, class: "warm")
    svg_for(name:, library:, variant:, data: { warm: true })
    reads = 0
    allow(File).to(receive(:read).and_wrap_original { |read, *args| (reads += 1) && read.call(*args) })
    svg_for(name:, library:, variant:, **attributes).tap { expect(reads).to eq(0) }
  end

  def uncached(**)
    Glyphs.configuration.cache_svgs = false
    svg_for(**)
  ensure
    Glyphs.configuration.cache_svgs = true
  end

  # Sets a library/variant's default data for one example (the icons gem's
  # configuration outlives reset_configuration!, so it is restored here).
  def with_default_data(data, library: :lucide, variant: :outline)
    defaults = Icons.config.libraries.dig(*[library, variant].compact, :default)
    original = defaults.data
    defaults.data = data
    yield
  ensure
    defaults.data = original
  end

  around do |example|
    with_default_data({ icon: true }) { example.run }
  end

  context "when on" do
    before { Glyphs.configure { |config| config.merge_default_data = true } }

    it "keeps the default data next to the caller's, cached and uncached alike" do
      cached = from_cache(data: { x: 1 })

      expect(cached).to include('data-icon="true"').and include('data-x="1"')
      expect(cached).to eq(uncached(data: { x: 1 })).and eq(icons_gem(data: { icon: true, x: 1 }))
    end

    it "lets the caller's value win on a shared key" do
      cached = from_cache(data: { icon: "custom" })

      expect(cached).to include('data-icon="custom"').and not_include('data-icon="true"')
      expect(cached).to eq(uncached(data: { icon: "custom" }))
    end

    it "lets a dashed string key win over an underscored symbol default" do
      with_default_data({ toggle_target: "a", icon: true }) do
        attributes = { data: { "toggle-target" => "b", x: "y" } }
        cached = from_cache(**attributes)

        expect(cached).to include('data-toggle-target="b"').and include('data-icon="true"')
        expect(cached.scan("data-toggle-target").size).to eq(1)
        expect(cached).to eq(uncached(**attributes))
          .and eq(icons_gem(data: { toggle_target: "a", icon: true, "toggle-target" => "b", x: "y" }))
      end
    end

    it "keeps the defaults' order when the caller overrides a later key and adds a new one" do
      with_default_data({ icon: true, size: "sm", tone: "muted" }) do
        cached = from_cache(data: { size: "lg", extra: "1" })

        expect(cached).to include('data-icon="true" data-size="lg" data-tone="muted"')
        expect(cached).to eq(uncached(data: { size: "lg", extra: "1" }))
          .and eq(icons_gem(data: { icon: true, size: "lg", tone: "muted", extra: "1" }))
      end
    end

    it "replaces a source attribute a default data key names, as the merged hash would" do
      with_default_data({ glyph: "default" }) do
        cached = from_cache(data: { x: 1 })

        expect(cached).to include('data-glyph="default"').and include('data-x="1"')
        expect(cached).to eq(uncached(data: { x: 1 })).and eq(icons_gem(data: { glyph: "default", x: 1 }))
      end
    end

    it "renders the defaults for an empty data hash" do
      cached = from_cache(data: {})

      expect(cached).to include('data-icon="true"')
      expect(cached).to eq(uncached(data: {})).and eq(icons_gem(data: { icon: true }))
    end

    it "merges with class: on a library with a default stroke width" do
      with_default_data({ icon: true }, library: :heroicons) do
        attributes = { class: "size-5", data: { x: 1 } }
        cached = from_cache(name: "check", library: :heroicons, **attributes)

        expect(cached).to include('data-icon="true"').and include('data-x="1"').and include('class="size-5"')
        expect(cached).to eq(uncached(name: "check", library: :heroicons, **attributes))
          .and eq(icons_gem(name: "check", library: :heroicons, class: "size-5", data: { icon: true, x: 1 }))
      end
    end

    it "merges the explicit variant's default data, not the default variant's" do
      with_default_data({ solid: true }, library: :heroicons, variant: :solid) do
        cached = from_cache(name: "check", library: :heroicons, variant: :solid, data: { x: 1 })

        expect(cached).to include('data-solid="true"').and include('data-x="1"').and not_include("data-icon")
        expect(cached).to eq(uncached(name: "check", library: :heroicons, variant: :solid, data: { x: 1 }))
      end
    end

    it "merges on a library without variants" do
      with_default_data({ icon: true }, library: :animated, variant: nil) do
        attributes = { name: "faded-spinner", library: :animated }
        cached = from_cache(**attributes, data: { x: 1 })

        expect(cached).to include('data-icon="true"').and include('data-x="1"')
        expect(cached).to eq(uncached(**attributes, data: { x: 1 }))
          .and eq(icons_gem(**attributes, data: { icon: true, x: 1 }))
      end
    end

    it "does not mutate the caller's hash, cached or uncached" do
      attributes = { data: { x: 1 }.freeze }.freeze

      svg_for(**attributes)
      Glyphs.svg_for(name: "house", library: :lucide, variant: nil, attributes:)
      Glyphs.configuration.cache_svgs = false
      Glyphs.svg_for(name: "house", library: :lucide, variant: nil, attributes:)

      expect(attributes).to eq(data: { x: 1 })
    end

    it "returns new hashes from .merge, leaving the caller's as given" do
      data = { x: 1 }.freeze
      attributes = { data:, class: "a" }.freeze

      merged = described_class.merge(attributes, library: :lucide, variant: nil)

      expect(merged).to eq(data: { "icon" => true, "x" => 1 }, class: "a")
      expect(attributes).to eq(data: { x: 1 }, class: "a")
    end

    it "renders a merged attribute the cache cannot apply through the icons gem with the defaults" do
      attributes = { href: "#home", data: { x: 1 } }

      expect(svg_for(**attributes)).to include('data-icon="true"')
        .and eq(icons_gem(href: "#home", data: { icon: true, x: 1 }))
    end

    it "renders a non-hash data value as the icons gem does, cached and uncached alike" do
      attributes = { data: "raw" }

      expect([svg_for(**attributes), svg_for(**attributes)]).to all(eq(icons_gem(**attributes)))
      expect(uncached(**attributes)).to eq(icons_gem(**attributes))
    end

    it "treats data: nil as no data, keeping the defaults and the cache" do
      cached = from_cache(class: "a", data: nil)

      expect(cached).to include('data-icon="true"').and not_include('data=""')
      expect(cached).to eq(uncached(class: "a", data: nil)).and eq(icons_gem(class: "a"))
    end

    {
      "the caller spells a key two ways" => [{ "icon" => true }, { icon: "s", "icon" => "t" }],
      "the defaults spell a key two ways" => [{ toggle_target: "a", "toggle-target" => "z" }, { toggle_target: "b" }],
      "both spell a key differently" => [{ toggle_target: "a", tone: "m" }, { "toggle-target" => "b", x: "1" }]
    }.each do |label, (defaults, data)|
      it "renders the same cached and uncached when #{label}" do
        with_default_data(defaults) do
          cached = from_cache(data:)

          expect(cached).to eq(uncached(data:))
        end
      end
    end

    it "lets the caller win when the defaults spell its key two ways" do
      with_default_data({ toggle_target: "a", "toggle-target" => "z" }) do
        expect(uncached(data: { toggle_target: "b" })).to include('data-toggle-target="b"')
      end
    end

    it "leaves a call without data: as the icons gem renders it" do
      expect(from_cache(class: "a")).to eq(icons_gem(class: "a")).and include('data-icon="true"')
    end

    it "merges through a library component" do
      html = Glyphs::LucideIcon.new(:house, data: { toggle_target: "show" }).call

      expect(html).to include('data-icon="true"').and include('data-toggle-target="show"')
    end

    it "renders a library with no default data as it does with the setting off" do
      with_default_data({}) do
        on = [from_cache(data: { x: 1 }), uncached(data: { x: 1 })]
        Glyphs.configuration.merge_default_data = false
        Glyphs.reset_cache!

        expect(on).to all(eq(from_cache(data: { x: 1 })))
      end
    end
  end

  context "when off (the default)" do
    it "replaces the default data with the caller's, as the icons gem does" do
      cached = from_cache(data: { x: 1 })

      expect(cached).to include('data-x="1"').and not_include("data-icon")
      expect(cached).to eq(uncached(data: { x: 1 })).and eq(icons_gem(data: { x: 1 }))
    end
  end
end
