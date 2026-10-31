# frozen_string_literal: true

module Glyphs
  # Raised on render, with Configuration#raise_on_prunable on, for an icon that
  # exists now and that glyphs:prune_icons would delete from the image. Not an
  # Icons::IconNotFound: the missing-icon policy must not turn it into a fallback.
  class PrunableIconError < StandardError; end
end
