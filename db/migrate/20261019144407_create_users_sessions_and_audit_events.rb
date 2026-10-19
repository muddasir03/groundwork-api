# Accounts, login sessions and an audit trail of admin actions. See docs/SECURITY.md.
class CreateUsersSessionsAndAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false # bcrypt hash, never the password
      t.string :role, null: false, default: "member"
      t.timestamps

      t.index "lower(email_address)", unique: true, name: "index_users_on_lower_email_address"
      t.check_constraint "role IN ('member', 'admin')", name: "users_role_values"
      t.check_constraint "email_address = lower(btrim(email_address))", name: "users_email_normalized"
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # SHA-256 of the session token. The token itself is only ever held by the client, so a leaked
      # database can't be used to log in.
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at, null: false
      t.datetime :revoked_at
      t.string :ip_address
      t.string :user_agent
      t.timestamps

      t.index :token_digest, unique: true
      t.index :expires_at
    end

    # Who did what, when. Append-only: rows are never updated or deleted by the app.
    create_table :audit_events do |t|
      t.references :user, foreign_key: { on_delete: :nullify } # kept if the account is removed
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :details, null: false, default: {}
      t.string :ip_address
      t.datetime :created_at, null: false

      t.index [ :subject_type, :subject_id ]
      t.index :created_at
    end
  end
end
