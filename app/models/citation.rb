# Links a claim, fact or problem row to a source that backs it.
class Citation < ApplicationRecord
  CITABLE_TYPES = %w[Claim Fact Problem].freeze

  belongs_to :source
  belongs_to :citable, polymorphic: true

  validates :citable_type, inclusion: { in: CITABLE_TYPES }
  validates :source_id, uniqueness: { scope: [ :citable_type, :citable_id ] }
end
