# frozen_string_literal: true

require "rubocop"
require "lint_roller"
require "pathname"
require "yaml"

require_relative "version"
require_relative "../rubocop/cop/glyphs/library_call_helpers"
require_relative "../rubocop/cop/glyphs/legacy_icon_helper"
require_relative "../rubocop/cop/glyphs/icon_resolution"
require_relative "../rubocop/cop/glyphs/prefer_library_component"

module Glyphs
  module RuboCop
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: "glyphs",
          version: Glyphs::VERSION,
          homepage: "https://github.com/zoolutions/glyphs",
          description: "Icon-name validation and legacy icon-helper autocorrection for Glyphs components."
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../config/default.yml")
        )
      end
    end
  end
end
