# frozen_string_literal: true

RSpec.describe Glyphs, ".register_library under contention" do
  let(:subject_call) { -> { described_class.register_library(:brand, component: :BrandIcon) } }

  # Forces the race: every thread yields between the const_defined? check and
  # the const_set, so without the lock several of them define the constant.
  before do
    allow(described_class).to receive(:const_defined?).and_wrap_original do |original, *args|
      original.call(*args).tap { Thread.pass }
    end
  end

  after do
    described_class.send(:remove_const, :BrandIcon) if described_class.const_defined?(:BrandIcon, false)
  end

  it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
end
