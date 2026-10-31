# frozen_string_literal: true

require "prism"

module Glyphs
  # Scans an application's source for statically-known icon references and
  # returns a Set of IconReference. Ruby/Phlex files are parsed with Prism (a
  # real AST); templates (.erb/.haml/.slim) are text-scanned for icon calls and
  # `iconify` class strings.
  #
  # Dynamic names/variants/libraries are silently skipped — they can't be known
  # statically and are covered by the pruner's keep-list. A file that fails to
  # parse warns and is skipped rather than aborting the scan.
  class SourceScanner
    DEFAULT_RUBY_GLOBS = ["app/**/*.rb", "lib/**/*.rb"].freeze
    DEFAULT_TEMPLATE_GLOBS = ["app/**/*.erb", "app/**/*.haml", "app/**/*.slim"].freeze

    # Template (.erb/.haml/.slim) text scanning. Prism can't parse these, so we
    # match icon calls textually: the method, the literal first-argument name,
    # and the argument tail (to pull out `variant:` and, for the generic
    # `icon`/`Icon` helper, `library:`/`from:`). `Icon`/`icon` are included here
    # (they're handled by the AST visitor for .rb files) so the generic
    # rails_icons view helper is caught in templates too.
    TEMPLATE_CALL_NAMES = (
      IconReference::LIBRARY_TO_COMPONENT.values +
        IconReference::LEGACY_HELPERS.keys +
        %w[Icon icon]
    ).freeze
    # The tail runs to the end of the line or the ERB/Slim tag close (`%>`,
    # `-%>`) — NOT to the first `)`, which would truncate `variant:`/`from:` sitting
    # after a nested call like `class: cn("a")`. Over-capturing the tail only ever
    # ADDS a keep (never drops a reference), so it errs safe.
    TEMPLATE_CALL_PATTERN = /
      \b(#{Regexp.union(TEMPLATE_CALL_NAMES)})
      \(?\s*[:"']([a-z0-9_-]+)['"]?      # first arg is a literal symbol or string
      ([^\n]*?)                          # argument tail (rest of the logical line)
      (?=-?%>|\n|\z)
    /x
    TEMPLATE_VARIANT_PATTERN = /\bvariant:\s*[:"']?([a-z0-9_.-]*)/
    TEMPLATE_LIBRARY_PATTERN = /\b(?:library|from):\s*[:"']([a-z0-9_-]+)/
    GENERIC_TEMPLATE_CALLS = %w[Icon icon].freeze

    # `extra_globs` are additional locations to text-scan on top of the built-in
    # Ruby and template defaults (never replacing them) — e.g. a config file that
    # names icons. They're scanned like templates (regex, not AST).
    def initialize(root:, ruby_globs: DEFAULT_RUBY_GLOBS, template_globs: DEFAULT_TEMPLATE_GLOBS, extra_globs: [])
      @root = root
      @ruby_globs = ruby_globs
      @template_globs = template_globs
      @extra_globs = Array(extra_globs)
    end

    # Confirmed references: icons named by a LITERAL in an icon call (or an
    # iconify string). These are guaranteed-real — the pruner keeps them AND the
    # runner asserts every one still resolves on disk after a prune.
    def call
      scan
      @references
    end

    # Advisory per-library keeps harvested from DYNAMIC call sites (see
    # DynamicHarvest). `{ library => Set[names] }`. These may include literals
    # that aren't real icons (a CSS class, a method name), so — like the
    # configured keep_icons — they are kept if present but NEVER asserted by
    # verification. Feed them into the pruner's keep path, not the runner's
    # expected-files set.
    def dynamic_keeps
      scan
      @dynamic_keeps
    end

    private

    def scan
      return if @scanned

      @references = Set.new
      harvest = DynamicHarvest.new
      ruby_files.each { |path| scan_ruby(path, @references, harvest) }
      (template_files - ruby_files).each { |path| scan_template(path, @references) }
      @dynamic_keeps = harvest.to_h
      @scanned = true
    end

    attr_reader :root

    def ruby_files
      glob(@ruby_globs)
    end

    def template_files
      glob(@template_globs + @extra_globs)
    end

    def glob(patterns)
      patterns.flat_map { |pattern| Dir.glob(File.join(root, pattern)) }.uniq
    end

    def scan_ruby(path, references, harvest)
      result = Prism.parse_file(path)
      visitor = CallVisitor.new(references)
      visitor.visit(result.value)
      harvest.absorb(visitor)
    rescue StandardError => e
      warn "[Glyphs::SourceScanner] skipped #{path}: #{e.class}: #{e.message}"
    end

    def scan_template(path, references)
      text = File.read(path)
      scan_iconify(text, references)
      text.scan(TEMPLATE_CALL_PATTERN) do |method_name, name, tail|
        add_template_call(references, method_name, name, tail)
      end
    rescue StandardError => e
      warn "[Glyphs::SourceScanner] skipped #{path}: #{e.class}: #{e.message}"
    end

    # Records a template icon call, reading `variant:` (and, for the generic
    # icon/Icon helper, `library:`/`from:`) out of the captured argument tail so
    # a variant-bearing template call resolves to the same file it renders.
    def add_template_call(references, method_name, name, tail)
      library = template_library(method_name, tail)
      return unless library

      references << IconReference.new(
        library:,
        variant: template_variant(tail, library),
        name: name.to_s.tr("_", "-")
      )
    end

    # A present-but-empty `variant:` (`variant: ""` / `variant: :"."`) means
    # no-variant — mirror the AST path: default ONLY when the keyword is absent.
    def template_variant(tail, library)
      match = tail.match(TEMPLATE_VARIANT_PATTERN)
      return IconReference.default_variant_for(library) unless match

      IconReference.normalize_variant(match[1])
    end

    def template_library(method_name, tail)
      return IconReference.library_for(method_name) unless GENERIC_TEMPLATE_CALLS.include?(method_name)

      match = tail.match(TEMPLATE_LIBRARY_PATTERN)
      match && match[1].to_sym
    end

    def scan_iconify(text, references)
      text.scan(IconReference::ICONIFY_PATTERN) do |library, name|
        library = library.to_sym
        references << IconReference.new(library:, variant: IconReference.default_variant_for(library), name:)
      end
    end

    # Accumulates the evidence needed to resolve DYNAMIC icon calls — ones whose
    # name the AST can't read (`LucideIcon(tile[:icon])`) — across every scanned
    # Ruby file, then turns that evidence into IconReferences.
    #
    # Three sources of candidate names, all harvested only from literals so we
    # never invent a reference:
    #
    #   1. file-scoped — a file that dynamically renders library L contributes
    #      every icon-name-shaped literal in that file as a candidate for L.
    #      Catches ternaries, case/when, and locals near the call.
    #   2. declaration-based — literals in icon-declaration positions ANYWHERE
    #      (a hash pair keyed `/icon/i`, or a constant named `/ICON/`) are
    #      candidates for EVERY dynamically-rendered library, since a bare
    #      `ICON = :bell` in one file is often rendered from another.
    #   3. forwarded — a file passing a non-literal under a key like an icon
    #      (`Badge(icon:)`, `Badge(icon: row.first)`) hands a name on to a wrapper
    #      that renders it elsewhere, so ALL its literals are candidates for
    #      every dynamically-rendered library, as declarations are.
    #
    # Names resolve at the library's default variant: a dynamic call names no
    # variant in practice, and the pruner keeps per (library, variant).
    class DynamicHarvest
      def initialize
        @dynamic_libraries = Set.new
        @file_literals = Hash.new { |hash, key| hash[key] = Set.new }
        @declaration_literals = Set.new
      end

      # Folds one file's visitor results into the running accumulator.
      def absorb(visitor)
        @declaration_literals.merge(visitor.declaration_literals)
        @declaration_literals.merge(visitor.file_literals) if visitor.forwards_icon
        return if visitor.dynamic_libraries.empty?

        @dynamic_libraries.merge(visitor.dynamic_libraries)
        visitor.dynamic_libraries.each do |library|
          @file_literals[library].merge(visitor.file_literals)
        end
      end

      # `{ library => Set[candidate names] }` for every dynamically-rendered
      # library. Advisory: names may not be real icons, so callers keep them but
      # must not assert they exist.
      def to_h
        @dynamic_libraries.to_h do |library|
          [library, @file_literals[library] | @declaration_literals]
        end
      end
    end

    # Walks the Prism AST collecting icon references from call nodes.
    class CallVisitor < Prism::Visitor
      GENERIC_CALLS = %i[Icon icon].freeze

      # A literal that could be an icon name: lowercase, digits, dashes/underscores.
      # Excludes CSS classes (spaces/slashes), paths, and interpolated strings.
      ICON_NAME_LITERAL = /\A[a-z][a-z0-9_-]*\z/

      # Values of an icon-keyed pair that forward nothing: a declaration harvest
      # reads the names, and `icon: nil` or `icon_size: 16` names no icon at all.
      LITERAL_VALUES = [
        Prism::SymbolNode, Prism::StringNode, Prism::NilNode, Prism::TrueNode, Prism::FalseNode,
        Prism::IntegerNode, Prism::FloatNode
      ].freeze

      # Libraries this file renders with a dynamic (non-literal) first argument.
      attr_reader :dynamic_libraries
      # Icon-name-shaped literals anywhere in this file (file-scoped candidates).
      attr_reader :file_literals
      # Literals in icon-declaration positions (`icon:` pairs, `ICON` constants).
      attr_reader :declaration_literals
      # Whether this file passes a non-literal under a key like an icon.
      attr_reader :forwards_icon

      def initialize(references)
        @references = references
        @dynamic_libraries = Set.new
        @file_literals = Set.new
        @declaration_literals = Set.new
        @forwards_icon = false
        super()
      end

      def visit_call_node(node)
        record(node) if node.receiver.nil?
        super
      end

      def visit_string_node(node)
        node.unescaped.scan(IconReference::ICONIFY_PATTERN) do |library, name|
          library = library.to_sym
          references << IconReference.new(library:, variant: IconReference.default_variant_for(library), name:)
        end
        collect_literal(@file_literals, node)
        super
      end

      def visit_symbol_node(node)
        collect_literal(@file_literals, node)
        super
      end

      # `ICON = :bell` / `CHANNEL_ICONS = { .. => :whatsapp_logo }` — a constant
      # named like an icon is a declaration of icon name(s), wherever it lives.
      def visit_constant_write_node(node)
        collect_declaration(node.value) if node.name.to_s.match?(/ICON/i)
        super
      end

      # `icon: :activity` / `menu_icon: "gear"` — a hash pair keyed like an icon
      # declares an icon name, wherever it lives. A non-literal value there
      # (`icon:`, `icon: row.first`) forwards a name instead.
      def visit_assoc_node(node)
        key = node.key
        if key.is_a?(Prism::SymbolNode) && key.unescaped.match?(/icon/i)
          collect_declaration(node.value)
          @forwards_icon ||= forwarded_value?(node.value)
        end
        super
      end

      private

      attr_reader :references

      # A container forwards when anything inside it does: `icon: [:a, pick]`.
      def forwarded_value?(value_node)
        value_node = unwrap_declaration_wrappers(value_node)
        case value_node
        when Prism::ArrayNode then value_node.elements.any? { |element| forwarded_value?(element) }
        when Prism::HashNode then value_node.elements.any? { |element| forwarded_pair?(element) }
        else LITERAL_VALUES.none? { |literal| value_node.is_a?(literal) }
        end
      end

      def forwarded_pair?(element)
        !element.is_a?(Prism::AssocNode) || forwarded_value?(element.value)
      end

      def record(node)
        method = node.name.to_s
        if GENERIC_CALLS.include?(node.name)
          record_generic(node)
        elsif IconReference.library_for(method)
          record_component(node, IconReference.library_for(method))
        end
      end

      def record_component(node, library)
        name = literal_string(first_argument(node))
        # A dynamic first arg (variable, method call, hash lookup) can't be read
        # off the call — flag the library so the harvest resolves its name from
        # file-scoped and declaration literals instead.
        unless name
          @dynamic_libraries << library if first_argument(node)
          return
        end

        variant = variant_for(node, library)
        return if variant == :dynamic

        references << IconReference.new(library:, variant:, name:)
      end

      def record_generic(node)
        library = literal_symbol_or_string(keyword_argument(node, %i[library from]))
        return unless library

        name = literal_string(first_argument(node))
        return unless name

        variant = variant_for(node, library.to_sym)
        return if variant == :dynamic

        references << IconReference.new(library: library.to_sym, variant:, name:)
      end

      def variant_for(node, library)
        value_node = keyword_argument(node, [:variant])
        return IconReference.default_variant_for(library) unless value_node

        value = literal_symbol_or_string(value_node)
        return :dynamic unless value

        IconReference.normalize_variant(value)
      end

      def first_argument(node)
        node.arguments&.arguments&.first
      end

      # Returns the value node for the first matching keyword, or nil.
      def keyword_argument(node, keys)
        pair = keyword_pairs(node).find do |element|
          element.key.is_a?(Prism::SymbolNode) && keys.include?(element.key.unescaped.to_sym)
        end
        pair&.value
      end

      def keyword_pairs(node)
        args = node.arguments&.arguments || []
        hash = args.find { |arg| arg.is_a?(Prism::KeywordHashNode) || arg.is_a?(Prism::HashNode) }
        hash ? hash.elements.grep(Prism::AssocNode) : []
      end

      def literal_string(value_node)
        literal_symbol_or_string(value_node)&.tr("_", "-")
      end

      # Returns the literal String for a symbol/string node, or nil when the
      # node is dynamic (a variable, method call, interpolation, ...).
      def literal_symbol_or_string(value_node)
        value_node.unescaped if value_node.is_a?(Prism::SymbolNode) || value_node.is_a?(Prism::StringNode)
      end

      # Adds a single symbol/string literal to `set` when it's shaped like an
      # icon name (dasherized). Interpolated strings (StringNode with no static
      # `unescaped`) and non-name-shaped literals are ignored.
      def collect_literal(set, node)
        raw = node.unescaped
        return unless raw.is_a?(String) && raw.match?(ICON_NAME_LITERAL)

        set << raw.tr("_", "-")
      end

      # Harvests icon names from a declaration value: a bare literal, an array of
      # literals (`ICON = %i[a b]`), or a hash's values (`{ "sms" => :device }`).
      # Trailing `.freeze` is unwrapped so `ICONS = { … }.freeze` still harvests —
      # without this, cross-file dynamics (`PhosphorIcon(@icon)` + names only in a
      # frozen `ICONS` hash) lose those names at prune.
      def collect_declaration(value_node)
        value_node = unwrap_declaration_wrappers(value_node)
        case value_node
        when Prism::SymbolNode, Prism::StringNode
          collect_literal(@declaration_literals, value_node)
        when Prism::ArrayNode
          value_node.elements.each { |element| collect_declaration(element) }
        when Prism::HashNode
          value_node.elements.grep(Prism::AssocNode).each { |assoc| collect_declaration(assoc.value) }
        end
      end

      # Peel zero-arg `.freeze` and parentheses so the underlying Hash/Array/literal
      # is what declaration harvest walks.
      def unwrap_declaration_wrappers(value_node)
        loop do
          case value_node
          when Prism::CallNode
            break unless freeze_call?(value_node)

            value_node = value_node.receiver
          when Prism::ParenthesesNode
            value_node = value_node.body
          when Prism::StatementsNode
            # `(expr)` → StatementsNode with one child; multi-statement bodies are
            # not valid constant values, so take the sole statement when present.
            break unless value_node.body.size == 1

            value_node = value_node.body.first
          else
            break
          end
        end
        value_node
      end

      # `receiver.freeze` with no args — the common immutable-constant pattern.
      def freeze_call?(node)
        node.name == :freeze &&
          node.receiver &&
          (node.arguments.nil? || node.arguments.arguments.empty?)
      end
    end
  end
end
