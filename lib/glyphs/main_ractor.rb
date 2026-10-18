# frozen_string_literal: true

module Glyphs
  # Renders an icon on the main Ractor for a non-main one. The icons gem reads
  # Icons.configuration (an unshareable module ivar) and parses with Nokogiri
  # (a C extension not marked Ractor-safe), so only the main Ractor can run it.
  # ractor-dispatch (Ruby 4.0+, a dependency of Rails 8.2's Active Support)
  # runs the render there and sends the markup back, where the calling Ractor's
  # own cache keeps it: each icon crosses once per Ractor, not once per render.
  module MainRactor
    # Raised in a non-main Ractor that cannot reach the main one.
    class Unavailable < StandardError; end

    class << self
      # Whether this Ractor runs the icons gem itself: the main Ractor, or any
      # code on an engine without Ractors.
      def current?
        defined?(::Ractor) ? ::Ractor.main? : true
      end

      # Glyphs' render (missing-icon policy included) of these arguments, run
      # on the main Ractor; an Icons::IconNotFound it raises is raised here.
      def render(**arguments)
        dispatcher = main_dispatcher(arguments)
        shared = ::Ractor.make_shareable(arguments, copy: true) # a shareable block captures only shareable values
        dispatcher.run { Glyphs.__send__(:render_svg, **shared) }
      end

      private

      def main_dispatcher(arguments)
        icon = "#{arguments[:library]}/#{arguments[:name]}"
        unless defined?(::Ractor::Port)
          raise Unavailable, "#{icon} isn't cached in this Ractor, and rendering it on the main Ractor " \
                             "needs ractor-dispatch, which needs Ruby 4.0+. Seed the cache with Glyphs.preload_svg."
        end

        require "ractor/dispatch"
        ::Ractor::Dispatch.main
      rescue LoadError
        raise Unavailable, "#{icon} isn't cached in this Ractor, and rendering it on the main Ractor " \
                           "needs the ractor-dispatch gem (Rails 8.2 apps have it): add gem \"ractor-dispatch\"."
      end
    end
  end
end
