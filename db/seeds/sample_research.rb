# Builds the fictional sample companies through the real models, so seeds obey the same rules as
# real research (every claim cites a source, unknown facts stay unknown, links are http(s)).
#
# Facts are written as [label, value, [source numbers]] when verified, or [label, :not_public] /
# [label, :unconfirmed] when unknown. Claims are [text, [source numbers]]. Source numbers are
# 1-based positions in the company's `sources` list.
module SampleResearch
  module_function

  def seed!
    ActiveRecord::Base.transaction do
      COMPANIES.each { |data| upsert!(data) }
      PIPELINE.each { |data| upsert_pipeline!(data) }
    end
  end

  def upsert!(data)
    company = Company.find_or_initialize_by(slug: data[:slug])
    reset!(company)
    company.update!(
      data.slice(:name, :description, :city, :country, :sector, :size, :stage, :researched_at, :people_verified_at)
          .merge(status: :published, published_at: Time.current)
    )

    sources = data[:sources].each_with_index.map do |(title, date_kind, date), index|
      company.sources.create!(position: index + 1, title: title, date_kind: date_kind, date: date,
                              url: "https://example.com/#{company.slug}/source-#{index + 1}")
    end

    claim!(company, sources, "summary", 1, data[:summary])
    claim!(company, sources, "problems_core", 1, data[:problems_core])
    %i[clients competitors goals product_engineering market_risks].each do |section|
      data.fetch(section, []).each_with_index { |claim, index| claim!(company, sources, section.to_s, index + 1, claim) }
    end
    %i[key_facts team_hiring].each do |section|
      data.fetch(section, []).each_with_index { |fact, index| fact!(company, sources, section.to_s, index + 1, fact) }
    end
    data.fetch(:problems, []).each_with_index do |(who, problem, solution, cited), index|
      cite(company.problems.build(position: index + 1, who: who, problem: problem, solution: solution), sources, cited).save!
    end
    data[:stack].each_with_index { |name, index| company.technologies.create!(position: index + 1, name: name) }
    data[:people].each_with_index do |(key, name, role), index|
      company.people.create!(position: index + 1, name: name, role: role,
                             profile_url: name && "https://example.com/#{company.slug}/people/#{key}")
    end
  end

  # Companies still in the research pipeline: visible to admins only, never to users.
  def upsert_pipeline!(data)
    company = Company.find_or_initialize_by(slug: data[:slug])
    reset!(company)
    company.update!(data)
  end

  def reset!(company)
    return unless company.persisted?

    %i[sources claims facts problems technologies people].each { |association| company.public_send(association).destroy_all }
    company.reload
  end

  def claim!(company, sources, section, position, (text, cited))
    cite(company.claims.build(section: section, position: position, text: text), sources, cited).save!
  end

  def fact!(company, sources, section, position, (label, value, cited))
    attrs = if value.is_a?(Symbol)
      { status: value, value: nil }
    else
      { status: :verified, value: value }
    end
    cite(company.facts.build(section: section, position: position, label: label, **attrs), sources, cited || []).save!
  end

  def cite(record, sources, numbers)
    numbers.each { |number| record.citations.build(source: sources.fetch(number - 1)) }
    record
  end

  COMPANIES = [
    {
      slug: "brisa-people", name: "Brisa People", description: "HR and payroll platform for small and mid-sized businesses.",
      city: "Valencia", country: "Spain", sector: "HR tech", size: "201-1000", stage: "Series C",
      researched_at: Date.new(2026, 9, 30), people_verified_at: Date.new(2026, 9, 30),
      sources: [
        [ "Brisa People: Series C announcement", "published", Date.new(2026, 6, 12) ],
        [ "Brisa People: pricing and modules", "accessed", Date.new(2026, 9, 30) ],
        [ "Brisa People careers: Senior Product Engineer", "published", Date.new(2026, 8, 20) ],
        [ "Brisa People engineering blog: Moving payroll rules out of the monolith", "published", Date.new(2026, 5, 2) ],
        [ "Brisa People: customer stories", "accessed", Date.new(2026, 9, 30) ],
        [ "Regional business press: HR software market in Spain", "published", Date.new(2026, 7, 15) ]
      ],
      summary: [ "Brisa People runs HR, payroll and time tracking for small and mid-sized businesses in one place. It serves around 4,000 companies in Spain and Portugal and is adding AI assistants to its core product. A Series C in June 2026 funded its expansion into payroll.", [ 1, 5 ] ],
      key_facts: [
        [ "Founded", "2018", [ 1 ] ], [ "Customers", "About 4,000 businesses", [ 5 ] ],
        [ "Employees", "About 320", [ 1 ] ], [ "Work policy", "Engineering office-first", [ 3 ] ]
      ],
      problems_core: [ "Replacing spreadsheets, email and separate tools with one system for every employee record, payslip and approval.", [ 2 ] ],
      problems: [
        [ "HR managers", "Employee data scattered across files and inboxes", "Brisa Core: records, documents, e-signature", [ 2 ] ],
        [ "Shift-based teams", "Manual time and absence tracking risks labour-law fines", "Time tracking, leave and shift planning", [ 2, 5 ] ],
        [ "Finance teams", "Payroll prepared by hand from several tools", "Integrated payroll with Spanish tax rules", [ 1, 2 ] ]
      ],
      clients: [
        [ "Mostly businesses with 20–500 employees in retail, hospitality and professional services.", [ 5 ] ],
        [ "Customer stories feature restaurant groups and regional retail chains.", [ 5 ] ]
      ],
      competitors: [ [ "Competes with other HR suites for small businesses and with local payroll agencies.", [ 6 ] ] ],
      goals: [
        [ "Expand payroll from Spain into Portugal during 2027.", [ 1 ] ],
        [ "Ship AI assistants that answer employees' HR questions inside the product.", [ 1, 3 ] ]
      ],
      stack: [ "Ruby on Rails", "React", "PostgreSQL", "TypeScript", "Sidekiq", "LLM assistants" ],
      product_engineering: [
        [ "About 60 engineers in product teams, each owning a domain such as payroll or time tracking.", [ 3 ] ],
        [ "Hardest problems: Spanish labour and tax rules, and splitting payroll out of a large Rails monolith.", [ 4 ] ],
        [ "Publishes an engineering blog.", [ 4 ] ]
      ],
      team_hiring: [
        [ "Offices", "Valencia, Madrid", [ 3 ] ],
        [ "Interview process", "Recruiter call, technical interview, pairing session, CTO chat", [ 3 ] ],
        [ "Pay", :not_public ], [ "Relocation support", :unconfirmed ]
      ],
      market_risks: [
        [ "The HR software market in Spain is crowded, and larger competitors are moving down to small businesses.", [ 6 ] ],
        [ "Payroll errors carry legal risk, so new payroll features ship slowly.", [ 4 ] ]
      ],
      people: [
        [ "ceo", "Lucía Ferrer", "CEO and co-founder" ], [ "cofounder", "Marc Soler", "Co-founder" ],
        [ "cto", nil, "Chief Technology Officer" ], [ "em-payroll", "Elena Ruiz", "Engineering Manager, Payroll" ],
        [ "talent", "Pablo Martín", "Head of Engineering Talent" ]
      ]
    }
  ] + [
    # [slug, name, description, city, sector, size, stage, researched_at, summary, founded, work policy, core problem, stack, points, people]
    [ "tramo-logistics", "Tramo Logistics", "Route planning and fleet software for regional delivery companies.", "Zaragoza", "Logistics software", "51-200", "Series B", Date.new(2026, 9, 24),
      "Tramo Logistics builds route planning and fleet tracking software for regional delivery companies. Its customers are mostly mid-sized carriers in Spain.",
      "2019", "Hybrid, two office days", "Planning delivery routes that change during the day, without dispatchers redoing them by hand.",
      [ "Ruby on Rails", "React", "PostgreSQL", "Go" ], [ "Small team of about 25 engineers.", "Route optimisation runs as a separate Go service." ],
      [ [ "ceo", "Irene Castell", "CEO and co-founder" ], [ "cto", "Jordi Valls", "CTO and co-founder" ], [ "em", nil, "Engineering Manager" ] ] ],
    [ "pulsar-health", "Pulsar Health", "Appointment and patient messaging software for private clinics.", "Madrid", "Health tech", "51-200", "Series A", Date.new(2026, 9, 18),
      "Pulsar Health sells appointment booking and patient messaging to private clinics in Spain. It recently raised a Series A.",
      "2020", "Remote within Spain", "Cutting no-shows and phone calls for small private clinics.",
      [ "Node.js", "React", "PostgreSQL", "React Native" ], [ "About 20 engineers.", "Handles health data, so security reviews are part of every release." ],
      [ [ "ceo", "Nuria Prats", "CEO" ], [ "cto", "Álvaro Gil", "CTO" ] ] ],
    [ "vela-pay", "Vela Pay", "Invoicing and payments for freelancers.", "Barcelona", "Fintech", "51-200", "Series A", Date.new(2026, 9, 12),
      "Vela Pay offers invoicing, tax estimates and payments for freelancers in Spain.",
      "2021", "Hybrid, three office days", "Helping freelancers send invoices and stay on top of quarterly taxes.",
      [ "Ruby on Rails", "Vue.js", "PostgreSQL", "Stripe" ], [ "About 30 engineers.", "Payments run through Stripe." ],
      [ [ "ceo", "Carla Bosch", "CEO and co-founder" ], [ "cto", "Óscar Vidal", "CTO" ], [ "talent", nil, "Talent lead" ] ] ],
    [ "cosecha-data", "Cosecha Data", "Crop and weather analytics for farming cooperatives.", "Seville", "Agritech", "1-50", "Seed", Date.new(2026, 9, 5),
      "Cosecha Data turns weather and satellite data into planting and irrigation advice for farming cooperatives in Andalusia.",
      "2022", "Office-first", "Helping cooperatives decide when to plant and irrigate.",
      [ "Python", "Django", "React", "PostgreSQL" ], [ "Team of about 8 engineers.", "Most work is data pipelines in Python." ],
      [ [ "ceo", "Rocío Lozano", "CEO and co-founder" ], [ "cto", "Manuel Ortega", "CTO and co-founder" ] ] ],
    [ "rastro-market", "Rastro Market", "Marketplace for buying and selling second-hand furniture.", "Barcelona", "Marketplace", "201-1000", "Series B", Date.new(2026, 8, 28),
      "Rastro Market is a marketplace for second-hand furniture with delivery handled by partner carriers.",
      "2017", "Office-first", "Making it easy to sell bulky second-hand furniture, including delivery.",
      [ "Java", "Kotlin", "Swift", "React" ], [ "Mobile-first: most traffic comes through their apps.", "Backend is Java and Kotlin services." ],
      [ [ "ceo", "Sergi Puig", "CEO" ], [ "cto", nil, "CTO" ] ] ]
  ].map do |slug, name, description, city, sector, size, stage, researched_at, summary, founded, work_policy, core, stack, points, people|
    {
      slug: slug, name: name, description: description, city: city, country: "Spain", sector: sector, size: size, stage: stage,
      researched_at: researched_at, people_verified_at: researched_at,
      sources: [
        [ "#{name}: about the company", "accessed", researched_at ],
        [ "#{name} careers page", "accessed", researched_at ],
        [ "#{name}: funding announcement", "published", Date.new(2026, 3, 10) ]
      ],
      summary: [ summary, [ 1, 3 ] ],
      key_facts: [ [ "Founded", founded, [ 1 ] ], [ "Work policy", work_policy, [ 2 ] ], [ "Customers", :unconfirmed ] ],
      problems_core: [ core, [ 1 ] ],
      stack: stack,
      product_engineering: points.map { [ it, [ 2 ] ] },
      team_hiring: [ [ "Offices", city, [ 2 ] ], [ "Pay", :not_public ] ],
      people: people
    }
  end

  PIPELINE = [
    { slug: "faro-robotics", name: "Faro Robotics", description: "Warehouse picking robots for mid-sized retailers.", city: "Bilbao",
      country: "Spain", sector: "Robotics", size: "51-200", status: :in_review, researched_at: Date.new(2026, 10, 14) },
    { slug: "nube-legal", name: "Nube Legal", description: "Contract management for small law firms.", city: "Madrid",
      country: "Spain", sector: "Legal tech", size: "1-50", status: :researching },
    { slug: "ola-travel", name: "Ola Travel", description: "Group travel planning for companies.", city: "Málaga",
      country: "Spain", sector: "Travel", size: "51-200", status: :draft }
  ].freeze
end
