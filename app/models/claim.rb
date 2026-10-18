# A sentence of research in one report section, always backed by at least one source.
class Claim < ApplicationRecord
  include Citable

  # `summary` and `problems_core` hold one claim each; the others are lists.
  SECTIONS = %w[summary problems_core clients competitors goals product_engineering market_risks].freeze

  belongs_to :company

  validates :section, inclusion: { in: SECTIONS }
  validates :position, presence: true, uniqueness: { scope: [ :company_id, :section ] }
  validates :text, presence: true
end
