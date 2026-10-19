require "test_helper"

class CompaniesApiTest < ActionDispatch::IntegrationTest
  setup do
    Rails.configuration.x.api_rate_limit_store.clear
    @company = create_company(slug: "brisa-people", name: "Brisa People", sector: "HR tech", city: "Valencia")
    create_company(slug: "vela-pay", name: "Vela Pay", sector: "Fintech", city: "Barcelona", size: "1-50")
    create_company(slug: "secret-co", status: :in_review)
    create_company(slug: "draft-co", status: :draft)
  end

  test "lists only published companies, with pagination metadata" do
    get api_v1_companies_path
    assert_response :ok
    assert_equal %w[brisa-people vela-pay], json["data"].pluck("slug")
    assert_equal({ "page" => 1, "perPage" => 20, "total" => 2 }, json["meta"])
  end

  test "summaries have exactly the contract's fields, and no personal fit" do
    get api_v1_companies_path
    assert_equal %w[city country description name researchedAt sector size slug sourceCount stage], json["data"].first.keys.sort
    assert_equal "2026-09-30", json["data"].first["researchedAt"]
    assert_equal 2, json["data"].first["sourceCount"]
  end

  test "filters by sector, city and size" do
    get api_v1_companies_path, params: { sector: "Fintech" }
    assert_equal %w[vela-pay], json["data"].pluck("slug")

    get api_v1_companies_path, params: { city: "Valencia", size: "51-200" }
    assert_equal %w[brisa-people], json["data"].pluck("slug")

    get api_v1_companies_path, params: { country: "Germany" }
    assert_empty json["data"]
  end

  test "caps the page size and ignores nonsense paging values" do
    get api_v1_companies_path, params: { per_page: 10_000, page: -3 }
    assert_equal 50, json["meta"]["perPage"]
    assert_equal 1, json["meta"]["page"]

    get api_v1_companies_path, params: { per_page: 1, page: 2 }
    assert_equal %w[vela-pay], json["data"].pluck("slug")
  end

  test "shows a published company's full report in the client's contract shape" do
    get api_v1_company_path("brisa-people")
    assert_response :ok
    company = json["data"]

    assert_equal %w[city country description name people peopleVerifiedAt report researchedAt sector size slug sourceCount sources stage],
                 company.keys.sort
    assert_equal %w[clients competitors goals keyFacts marketRisks problems productEngineering summary teamHiring], company["report"].keys.sort
    assert_equal({ "text" => "What they do.", "sourceIds" => [ @company.sources.first.id.to_s ] }, company["report"]["summary"])
    assert_equal %w[date dateKind id title url], company["sources"].first.keys.sort
  end

  test "every cited source id points to a source in the same response" do
    get api_v1_company_path("brisa-people")
    report = json["data"]["report"]
    source_ids = json["data"]["sources"].pluck("id")
    cited = [ report["summary"], report["problems"]["core"], *report["clients"], *report["keyFacts"], *report["teamHiring"], *report["problems"]["rows"] ]
      .flat_map { it["sourceIds"] }
    assert cited.any?
    assert (cited - source_ids).empty?, "unknown source ids: #{cited - source_ids}"
  end

  test "unknown facts and private names come through as explicit nulls" do
    get api_v1_company_path("brisa-people")
    pay = json["data"]["report"]["teamHiring"].find { it["label"] == "Pay" }
    assert_equal({ "label" => "Pay", "value" => nil, "status" => "not_public", "sourceIds" => [] }, pay)
    cto = json["data"]["people"].find { it["role"] == "CTO" }
    assert_nil cto["name"]
    assert_nil cto["profileUrl"]
  end

  test "unpublished and missing companies give the same 404, so the pipeline can't be probed" do
    get api_v1_company_path("secret-co")
    assert_response :not_found
    unpublished = response.body

    get api_v1_company_path("no-such-co")
    assert_response :not_found
    assert_equal unpublished, response.body
    assert_equal({ "error" => { "code" => "not_found", "message" => "Not found" } }, json)
  end

  test "rejects malformed slugs at the router" do
    get "/api/v1/companies/Bad%20Slug"
    assert_response :not_found
  end

  test "loads a report in a fixed number of queries, however big it is" do
    get api_v1_company_path("brisa-people") # warm up schema and connection queries
    small = count_queries { get api_v1_company_path("brisa-people") }

    5.times { |i| add_report_rows(@company, i) }
    large = count_queries { get api_v1_company_path("brisa-people") }
    assert_equal small, large, "queries grew with report size (N+1)"
    assert_operator small, :<=, 10
  end

  test "rate limits each client" do
    Rails.configuration.x.api_rate_limit.times { get api_v1_companies_path }
    assert_response :ok
    get api_v1_companies_path
    assert_response :too_many_requests
    assert_equal "rate_limited", json["error"]["code"]
  end

  private

  def json = response.parsed_body

  def count_queries(&block)
    count = 0
    # Count cached queries too: in tests the query cache can carry over between requests.
    counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def add_report_rows(company, index)
    source = create_source(company, 10 + index)
    build_cited(company.claims.build(section: "goals", position: 10 + index, text: "Goal #{index}"), source).save!
    build_cited(company.facts.build(section: "key_facts", position: 10 + index, label: "Fact #{index}", value: "v", status: :verified), source).save!
    build_cited(company.problems.build(position: 10 + index, who: "W", problem: "P", solution: "S"), source).save!
    company.people.create!(position: 10 + index, name: "Person #{index}", role: "Engineer")
  end
end
