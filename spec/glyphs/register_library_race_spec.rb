# frozen_string_literal: true

RSpec.describe Glyphs, ".register_library under contention" do
  let(:subject_call) { -> { described_class.register_library(:brand, component: :BrandIcon) } }

  # Every check the wedge below delays, so the example after it can prove the
  # wedge is not inert.
  let!(:wedged) { Queue.new }

  # Forces the race: every thread yields between the const_defined? check and
  # the const_set, so without the lock several of them define the constant
  # (5 runs out of 5 on the unlocked code). It is coupled to register_library
  # checking for the constant with Glyphs.const_defined?; the example below fails
  # if that check moves. Thread.pass only hints the scheduler, but a blocking
  # handshake here would deadlock: the first thread holds the lock while it waits.
  before do
    allow(described_class).to receive(:const_defined?).and_wrap_original do |original, *args|
      original.call(*args).tap do
        wedged << args.first
        Thread.pass
      end
    end
  end

  after do
    described_class.send(:remove_const, :BrandIcon) if described_class.const_defined?(:BrandIcon, false)
  end

  it "wedges the existence check register_library makes" do
    subject_call.call

    expect(wedged.pop(timeout: 0)).to eq(:BrandIcon)
  end

  it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
end
