# frozen_string_literal: true

require_relative "lib/glyphs/version"

Gem::Specification.new do |s|
  s.name = "glyphs"
  s.version = Glyphs::VERSION
  s.licenses = ["MIT"]
  s.summary = "Phlex icon components for every rails_icons library"
  s.description = "Glyphs renders SVG icons as Phlex components (LucideIcon, PhosphorIcon, HeroIcon, ...) " \
                  "from rails_icons-synced icon sets, with configurable missing-icon handling and bundled " \
                  "RuboCop cops that validate icon names and autocorrect legacy icon helpers."
  s.authors = ["Mikael Henriksson"]
  s.email = "mikael@zoolutions.llc"
  s.files = begin
    files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
      ls.readlines("\x0", chomp: true).select do |f|
        f.start_with?("lib/", "config/") ||
          f == "CHANGELOG.md" || f == "LICENSE.txt" || f == "README.md"
      end
    end
    files.empty? ? raise(Errno::ENOENT) : files
  rescue Errno::ENOENT
    Dir[
      "lib/**/*.rb", "config/**/*",
      "CHANGELOG.md", "LICENSE.txt", "README.md"
    ].select { |f| File.file?(f) }
  end
  s.homepage = "https://github.com/zoolutions/glyphs"
  s.metadata = {
    "source_code_uri" => "https://github.com/zoolutions/glyphs",
    "changelog_uri" => "https://github.com/zoolutions/glyphs/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/zoolutions/glyphs/issues",
    "default_lint_roller_plugin" => "Glyphs::RuboCop::Plugin",
    "rubygems_mfa_required" => "true"
  }
  s.required_ruby_version = ">= 3.4"
  s.add_dependency "phlex", "~> 2.0"
  s.add_dependency "rails_icons", "~> 1.2"
  s.add_dependency "zeitwerk", "~> 2.6"
end
