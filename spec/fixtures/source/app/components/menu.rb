# frozen_string_literal: true

# Issue #35, shape 2: renders whatever its caller passes positionally.
class Menu < Phlex::HTML
  def row(label, icon) = LucideIcon(icon)
end
