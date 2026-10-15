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

    # Freezes the configuration and makes every setting Ractor-shareable that
    # can be, so svg_for can read it from a non-main Ractor. Glyphs.finalize!
    # calls it (in a Rails app, Glyphs::Railtie does after boot). Never raises
    # and never freezes an object the app still holds: a collection becomes a
    # frozen copy, and a value that cannot be shared (an on_missing_icon lambda
    # closing over self, a callable holding a logger) is kept as is, which
    # leaves the configuration readable on the main Ractor only.
    def finalize!
      return self if frozen?

      if defined?(::Ractor)
        instance_variables.each { |ivar| instance_variable_set(ivar, shareable(instance_variable_get(ivar))) }
      end
      freeze
    end

    private

    def shareable(value)
      return value if ::Ractor.shareable?(value)

      case value
      when ::Proc then ::Ractor.make_shareable(value) # a Proc cannot be copied; a failed attempt freezes nothing
      when ::Hash, ::Array, ::String then ::Ractor.make_shareable(value, copy: true)
      else value # an app's object: freezing it in place would freeze what it refers to (its logger) too
      end
    rescue StandardError # Ractor::Error, or TypeError/ArgumentError for what cannot be copied or shared
      value
    end
  end
end
