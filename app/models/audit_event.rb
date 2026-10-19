# An append-only record of a security-relevant or admin action: logins, logouts, research edits,
# publishing. Never updated or deleted by the app.
class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true

  def readonly? = persisted?

  def self.record!(action, user: nil, subject: nil, ip_address: nil, **details)
    create!(action: action, user: user, subject: subject, ip_address: ip_address, details: details)
  end
end
