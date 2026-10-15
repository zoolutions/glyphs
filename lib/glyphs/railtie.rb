# frozen_string_literal: true

module Glyphs
  # Loaded only when Rails is present (see the guard in lib/glyphs.rb). It
  # exposes the icon-pruning rake task to consuming apps and finalizes the
  # configuration after boot. Kept a Railtie, not an Engine: glyphs contributes
  # no routes, views, or migrations.
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/glyphs.rake", __dir__)
    end

    # Once every initializer has run (and so every Glyphs.configure), freeze the
    # configuration for Ractors, with no code of the app's. This is the hook
    # config.after_initialize registers (Rails::Railtie::Configuration#after_initialize);
    # calling it directly keeps the Railtie from being instantiated at require
    # (Glyphs::Railtie.@instance), which Rails otherwise does only at boot.
    ActiveSupport.on_load(:after_initialize, yield: true) { Glyphs.finalize! }
  end
end
