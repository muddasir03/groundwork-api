require "rotp"
require "bcrypt"

# Authenticator-app (TOTP, RFC 6238) two-factor login, plus one-time recovery codes.
#
# - Secrets are encrypted at rest (Active Record Encryption; keys in credentials).
# - A code is accepted within ±1 time step (30 s) for clock drift, and only once: the step of the
#   last accepted code is stored and older-or-equal steps are refused (no replay), under a row lock.
# - Recovery codes are random, shown once, stored as bcrypt hashes and usable once each.
module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  ISSUER = "Groundwork"
  STEP = 30 # seconds per code
  RECOVERY_CODE_COUNT = 10
  TOTP_FORMAT = /\A\d{6}\z/
  RECOVERY_FORMAT = /\A[a-z2-7]{10}\z/ # base32, ~50 bits

  included do
    encrypts :otp_secret, :otp_pending_secret
    has_many :recovery_codes, dependent: :destroy
    has_many :login_challenges, dependent: :destroy
  end

  def two_factor_enabled?
    otp_enabled_at.present? && otp_secret.present?
  end

  # Starts (or restarts) setup with a fresh secret. Returns what the authenticator app needs.
  def start_two_factor_setup!
    secret = ROTP::Base32.random
    update!(otp_pending_secret: secret)
    { secret: secret, uri: ROTP::TOTP.new(secret, issuer: ISSUER).provisioning_uri(email_address) }
  end

  # Finishes setup when `code` matches the pending secret. Returns the new recovery codes (shown
  # once), or nil if the code is wrong.
  def confirm_two_factor!(code)
    with_lock do
      return nil if otp_pending_secret.blank?

      step = matching_step(otp_pending_secret, code)
      return nil unless step

      update!(otp_secret: otp_pending_secret, otp_pending_secret: nil, otp_enabled_at: Time.current, otp_last_used_step: step)
      regenerate_recovery_codes!
    end
  end

  # True if `code` is a valid, not-yet-used authenticator code.
  def verify_two_factor_code!(code)
    return false unless two_factor_enabled?

    with_lock do
      step = matching_step(otp_secret, code)
      return false unless step && (otp_last_used_step.nil? || step > otp_last_used_step)

      update!(otp_last_used_step: step)
      true
    end
  end

  # True if `code` matches an unused recovery code, which is then spent.
  def use_recovery_code!(code)
    normalized = code.to_s.downcase.gsub(/[\s-]/, "")
    return false unless two_factor_enabled? && normalized.match?(RECOVERY_FORMAT)

    with_lock do
      match = recovery_codes.where(used_at: nil).find { |recovery| BCrypt::Password.new(recovery.code_digest) == normalized }
      match&.update!(used_at: Time.current)
      match.present?
    end
  end

  # Replaces all recovery codes. Returns the plain codes, formatted "abcde-fghij" (shown once).
  def regenerate_recovery_codes!
    codes = Array.new(RECOVERY_CODE_COUNT) { ROTP::Base32.random(10).downcase.first(10) }
    transaction do
      recovery_codes.delete_all
      codes.each { |code| recovery_codes.create!(code_digest: BCrypt::Password.create(code, cost: bcrypt_cost)) }
    end
    codes.map { |code| "#{code[0, 5]}-#{code[5, 5]}" }
  end

  def remaining_recovery_codes = recovery_codes.where(used_at: nil).count

  # For an admin who lost both their device and their recovery codes (bin/rails admin:reset_two_factor).
  def reset_two_factor!
    transaction do
      update!(otp_secret: nil, otp_pending_secret: nil, otp_enabled_at: nil, otp_last_used_step: nil)
      recovery_codes.delete_all
      sessions.update_all(revoked_at: Time.current)
    end
  end

  private

  # Full cost in production; minimum cost in tests (the same rule has_secure_password follows).
  def bcrypt_cost
    ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
  end

  # The time step `code` belongs to (now, or one step either side), or nil.
  def matching_step(secret, code)
    return nil unless code.to_s.match?(TOTP_FORMAT)

    timestamp = ROTP::TOTP.new(secret, issuer: ISSUER).verify(code.to_s, drift_behind: STEP, drift_ahead: STEP)
    timestamp && timestamp / STEP
  end
end
