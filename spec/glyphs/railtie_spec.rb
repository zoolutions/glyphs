# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Boots a minimal Rails app in a child process, so Rails never loads into this
# suite, and reports the configuration Glyphs::Railtie's after_initialize hook
# left behind. Named by string: the Railtie is only loaded under Rails.
RSpec.describe "Glyphs::Railtie" do
  let(:boot_script) do
    <<~RUBY
      require "bundler/setup"
      require "json"
      require "rails"
      require "glyphs"

      module GlyphsBootSpec
        class Application < Rails::Application
          config.root = ARGV.fetch(0)
          config.eager_load = false
          config.logger = Logger.new(nil)
        end
      end
      Rails.application.initialize!

      configuration = Glyphs.configuration
      hook = configuration.on_missing_icon
      hook&.call(StandardError.new("gone"), name: "house", library: :lucide, variant: nil)
      puts JSON.generate(
        frozen: configuration.frozen?,
        shareable: Ractor.shareable?(configuration),
        settings_frozen: configuration.fallback_icons.frozen? && configuration.keep_icons.frozen?,
        hook: hook.class.name,
        logger_frozen: Rails.logger.frozen?
      )
    RUBY
  end

  # The README's own config/initializers/glyphs.rb: its on_missing_icon closes
  # over the initializer's self, so it can never be made shareable.
  let(:readme_initializer) do
    <<~'RUBY'
      Glyphs.configure do |config|
        config.raise_on_missing = Rails.env.local?

        config.on_missing_icon = lambda do |error, name:, library:, variant:|
          Rails.logger.error("Icon missing: #{library}/#{variant}/#{name} (#{error.message})")
        end

        config.fallback_icons = {
          lucide: "circle-question-mark",
          phosphor: "question",
          heroicons: "question-mark-circle"
        }
        config.cache_svgs = true
        config.svg_cache_size = 1024
      end
    RUBY
  end

  def boot(initializer: nil)
    Dir.mktmpdir do |root|
      if initializer
        FileUtils.mkdir_p(File.join(root, "config/initializers"))
        File.write(File.join(root, "config/initializers/glyphs.rb"), initializer)
      end
      out, err, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__),
        "-e", boot_script, root)
      raise "the app failed to boot:\n#{err}" unless status.success?

      JSON.parse(out.lines.last, symbolize_names: true)
    end
  end

  it "finalizes the configuration once the app has booted, with no code of the app's" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)

    expect(boot).to include(frozen: true, shareable: true, settings_frozen: true)
  end

  it "boots with the README's on_missing_icon, which cannot be shared, and keeps it working" do
    skip "no Ractor on #{RUBY_ENGINE}" unless defined?(Ractor)

    expect(boot(initializer: readme_initializer))
      .to include(frozen: true, shareable: false, settings_frozen: true, hook: "Proc", logger_frozen: false)
  end
end
