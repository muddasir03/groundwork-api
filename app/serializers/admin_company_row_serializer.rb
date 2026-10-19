# One row of the admin companies table. Matches the client's AdminCompanyRow.
class AdminCompanyRowSerializer
  def initialize(company, contacts_verified:, contacts_total:)
    @company = company
    @contacts_verified = contacts_verified
    @contacts_total = contacts_total
  end

  def as_json(*)
    {
      slug: @company.slug,
      name: @company.name,
      status: @company.status,
      lastResearchedAt: @company.researched_at&.iso8601,
      sourceCount: @company.sources_count.positive? ? @company.sources_count : nil,
      contactsVerified: @contacts_total ? @contacts_verified.to_i : nil,
      contactsTotal: @contacts_total
    }
  end
end
