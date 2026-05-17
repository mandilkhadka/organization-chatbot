require "test_helper"

class VectorSearchServiceTest < ActiveSupport::TestCase
  setup do
    @query_vec = Array.new(768) { 0.1 }
    @embedding_service = Minitest::Mock.new
    @service = VectorSearchService.new(embedding_service: @embedding_service)
    @document = documents(:document_one)
  end

  test "returns empty array when embedding generation fails" do
    @embedding_service.expect(:generate, nil) { raise StandardError, "API error" }
    result = @service.search("anything")
    assert_equal [], result
  end

  test "ruby fallback computes cosine similarity and applies threshold" do
    # Force the Ruby fallback path.
    DocumentChunk.stub :pgvector_enabled?, false do
      relevant_vec = Array.new(768) { 0.5 }
      irrelevant_vec = Array.new(768) { -0.5 }

      relevant = DocumentChunk.create!(
        document: @document, content: "Relevant chunk", position: 100,
        embedding: relevant_vec.to_json
      )
      irrelevant = DocumentChunk.create!(
        document: @document, content: "Irrelevant chunk", position: 101,
        embedding: irrelevant_vec.to_json
      )

      @embedding_service.expect(:generate, relevant_vec, ["query"])
      result = @service.search("query", limit: 5, threshold: 0.5)

      assert_includes result, relevant
      refute_includes result, irrelevant
    end
  end

  test "ruby fallback respects limit" do
    DocumentChunk.stub :pgvector_enabled?, false do
      vec = Array.new(768) { 0.5 }
      3.times do |i|
        DocumentChunk.create!(
          document: @document, content: "Chunk #{i}", position: 200 + i,
          embedding: vec.to_json
        )
      end

      @embedding_service.expect(:generate, vec, ["query"])
      result = @service.search("query", limit: 2, threshold: 0.5)
      assert_equal 2, result.length
    end
  end

  test "ruby fallback filters chunks below the similarity threshold" do
    DocumentChunk.stub :pgvector_enabled?, false do
      similar_vec = Array.new(768) { 0.5 }
      dissimilar_vec = Array.new(768) { -0.5 }

      similar = DocumentChunk.create!(
        document: @document, content: "Similar", position: 500, embedding: similar_vec
      )
      dissimilar = DocumentChunk.create!(
        document: @document, content: "Dissimilar", position: 501, embedding: dissimilar_vec
      )

      @embedding_service.expect(:generate, similar_vec, ["query"])
      # 0.9 threshold rejects the negatively-correlated vector.
      result = @service.search("query", limit: 5, threshold: 0.9)
      assert_includes result, similar
      refute_includes result, dissimilar
    end
  end
end
