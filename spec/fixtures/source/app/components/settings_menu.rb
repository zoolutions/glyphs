# frozen_string_literal: true

# Issue #35, shape 2: a literal passed positionally, invisible to a static scan.
class SettingsMenu < Phlex::HTML
  def view_template = Menu { |m| m.row("Alerts", :anchor) }
end
