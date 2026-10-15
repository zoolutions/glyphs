# frozen_string_literal: true

# conformance-kit's audit.require: boots glyphs the way a Rails app does, then
# finalizes it, so `conformance-audit --strict` sees every file under lib/glyphs
# in its post-boot state.
require "rails" # so lib/glyphs.rb loads the Railtie, as it does in an app
require "glyphs"
require "glyphs/rubocop" # Glyphs::RuboCop is an autoload; RuboCop loads it in a lint run
Zeitwerk::Loader.eager_load_namespace(Glyphs)
Glyphs.finalize!
