# Research that must be backed by sources (claims, facts, problem rows). Enforces the product rule
# "every claim shows its source": a citable record needs at least one source, and only sources from
# its own company.
module Citable
  extend ActiveSupport::Concern

  included do
    has_many :citations, as: :citable, dependent: :destroy, inverse_of: :citable
    has_many :sources, through: :citations

    validate :cites_own_company_sources
    validate :cites_at_least_one_source, if: :requires_source?
  end

  # Ids of the cited sources, without loading them (citations are usually preloaded).
  def source_ids_for_api
    citations.map { |citation| citation.source_id.to_s }
  end

  private

  def requires_source?
    true
  end

  def cited_sources
    citations.map(&:source).compact
  end

  def cites_at_least_one_source
    errors.add(:base, "must cite at least one source") if citations.reject(&:marked_for_destruction?).empty?
  end

  def cites_own_company_sources
    return unless cited_sources.any? { |source| source.company_id != company_id }

    errors.add(:base, "can only cite sources from the same company")
  end
end
