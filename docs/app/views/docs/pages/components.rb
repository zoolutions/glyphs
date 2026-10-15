# frozen_string_literal: true

class Views::Docs::Pages::Components < DocsUI::Page
  title "Components"
  eyebrow "Guide"

  def lead = "One component per rails_icons library, all subclasses of Glyphs::Icon."

  def content
    the_table
    kit_mechanics
  end

  private

  def the_table
    DocsUI::Section("Library components") do
      md <<~'MD'
        | Component | rails_icons library |
        |---|---|
        | `LucideIcon` | lucide |
        | `PhosphorIcon` | phosphor |
        | `HeroIcon` | heroicons |
        | `TablerIcon` | tabler |
        | `FeatherIcon` | feather |
        | `BoxIcon` | boxicons |
        | `FlagIcon` | flags |
        | `HugeIcon` | hugeicons |
        | `LinearIcon` | linear |
        | `RadixIcon` | radix |
        | `SidekickIcon` | sidekickicons |
        | `WeatherIcon` | weather |
        | `AnimatedIcon` | animated |

        `AnimatedIcon` renders the spinners bundled inside the `icons` gem
        itself (`faded-spinner`, `trailing-spinner`, `fading-dots`,
        `bouncing-dots`) — nothing to sync.
      MD
    end
  end

  def kit_mechanics
    DocsUI::Section("Kit mechanics") do
      md <<~'MD'
        Each component is a tiny `Glyphs::Icon` subclass that pins its library.
        Because `Glyphs` extends `Phlex::Kit`, including it gives you the
        capitalized call form; outside a kit context, instantiate directly:
      MD
      DocsUI::Code(<<~RUBY)
        # Inside a component that includes Glyphs:
        LucideIcon(:house, class: "size-4")

        # Anywhere else:
        render Glyphs::LucideIcon.new(:house, class: "size-4")
        Glyphs::LucideIcon.new(:house).call # => "<svg ...>" (standalone string)
      RUBY
      md <<~'MD'
        Rendered SVGs are memoized per `[library, variant, name]` in a bounded
        LRU cache (`config.svg_cache_size`, 1024 by default, one per Ractor);
        each call's attributes are applied to the cached markup, so repeated
        renders of an icon skip the file read and Nokogiri parse whatever their
        `class:` or `id:`. Disable with `config.cache_svgs = false`.
      MD
    end
  end
end
