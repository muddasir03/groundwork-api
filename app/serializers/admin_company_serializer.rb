# A company as admins see it: the full report (same shape as the public one) plus pipeline fields.
# Admin-only; never used by public endpoints.
class AdminCompanySerializer
  def initialize(company)
    @company = company
  end

  def as_json(*)
    CompanySerializer.new(@company).as_json.merge(
      status: @company.status,
      publishedAt: @company.published_at&.iso8601,
      updatedAt: @company.updated_at.iso8601
    )
  end
end
