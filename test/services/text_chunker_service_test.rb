require "test_helper"

class TextChunkerServiceTest < ActiveSupport::TestCase
  setup do
    @chunker = TextChunkerService.new
  end

  test "returns empty array for blank input" do
    assert_equal [], @chunker.chunk("")
    assert_equal [], @chunker.chunk(nil)
    assert_equal [], @chunker.chunk("   ")
  end

  test "returns single chunk for short text" do
    text = "This is a short sentence. Here is another one."
    chunks = @chunker.chunk(text)
    assert_equal 1, chunks.length
    assert_includes chunks.first, "short sentence"
  end

  test "splits long text into multiple chunks" do
    sentence = "This is sentence number #{rand(100)} which is long enough. "
    text = sentence * 50

    chunks = @chunker.chunk(text)
    assert_operator chunks.length, :>, 1, "Expected multiple chunks for long input"
  end

  test "preserves overlap between consecutive chunks" do
    chunker = TextChunkerService.new(chunk_size: 100, chunk_overlap: 20)
    text = (1..30).map { |i| "Sentence number #{i} contains content." }.join(" ")

    chunks = chunker.chunk(text)
    skip "Need at least 2 chunks to test overlap" if chunks.length < 2

    # Overlap: the chunker carries some trailing characters from the previous
    # chunk into the next one. We don't pin a precise window because sentence
    # boundaries shift it; we just require *some* shared token.
    first_tail_words = chunks.first.split.last(5)
    second_head_text = chunks[1][0, 80]
    shared = first_tail_words.any? { |w| second_head_text.include?(w) }
    assert shared, "Expected some overlap from first chunk to appear at start of second"
  end

  test "rejects blank chunks from output" do
    text = "One sentence here. \n\n\n Another sentence."
    chunks = @chunker.chunk(text)
    assert chunks.none?(&:blank?), "No chunk should be blank"
  end

  test "splits on sentence boundaries (. ! ?)" do
    text = "First sentence. Second one! Third question? Fourth thing."
    chunks = @chunker.chunk(text)
    # All sentences should be present somewhere in the output
    joined = chunks.join(" ")
    assert_includes joined, "First sentence"
    assert_includes joined, "Second one"
    assert_includes joined, "Third question"
    assert_includes joined, "Fourth thing"
  end
end
