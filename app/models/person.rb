# A senior person at a company. Public information only (product brief): no private emails, no
# scraped profiles. A nil name means the name is not public; never guess one.
class Person < ApplicationRecord
  belongs_to :company

  validates :position, presence: true, uniqueness: { scope: :company_id }
  validates :role, presence: true
  validates :profile_url, http_url: { allow_nil: true }
end
