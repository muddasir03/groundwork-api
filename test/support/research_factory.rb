# Builds valid research records for tests, so each test only spells out what it's about.
module ResearchFactory
  def create_company(slug: "test-co", status: :published, **attrs)
    company = Company.create!(
      { slug: slug, name: slug.titleize, description: "A test company.", city: "Valencia", country: "Spain",
        sector: "HR tech", size: "51-200", stage: "Series A", status: status,
        researched_at: Date.new(2026, 9, 30), people_verified_at: Date.new(2026, 9, 30),
        published_at: (status.to_s == "published" ? Time.current : nil) }.merge(attrs)
    )
    add_report(company)
    company
  end

  def add_report(company)
    first = create_source(company, 1)
    second = create_source(company, 2)
    build_cited(company.claims.build(section: "summary", position: 1, text: "What they do."), first).save!
    build_cited(company.claims.build(section: "problems_core", position: 1, text: "The core problem."), first).save!
    build_cited(company.claims.build(section: "clients", position: 1, text: "Small businesses."), first, second).save!
    build_cited(company.facts.build(section: "key_facts", position: 1, label: "Founded", value: "2018", status: :verified), first).save!
    company.facts.create!(section: "team_hiring", position: 1, label: "Pay", value: nil, status: :not_public)
    build_cited(company.problems.build(position: 1, who: "HR managers", problem: "Scattered data", solution: "One system"), second).save!
    company.technologies.create!(position: 1, name: "Ruby on Rails")
    company.people.create!(position: 1, name: "Alex Example", role: "CEO", profile_url: "https://example.com/alex")
    company.people.create!(position: 2, name: nil, role: "CTO", profile_url: nil)
  end

  def create_source(company, position)
    company.sources.create!(position: position, title: "Source #{position}", url: "https://example.com/#{position}",
                            date_kind: "published", date: Date.new(2026, 6, position))
  end

  def build_cited(record, *sources)
    sources.each { |source| record.citations.build(source: source) }
    record
  end
end
