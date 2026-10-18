# A row of "Problems they solve": who has the problem, what it is, and the company's solution.
class Problem < ApplicationRecord
  include Citable

  belongs_to :company

  validates :position, presence: true, uniqueness: { scope: :company_id }
  validates :who, :problem, :solution, presence: true
end
