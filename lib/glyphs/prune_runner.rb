# frozen_string_literal: true

module Glyphs
  # Wires configuration → SourceScanner → IconPruner and (when deleting) verifies
  # every kept icon still resolves on disk. Thin orchestrator so the rake task is
  # a one-liner and the whole flow is unit-testable.
  #
  #   Glyphs::PruneRunner.call(dry_run: false)   # scans Rails.root, prunes, verifies
  class PruneRunner
    # Raised when a kept icon (static ref, keep_icons, or fallback) is missing
    # after a prune — turns a bad prune into a failed build, never a 500.
    class VerificationError < StandardError; end

    def self.call(**)
      new(**).call
    end

    def initialize(root: default_root, icons_root: default_icons_root, dry_run: true, config: Glyphs.configuration)
      @root = root
      @icons_root = icons_root
      @dry_run = dry_run
      @config = config
    end

    def call
      report = pruner.call
      verify! unless @dry_run
      report
    end

    # The IconReferences a prune would delete, deleting nothing: the pruner's own
    # answer over the same scan and keep-sets #call uses.
    def prunable
      pruner.prunable
    end

    # Asserts every kept icon resolves to a file on disk. Raises
    # VerificationError listing the first few misses.
    def verify!
      missing = expected_files.reject { |path| File.exist?(path) }
      return if missing.empty?

      names = missing.first(10).map { |path| relative(path) }
      raise VerificationError,
        "#{missing.size} kept icon(s) missing after prune: #{names.join(', ')}"
    end

    private

    attr_reader :config

    def pruner
      @pruner ||= IconPruner.new(
        icons_root: @icons_root,
        references:,
        keep_icons: keep_icons,
        fallback_icons: config.fallback_icons,
        dry_run: @dry_run
      )
    end

    def scanner
      @scanner ||= SourceScanner.new(root: @root, **scanner_options)
    end

    def references
      @references ||= scanner.call
    end

    # The pruner's keep-set: the configured keep_icons MERGED with the scanner's
    # advisory per-library dynamic keeps (names harvested from dynamic call
    # sites). Both are advisory — kept if present, never asserted by verify!.
    #
    # With no dynamic keeps, the configured value passes straight through (flat
    # list or hash — the pruner accepts both). Otherwise everything folds into a
    # per-library hash; a flat configured list applies to every kept library.
    def keep_icons
      dynamic = scanner.dynamic_keeps
      return config.keep_icons if dynamic.empty?

      merged = Hash.new { |hash, key| hash[key] = [] }
      dynamic.each { |library, names| merged[library].concat(names.to_a) }
      merge_configured_keeps(merged)
      merged.transform_values(&:uniq)
    end

    # Folds the configured keep_icons into the per-library `merged` hash: a hash
    # merges per library; a flat list applies to every library already present.
    def merge_configured_keeps(merged)
      case config.keep_icons
      when Hash
        config.keep_icons.each { |library, names| merged[library.to_sym].concat(Array(names)) }
      else
        flat = Array(config.keep_icons)
        merged.each_key { |library| merged[library].concat(flat) }
      end
    end

    def scanner_options
      globs = config.prune_source_globs
      globs ? { extra_globs: Array(globs) } : {}
    end

    # Files that MUST exist after a prune: every scanned reference and every
    # configured fallback icon, restricted to libraries actually synced under
    # icons_root (the pruner only touches those — a fallback for an un-synced
    # library is irrelevant and must not fail the build). keep_icons globs are
    # advisory (they may match nothing), so they're not asserted here.
    def expected_files
      fallback_refs = config.fallback_icons.map do |library, name|
        IconReference.new(library:, variant: IconReference.default_variant_for(library), name:)
      end

      (references.to_a + fallback_refs)
        .select { |reference| library_present?(reference.library) }
        .map { |reference| file_for(reference) }
        .uniq
    end

    def library_present?(library)
      Dir.exist?(File.join(@icons_root, library.to_s))
    end

    def file_for(reference)
      parts = [reference.library.to_s, reference.variant, "#{reference.name}.svg"].compact
      File.join(@icons_root, *parts)
    end

    def relative(path)
      path.delete_prefix("#{@icons_root}/")
    end

    def default_root
      defined?(Rails) ? Rails.root.to_s : Dir.pwd
    end

    def default_icons_root
      base = Icons.config.base_path
      File.join(base.to_s, Icons.config.icons_path.to_s)
    end
  end
end
