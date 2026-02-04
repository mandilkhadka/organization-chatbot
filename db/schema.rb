# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_03_100006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "admin_audit_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "resource_type", null: false
    t.bigint "resource_id"
    t.jsonb "change_data", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_admin_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_admin_audit_logs_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "documents_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "content", null: false
    t.integer "position"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "embedding"
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.integer "file_size"
    t.integer "status", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.index ["category_id"], name: "index_documents_on_category_id"
    t.index ["status"], name: "index_documents_on_status"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "message_sources", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "document_chunk_id", null: false
    t.float "relevance_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_chunk_id"], name: "index_message_sources_on_document_chunk_id"
    t.index ["message_id"], name: "index_message_sources_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.integer "role", null: false
    t.text "content", null: false
    t.integer "feedback", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 2, null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["status"], name: "index_messages_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "admin_session_expires_at"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.index ["admin_session_expires_at"], name: "index_users_on_admin_session_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "admin_audit_logs", "users"
  add_foreign_key "conversations", "users"
  add_foreign_key "document_chunks", "documents"
  add_foreign_key "documents", "categories"
  add_foreign_key "documents", "users"
  add_foreign_key "message_sources", "document_chunks"
  add_foreign_key "message_sources", "messages"
  add_foreign_key "messages", "conversations"
end
