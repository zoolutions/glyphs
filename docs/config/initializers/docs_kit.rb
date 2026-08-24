# frozen_string_literal: true

# docs-kit synced: v1.0.8

# docs-kit configuration — everything that makes this site look like "glyphs"
# rather than any other docs site. The shared chrome (Shell/Sidebar/ThemeSwitcher/
# Code/Page) comes from the gem; only this config differs per site. The `themes`
# MUST match the @plugin "daisyui" { themes: ... } block in
# app/assets/stylesheets/application.tailwind.css, or the switcher offers a theme
# the compiled CSS never generated.
Rails.application.config.to_prepare do
  DocsKit.configure do |c|
    c.brand        = "glyphs"
    c.title_suffix = "glyphs"

    # The one-line summary agents read first in /llms.txt (the llmstxt.org
    # blockquote under the H1).
    c.tagline = "Phlex icon components for every rails_icons library — " \
                "LucideIcon, HeroIcon, PhosphorIcon and friends as a Phlex::Kit, " \
                "with a configurable missing-icon policy and bundled RuboCop cops " \
                "that validate icon names and autocorrect legacy helpers."

    c.themes = %w[dark light synthwave retro cyberpunk dracula night nord sunset]

    # The version badge in the sidebar header tracks the documented gem. A lambda
    # (not a String) so it re-reads Glyphs::VERSION on every reload — the glyphs
    # path-gem is required as "glyphs/version" (Gemfile), so only the constant is
    # loaded.
    c.version_badge = -> { "v#{Glyphs::VERSION}" }

    # Code blocks: a light base with a dark override, so the highlight stays
    # readable when the switcher lands on a dark daisyUI theme. CSS-only scoping
    # ([data-theme=X]) — no JS, no flash.
    c.code_theme      = "Rouge::Themes::Github"  # light themes
    c.code_theme_dark = "Rouge::Themes::Monokai" # dark themes

    # Repo + rubygems links in the topbar, rendered with the shipped brand marks.
    c.topbar_links = [
      { href: "https://github.com/zoolutions/glyphs", label: "GitHub", icon: :github },
      { href: "https://rubygems.org/gems/glyphs", label: "RubyGems", icon: :rubygems }
    ]

    # SEO + social sharing. docs-kit emits the full <head> (description, Open
    # Graph, Twitter Card, canonical, favicon, theme-color) from these knobs.
    # og_image resolves through THIS site's asset pipeline (app/assets/images/) to
    # the digested /assets URL — regenerate the card with `bin/rails docs_kit:og`.
    c.seo.description  = "Phlex icon components for every rails_icons library — " \
                         "Lucide, Heroicons, Phosphor, Tabler and more as Phlex::Kit " \
                         "components, with icon-name validation and legacy-helper " \
                         "autocorrection via bundled RuboCop cops."
    c.seo.site_url     = "https://glyphs.zoolutions.llc"
    c.seo.og_image     = "og/og.png"
    c.seo.og_type      = "website"
    c.seo.twitter_card = "summary_large_image"
    c.seo.twitter_site = "@mhenrixon"
    c.seo.locale       = "en_US"
    c.seo.theme_color  = "#1d232a" # daisyUI dark base-100 (themes.first)
    # favicon href is used verbatim (not through the asset pipeline), so it's a
    # public/ path served at a stable root URL.
    c.seo.favicon      = "/icon.svg"

    # The sidebar nav derives from the registry — one heading → one registry.
    # Each registry's authored pages become NavItems automatically (an unwritten
    # page is skipped, so no dead links); the page `group:` values render as the
    # collapsible sub-groups. This also feeds the AI surfaces (/llms.txt,
    # /llms-full.txt, search, MCP) with zero extra code.
    c.nav_registries = { "Docs" => Doc }
  end
end
