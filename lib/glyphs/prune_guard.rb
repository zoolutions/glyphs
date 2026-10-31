# frozen_string_literal: true

module Glyphs
  # Backs Configuration#raise_on_prunable: a render of an icon the prune would
  # delete fails in the test suite instead of in production, where development's
  # full SVG tree no longer hides it. Dynamic keeps are advisory, so
  # PruneRunner#verify! cannot catch this; a render names a real icon, so here
  # it is safe to fail.
  #
  # It asks the pruner, so under one configuration the two agree, and it asks
  # once: the scan runs in the constructor and #check! only reads the result. It
  # deletes nothing. Glyphs keeps one per process, replacing it when #current?
  # says the settings behind that answer changed.
  class PruneGuard
    def initialize(config: Glyphs.configuration, runner: PruneRunner.new(config:))
      @keep_settings = keep_settings(config)
      @prunable = runner.prunable
    end

    def current?(config)
      @keep_settings == keep_settings(config)
    end

    def check!(name:, library:, variant:)
      library = library.to_sym
      variant = variant.nil? ? IconReference.default_variant_for(library) : IconReference.normalize_variant(variant)
      reference = IconReference.new(library:, variant:, name: name.to_s)
      raise PrunableIconError, message(reference) if @prunable.include?(reference)
    end

    private

    # A hash of the values, so a list changed in place reads as a change.
    def keep_settings(config)
      [config.keep_icons, config.fallback_icons, config.prune_source_globs].hash
    end

    def message(reference)
      icon = [reference.library, reference.variant, reference.name].compact.join("/")
      "glyphs:prune_icons would delete #{icon}, so this render would fail in production. " \
        "Name it in an icon position (`icon: :#{reference.name.tr('-', '_')}`, an `ICON` constant) " \
        "or list it in keep_icons."
    end
  end
end
