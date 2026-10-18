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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_222830) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "citations", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.string "citable_type", null: false
    t.bigint "citable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["citable_type", "citable_id"], name: "index_citations_on_citable"
    t.index ["source_id", "citable_type", "citable_id"], name: "index_citations_uniqueness", unique: true
    t.index ["source_id"], name: "index_citations_on_source_id"
    t.check_constraint "citable_type::text = ANY (ARRAY['Claim'::character varying, 'Fact'::character varying, 'Problem'::character varying]::text[])", name: "citations_citable_type_values"
  end

  create_table "claims", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "section", null: false
    t.integer "position", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "section", "position"], name: "index_claims_on_company_id_and_section_and_position", unique: true
    t.index ["company_id"], name: "index_claims_on_company_id"
    t.check_constraint "section::text = ANY (ARRAY['summary'::character varying, 'problems_core'::character varying, 'clients'::character varying, 'competitors'::character varying, 'goals'::character varying, 'product_engineering'::character varying, 'market_risks'::character varying]::text[])", name: "claims_section_values"
  end

  create_table "companies", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "description", null: false
    t.string "city", null: false
    t.string "country", null: false
    t.string "sector", null: false
    t.string "size", null: false
    t.string "stage"
    t.string "status", default: "draft", null: false
    t.date "researched_at"
    t.date "people_verified_at"
    t.datetime "published_at"
    t.integer "sources_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city"], name: "index_companies_on_city"
    t.index ["sector"], name: "index_companies_on_sector"
    t.index ["slug"], name: "index_companies_on_slug", unique: true
    t.index ["status", "country"], name: "index_companies_on_status_and_country"
    t.check_constraint "size::text = ANY (ARRAY['1-50'::character varying, '51-200'::character varying, '201-1000'::character varying, '1000+'::character varying]::text[])", name: "companies_size_values"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "companies_slug_format"
    t.check_constraint "status::text <> 'published'::text OR researched_at IS NOT NULL AND published_at IS NOT NULL", name: "companies_published_needs_dates"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'researching'::character varying, 'in_review'::character varying, 'published'::character varying]::text[])", name: "companies_status_values"
  end

  create_table "facts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "section", null: false
    t.integer "position", null: false
    t.string "label", null: false
    t.text "value"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "section", "position"], name: "index_facts_on_company_id_and_section_and_position", unique: true
    t.index ["company_id"], name: "index_facts_on_company_id"
    t.check_constraint "(status::text = 'verified'::text) = (value IS NOT NULL)", name: "facts_value_only_when_verified"
    t.check_constraint "section::text = ANY (ARRAY['key_facts'::character varying, 'team_hiring'::character varying]::text[])", name: "facts_section_values"
    t.check_constraint "status::text = ANY (ARRAY['verified'::character varying, 'unconfirmed'::character varying, 'not_public'::character varying]::text[])", name: "facts_status_values"
  end

  create_table "people", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "position", null: false
    t.string "name"
    t.string "role", null: false
    t.string "profile_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "position"], name: "index_people_on_company_id_and_position", unique: true
    t.index ["company_id"], name: "index_people_on_company_id"
    t.check_constraint "profile_url IS NULL OR profile_url::text ~ '^https?://'::text", name: "people_profile_url_http"
  end

  create_table "problems", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "position", null: false
    t.string "who", null: false
    t.text "problem", null: false
    t.text "solution", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "position"], name: "index_problems_on_company_id_and_position", unique: true
    t.index ["company_id"], name: "index_problems_on_company_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.string "url", null: false
    t.string "date_kind", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "position"], name: "index_sources_on_company_id_and_position", unique: true
    t.index ["company_id"], name: "index_sources_on_company_id"
    t.check_constraint "date_kind::text = ANY (ARRAY['published'::character varying, 'accessed'::character varying]::text[])", name: "sources_date_kind_values"
    t.check_constraint "url::text ~ '^https?://'::text", name: "sources_url_http"
  end

  create_table "technologies", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "position", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_technologies_on_company_id_and_name", unique: true
    t.index ["company_id", "position"], name: "index_technologies_on_company_id_and_position", unique: true
    t.index ["company_id"], name: "index_technologies_on_company_id"
  end

  add_foreign_key "citations", "sources", on_delete: :cascade
  add_foreign_key "claims", "companies", on_delete: :cascade
  add_foreign_key "facts", "companies", on_delete: :cascade
  add_foreign_key "people", "companies", on_delete: :cascade
  add_foreign_key "problems", "companies", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sources", "companies", on_delete: :cascade
  add_foreign_key "technologies", "companies", on_delete: :cascade
end
