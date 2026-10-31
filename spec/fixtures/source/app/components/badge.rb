# frozen_string_literal: true

# Issue #35: the only dynamic render of the wrapper shapes below.
class Badge < Phlex::HTML
  def initialize(icon:) = @icon = icon
  def view_template = LucideIcon(@icon)
end
