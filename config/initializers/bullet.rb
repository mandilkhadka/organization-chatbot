# N+1 detection. Surfaces queries that would silently scale linearly with
# row count, before they reach production. Bullet is dev/test only — it has
# false-positive cost and would be noise in prod logs.
if defined?(Bullet) && Rails.env.local?
  Rails.application.config.after_initialize do
    Bullet.enable        = true
    Bullet.bullet_logger = true
    Bullet.rails_logger  = true

    # In dev we want loud feedback; in CI we just want a log line.
    Bullet.alert         = Rails.env.development?
    Bullet.console       = Rails.env.development?
    Bullet.add_footer    = Rails.env.development?

    # Keep raise=false until existing N+1s are cleaned up. Flip to
    # Rails.env.test? once the test suite is green with the stricter rule.
    Bullet.raise = false
  end
end
