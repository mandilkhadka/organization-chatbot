require "test_helper"

class EmbeddingServiceTest < ActiveSupport::TestCase
  setup do
    @service = EmbeddingService.new
    @fake_vector = Array.new(768) { rand(-1.0..1.0) }
  end

  test "generate returns vectors from RubyLLM response" do
    fake_response = Struct.new(:vectors).new(@fake_vector)
    RubyLLM.stub :embed, fake_response do
      result = @service.generate("Some text to embed")

      assert_equal @fake_vector, result
    end
  end

  test "generate logs error and re-raises on failure" do
    RubyLLM.stub :embed, ->(*) { raise StandardError, "Gemini API down" } do
      assert_raises(StandardError) do
        @service.generate("Some text")
      end
    end
  end

  test "generate_batch returns one vector per input" do
    fake_response = Struct.new(:vectors).new(@fake_vector)
    RubyLLM.stub :embed, fake_response do
      results = @service.generate_batch(["a", "b", "c"])

      assert_equal 3, results.length
      results.each { |r| assert_equal @fake_vector, r }
    end
  end

  test "generate_batch raises if any single call fails" do
    call_count = 0
    fake_response = Struct.new(:vectors).new(@fake_vector)
    stub_proc = lambda do |*_args|
      call_count += 1
      raise StandardError, "boom" if call_count == 2

      fake_response
    end

    RubyLLM.stub :embed, stub_proc do
      assert_raises(StandardError) do
        @service.generate_batch(["a", "b", "c"])
      end
    end
  end
end
