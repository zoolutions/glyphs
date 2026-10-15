# frozen_string_literal: true

module Glyphs
  # A rendered <svg>, split once into its opening tag's attributes and the
  # rest, so a cache hit applies a caller's attributes without the File.read
  # and Nokogiri pass of a fresh render (Icons::Icon#svg).
  #
  # The attributes go through the icons gem's own Icons::Icon::Attributes
  # (class token lists, nested data:/aria: hashes, `_` to `-`), collected into a
  # Hash instead of a Nokogiri node, and are written the way libxml2 writes
  # them: an attribute already on the tag is replaced in place, a new one is
  # appended, `&`, `<` and `>` are escaped, and a value holding `"` but no `'`
  # is single-quoted. What libxml2 writes specially (HTML boolean attributes,
  # href/src/action, control characters) is not merged: #render returns nil and
  # the caller renders it uncached. spec/glyphs/svg_template_spec.rb holds the
  # output byte-for-byte to the icons gem's.
  #
  # A caller's data: replaces the library's default data (the icons gem merges
  # them that way) and lands where the defaults would have, so data: calls use
  # a template rendered with DATA_SLOT, whose marker attribute holds that place.
  class SvgTemplate
    DATA_SLOT = { data: { "glyphs-data-slot" => "" }.freeze }.freeze
    SLOT_ATTRIBUTE = "data-glyphs-data-slot"

    OPENING_TAG = /\A<svg((?:\s+[^\s=>]+(?:="[^"]*"|='[^']*')?)*)\s*>/
    ATTRIBUTE = /\s+(([^\s=>]+)(?:="[^"]*"|='[^']*')?)/
    ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;" }.freeze
    ESCAPABLE = /[&<>"]/
    # libxml2 writes HTML boolean attributes without their value and
    # percent-encodes URI attributes.
    SPECIAL_NAMES = %w[
      checked compact declare defer disabled ismap multiple nohref noresize noshade nowrap readonly selected
      href src action
    ].to_h { |name| [name, true] }.freeze
    UPPERCASE = /[A-Z]/
    PLAIN_NAME = %r{\A[^\s"'<>/=\x00-\x1F\x7F]+\z}
    CONTROL_CHARACTER = /[\x00-\x08\x0B\x0C\x0E-\x1F]/

    attr_reader :svg

    # `data_slot: true` for markup rendered with DATA_SLOT as its data:.
    def initialize(svg, data_slot: false)
      @svg = svg.frozen? ? svg : svg.dup.freeze
      match = OPENING_TAG.match(@svg)
      @rest = match&.post_match.freeze
      @pairs = match && parse(match[1])
      @slot = data_slot ? slot_index : nil
      @pairs = nil if data_slot && @slot.nil? # no marker: nothing to merge onto
      freeze
    end

    # The SVG with `attributes` applied, or nil when they cannot be merged
    # exactly (the caller then renders them through the icons gem).
    def render(attributes)
      return @svg if attributes.empty?
      return unless mergeable?(attributes)

      pairs = merge(@pairs.dup, attributes)
      build(pairs) if pairs
    end

    private

    def parse(attributes)
      attributes.scan(ATTRIBUTE).map { |fragment, name| [name.freeze, " #{fragment}".freeze].freeze }.freeze
    end

    def slot_index
      @pairs&.index { |name, _| name == SLOT_ATTRIBUTE }
    end

    # A data: call needs the data: template, any other call the plain one.
    def mergeable?(attributes)
      !@pairs.nil? && attributes.key?(:data) == !@slot.nil?
    end

    def merge(pairs, attributes)
      return if @slot && !splice_data(pairs, attributes.slice(:data))

      merged = collect(@slot ? attributes.except(:data) : attributes)
      return unless merged

      merged.each { |name, fragment| assign(pairs, name, fragment) }
      pairs
    end

    # Puts the data: attributes where the slot marker is, in order, replacing
    # any already on the tag, then drops the marker.
    def splice_data(pairs, data)
      merged = collect(data)
      return false unless merged

      slot = @slot
      merged.each do |name, fragment|
        index = pairs.index { |pair_name, _| pair_name == name }
        next pairs[index] = [name, fragment] if index

        pairs.insert(slot, [name, fragment])
        slot += 1
      end
      pairs.delete_at(slot)
    end

    def assign(pairs, name, fragment)
      index = pairs.index { |pair_name, _| pair_name == name }
      if index
        pairs[index] = [name, fragment]
      else
        pairs << [name, fragment]
      end
    end

    # [[name, fragment], ...] in the order the icons gem would set them, or nil
    # if any of them is one libxml2 writes specially.
    def collect(attributes)
      collected = {}
      Icons::Icon::Attributes.new(arguments: attributes).attach(to: collected)
      collected.map do |name, value|
        name = name.to_s
        value = value.to_s
        return nil unless plain?(name, value)

        [name, fragment(name, value)]
      end
    end

    def plain?(name, value)
      PLAIN_NAME.match?(name) && !special?(name) && value.valid_encoding? &&
        (value.ascii_only? || value.encoding == Encoding::UTF_8) && !CONTROL_CHARACTER.match?(value)
    end

    def special?(name)
      SPECIAL_NAMES.key?(name) || (UPPERCASE.match?(name) && SPECIAL_NAMES.key?(name.downcase))
    end

    def fragment(name, value)
      return " #{name}=\"#{value}\"" unless ESCAPABLE.match?(value)

      if value.include?('"') && !value.include?("'")
        " #{name}='#{value.gsub(/[&<>]/, ESCAPES)}'"
      else
        " #{name}=\"#{value.gsub(ESCAPABLE, ESCAPES)}\""
      end
    end

    def build(pairs)
      svg = +"<svg"
      pairs.each { |pair| svg << pair.last }
      svg << ">" << @rest
    end
  end
end
