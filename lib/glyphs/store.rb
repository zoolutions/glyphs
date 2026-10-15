# frozen_string_literal: true

module Glyphs
  # Per-Ractor lazy storage: `Store.fetch(:glyphs_svg_cache) { SvgCache.new }`.
  #
  # Adapted from conformance-kit's ConformanceKit::Store (MIT, same author),
  # which glyphs cannot depend on at runtime. On CRuby (3.4+, the gem's floor)
  # this is `Ractor.store_if_absent`: atomic, one value per Ractor. Engines
  # without it (TruffleRuby, JRuby) get one Mutex-guarded Hash, created at load
  # and only there, so on CRuby no unshareable module state exists at all.
  module Store
    class << self
      def fetch(key, &)
        return ::Ractor.store_if_absent(key, &) if native?

        @fallback_lock.synchronize do
          @fallback_values.fetch(key) { @fallback_values[key] = yield }
        end
      end

      def native?
        defined?(::Ractor) ? ::Ractor.respond_to?(:store_if_absent) : false
      end
    end

    unless native?
      @fallback_lock = Mutex.new
      # Only on engines without Ractor: guarded by @fallback_lock, never read unlocked.
      @fallback_values = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    end
  end
end
