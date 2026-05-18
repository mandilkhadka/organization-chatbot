class EnablePgvector < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # pgvector extension - required for vector similarity search
    # In Supabase, this is pre-installed. For local development, install pgvector first.
    # On macOS: brew install pgvector (ensure it matches your PostgreSQL version)

    execute "CREATE EXTENSION IF NOT EXISTS vector"
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("not available")

    Rails.logger.debug "WARNING: pgvector extension not available. Vector search will not work."
    Rails.logger.debug "For Supabase, the extension is pre-installed."
    Rails.logger.debug "For local development, install pgvector matching your PostgreSQL version."
  end

  def down
    execute "DROP EXTENSION IF EXISTS vector"
  end
end
