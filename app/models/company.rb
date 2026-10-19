# A researched company. Only `published` companies are ever shown to users; the other statuses are
# the research pipeline (draft → researching → in review → published), visible to admins only.
class Company < ApplicationRecord
  SIZES = %w[1-50 51-200 201-1000 1000+].freeze
  # Lowercase words joined by single hyphens ("brisa-people"). Also used by the route constraint and
  # mirrored by the companies_slug_format check constraint.
  SLUG_PATTERN = /[a-z0-9]+(?:-[a-z0-9]+)*/
  SLUG_FORMAT = /\A#{SLUG_PATTERN}\z/

  enum :status, { draft: "draft", researching: "researching", in_review: "in_review", published: "published" },
       default: :draft, validate: true

  has_many :sources, -> { order(:position) }, dependent: :destroy, inverse_of: :company
  has_many :claims, -> { order(:section, :position) }, dependent: :destroy, inverse_of: :company
  has_many :facts, -> { order(:section, :position) }, dependent: :destroy, inverse_of: :company
  has_many :problems, -> { order(:position) }, dependent: :destroy, inverse_of: :company
  has_many :technologies, -> { order(:position) }, dependent: :destroy, inverse_of: :company
  has_many :people, -> { order(:position) }, dependent: :destroy, inverse_of: :company

  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT }
  validates :name, :description, :city, :country, :sector, presence: true
  validates :name, :city, :country, :sector, :stage, length: { maximum: 120 }
  validates :description, length: { maximum: 300 }
  validates :slug, length: { maximum: 80 }
  validates :size, inclusion: { in: SIZES }
  validates :researched_at, :published_at, presence: true, if: :published?

  # Everything the full report needs, in one round of queries (no N+1).
  scope :with_report, -> {
    includes(:sources, :technologies, :people, claims: :citations, facts: :citations, problems: :citations)
  }

  def to_param = slug

  def publish!(at: Time.current)
    update!(status: :published, published_at: at)
  end
end
