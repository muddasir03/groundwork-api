# Two-factor login for admins (authenticator-app codes). See docs/SECURITY.md.
class AddTwoFactorAuthentication < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      # Base32 TOTP secrets, encrypted at rest with Active Record Encryption (see User).
      t.text :otp_secret
      t.text :otp_pending_secret # during setup, until the first code is confirmed
      t.datetime :otp_enabled_at
      # The 30-second time step of the last accepted code: each code works only once.
      t.bigint :otp_last_used_step
    end

    # One-time recovery codes for a lost device. Only bcrypt hashes are stored.
    create_table :recovery_codes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false
      t.datetime :used_at
      t.timestamps
    end

    # The step between a correct password and a valid code. Short-lived and single-use; only the
    # digest of its token is stored.
    create_table :login_challenges do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :consumed_at
      t.string :ip_address
      t.timestamps

      t.index :token_digest, unique: true
      t.index :expires_at
    end
  end
end
