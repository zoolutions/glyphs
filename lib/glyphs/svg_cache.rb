# frozen_string_literal: true

module Glyphs
  # A bounded LRU of SvgTemplates, one per Ractor (see Glyphs.svg_cache). The
  # threads of a Ractor share it, so every access holds the instance's Mutex;
  # the size limit is passed per write, so a reconfigured svg_cache_size
  # applies to a cache that already exists.
  class SvgCache
    def initialize
      @entries = {}
      @lock = Mutex.new
    end

    # The cached value for `key` (never nil), marked most recently used; on a
    # miss, the block's value, stored. Either way the cache is trimmed to
    # `limit` entries, so a lowered svg_cache_size applies on the next call. The
    # block runs under the lock, so a missing icon is rendered (and reported) once.
    def compute_if_absent(key, limit)
      @lock.synchronize do
        hit = @entries[key]
        insert(key, hit.nil? ? yield : hit, limit)
      end
    end

    def store(key, value, limit)
      @lock.synchronize { insert(key, value, limit) }
    end

    def size
      @lock.synchronize { @entries.size }
    end

    def clear
      @lock.synchronize { @entries.clear }
      self
    end

    private

    def insert(key, value, limit)
      @entries.delete(key)
      @entries[key] = value
      @entries.shift while @entries.size > limit
      value
    end
  end
end
