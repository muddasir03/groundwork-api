require "test_helper"

# The product brief's research rules, enforced by models and, where possible, by the database too
# (so they hold even if a validation is skipped).
class ResearchRulesTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @source = @company.sources.first
  end

  test "a claim must cite at least one source" do
    claim = @company.claims.build(section: "goals", position: 1, text: "Expand to Portugal.")
    assert_not claim.valid?
    assert_includes claim.errors[:base], "must cite at least one source"
  end

  test "a claim can't cite another company's source" do
    other = create_company(slug: "other-co")
    claim = build_cited(@company.claims.build(section: "goals", position: 1, text: "Expand."), other.sources.first)
    assert_not claim.valid?
    assert_includes claim.errors[:base], "can only cite sources from the same company"
  end

  test "a verified fact needs a value and a source" do
    fact = @company.facts.build(section: "key_facts", position: 9, label: "Employees", status: :verified)
    assert_not fact.valid?
    assert fact.errors[:value].any?
    assert_includes fact.errors[:base], "must cite at least one source"
  end

  test "an unknown fact has no value and needs no source" do
    assert @company.facts.build(section: "key_facts", position: 9, label: "Pay", status: :not_public).valid?

    guessed = @company.facts.build(section: "key_facts", position: 9, label: "Pay", status: :unconfirmed, value: "About 50k")
    assert_not guessed.valid?
    assert_includes guessed.errors[:value], "must be empty unless the fact is verified"
  end

  test "the database refuses a value on an unknown fact even without validations" do
    fact = @company.facts.find_by!(status: "not_public")
    assert_check_violation { fact.update_column(:value, "A guess") }
  end

  test "links must be http(s) URLs" do
    [ "javascript:alert(1)", "data:text/html,<script>alert(1)</script>", "/relative", "ftp://example.com/x", "https://" ].each do |url|
      assert_not Source.new(company: @company, position: 9, title: "x", url: url, date_kind: "accessed", date: Date.today).valid?, url
      assert_not Person.new(company: @company, position: 9, role: "CEO", profile_url: url).valid?, url
    end
    assert Person.new(company: @company, position: 9, role: "CEO", profile_url: nil).valid?
  end

  test "the database refuses non-http links even without validations" do
    assert_check_violation { @source.update_column(:url, "javascript:alert(1)") }
    assert_check_violation { @company.people.first.update_column(:profile_url, "javascript:alert(1)") }
  end

  test "a published company needs research and publication dates" do
    company = Company.new(slug: "new-co", name: "New", description: "x", city: "x", country: "Spain", sector: "x",
                          size: "1-50", status: :published)
    assert_not company.valid?
    assert company.errors[:researched_at].any?
    assert company.errors[:published_at].any?
  end

  test "slugs, sizes and statuses are limited to known values" do
    assert_not Company.new(slug: "Bad Slug!").tap(&:valid?).errors[:slug].empty?
    assert_check_violation { @company.update_column(:size, "huge") }
    assert_check_violation { @company.update_column(:status, "secret") }
    assert_check_violation { @company.update_column(:slug, "../etc") }
  end

  test "sources_count tracks the company's sources" do
    assert_equal 2, @company.reload.sources_count
  end

  test "deleting a company removes all of its research" do
    @company.destroy!
    assert_equal 0, Source.where(company_id: @company.id).count
    assert_equal 0, Citation.count
    assert_equal 0, Person.where(company_id: @company.id).count
  end

  private

  # Each violation gets its own savepoint: after a failed statement PostgreSQL aborts the enclosing
  # transaction, which would break the next check in the same test.
  def assert_check_violation(&block)
    assert_raises(ActiveRecord::CheckViolation) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end
end
