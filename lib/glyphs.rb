# frozen_string_literal: true

require "monitor"
require "phlex"
require "icons"
require "zeitwerk"
require_relative "glyphs/version"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/glyphs/version.rb")
# The RuboCop plugin lives in a foreign namespace and is only loaded inside a
# RuboCop process (see the bottom of this file).
loader.ignore("#{__dir__}/glyphs/rubocop.rb")
loader.ignore("#{__dir__}/rubocop")
# The Railtie is required conditionally below (only under Rails), and the rake
# tasks aren't Ruby constants — keep both out of Zeitwerk's managed set.
loader.ignore("#{__dir__}/glyphs/railtie.rb")
loader.ignore("#{__dir__}/tasks")
loader.setup

# Expose the icon-pruning rake task to consuming Rails apps.
require_relative "glyphs/railtie" if defined?(Rails::Railtie)

# Ensure the icons gem is configured even outside Rails. Inside Rails the
# rails_icons engine calls `Icons.configure` with the app's settings; the
# configuration is memoized, so this never clobbers app configuration.
Icons.config

# Phlex icon components for every rails_icons library, exposed as a Phlex::Kit:
#
#   include Glyphs
#   LucideIcon(:house, class: "size-4")
module Glyphs
  extend Phlex::Kit

  # Guards the boot-time writers (configure, register_library, finalize!). A
  # Monitor, so a configure block may call register_library. Main Ractor only:
  # readers never take it, so svg_for runs in any Ractor once finalized.
  @lock = Monitor.new
  @configuration = Configuration.new

  class << self
    # The current configuration: a plain read, shareable after finalize!.
    attr_reader :configuration

    def configure
      @lock.synchronize { yield(@configuration) if block_given? }
      configuration
    end

    def reset_configuration!
      @lock.synchronize { @configuration = Configuration.new }
    end

    # Freezes the configuration so svg_for can run inside a non-main Ractor
    # (see Configuration#finalize!; never raises). Glyphs::Railtie calls it once
    # a Rails app has booted; outside Rails, call it at the end of boot, after
    # every configure. reset_configuration! (tests) starts over with a fresh one.
    def finalize!
      @lock.synchronize { @configuration.finalize! }
      self
    end

    # Defines a `Glyphs::Icon` subclass for a custom icon library and exposes it
    # as a kit method. The library's SVG location itself is configured through
    # the icons/rails_icons custom-library configuration.
    #
    #   Glyphs.register_library(:brand, component: :BrandIcon)
    #   # => BrandIcon(:logo, class: "size-4")
    def register_library(library, component:)
      library = library.to_sym
      name = component.to_sym

      @lock.synchronize do
        if const_defined?(name, false)
          existing = const_get(name, false)
          return existing if existing < Icon && library == existing::LIBRARY

          raise ArgumentError, "Glyphs::#{name} is already defined and does not render the #{library} library"
        end

        klass = Class.new(Icon)
        klass.const_set(:LIBRARY, library)
        const_set(name, klass)
      end
    end

    # Returns the SVG markup for an icon, applying the configured missing-icon
    # policy (raise / instrument / fallback) and the per-Ractor cache: one
    # entry per [library, variant, name], the caller's attributes applied to
    # the cached markup on every call.
    def svg_for(name:, library:, variant:, attributes:)
      return render_svg(name:, library:, variant:, attributes:) unless configuration.cache_svgs

      data = attributes.key?(:data)
      template = svg_cache.compute_if_absent([library, variant, name, data], configuration.svg_cache_size) do
        markup = render_svg(name:, library:, variant:, attributes: data ? SvgTemplate::DATA_SLOT : {})
        SvgTemplate.new(markup, data_slot: data)
      end
      template.render(attributes) || render_svg(name:, library:, variant:, attributes:)
    end

    # Seeds this Ractor's cache with markup rendered elsewhere, e.g. on the
    # main Ractor (which can run the icons gem and Nokogiri) for a Ractor that
    # cannot. Calls with a data: attribute still render through the icons gem.
    def preload_svg(name:, library:, svg:, variant: nil)
      key = [library.to_sym, variant&.to_sym, name.to_s.tr("_", "-"), false]
      svg_cache.store(key, SvgTemplate.new(svg), configuration.svg_cache_size)
    end

    # The current Ractor's SvgCache.
    def svg_cache
      Store.fetch(:glyphs_svg_cache) { SvgCache.new }
    end

    # Empties the current Ractor's cache (other Ractors keep theirs).
    def reset_cache!
      svg_cache.clear
    end

    private

    def render_svg(name:, library:, variant:, attributes:)
      build_svg(name:, library:, variant:, attributes:)
    rescue Icons::IconNotFound => e
      handle_missing_icon(e, name:, library:, variant:, attributes:)
    end

    def build_svg(name:, library:, variant:, attributes:)
      Icons::Icon.new(name:, library:, variant:, arguments: attributes).svg
    end

    def handle_missing_icon(error, name:, library:, variant:, attributes:)
      raise error if configuration.raise_on_missing

      configuration.on_missing_icon&.call(error, name:, library:, variant:)

      fallback = configuration.fallback_icons[library.to_sym]
      raise error if fallback.nil?

      begin
        build_svg(name: fallback, library:, variant:, attributes:)
      rescue Icons::IconNotFound
        raise error
      end
    end
  end
end

# Make the RuboCop plugin resolvable lazily: RuboCop constantizes
# Glyphs::RuboCop::Plugin (from the gemspec's default_lint_roller_plugin
# metadata) when it loads plugins, which can happen long after this gem was
# required — e.g. app boots first, cop specs load RuboCop later.
Glyphs.autoload :RuboCop, File.expand_path("glyphs/rubocop", __dir__)
