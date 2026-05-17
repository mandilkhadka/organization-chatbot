require "test_helper"

class RagServiceTest < ActiveSupport::TestCase
  setup do
    @vector_search = Minitest::Mock.new
    @service = RagService.new(vector_search_service: @vector_search)
    @document = documents(:document_one)
    @chunk = document_chunks(:chunk_one)
  end

  test "returns no-info message and yields it when no chunks are found" do
    @vector_search.expect(:search, [], ["anything"])

    yielded = []
    result = @service.query("anything") { |c| yielded << c }

    assert_includes result[:response], "I don't have"
    assert_equal [], result[:sources]
    assert_equal [result[:response]], yielded
  end

  test "returns chunks as sources and aggregated response on success" do
    @vector_search.expect(:search, [@chunk], ["what is the policy?"])

    fake_response = Struct.new(:content).new("The vacation policy is 15 days.")
    chat = Minitest::Mock.new
    chat.expect(:ask, fake_response) do |_prompt, system:, &block|
      assert_equal RagService::SYSTEM_PROMPT, system
      block.call(Struct.new(:content).new("The vacation ")) if block
      block.call(Struct.new(:content).new("policy is 15 days.")) if block
      true
    end

    yielded = []
    RubyLLM.stub :chat, chat do
      result = @service.query("what is the policy?") { |c| yielded << c }
      assert_equal "The vacation policy is 15 days.", result[:response]
      assert_equal [@chunk], result[:sources]
      assert_equal ["The vacation ", "policy is 15 days."], yielded
    end
    chat.verify
  end

  test "returns generic error message when LLM call raises" do
    @vector_search.expect(:search, [@chunk], ["question"])

    raising_chat = Object.new.tap do |o|
      def o.ask(*, **)
        raise StandardError, "Gemini down"
      end
    end

    RubyLLM.stub :chat, raising_chat do
      result = @service.query("question")
      assert_match(/error/i, result[:response])
      assert_equal [], result[:sources]
    end
  end

  test "sanitizes input by truncating and removing control characters" do
    long_question = "a" * (RagService::MAX_QUESTION_LENGTH + 500) + "\x00\x01\x07tail"
    @vector_search.expect(:search, [@chunk], [long_question])

    fake_response = Struct.new(:content).new("ok")
    captured_prompt = nil
    chat = Object.new.tap do |o|
      o.define_singleton_method(:ask) do |prompt, **, &_block|
        captured_prompt = prompt
        fake_response
      end
    end

    RubyLLM.stub :chat, chat do
      @service.query(long_question)
    end

    refute_includes captured_prompt, "\x00"
    refute_includes captured_prompt, "\x07"
    # Truncated content should still have the ellipsis marker.
    assert_includes captured_prompt, "..."
  end
end
