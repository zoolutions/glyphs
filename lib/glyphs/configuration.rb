# frozen_string_literal: true

module Glyphs
  class Configuration
    DEFAULT_FALLBACK_ICONS = {
      lucide: "circle-question-mark",
      phosphor: "question",
      heroicons: "question-mark-circle"
    }.freeze

    DEFAULT_SVG_CACHE_SIZE = 1024

    # raise_on_missing: boolean; when true, Icons::IconNotFound is re-raised.
    #   Defaults to true in local Rails environments (and outside Rails).
    # on_missing_icon: optional callable(error, name:, library:, variant:),
    #   invoked before the fallback renders when not raising.
    # fallback_icons: { library => icon_name } rendered instead of a missing icon.
    # cache_svgs: memoize rendered SVGs per [library, variant, name]; the
    #   caller's attributes are applied to the cached markup on every call.
    # svg_cache_size: how many icons each Ractor's LRU cache holds (1024).
    # keep_icons: icons the pruner must keep despite no static reference
    #   (dynamic / data-driven names). A flat list of names/globs, or a
    #   { library => [names/globs] } hash. fallback_icons are always kept.
    # prune_source_globs: extra locations the pruner's scanner text-scans IN
    #   ADDITION to the built-in Ruby/template defaults — e.g. a config file that
    #   names icons. Never replaces the defaults (nil = defaults only).
    attr_accessor :raise_on_missing, :on_missing_icon, :fallback_icons, :cache_svgs,
      :keep_icons, :prune_source_globs
    attr_reader :svg_cache_size

    def initialize
      @raise_on_missing = defined?(Rails) ? Rails.env.local? : true
      @on_missing_icon = nil
      @fallback_icons = DEFAULT_FALLBACK_ICONS.dup
      @cache_svgs = true
      @svg_cache_size = DEFAULT_SVG_CACHE_SIZE
      @keep_icons = []
      @prune_source_globs = nil
    end

    def svg_cache_size=(size)
      unless size.is_a?(Integer) && size.positive?
        raise ArgumentError, "svg_cache_size must be a positive Integer, got #{size.inspect}"
      end

      @svg_cache_size = size
    end

    # Deep-freezes the configuration so it is Ractor-shareable (see
    # Glyphs.finalize!). Raises ArgumentError naming the setting whose value
    # cannot be shared, e.g. an on_missing_icon lambda that closes over self.
    def finalize!
      return freeze unless defined?(::Ractor)

      instance_variables.each { |ivar| make_shareable(ivar) }
      ::Ractor.make_shareable(self)
    end

    private

    def make_shareable(ivar)
      ::Ractor.make_shareable(instance_variable_get(ivar))
    rescue ::Ractor::Error => e # IsolationError included
      raise ArgumentError, "Glyphs.finalize!: #{ivar.to_s.delete_prefix('@')} is not Ractor-shareable " \
                           "(#{e.message}). Give it a shareable value, e.g. a frozen object that responds " \
                           "to #call, or Ractor.shareable_proc on Ruby 4.0+."
    end
  end
end
