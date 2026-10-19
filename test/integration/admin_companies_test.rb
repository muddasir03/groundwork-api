require "test_helper"

class AdminCompaniesTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    clear_rate_limits
    @headers = admin_headers
    @company = create_company(slug: "brisa-people", name: "Brisa People")
    @draft = create_company(slug: "draft-co", status: :draft)
  end

  test "every admin endpoint except login requires a session" do
    admin_routes = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/api/v1/admin") }
    assert_operator admin_routes.size, :>=, 8

    admin_routes.each do |route|
      verb = route.verb.downcase
      path = route.path.spec.to_s.sub("(.:format)", "").sub(":slug", "brisa-people")
      next if verb == "post" && path == "/api/v1/admin/session"

      # JSON bodies only for writes: `as: :json` on a GET makes the test client send a different request.
      verb == "get" ? get(path) : public_send(verb, path, params: {}, as: :json)
      assert_response :unauthorized, "#{verb.upcase} #{path} answered without a session"
    end
  end

  test "lists companies in every status, with pipeline stats" do
    get api_v1_admin_companies_path, headers: @headers
    assert_response :ok
    assert_equal %w[brisa-people draft-co], json["data"].pluck("slug")
    assert_equal %w[contactsTotal contactsVerified lastResearchedAt name slug sourceCount status], json["data"].first.keys.sort
    assert_equal({ "published" => 1, "total" => 2, "waitingForReview" => 0, "verdictsCorrectPercent" => nil, "aiCostThisMonthUsd" => nil },
                 json.dig("meta", "stats"))
  end

  test "shows an unpublished company to admins only" do
    get api_v1_admin_company_path("draft-co"), headers: @headers
    assert_response :ok
    assert_equal "draft", json.dig("data", "status")

    get api_v1_company_path("draft-co")
    assert_response :not_found
  end

  test "creates a draft, ignoring any attempt to set its status" do
    post api_v1_admin_companies_path, headers: @headers, as: :json, params: {
      company: { slug: "new-co", name: "New Co", description: "Something.", city: "Madrid", country: "Spain",
                 sector: "SaaS", size: "1-50", status: "published", publishedAt: "2026-01-01" }
    }
    assert_response :created
    assert_equal "draft", Company.find_by!(slug: "new-co").status
    assert_equal "company.create", AuditEvent.last.action
  end

  test "rejects an invalid company with every problem listed" do
    post api_v1_admin_companies_path, headers: @headers, as: :json, params: { company: { slug: "Bad Slug", name: "", size: "huge" } }
    assert_response :unprocessable_content
    paths = json.dig("error", "details").pluck("path")
    assert_includes paths, "slug"
    assert_includes paths, "name"
    assert_includes paths, "size"
  end

  test "updates details but never the slug or status" do
    patch api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json,
          params: { company: { name: "Brisa People S.L.", slug: "hijacked", status: "draft" } }
    assert_response :ok
    @company.reload
    assert_equal [ "Brisa People S.L.", "brisa-people", "published" ], [ @company.name, @company.slug, @company.status ]
    assert_equal [ "name" ], AuditEvent.last.details["fields"]
  end

  test "replaces the whole report, citing new sources by ref" do
    put report_api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json, params: { report: valid_report }
    assert_response :ok

    @company.reload
    assert_equal 2, @company.sources_count
    summary = @company.claims.find_by!(section: "summary")
    assert_equal [ "Announcement" ], summary.sources.map(&:title)
    assert_equal [ "Ruby on Rails", "React" ], @company.technologies.map(&:name)
    assert_nil @company.people.find_by!(role: "CTO").name
    assert_equal "company.report_replace", AuditEvent.last.action
  end

  test "an unknown fact never keeps a submitted value" do
    report = valid_report.merge(teamHiring: [ { label: "Pay", status: "not_public", value: "€60k (guess)", sourceRefs: [] } ])
    put report_api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json, params: { report: report }
    assert_response :ok
    assert_nil @company.facts.find_by!(label: "Pay").value
  end

  test "an invalid report changes nothing and lists every problem" do
    before = @company.claims.pluck(:text).sort
    report = valid_report.merge(
      sources: [ { ref: "s1", title: "Bad link", url: "javascript:alert(1)", dateKind: "accessed", date: "2026-09-30" } ],
      clients: [ { text: "Uncited claim", sourceRefs: [] } ],
      goals: [ { text: "Cites a ghost", sourceRefs: [ "nope" ] } ]
    )
    put report_api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json, params: { report: report }
    assert_response :unprocessable_content

    paths = json.dig("error", "details").pluck("path")
    assert_includes paths, "sources[0]"
    assert_includes paths, "report.clients[0]"
    assert_includes paths, "report.goals[0].sourceRefs"
    assert_equal before, @company.reload.claims.pluck(:text).sort, "a failed save must not change the report"
    assert_not_equal "company.report_replace", AuditEvent.last&.action
  end

  test "refuses oversized reports" do
    sources = Array.new(101) { |i| { ref: "s#{i}", title: "S", url: "https://example.com/#{i}", dateKind: "accessed", date: "2026-09-30" } }
    put report_api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json, params: { report: { sources: sources } }
    assert_response :unprocessable_content
    assert_equal "sources", json.dig("error", "details", 0, "path")
  end

  test "status moves only along the pipeline" do
    patch status_api_v1_admin_company_path("draft-co"), headers: @headers, as: :json, params: { status: "published" }
    assert_response :unprocessable_content
    assert_equal "Can't move from draft to published", json.dig("error", "details", 0, "message")
  end

  test "publishing needs a complete report, and makes the company public" do
    empty = create_company(slug: "empty-co", status: :in_review)
    empty.claims.destroy_all
    patch status_api_v1_admin_company_path("empty-co"), headers: @headers, as: :json, params: { status: "published" }
    assert_response :unprocessable_content
    assert_includes json.dig("error", "details").pluck("message"), "Add a summary"

    ready = create_company(slug: "ready-co", status: :in_review)
    patch status_api_v1_admin_company_path("ready-co"), headers: @headers, as: :json, params: { status: "published" }
    assert_response :ok
    assert_not_nil ready.reload.published_at
    assert_equal({ "from" => "in_review", "to" => "published" }, AuditEvent.last.details)

    get api_v1_company_path("ready-co")
    assert_response :ok
  end

  test "unpublishing hides the company from the public API" do
    patch status_api_v1_admin_company_path("brisa-people"), headers: @headers, as: :json, params: { status: "in_review" }
    assert_response :ok
    assert_nil @company.reload.published_at
    get api_v1_company_path("brisa-people")
    assert_response :not_found
  end

  private

  def json = response.parsed_body

  def valid_report
    {
      sources: [
        { ref: "s1", title: "Announcement", url: "https://example.com/a", dateKind: "published", date: "2026-06-12" },
        { ref: "s2", title: "Careers", url: "https://example.com/b", dateKind: "accessed", date: "2026-09-30" }
      ],
      summary: { text: "What they do.", sourceRefs: [ "s1" ] },
      problemsCore: { text: "The core problem.", sourceRefs: [ "s2" ] },
      clients: [ { text: "Small businesses.", sourceRefs: [ "s1", "s2" ] } ],
      keyFacts: [ { label: "Founded", status: "verified", value: "2018", sourceRefs: [ "s1" ] } ],
      problems: [ { who: "HR", problem: "Scattered data", solution: "One system", sourceRefs: [ "s2" ] } ],
      technologies: [ "Ruby on Rails", "React" ],
      people: [ { name: "Alex Example", role: "CEO", profileUrl: "https://example.com/alex" }, { name: "", role: "CTO", profileUrl: "" } ]
    }
  end
end
