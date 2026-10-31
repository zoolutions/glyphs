# frozen_string_literal: true

# Issue #35, shape 1: names in a plain array, forwarded with the `icon:` shorthand.
class StepsList < Phlex::HTML
  ROWS = [[:bell, 1], [:star, 2]].freeze
  def view_template = ROWS.each { |icon, number| Badge(icon:) }
end
