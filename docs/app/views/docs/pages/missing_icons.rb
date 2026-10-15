# frozen_string_literal: true

class Views::Docs::Pages::MissingIcons < DocsUI::Page
  title "Missing icons"
  eyebrow "Guide"

  def lead = "Raise loudly in development, degrade gracefully in production."

  def content
    the_policy
    the_hook
    caching_note
  end

  private

  def the_policy
    DocsUI::Section("The policy", description: "Configured once, in an initializer.") do
      DocsUI::Code(<<~RUBY, filename: "config/initializers/glyphs.rb")
        Glyphs.configure do |config|
          # Re-raise Icons::IconNotFound? Defaults to true in local Rails
          # environments (and outside Rails), false otherwise.
          config.raise_on_missing = Rails.env.local?

          # Rendered instead of the missing icon (per library).
          # A library without an entry re-raises.
          config.fallback_icons = {
            lucide: "circle-question-mark",
            phosphor: "question",
            heroicons: "question-mark-circle"
          }
        end
      RUBY
      md <<~'MD'
        With `raise_on_missing` true a typo fails fast in development and test.
        With it false (production), the library's fallback icon renders instead
        so the page never 500s over a missing glyph. If the fallback itself is
        missing, the original error re-raises — no silent loops.
      MD
    end
  end

  def the_hook
    DocsUI::Section("The instrumentation hook") do
      md <<~'MD'
        `on_missing_icon` is an optional handler, called before the fallback
        renders (never when raising). Wire it to your logger or error tracker:
      MD
      DocsUI::Code(<<~'RUBY', filename: "config/initializers/glyphs.rb")
        Glyphs.configure do |config|
          config.on_missing_icon = lambda do |error, name:, library:, variant:|
            Rails.logger.error(
              "Icon missing: #{library}/#{variant}/#{name} (#{error.message})"
            )
          end
        end
      RUBY
    end
  end

  def caching_note
    DocsUI::Section("Interaction with the SVG cache") do
      md <<~'MD'
        Fallback renders are cached under the *original* icon name, so
        `on_missing_icon` fires **once per missing icon while it is cached**, not on
        every render — your logs stay readable while the fallback keeps
        rendering. Set `config.cache_svgs = false` to trade that for a
        notification per render.
      MD
    end
  end
end
