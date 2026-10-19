module Research
  # Moves a company through the research pipeline. Only these moves are allowed:
  #
  #   draft → researching → in_review → published
  #                ↑____________|           |
  #                     (send back)         ↓
  #                              in_review ← (unpublish)
  #
  # Publishing requires a complete report (summary, core problem, at least one source, research date),
  # because the brief says every report is reviewed before it goes live.
  class ChangeStatus
    TRANSITIONS = {
      "draft" => %w[researching],
      "researching" => %w[draft in_review],
      "in_review" => %w[researching published],
      "published" => %w[in_review]
    }.freeze

    Result = Data.define(:ok, :errors)

    def self.call(...) = new(...).call

    def initialize(company:, to:)
      @company = company
      @to = to.to_s
    end

    def call
      from = @company.status
      unless TRANSITIONS.fetch(from, []).include?(@to)
        return Result.new(ok: false, errors: [ { path: "status", message: "Can't move from #{from} to #{@to}" } ])
      end

      if @to == "published"
        missing = missing_for_publishing
        return Result.new(ok: false, errors: missing.map { { path: "status", message: it } }) if missing.any?
      end

      @company.update!(status: @to, published_at: (@to == "published" ? Time.current : nil))
      Result.new(ok: true, errors: [])
    end

    private

    def missing_for_publishing
      claims = @company.claims.pluck(:section)
      [
        ("Add a summary" unless claims.include?("summary")),
        ("Add the core problem they solve" unless claims.include?("problems_core")),
        ("Add at least one source" if @company.sources.none?),
        ("Set the research date" if @company.researched_at.blank?)
      ].compact
    end
  end
end
