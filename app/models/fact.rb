# A labelled fact ("Founded: 2018"). Unknown values are explicit: a fact is `verified` (with a value
# and a source), `unconfirmed`, or `not_public`, and never carries a guessed value.
class Fact < ApplicationRecord
  include Citable

  SECTIONS = %w[key_facts team_hiring].freeze

  enum :status, { verified: "verified", unconfirmed: "unconfirmed", not_public: "not_public" }, validate: true

  belongs_to :company

  validates :section, inclusion: { in: SECTIONS }
  validates :position, presence: true, uniqueness: { scope: [ :company_id, :section ] }
  validates :label, presence: true
  validates :value, presence: true, if: :verified?
  validates :value, absence: { message: "must be empty unless the fact is verified" }, unless: :verified?

  private

  # Only verified facts need a source; unknowns have nothing to cite.
  def requires_source? = verified?
end
