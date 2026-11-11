# frozen_string_literal: true

module Glyphs
  # config.merge_default_data: merges a library's configured default data under
  # a caller's data: hash, which the icons gem would otherwise replace it with.
  # Reads the icons gem's configuration, so it runs on the main Ractor only
  # (Glyphs.build_svg, which a non-main Ractor reaches through MainRactor).
  module DefaultData
    class << self
      # The attributes with the default data merged under a data: hash (a new
      # Hash; the caller's is never mutated), or the attributes as given.
      def merge(attributes, library:, variant:)
        data = attributes[:data]
        return attributes unless data.is_a?(Hash)

        defaults = lookup(library:, variant:)
        return attributes unless defaults.is_a?(Hash) && !defaults.empty?

        attributes.merge(data: defaults.merge(data))
      end

      private

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
