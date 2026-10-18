# A technology in the company's stack. Whether it is also on a user's profile is personal and is
# worked out per user, not stored here.
class Technology < ApplicationRecord
  belongs_to :company

  validates :position, presence: true, uniqueness: { scope: :company_id }
  validates :name, presence: true, uniqueness: { scope: :company_id }
end
