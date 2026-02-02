class RAGService
  CHAT_MODEL = ENV.fetch("CHAT_MODEL", "gemini-2.0-flash")

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a helpful company knowledge assistant. Answer questions based ONLY on
    the provided context from company documents. If the answer is not in the context,
    say "I don't have information about that in the company documents."

    Always be professional, accurate, and cite which document the information comes from.
    Keep your answers concise and helpful.
  PROMPT

  def initialize(vector_search_service: VectorSearchService.new)
    @vector_search_service = vector_search_service
  end

  def query(question)
    # 1. Retrieve relevant chunks
    chunks = @vector_search_service.search(question)

    if chunks.empty?
      no_info_response = "I don't have any information about that in the company documents."
      yield no_info_response if block_given?
      return { response: no_info_response, sources: [] }
    end

    # 2. Build context from retrieved chunks
    context = build_context(chunks)

    # 3. Generate response with optional streaming
    chat = RubyLLM.chat(model: CHAT_MODEL)

    prompt = build_prompt(context, question)
    response_text = ""

    response = chat.ask(prompt, system: SYSTEM_PROMPT) do |chunk|
      response_text << chunk.content if chunk.content
      yield chunk.content if block_given? && chunk.content
    end

    { response: response_text.presence || response.content, sources: chunks }
  rescue StandardError => e
    Rails.logger.error("RAG query failed: #{e.message}")
    error_response = "I'm sorry, I encountered an error while processing your question. Please try again."
    yield error_response if block_given?
    { response: error_response, sources: [] }
  end

  private

  def build_context(chunks)
    chunks.map.with_index do |chunk, index|
      "[Source #{index + 1}: #{chunk.document.title}]\n#{chunk.content}"
    end.join("\n\n---\n\n")
  end

  def build_prompt(context, question)
    <<~PROMPT
      Context from company documents:
      #{context}

      ---

      User Question: #{question}

      Please answer the question based on the context provided above. If you cite information, mention which source it came from.
    PROMPT
  end
end
