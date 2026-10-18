# A company in a list (search results). JSON keys are camelCase to match the client's data contract
# (groundwork-client lib/api/types.ts, CompanySummary without the personal `fit`).
#
# Serializers list every field explicitly, so new columns are never exposed by accident.
class CompanySummarySerializer
  def initialize(company)
    @company = company
  end

  def as_json(*)
    {
      slug: @company.slug,
      name: @company.name,
      description: @company.description,
      city: @company.city,
      country: @company.country,
      sector: @company.sector,
      size: @company.size,
      stage: @company.stage,
      researchedAt: @company.researched_at&.iso8601,
      sourceCount: @company.sources_count
    }
  end
end
