class HealthController < ActionController::Base
  # Health endpoints are public by design — load balancers hit them with no
  # cookies. Inheriting from ActionController::Base instead of
  # ApplicationController skips Devise auth, CSRF tokens, and flash.

  # /health — liveness only. Returns 200 if Rails booted. Use this from k8s
  # liveness probes; it must NOT fail just because a dependency is degraded,
  # or your load balancer will kill an otherwise-healthy pod.
  def liveness
    render json: { status: "ok", env: Rails.env }, status: :ok
  end

  # /health/deep — readiness. Checks Postgres + Redis + (optionally) Gemini.
  # Returns 503 if any required dependency is unreachable. Use for
  # readiness probes and uptime monitors.
  def readiness
    checks = {
      postgres: check_postgres,
      redis: check_redis
    }
    checks[:gemini] = check_gemini if ENV["HEALTH_CHECK_GEMINI"] == "true"

    overall_ok = checks.values.all? { |c| c[:ok] }
    render json: { status: overall_ok ? "ok" : "degraded", checks: checks },
           status: overall_ok ? :ok : :service_unavailable
  end

  private

  def check_postgres
    ActiveRecord::Base.connection.execute("SELECT 1")
    { ok: true }
  rescue StandardError => e
    { ok: false, error: e.class.name, message: e.message.truncate(200) }
  end

  def check_redis
    Rails.cache.write("health:ping", Time.current.to_i, expires_in: 5)
    value = Rails.cache.read("health:ping")
    { ok: value.present? }
  rescue StandardError => e
    { ok: false, error: e.class.name, message: e.message.truncate(200) }
  end

  def check_gemini
    return { ok: true, skipped: true } if ENV["GEMINI_API_KEY"].blank?

    # Minimal token request — we only need to confirm the API key auths.
    timeout_seconds = 3
    Timeout.timeout(timeout_seconds) do
      EmbeddingService.new.health_check
    end
    { ok: true }
  rescue StandardError => e
    { ok: false, error: e.class.name, message: e.message.truncate(200) }
  end
end
