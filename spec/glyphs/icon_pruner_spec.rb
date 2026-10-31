# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Glyphs::IconPruner do
  let(:tmpdir) { Dir.mktmpdir("glyphs-prune") }
  let(:icons_root) { File.join(tmpdir, "icons") }

  before do
    FileUtils.mkdir_p(icons_root)
    source = File.expand_path("../fixtures/svg/icons", __dir__)
    FileUtils.cp_r(Dir.glob(File.join(source, "*")), icons_root)
  end

  after { FileUtils.remove_entry(tmpdir) }

  def ref(library, variant, name)
    Glyphs::IconReference.new(library:, variant:, name:)
  end

  def exists?(relative)
    File.exist?(File.join(icons_root, relative))
  end

  describe "#prunable" do
    subject(:pruner) do
      described_class.new(icons_root:, references: Set[ref(:lucide, "outline", "house")],
        keep_icons: %w[triangle-*], fallback_icons: { lucide: "circle-question-mark" })
    end

    it "lists what #call would delete, as references" do
      expect(pruner.prunable).to contain_exactly(
        ref(:lucide, "outline", "anchor"), ref(:lucide, "outline", "circle-check")
      )
    end

    it "deletes nothing" do
      pruner.prunable

      expect(exists?("lucide/outline/circle-check.svg")).to be(true)
    end

    it "leaves out libraries #call refuses to prune, without its warning" do
      expect { pruner.prunable }.not_to output.to_stderr
      expect(pruner.prunable.map(&:library).uniq).to contain_exactly(:lucide)
    end

    it "matches the report of a real prune" do
      names = pruner.prunable.map(&:name)

      expect(names).to match_array(pruner.call.deleted_names)
    end
  end

  def prune(references:, keep_icons: [], fallback_icons: {}, dry_run: false)
    described_class.new(
      icons_root:, references: Set.new(references),
      keep_icons:, fallback_icons:, dry_run:
    ).call
  end

  describe "#call" do
    it "deletes unreferenced icons and keeps referenced ones" do
      prune(references: [ref(:lucide, "outline", "house")])

      expect(exists?("lucide/outline/house.svg")).to be(true)
      expect(exists?("lucide/outline/circle-check.svg")).to be(false)
    end

    it "always keeps configured fallback icons even without a reference" do
      prune(
        references: [ref(:lucide, "outline", "house")],
        fallback_icons: { lucide: "circle-question-mark" }
      )

      expect(exists?("lucide/outline/circle-question-mark.svg")).to be(true)
    end

    it "keeps icons named in a flat keep_icons list" do
      prune(references: [], keep_icons: %w[triangle-alert], fallback_icons: { lucide: "circle-question-mark" })

      expect(exists?("lucide/outline/triangle-alert.svg")).to be(true)
      expect(exists?("lucide/outline/house.svg")).to be(false)
    end

    it "keeps icons matched by a glob in keep_icons" do
      prune(references: [], keep_icons: %w[circle-*], fallback_icons: { lucide: "circle-question-mark" })

      expect(exists?("lucide/outline/circle-check.svg")).to be(true)
      expect(exists?("lucide/outline/circle-question-mark.svg")).to be(true)
      expect(exists?("lucide/outline/house.svg")).to be(false)
    end

    it "honors a per-library keep_icons hash" do
      prune(
        references: [ref(:lucide, "outline", "house")],
        keep_icons: { phosphor: %w[lock] },
        fallback_icons: { lucide: "circle-question-mark", phosphor: "question" }
      )

      expect(exists?("phosphor/regular/lock.svg")).to be(true)
      expect(exists?("lucide/outline/circle-check.svg")).to be(false)
    end

    it "scopes deletions per variant" do
      prune(
        references: [ref(:phosphor, "regular", "lock")],
        fallback_icons: { phosphor: "question" }
      )

      expect(exists?("phosphor/regular/lock.svg")).to be(true)
      expect(exists?("phosphor/light/padlock.svg")).to be(false)
    end

    it "never touches the animated library" do
      FileUtils.mkdir_p(File.join(icons_root, "animated"))
      File.write(File.join(icons_root, "animated", "faded-spinner.svg"), "<svg/>")

      prune(references: [ref(:lucide, "outline", "house")])

      expect(exists?("animated/faded-spinner.svg")).to be(true)
    end

    it "refuses to prune a library with no references, fallback, or per-library keep_icons" do
      report = nil
      expect do
        report = prune(references: [ref(:phosphor, "regular", "lock")], fallback_icons: { phosphor: "question" })
      end.to output(/refusing to prune lucide/).to_stderr

      # lucide had no references / keep / fallback → skipped, not wiped.
      expect(exists?("lucide/outline/house.svg")).to be(true)
      expect(report.stats.map(&:library)).not_to include(:lucide)
    end

    it "does not let a flat keep_icons list defeat the wipe guard for an unreferenced library" do
      # phosphor is referenced; lucide/heroicons are NOT. A flat (non-hash)
      # keep_icons must not make the guard think lucide/heroicons are in use.
      prune(
        references: [ref(:phosphor, "regular", "lock")],
        keep_icons: %w[lock question],
        fallback_icons: { phosphor: "question" }
      )

      # Unreferenced libraries are skipped whole, not wiped down to matches.
      expect(exists?("lucide/outline/house.svg")).to be(true)
      expect(exists?("lucide/outline/circle-check.svg")).to be(true)
      expect(exists?("heroicons/outline/check.svg")).to be(true)
    end

    it "treats an empty per-library keep_icons array as no evidence of use" do
      # { lucide: [] } must not bypass the wipe guard for an unreferenced lucide.
      prune(
        references: [ref(:phosphor, "regular", "lock")],
        keep_icons: { lucide: [] },
        fallback_icons: { phosphor: "question" }
      )

      expect(exists?("lucide/outline/house.svg")).to be(true)
      expect(exists?("lucide/outline/circle-check.svg")).to be(true)
    end

    it "keeps a flat keep_icons list scoping deletions WITHIN a referenced library" do
      # lucide IS referenced, so the flat list filters within it.
      prune(
        references: [ref(:lucide, "outline", "house")],
        keep_icons: %w[circle-*],
        fallback_icons: { lucide: "circle-question-mark" }
      )

      expect(exists?("lucide/outline/house.svg")).to be(true)          # referenced
      expect(exists?("lucide/outline/circle-check.svg")).to be(true)   # flat glob
      expect(exists?("lucide/outline/triangle-alert.svg")).to be(false) # pruned
    end

    it "returns a report with accurate counts and bytes" do
      report = prune(
        references: [ref(:lucide, "outline", "house")],
        fallback_icons: { lucide: "circle-question-mark" }
      )

      lucide = report.stats.find { |stat| stat.library == :lucide }
      expect(lucide.kept).to eq(2)            # house + circle-question-mark
      expect(lucide.deleted).to eq(3)         # anchor + circle-check + triangle-alert
      expect(lucide.bytes_freed).to be > 0
    end
  end

  describe "dry_run: true" do
    it "deletes nothing but reports what would be deleted" do
      report = prune(
        references: [ref(:lucide, "outline", "house")],
        fallback_icons: { lucide: "circle-question-mark" },
        dry_run: true
      )

      expect(exists?("lucide/outline/circle-check.svg")).to be(true)
      expect(report.deleted_count).to be > 0
      expect(report.dry_run).to be(true)
    end
  end
end
