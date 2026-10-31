# frozen_string_literal: true

require "fileutils"

module Glyphs
  # Deletes synced SVG icons that no source references, keeping the union of:
  # scanned references, the configured keep_icons allowlist (names or globs,
  # flat or per-library), and the configured fallback_icons (always — a pruned
  # fallback would make every future missing-icon 500).
  #
  # Operates only on `icons_root` (`app/assets/svg/icons`), skips the bundled
  # `animated` library, never deletes non-.svg files, and refuses to empty a
  # library whose computed keep-set is empty (guards against a mis-scan wiping a
  # whole library). Returns a PruneReport.
  class IconPruner
    ANIMATED = :animated

    def initialize(icons_root:, references:, keep_icons: [], fallback_icons: {}, dry_run: false)
      @icons_root = icons_root
      @references = references
      @keep_icons = keep_icons
      @fallback_icons = fallback_icons
      @dry_run = dry_run
    end

    def call
      stats = []
      deleted_names = []

      grouped_files.each do |(library, variant), files|
        # Guard on library-specific evidence of use, NOT on the merged keep-set:
        # a flat keep_icons list is non-empty for every library, so keying the
        # guard off keep.empty? would let it wipe an entirely-unreferenced
        # library down to whatever the flat list happens to match.
        unless library_used?(library)
          warn "[Glyphs::IconPruner] refusing to prune #{library}/#{variant || '.'} — " \
               "no references, fallback, or per-library keep_icons for #{library}"
          next
        end

        stats << prune_group(library, variant, files, unkept_files(library, variant, files), deleted_names)
      end

      PruneReport.new(stats:, deleted_names:, dry_run: @dry_run)
    end

    # The Set of IconReferences #call would delete: same files, same keep-sets.
    # Deletes nothing and warns about nothing.
    def prunable
      groups = grouped_files.select { |(library, _), _| library_used?(library) }
      groups.each_with_object(Set.new) do |((library, variant), files), references|
        unkept_files(library, variant, files).each do |path|
          references << IconReference.new(library:, variant:, name: File.basename(path, ".svg"))
        end
      end
    end

    private

    # { [library, variant] => [absolute svg paths] }, excluding the animated lib.
    def grouped_files
      svg_files.group_by { |path| library_and_variant(path) }.reject { |(library, _), _| library == ANIMATED }
    end

    def svg_files
      Dir.glob([File.join(@icons_root, "*", "*", "*.svg"), File.join(@icons_root, "*", "*.svg")]).uniq
    end

    # Derives [library_sym, variant_or_nil] from an svg path under icons_root.
    # Two dirs deep => library/variant/name.svg; one dir deep => library/name.svg.
    def library_and_variant(path)
      relative = path.delete_prefix("#{@icons_root}/")
      parts = relative.split("/")
      if parts.size >= 3
        [parts[0].to_sym, parts[1]]
      else
        [parts[0].to_sym, nil]
      end
    end

    # The one decision of what goes, shared by #call and #prunable.
    def unkept_files(library, variant, files)
      keep = keep_names_for(library, variant)
      files.reject { |path| keep_file?(File.basename(path, ".svg"), keep) }
    end

    def prune_group(library, variant, files, unkept, deleted_names)
      bytes_freed = unkept.sum { |path| File.size(path) }
      deleted_names.concat(unkept.map { |path| File.basename(path, ".svg") })
      unkept.each { |path| File.delete(path) } unless @dry_run

      PruneReport::LibraryStat.new(library:, variant:, kept: files.size - unkept.size, deleted: unkept.size,
        bytes_freed:)
    end

    def keep_file?(name, keep)
      keep.any? { |pattern| pattern == name || File.fnmatch?(pattern, name) }
    end

    # The set of names/globs to keep for a (library, variant): references for
    # this exact library+variant, the library's keep_icons entries, and the
    # library's fallback icon.
    def keep_names_for(library, variant)
      names = Set.new
      @references.each do |reference|
        names << reference.name if reference.library == library && reference.variant == variant
      end
      names.merge(keep_icons_for(library))
      fallback = @fallback_icons[library]
      names << fallback if fallback
      names
    end

    def keep_icons_for(library)
      case @keep_icons
      when Hash then Array(@keep_icons[library] || @keep_icons[library.to_s])
      else Array(@keep_icons)
      end
    end

    # Whether a library has library-specific evidence it's in use: any scanned
    # reference, a configured fallback, or a per-library keep_icons entry. A flat
    # keep_icons list is deliberately NOT evidence — it applies to every library,
    # so counting it would defeat the wipe guard for unreferenced libraries.
    def library_used?(library)
      return true if @references.any? { |reference| reference.library == library }
      return true if @fallback_icons[library]

      # A per-library keep_icons entry counts only if it actually lists icons —
      # an empty array (`{ tabler: [] }`) is not evidence of use.
      @keep_icons.is_a?(Hash) && keep_icons_for(library).any?
    end
  end
end
