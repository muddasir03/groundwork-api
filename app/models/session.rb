require "digest"

# A login session. The client holds a random token; only its SHA-256 digest is stored, so a copy of
# the database can't be used to log in. Sessions end after ABSOLUTE_TTL, after IDLE_TTL without
# use, or on logout (revoked_at).
class Session < ApplicationRecord
  ABSOLUTE_TTL = 8.hours
  IDLE_TTL = 2.hours
  TOUCH_EVERY = 5.minutes # limit writes: refresh last_used_at at most this often

  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current).where("last_used_at > ?", IDLE_TTL.ago) }

  # Starts a session and returns [session, token]. The token is shown to the client once.
  def self.start!(user:, ip_address: nil, user_agent: nil)
    token = SecureRandom.urlsafe_base64(32) # 256 bits
    now = Time.current
    session = create!(user: user, token_digest: digest(token), expires_at: now + ABSOLUTE_TTL, last_used_at: now,
                      ip_address: ip_address, user_agent: user_agent&.first(255))
    [ session, token ]
  end

  # The active session for a token, or nil. Looks up by digest, so the comparison never touches the
  # raw token and the database never stores it.
  def self.find_active(token)
    return nil if token.blank? || token.length > 100

    active.includes(:user).find_by(token_digest: digest(token))
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token)

  def touch_last_used!
    update_column(:last_used_at, Time.current) if last_used_at < TOUCH_EVERY.ago
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at
  end
end
