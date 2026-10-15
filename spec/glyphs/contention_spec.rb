# frozen_string_literal: true

RSpec.describe Glyphs, ".svg_for under contention" do
  def self.svg_for(name, **attributes)
    described_class.svg_for(name:, library: :lucide, variant: nil, attributes:)
  end

  context "when every caller renders the same icon" do
    let(:subject_call) { -> { self.class.svg_for("house", class: "size-4") } }

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 50, consistent: :equal
    it_behaves_like "fiber-safe under an Async reactor", fibers: 8, iterations: 50, consistent: :equal
  end

  context "when the cache is smaller than the working set" do
    before { described_class.configure { |config| config.svg_cache_size = 2 } }

    # Three icons through a two-entry cache: every call evicts.
    let(:subject_call) do
      -> { %w[house circle-check triangle-alert].map { |name| self.class.svg_for(name, class: "size-#{name.size}") } }
    end

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 50, consistent: :equal
    it_behaves_like "fiber-safe under an Async reactor", fibers: 8, iterations: 50, consistent: :equal
  end
end
