# frozen_string_literal: true

module Glyphs
  # A single (library, variant, name) icon reference discovered in source, with
  # the shared library/variant resolution tables the scanner and the RuboCop
  # cops both rely on.
  #
  # `library` is an icons-gem library symbol (`:lucide`), `variant` is a string
  # or nil (variant-less libraries), and `name` is dasherized (`"circle-check"`).
  #
  # The library/variant tables are sourced from the `icons` gem wherever
  # possible (`default_variant_for`) so they never drift from what actually
  # resolves at render time.
  class IconReference < Data.define(:library, :variant, :name)
    # Subclassed (not the block form) so the constants below are namespaced under
    # IconReference — constants defined inside a `Data.define do…end` block leak
    # to the enclosing scope instead of nesting under the class.
    #
    # Maps every Glyphs library component to its icons-gem library symbol. This
    # is the canonical map; `RuboCop::Cop::Glyphs::LibraryCallHelpers` reads it
    # so the cops and the pruner agree on the full set of libraries.
    LIBRARY_TO_COMPONENT = {
      lucide: "LucideIcon",
      phosphor: "PhosphorIcon",
      heroicons: "HeroIcon",
      tabler: "TablerIcon",
      feather: "FeatherIcon",
      boxicons: "BoxIcon",
      flags: "FlagIcon",
      hugeicons: "HugeIcon",
      linear: "LinearIcon",
      radix: "RadixIcon",
      sidekickicons: "SidekickIcon",
      weather: "WeatherIcon",
      animated: "AnimatedIcon"
    }.freeze

    # Legacy icon helpers (`_lucide(:house)`) the scanner also recognizes.
    LEGACY_HELPERS = {
      "_lucide" => :lucide,
      "_phosphor" => :phosphor,
      "_hero" => :heroicons,
      "_heroicon" => :heroicons,
      "_tabler" => :tabler
    }.freeze

    # Component name (`"LucideIcon"`) => library symbol (`:lucide`). Built at
    # load, frozen, so it is shareable and never lazily (re)computed.
    COMPONENT_TO_LIBRARY = LIBRARY_TO_COMPONENT.to_h { |library, component| [component, library] }.freeze

    # Raw `iconify lucide--house` class strings.
    ICONIFY_PATTERN = /\biconify\s+(lucide|phosphor|heroicons)--([a-z0-9-]+)/

    class << self
      def component_to_library
        COMPONENT_TO_LIBRARY
      end

      def legacy_helpers
        LEGACY_HELPERS
      end

      # Resolves a called method name (component or legacy helper) to a library
      # symbol, or nil when the method isn't an icon call.
      def library_for(method_name)
        name = method_name.to_s
        COMPONENT_TO_LIBRARY[name] || LEGACY_HELPERS[name]
      end

      # The library's default variant, as configured in the icons gem. Returns a
      # string (`"outline"`), or nil for variant-less libraries.
      def default_variant_for(library)
        options = Icons.config.libraries[library.to_sym]
        normalize_variant(options&.default_variant)
      rescue StandardError
        nil
      end

      # Mirrors the icons gem's variant→path handling so a scanned reference
      # points at the same file that renders: an empty string (a documented
      # rails_icons override) and `"."` (the variant-less convention) both mean
      # "no variant subdirectory" and normalize to nil. See the icons gem's
      # Icons::Icon::Configurable#set_variant and Icons::Icon::FilePath#parts.
      def normalize_variant(variant)
        return if variant.nil?

        string = variant.to_s
        return if string.empty? || string == "."

        string
      end
    end
  end
end
