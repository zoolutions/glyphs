# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Glyphs::PruneGuard do
  let(:source_root) { File.expand_path("../fixtures/source", __dir__) }
  let(:svg_root) { File.expand_path("../fixtures/svg/icons", __dir__) }

  # The guard scans Dir.pwd outside Rails, and Icons.config already points at
  # spec/fixtures, so this makes the fixtures the whole app.
  before do
    allow(Dir).to receive(:pwd).and_return(source_root)
    Glyphs.configure { |config| config.raise_on_prunable = true }
  end

  def render(name, library: :lucide, variant: nil)
    Glyphs.svg_for(name:, library:, variant:, attributes: {})
  end

  describe "with raise_on_prunable on" do
    it "raises for shape 2 of the issue, a positional literal no scan can see" do
      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)
    end

    it "names the library, variant and name, and both ways out" do
      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError) { |error|
        expect(error.message).to include("lucide/outline/anchor", "icon:", "keep_icons")
      }
    end

    it "raises through the component, as a test rendering a page would" do
      expect { Glyphs::LucideIcon.new(:anchor).call }.to raise_error(Glyphs::PrunableIconError)
    end

    it "raises on every render, because a refused icon is never cached" do
      2.times { expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError) }
      expect(Glyphs.svg_cache.size).to eq(0)
    end

    it "raises when the cache is off" do
      Glyphs.configure { |config| config.cache_svgs = false }

      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)
    end

    it "renders a referenced icon" do
      expect(render("house")).to include("<svg")
    end

    it "renders a referenced icon at its explicit variant" do
      expect(render("question", library: :phosphor, variant: :regular)).to include("<svg")
    end

    it "judges each variant on its own, as the pruner does" do
      expect { render("padlock", library: :phosphor, variant: :light) }.to raise_error(Glyphs::PrunableIconError)
    end

    it "renders a configured fallback icon" do
      expect(render("circle-question-mark")).to include("<svg")
    end

    it "accepts a symbol name" do
      expect { render(:anchor) }.to raise_error(Glyphs::PrunableIconError)
    end

    context "with keep_icons" do
      it "renders a name listed flat" do
        Glyphs.configure { |config| config.keep_icons = %w[anchor] }

        expect(render("anchor")).to include("<svg")
      end

      it "renders a name matched by a glob" do
        Glyphs.configure { |config| config.keep_icons = %w[anch*] }

        expect(render("anchor")).to include("<svg")
      end

      it "renders a name listed for its library" do
        Glyphs.configure { |config| config.keep_icons = { lucide: %w[anchor] } }

        expect(render("anchor")).to include("<svg")
      end

      it "raises for a name listed only for another library" do
        Glyphs.configure { |config| config.keep_icons = { phosphor: %w[anchor] } }

        expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)
      end
    end

    context "with an icon that does not exist" do
      it "leaves a raise to the missing-icon policy" do
        expect { render("does-not-exist") }.to raise_error(Icons::IconNotFound)
      end

      it "leaves a fallback to the missing-icon policy" do
        Glyphs.configure { |config| config.raise_on_missing = false }

        expect(render("does-not-exist")).to include("<svg")
      end
    end

    it "leaves the animated library alone, which a prune never touches" do
      expect(render("faded-spinner", library: :animated)).to include("<svg")
    end

    it "leaves a library alone that the prune refuses to touch" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "app"))
        File.write(File.join(dir, "app/only_lucide.rb"), "LucideIcon(:house)")
        Glyphs.configure { |config| config.fallback_icons = { lucide: "circle-question-mark" } }

        allow(Dir).to receive(:pwd).and_return(dir)

        expect(render("check", library: :heroicons)).to include("<svg")
      end
    end

    it "scans once however many icons render" do
      allow(Glyphs::SourceScanner).to receive(:new).and_call_original

      render("house")
      render("house")
      render("circle-check")

      expect(Glyphs::SourceScanner).to have_received(:new).once
    end

    it "does not reach the guard on a cache hit" do
      render("house")
      allow(described_class).to receive(:new).and_call_original

      render("house")

      expect(described_class).not_to have_received(:new)
    end

    context "when threads race on the first render" do
      let(:subject_call) { -> { render("house") } }

      # With the cache on, SvgCache already serializes first renders. `allow` with a
      # count raises on the second scan, inside the racing thread.
      before do
        Glyphs.configure { |config| config.cache_svgs = false }
        allow(Glyphs::SourceScanner).to receive(:new).once.and_call_original
      end

      it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :equal
    end

    it "scans again after configure, because the settings feed the keep-set" do
      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)

      Glyphs.configure { |config| config.keep_icons = %w[anchor] }

      expect(render("anchor")).to include("<svg")
    end

    it "scans again when a keep_icons list changes in place" do
      names = []
      Glyphs.configure { |config| config.keep_icons = names }
      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)

      names << "anchor"

      expect(render("anchor")).to include("<svg")
    end

    it "does not scan again for a setting the keep-set does not read" do
      render("house")
      allow(Glyphs::SourceScanner).to receive(:new).and_call_original

      Glyphs.configure { |config| config.raise_on_missing = false }
      render("circle-check")

      expect(Glyphs::SourceScanner).not_to have_received(:new)
    end

    it "renders from inside a configure block" do
      Glyphs.configure { |_config| expect(render("house")).to include("<svg") }
    end

    it "scans again after reset_configuration!" do
      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)

      Glyphs.reset_configuration!
      Glyphs.configure do |config|
        config.raise_on_prunable = true
        config.keep_icons = %w[anchor]
      end

      expect(render("anchor")).to include("<svg")
    end

    it "keeps working once the configuration is finalized" do
      Glyphs.finalize!

      expect { render("anchor") }.to raise_error(Glyphs::PrunableIconError)
    end
  end

  describe "with raise_on_prunable off" do
    before { Glyphs.reset_configuration! }

    it "never runs the scanner" do
      allow(Glyphs::SourceScanner).to receive(:new).and_call_original
      allow(Glyphs::PruneRunner).to receive(:new).and_call_original

      render("anchor")

      expect(Glyphs::SourceScanner).not_to have_received(:new)
      expect(Glyphs::PruneRunner).not_to have_received(:new)
    end

    it "renders an icon a prune would delete" do
      expect(render("anchor")).to include("<svg")
    end
  end

  # The agreement the issue asks for: one fixture, the guard's verdict on every
  # SVG beforehand, a real prune, and each verdict held against the disk.
  describe "agreement with the pruner" do
    let(:root) { Dir.mktmpdir("glyphs-guard") }
    let(:icons_root) { File.join(root, "app/assets/svg/icons") }

    before do
      FileUtils.mkdir_p(icons_root)
      File.write(File.join(root, "app/demo.rb"), <<~RUBY)
        LucideIcon(:house)
        PhosphorIcon(:question)
        HeroIcon(:check, variant: :solid)
        name = :circle_check
        LucideIcon(name)
      RUBY
      FileUtils.cp_r(Dir.glob(File.join(svg_root, "*")), icons_root)
      Glyphs.configure { |config| config.keep_icons = %w[triangle-*] }
    end

    after { FileUtils.remove_entry(root) }

    def runner(dry_run: true)
      Glyphs::PruneRunner.new(root:, icons_root:, dry_run:)
    end

    def reference_for(path)
      library, *variant, file = path.delete_prefix("#{icons_root}/").split("/")
      { library: library.to_sym, variant: variant.first, name: File.basename(file, ".svg") }
    end

    def guard_refuses?(guard, path)
      guard.check!(**reference_for(path))
      false
    rescue Glyphs::PrunableIconError
      true
    end

    it "refuses exactly the icons a prune deletes" do
      guard = described_class.new(runner: runner)
      svgs = Dir.glob(File.join(icons_root, "**/*.svg"))
      refused = svgs.select { |path| guard_refuses?(guard, path) }

      runner(dry_run: false).call

      expect(refused).to match_array(svgs.reject { |path| File.exist?(path) })
      expect(refused).not_to be_empty
      expect(svgs - refused).not_to be_empty
    end
  end
end
