# Centralized Sidekiq config. REDIS_URL must be set in prod; locally we fall
# back to a sensible default so a fresh `brew install redis` works.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
redis_pool_size = ENV.fetch("SIDEKIQ_REDIS_POOL_SIZE", 12).to_i

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, size: redis_pool_size }

  # Treat the standard set of network/timeout errors as retryable, capped by
  # Sidekiq's default backoff schedule. ServerMiddleware can add per-job rules.
  config.death_handlers << lambda do |job, ex|
    Rails.logger.error("[sidekiq] dead job #{job['class']} jid=#{job['jid']} args=#{job['args'].inspect} error=#{ex.class}: #{ex.message}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, size: 5 }
end
