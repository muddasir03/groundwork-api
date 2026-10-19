# An account. Only admins exist for now (created with `bin/rails admin:create` or the one-time
# bootstrap, never through the API). Members arrive with user accounts.
class User < ApplicationRecord
  include TwoFactorAuthenticatable

  PASSWORD_LENGTH = 12..72 # bcrypt only uses the first 72 bytes

  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { member: "member", admin: "admin" }, default: :member, validate: true

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :password, length: { in: PASSWORD_LENGTH }, allow_nil: true

  # What the API may say about a user. Never digests, secrets or recovery codes.
  def as_api_json
    { id: id.to_s, emailAddress: email_address, role: role, twoFactorEnabled: two_factor_enabled? }
  end
end
