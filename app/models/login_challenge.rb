require "digest"

# The step between a correct password and a valid two-factor code. Holding a challenge grants
# nothing except the right to submit a code for that user: it expires after TTL, allows at most
# MAX_ATTEMPTS wrong codes, and is consumed on success. Only its token's digest is stored.
class LoginChallenge < ApplicationRecord
  TTL = 5.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user

  scope :usable, -> { where(consumed_at: nil).where("expires_at > ?", Time.current).where("failed_attempts < ?", MAX_ATTEMPTS) }

  def self.start!(user:, ip_address: nil)
    token = SecureRandom.urlsafe_base64(32)
    challenge = create!(user: user, token_digest: Session.digest(token), expires_at: TTL.from_now, ip_address: ip_address)
    [ challenge, token ]
  end

  def self.find_usable(token)
    return nil if token.blank? || token.length > 100

    usable.includes(:user).find_by(token_digest: Session.digest(token))
  end

  def record_failure!
    increment!(:failed_attempts)
  end

  def consume!
    update!(consumed_at: Time.current)
  end
end
