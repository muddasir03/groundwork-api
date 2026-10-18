# A company's full research report. Matches the client's `Company` contract (lib/api/types.ts)
# minus the personal parts (`fit`, `approach`, and `onProfile` on technologies), which depend on
# the signed-in user and arrive with accounts.
#
# Expects the company loaded with `Company.with_report` so nothing here triggers extra queries.
class CompanySerializer
  def initialize(company)
    @company = company
  end

  def as_json(*)
    CompanySummarySerializer.new(@company).as_json.merge(
      peopleVerifiedAt: @company.people_verified_at&.iso8601,
      report: report,
      sources: @company.sources.map { |source| source_json(source) },
      people: @company.people.map { |person| person_json(person) }
    )
  end

  private

  def report
    claims = @company.claims.group_by(&:section)
    facts = @company.facts.group_by(&:section)
    {
      summary: claims["summary"]&.first&.then { claim_json(it) },
      keyFacts: facts.fetch("key_facts", []).map { fact_json(it) },
      problems: {
        core: claims["problems_core"]&.first&.then { claim_json(it) },
        rows: @company.problems.map { problem_json(it) }
      },
      clients: claims.fetch("clients", []).map { claim_json(it) },
      competitors: claims.fetch("competitors", []).map { claim_json(it) },
      goals: claims.fetch("goals", []).map { claim_json(it) },
      productEngineering: {
        stack: @company.technologies.map { { name: it.name } },
        points: claims.fetch("product_engineering", []).map { claim_json(it) }
      },
      teamHiring: facts.fetch("team_hiring", []).map { fact_json(it) },
      marketRisks: claims.fetch("market_risks", []).map { claim_json(it) }
    }
  end

  def claim_json(claim)
    { text: claim.text, sourceIds: claim.source_ids_for_api }
  end

  def fact_json(fact)
    { label: fact.label, value: fact.value, status: fact.status, sourceIds: fact.source_ids_for_api }
  end

  def problem_json(problem)
    { who: problem.who, problem: problem.problem, solution: problem.solution, sourceIds: problem.source_ids_for_api }
  end

  def source_json(source)
    { id: source.id.to_s, title: source.title, url: source.url, dateKind: source.date_kind, date: source.date.iso8601 }
  end

  def person_json(person)
    { id: person.id.to_s, name: person.name, role: person.role, profileUrl: person.profile_url }
  end
end
