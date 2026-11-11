# frozen_string_literal: true

module Glyphs
  # config.merge_default_data: merges a library's configured default data under
  # a caller's data: hash, which the icons gem would otherwise replace it with.
  # Reads the icons gem's configuration, so it runs on the main Ractor only
  # (Glyphs.build_svg, which a non-main Ractor reaches through MainRactor).
  # A default data key named like SvgTemplate's slot marker (glyphs-data-slot)
  # is reserved: the cached data: template would drop it.
  module DefaultData
    class << self
      # The attributes with the default data merged under a data: hash, or
      # without a data: nil (the defaults alone, as with no data:), when the
      # library has default data; else the attributes as given. A new Hash: the
      # caller's is never mutated.
      def merge(attributes, library:, variant:)
        return attributes unless attributes.key?(:data)

        data = attributes[:data]
        return attributes unless data.nil? || data.is_a?(Hash)

        defaults = lookup(library:, variant:)
        return attributes unless defaults.is_a?(Hash) && !defaults.empty?

        data.nil? ? attributes.except(:data) : attributes.merge(data: by_name(defaults, data))
      end

      private

      # One entry per attribute name, however its key is spelled (:toggle_target,
      # "toggle-target"): at the position its name first appears, with the value
      # it was given last, the caller's after the defaults. That is how a cache
      # hit splices the caller's data over the template's defaults.
      def by_name(defaults, data)
        merged = {}
        defaults.each { |key, value| merged[key.to_s.tr("_", "-")] = value }
        data.each { |key, value| merged[key.to_s.tr("_", "-")] = value }
        merged
      end

      # The icons gem's own lookup (Icons::Icon::Configurable): the variant, else
      # the library's default_variant, else the global default_variant.
      def lookup(library:, variant:)
        icons = Icons.configuration
        library = library.to_sym
        variant ||= icons.libraries.dig(library, :default_variant) || icons.default_variant
        variant = variant.to_s.empty? ? nil : variant.to_sym
        (icons.libraries.dig(*[library, variant].compact) || {}).dig(:default, :data)
      end
    end
  end
end
