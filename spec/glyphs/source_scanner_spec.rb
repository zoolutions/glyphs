# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec::Matchers.define_negated_matcher :exclude, :include

RSpec.describe Glyphs::SourceScanner do
  let(:root) { File.expand_path("../fixtures/source", __dir__) }

  def ref(library, variant, name)
    Glyphs::IconReference.new(library:, variant:, name:)
  end

  describe "#call" do
    subject(:references) { described_class.new(root:).call }

    context "with Ruby (Phlex) source" do
      it "records component calls with literal names" do
        expect(references).to include(
          ref(:lucide, "outline", "house"),
          ref(:lucide, "outline", "circle-check"),
          ref(:phosphor, "regular", "question")
        )
      end

      it "records the explicit variant, not the default" do
        expect(references).to include(
          ref(:heroicons, "solid", "check"),
          ref(:phosphor, "bold", "lock")
        )
      end

      it "dasherizes underscored symbol names" do
        expect(references).to include(ref(:lucide, "outline", "triangle-alert"))
      end

      it "records legacy helper calls" do
        expect(references).to include(
          ref(:lucide, "outline", "triangle-alert"),
          ref(:heroicons, "outline", "check")
        )
      end

      it "records generic Icon/icon calls with a literal library" do
        expect(references).to include(
          ref(:lucide, "outline", "house"),
          ref(:heroicons, "outline", "check")
        )
      end

      it "records iconify class strings inside Ruby" do
        expect(references).to include(ref(:lucide, "outline", "menu"))
      end
    end

    context "with dynamic references resolved from source" do
      subject(:keeps) { described_class.new(root:).dynamic_keeps }

      # Harvested names are ADVISORY keeps, not confirmed references — they never
      # appear in #call (which feeds verification) and never carry a variant
      # (the pruner keeps them across the library's default variant).
      it "does not leak harvested names into the confirmed reference set" do
        expect(references).not_to include(ref(:lucide, "outline", "zap"))
      end

      # `status = :zap; LucideIcon(status)` — the name is a literal in the same
      # file as a dynamic lucide call, so file-scoped harvesting keeps it for lucide.
      it "keeps a file-local literal for the dynamically-rendered library" do
        expect(keeps[:lucide]).to include("zap")
      end

      # `tiles = [{ icon: :feather }, { icon: "gear" }]; PhosphorIcon(tile[:icon])`
      # — `icon:` hash values are icon-declaration positions kept for phosphor.
      it "keeps icon: hash literals for a dynamically-rendered library" do
        expect(keeps[:phosphor]).to include("feather", "gear")
      end

      # `ICON = :bell_ringing` in sample_notifier.rb, rendered dynamically from a
      # different file. Declaration-based harvesting is global, so an ICON
      # constant anywhere is kept for every dynamically-rendered library.
      it "keeps an ICON constant declared in another file" do
        expect(keeps[:phosphor]).to include("bell-ringing")
      end

      # `ICONS = { "driving_license" => :car, … }.freeze` in frozen_icons_map.rb,
      # rendered via PhosphorIcon(@icon) in selectable_row.rb. Without unwrapping
      # the trailing `.freeze` CallNode, declaration harvest sees nothing and
      # cross-file dynamics prune those SVGs (production Icons::IconNotFound).
      it "keeps ICON* hash and array values even when the constant is .freeze'd" do
        expect(keeps[:phosphor]).to include(
          "car",
          "identification-badge",
          "warning",
          "check-circle"
        )
      end

      # A library with no dynamic call gets no dynamic keeps — heroicons here is
      # only ever called with literal names, so declaration literals don't leak
      # into it.
      it "does not create dynamic keeps for a statically-only library" do
        expect(keeps).not_to have_key(:heroicons)
      end

      # Guard against over-keeping across files: a bare literal in a file with no
      # dynamic icon call, not in a declaration position, is not harvested.
      it "does not harvest unrelated literals from files without dynamic calls" do
        expect(keeps.values.flat_map(&:to_a)).not_to include("definitely-not-an-icon")
      end
    end

    # Issue #35. The name lives in one file and reaches a wrapper's dynamic render
    # through a keyword only that file's own literals can resolve.
    context "with an icon name forwarded to a wrapper component" do
      subject(:keeps) { described_class.new(root:).dynamic_keeps }

      def keeps_for(source)
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p(File.join(dir, "app"))
          File.write(File.join(dir, "app/badge.rb"), "LucideIcon(@icon)")
          File.write(File.join(dir, "app/caller.rb"), source)
          described_class.new(root: dir).dynamic_keeps[:lucide]
        end
      end

      it "keeps a file's literals when it forwards with the icon: shorthand" do
        expect(keeps[:lucide]).to include("bell", "star")
      end

      it "keeps them for every dynamically-rendered library" do
        expect(keeps[:phosphor]).to include("bell", "star")
      end

      it "treats a computed value as a forward" do
        expect(keeps_for("ROWS = [[:bell]]\nBadge(icon: ROWS.first.first)")).to include("bell")
      end

      it "treats a ternary between literals as a forward, keeping both" do
        expect(keeps_for("Badge(icon: open ? :caret_up : :caret_down)")).to include("caret-up", "caret-down")
      end

      it "matches any key shaped like an icon" do
        expect(keeps_for("ROWS = [:bell]\nBadge(menu_icon: ROWS.first)")).to include("bell")
      end

      it "keeps only the declared name for a literal icon: value" do
        expect(keeps_for("ROWS = [:star]\nBadge(icon: :bell)")).to include("bell").and exclude("star")
      end

      it "reads a frozen literal as a literal, not a forward" do
        expect(keeps_for("ROWS = [:star]\nBadge(icon: { a: :bell }.freeze)")).to include("bell").and exclude("star")
      end

      it "treats a dynamic element of an array as a forward" do
        expect(keeps_for("ROWS = [:bell]\nBadge(icon: [:star, ROWS.first])")).to include("bell", "star")
      end

      it "treats a dynamic value of a hash as a forward" do
        expect(keeps_for("ROWS = [:bell]\nBadge(icon: { open: :star, closed: ROWS.first })")).to include("bell")
      end

      it "treats a splat inside a container as a forward" do
        expect(keeps_for("ROWS = [:bell]\nBadge(icons: [*ROWS])")).to include("bell")
        expect(keeps_for("ROWS = [:bell]\nBadge(icon: { **rows })")).to include("bell")
      end

      it "reads a container of nothing but literals as a declaration" do
        expect(keeps_for("ROWS = [:star]\nBadge(icon: [[:bell, 1], { a: :gear, b: nil }])"))
          .to include("bell", "gear").and exclude("star")
      end

      it "does not read a number as a forward" do
        expect(keeps_for("ROWS = [:star]\nBadge(icon_size: 16)\nBadge(icon_stroke: 1.5)")).to exclude("star")
      end

      it "does not read an explicit nil or false as a forward" do
        expect(keeps_for("ROWS = [:star]\nBadge(icon: nil)\nBadge(icon: false)\nBadge(icon: true)")).to exclude("star")
      end

      it "does not read a keyword named otherwise as a forward" do
        expect(keeps_for("ROWS = [:star]\nBadge(label: ROWS.first)")).to exclude("star")
      end

      # Shape 2 of the issue: a positional literal, with neither a forwarded
      # keyword nor a dynamic call in its file. Its literals stay prunable, and
      # raise_on_prunable is what catches this shape.
      it "harvests nothing from a file with neither a forward nor a dynamic call" do
        expect(keeps.values.flat_map(&:to_a)).not_to include("anchor")
      end

      it "keeps nothing when no library renders dynamically" do
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p(File.join(dir, "app"))
          File.write(File.join(dir, "app/caller.rb"), "Badge(icon: pick)\nLucideIcon(:house)")

          expect(described_class.new(root: dir).dynamic_keeps).to be_empty
        end
      end
    end

    context "with dynamic references" do
      it "does not record a reference with a dynamic variant" do
        heroicons = references.select { |r| r.library == :heroicons && r.name == "check" }

        expect(heroicons.map(&:variant)).not_to include("some-variant")
        expect(heroicons.map(&:variant)).to include("solid", "outline")
      end

      it "skips a generic Icon call with a dynamic library" do
        # `Icon(:house, library: some_library)` — house appears via the literal
        # lucide call, but no dynamic-library reference should be recorded.
        expect(references.count { |r| r.name == "house" && r.library == :lucide }).to be >= 1
      end
    end

    context "with template source" do
      it "records iconify strings in .erb" do
        expect(references).to include(ref(:heroicons, "outline", "search"))
      end

      it "records component calls embedded in .erb" do
        expect(references).to include(
          ref(:lucide, "outline", "house"),
          ref(:phosphor, "regular", "lock")
        )
      end

      it "records the explicit variant on a template component call" do
        # HeroIcon(:check, variant: :solid) in .erb must resolve to solid, not
        # the default outline — else the solid file gets pruned. (outline/check
        # is also present via _hero(:check) in the Ruby fixture, so only assert
        # the solid tuple is captured.)
        expect(references).to include(ref(:heroicons, "solid", "check"))
      end

      it "records the generic icon helper with from:/library: in a template" do
        expect(references).to include(
          ref(:lucide, "outline", "gauge"),          # icon "gauge", from: :lucide
          ref(:heroicons, "solid", "bell")           # icon("bell", library: "heroicons", variant: "solid")
        )
      end

      it "reads variant:/from: past a nested method call in the argument tail" do
        # icon("save", class: cn("a", active?), from: :lucide) — the nested cn()
        # paren must not truncate the tail before from:.
        expect(references).to include(ref(:lucide, "outline", "save"))
        # PhosphorIcon(:lock, class: cn("b"), variant: :bold) — variant past nested paren.
        expect(references).to include(ref(:phosphor, "bold", "lock"))
      end
    end

    context "with the variant-less '.' convention" do
      it "normalizes variant: :\".\" to no-variant so the flat file is kept" do
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p(File.join(dir, "app"))
          File.write(File.join(dir, "app/dot.rb"), 'LucideIcon(:house, variant: :".")')
          refs = described_class.new(root: dir).call

          expect(refs).to include(ref(:lucide, nil, "house"))
          expect(refs).not_to include(ref(:lucide, ".", "house"))
        end
      end
    end

    context "with an unparseable file" do
      it "warns and continues instead of crashing" do
        expect { described_class.new(root:).call }.not_to raise_error
      end
    end
  end
end
