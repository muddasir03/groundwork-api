# A document backing the research: an announcement, a careers page, a news article.
class Source < ApplicationRecord
  DATE_KINDS = %w[published accessed].freeze

  belongs_to :company, counter_cache: true
  has_many :citations, dependent: :destroy

  validates :position, presence: true, uniqueness: { scope: :company_id }
  validates :title, presence: true, length: { maximum: 300 }
  validates :url, length: { maximum: 2000 }
  validates :url, presence: true, http_url: true
  validates :date_kind, inclusion: { in: DATE_KINDS }
  validates :date, presence: true
end
