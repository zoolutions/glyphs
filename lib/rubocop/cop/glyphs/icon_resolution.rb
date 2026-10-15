# frozen_string_literal: true

module RuboCop
  module Cop
    module Glyphs
      # Validates that statically-known icon names exist in the synced SVG
      # directories (`IconsPath`), suggests close matches for typos, and flags
      # raw `iconify` class strings.
      #
      # Both Glyphs component calls (`LucideIcon(:house)`) and legacy helper
      # calls (`_lucide(:house)`) are validated. A literal `variant:` keyword is
      # honored; calls with dynamic names or variants are skipped.
      #
      # A directory that does not exist is a configuration error, not "nothing
      # to check": it warns once per library/variant, or — with `Strict` — adds
      # an offence, so the cop can never quietly validate nothing. A directory
      # that exists but ships no SVGs stays silent.
      #
      # @example
      #   # bad
      #   LucideIcon(:non_existent_icon)
      #   span(class: "iconify lucide--house size-4")
      #
      #   # good
      #   LucideIcon(:house, class: "size-4")
      class IconResolution < Base
        extend AutoCorrector

        DEFAULT_LIBRARIES = {
          "LucideIcon" => { "Dir" => "lucide", "DefaultVariant" => "outline" },
          "PhosphorIcon" => { "Dir" => "phosphor", "DefaultVariant" => "regular" },
          "HeroIcon" => { "Dir" => "heroicons", "DefaultVariant" => "outline" },
          "TablerIcon" => { "Dir" => "tabler", "DefaultVariant" => "outline" },
          "SidekickIcon" => { "Dir" => "sidekickicons", "DefaultVariant" => "outline" }
        }.freeze

        LEGACY_HELPERS = {
          "_lucide" => "LucideIcon",
          "_phosphor" => "PhosphorIcon",
          "_hero" => "HeroIcon",
          "_heroicon" => "HeroIcon",
          "_tabler" => "TablerIcon"
        }.freeze

        ICONIFY_PREFIX_TO_COMPONENT = {
          "lucide" => "LucideIcon",
          "phosphor" => "PhosphorIcon",
          "heroicons" => "HeroIcon"
        }.freeze

        KNOWN_LUCIDE_RENAMES = {
          "alert-triangle" => "triangle-alert",
          "alert-circle" => "circle-alert",
          "x-circle" => "circle-x"
        }.freeze

        ICONIFY_PATTERN = /\biconify\s+(lucide|phosphor|heroicons)--([a-z0-9-]+)/

        DEFAULT_ICONS_PATH = "app/assets/svg/icons"

        RAW_MSG = "Use `%{component}(:%{symbol}, class: \"%{rest}\")` instead of raw `iconify %{library}--…` class."
        RAW_DSTR_MSG = "Use `LucideIcon(name, class: ...)` etc. instead of building a raw " \
                       "`iconify <library>--…` class string."
        MISSING_MSG = "Icon `%{name}` not found in %{library}/%{variant}. %{suggestion}"
        MISSING_DIR_MSG = "Icon directory `%{path}` not found, so `%{component}` names are not validated. " \
                          "Sync the library or fix `IconsPath`/`Libraries`."

        def on_str(node)
          return if node.parent&.dstr_type?

          check_iconify_string(node, node.value)
        end

        def on_dstr(node)
          combined = node.children.filter_map { |child| child.str_type? ? child.value : "INTERPOLATED" }.join
          return unless combined.include?("iconify ")

          add_offense(node, message: RAW_DSTR_MSG)
        end

        def on_send(node)
          return unless node.receiver.nil?

          component = component_for(node.method_name)
          return unless component

          library = libraries[component]
          return unless library

          check_call(node, component, library)
        rescue StandardError => e
          source = node.location.expression.source_buffer.name
          warn "[Glyphs/IconResolution] suppressed #{e.class}: #{e.message} at #{source}:#{node.first_line}"
        end

        private

        def component_for(method_name)
          name = method_name.to_s
          return name if libraries.key?(name)

          LEGACY_HELPERS[name]
        end

        def libraries
          @libraries ||= DEFAULT_LIBRARIES.merge(cop_config["Libraries"] || {})
        end

        def check_call(node, component, library)
          name = literal_name(node.first_argument)
          return unless name

          variant = variant_for(node, library)
          return if variant == :dynamic

          available = available_icons(library["Dir"], variant)
          return report_missing_directory(node, component, library["Dir"], variant) if available.nil?
          return if available.empty?
          return if available.include?(name)

          suggestion = build_suggestion(name, available, library["Dir"])
          add_offense(node.first_argument,
            message: format(MISSING_MSG, name:, library: library["Dir"], variant:,
              suggestion: suggestion[:msg])) do |corrector|
            next unless suggestion[:autocorrect]

            replacement =
              if node.first_argument.sym_type?
                ":#{suggestion[:name].tr('-', '_')}"
              else
                %("#{suggestion[:name]}")
              end
            corrector.replace(node.first_argument, replacement)
          end
        end

        # The directory the cop was told to read is missing, so every call for
        # this library goes unchecked. Report it rather than pass silently.
        def report_missing_directory(node, component, library_dir, variant)
          message = format(MISSING_DIR_MSG, path: configured_directory(library_dir, variant), component:)
          return add_offense(node.first_argument, message:) if cop_config["Strict"]

          self.class.warn_once("[Glyphs/IconResolution] #{message}")
        end

        # Built from the unexpanded `IconsPath` so the message shows the path as
        # the project wrote it, not an absolute machine-specific one.
        def configured_directory(library_dir, variant)
          self.class.directory_for(cop_config["IconsPath"] || DEFAULT_ICONS_PATH, library_dir, variant)
        end

        def variant_for(node, library)
          pair = variant_pair(node)
          return library["DefaultVariant"] if pair.nil?
          return :dynamic unless pair.value.str_type? || pair.value.sym_type?

          pair.value.value.to_s
        end

        def variant_pair(node)
          hash = node.arguments.last
          return nil unless hash&.hash_type?

          hash.pairs.find { |pair| pair.key.sym_type? && pair.key.value == :variant }
        end

        def literal_name(node)
          return unless node && (node.sym_type? || node.str_type?)

          node.value.to_s.tr("_", "-")
        end

        def check_iconify_string(node, value)
          return unless value.include?("iconify ")
          return unless (match = ICONIFY_PATTERN.match(value))

          iconify_prefix = match[1]
          icon_name = match[2]
          rest = remaining_classes(value, iconify_prefix, icon_name)
          symbol = icon_name.tr("-", "_")
          component = ICONIFY_PREFIX_TO_COMPONENT.fetch(iconify_prefix)

          add_offense(node,
            message: format(RAW_MSG, component:, library: iconify_prefix, symbol:, rest:)) do |corrector|
            replacement = if rest.empty?
              "#{component}(:#{symbol})"
            else
              "#{component}(:#{symbol}, class: \"#{rest}\")"
            end

            span_node = enclosing_span_call(node)
            corrector.replace(span_node, replacement) if span_node
          end
        end

        def enclosing_span_call(str_node)
          pair = str_node.parent
          return nil unless pair&.pair_type?
          return nil unless pair.key.sym_type? && pair.key.value == :class

          hash = pair.parent
          return nil unless hash&.hash_type?
          return nil if hash.pairs.size != 1

          send_node = hash.parent
          return nil unless send_node&.send_type?
          return nil unless send_node.method_name == :span
          return nil unless send_node.arguments.size == 1

          send_node
        end

        def remaining_classes(value, library, icon_name)
          value.sub(/iconify\s+#{library}--#{Regexp.escape(icon_name)}\s*/, "").strip
        end

        def build_suggestion(name, available, library_dir)
          if library_dir == "lucide" && (renamed = KNOWN_LUCIDE_RENAMES[name]) && available.include?(renamed)
            return { msg: "Did you mean `:#{renamed.tr('-', '_')}`? (Lucide v1 reordered prefix and suffix.)",
                     autocorrect: true,
                     name: renamed }
          end

          matches = fuzzy_match(name, available)
          if matches.size == 1
            { msg: "Did you mean `:#{matches.first.tr('-', '_')}`?", autocorrect: true, name: matches.first }
          elsif matches.any?
            list = matches.first(5).map { |match| "`:#{match.tr('-', '_')}`" }.join(", ")
            { msg: "Did you mean one of: #{list}?", autocorrect: false, name: nil }
          else
            { msg: "No similar icons found.", autocorrect: false, name: nil }
          end
        end

        def fuzzy_match(name, available)
          name_parts = name.split("-")

          scored = available.filter_map do |candidate|
            score = part_score(name_parts, candidate.split("-"))
            distance = damerau_levenshtein(name, candidate)
            score += [3 - distance, 0].max if distance <= 2
            score += 2 if name.length >= 3 && candidate.include?(name)
            score += 2 if name.length >= 3 && candidate.split("-").any? { |part| part.start_with?(name[0..2]) }

            [candidate, score] if score >= 3
          end

          scored.sort_by { |_, score| -score }.map(&:first).take(5)
        end

        def part_score(name_parts, candidate_parts)
          score = 0
          score += 5 if name_parts.sort == candidate_parts.sort
          score += (name_parts & candidate_parts).size * 2
          score += 4 if name_parts.size == 2 && candidate_parts.size == 2 && name_parts.reverse == candidate_parts
          score
        end

        def damerau_levenshtein(left, right)
          return right.length if left.empty?
          return left.length if right.empty?
          return 99 if (left.length - right.length).abs > 3

          rows = Array.new(left.length + 1) { Array.new(right.length + 1, 0) }
          (0..left.length).each { |i| rows[i][0] = i }
          (0..right.length).each { |j| rows[0][j] = j }

          (1..left.length).each do |i|
            (1..right.length).each do |j|
              cost = left[i - 1] == right[j - 1] ? 0 : 1
              rows[i][j] = [
                rows[i - 1][j] + 1,
                rows[i][j - 1] + 1,
                rows[i - 1][j - 1] + cost
              ].min
              if i > 1 && j > 1 && left[i - 1] == right[j - 2] && left[i - 2] == right[j - 1]
                rows[i][j] = [rows[i][j], rows[i - 2][j - 2] + 1].min
              end
            end
          end

          rows[left.length][right.length]
        end

        def icons_base_path
          @icons_base_path ||= File.expand_path(cop_config["IconsPath"] || DEFAULT_ICONS_PATH, Dir.pwd)
        end

        def available_icons(library_dir, variant)
          self.class.available_icons_for(icons_base_path, library_dir, variant)
        end

        # Guards the two class-level memos below: RuboCop builds a cop instance
        # per file, and a server or LSP process may inspect files on threads.
        @memo_lock = Mutex.new

        class << self
          # nil when the directory is absent, [] when it exists but ships no
          # SVGs — the caller has to tell those apart. Memoized with `key?` (not
          # `||=`) so a nil result is not re-probed on every call site.
          def available_icons_for(base_path, library_dir, variant)
            key = [base_path, library_dir, variant]
            @memo_lock.synchronize do
              @available_icons_cache ||= {}
              return @available_icons_cache[key] if @available_icons_cache.key?(key)

              @available_icons_cache[key] = load_icons(directory_for(base_path, library_dir, variant))
            end
          end

          def directory_for(base_path, library_dir, variant)
            File.join(*[base_path, library_dir, variant].compact.reject { |part| part.to_s.empty? })
          end

          # RuboCop builds a fresh cop instance per file, so deduplicating the
          # missing-directory warning has to outlive the instance.
          def warn_once(message)
            first = @memo_lock.synchronize do
              @warned_messages ||= {}
              !@warned_messages.key?(message) && (@warned_messages[message] = true)
            end
            warn message if first
          end

          def reset_warnings!
            @memo_lock.synchronize { @warned_messages = nil }
          end

          private

          def load_icons(path)
            return nil unless Dir.exist?(path)

            Dir.children(path).filter_map { |file| File.basename(file, ".svg") if file.end_with?(".svg") }.sort
          end
        end
      end
    end
  end
end
