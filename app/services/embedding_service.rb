class EmbeddingService
  MODEL = ENV.fetch("EMBEDDING_MODEL", "gemini-embedding-exp-03-07")

  def generate(text)
    response = RubyLLM.embed(text, model: MODEL)
    response.vectors
  rescue StandardError => e
    Rails.logger.error("Embedding generation failed: #{e.message}")
    raise
  end

  def generate_batch(texts)
    texts.map { |text| generate(text) }
  end
end
