RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
  config.request_timeout = 30
end

if ENV["GEMINI_API_KEY"].blank? && !Rails.env.test?
  Rails.logger.warn("WARNING: GEMINI_API_KEY is not set. RAG chatbot features will not work.")
end
