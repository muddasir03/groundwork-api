module Api
  module V1
    module Admin
      # Research editing for admins. Sees companies in every status.
      #
      #   GET   /api/v1/admin/companies               all companies + pipeline stats
      #   POST  /api/v1/admin/companies               { company: {...} } → a new draft
      #   GET   /api/v1/admin/companies/:slug         the full report, any status
      #   PATCH /api/v1/admin/companies/:slug         { company: {...} } details (not slug or status)
      #   PUT   /api/v1/admin/companies/:slug/report  { report: {...} } replaces the whole report
      #   PATCH /api/v1/admin/companies/:slug/status  { status: "in_review" }
      class CompaniesController < BaseController
        # Request field → column. Only these can be set; anything else in the request is ignored.
        DETAIL_FIELDS = { name: :name, description: :description, city: :city, country: :country, sector: :sector,
                          size: :size, stage: :stage, researchedAt: :researched_at, peopleVerifiedAt: :people_verified_at }.freeze

        before_action :set_company, only: %i[show update replace_report update_status]

        def index
          companies = Company.order(:name, :id).to_a
          named = Person.where.not(name: nil).group(:company_id).count
          total = Person.group(:company_id).count
          render json: {
            data: companies.map { AdminCompanyRowSerializer.new(it, contacts_verified: named[it.id], contacts_total: total[it.id]).as_json },
            meta: { stats: stats }
          }
        end

        def show
          render json: { data: AdminCompanySerializer.new(@company).as_json }
        end

        def create
          attrs = detail_params.merge(slug: params.expect(company: [ :slug ])[:slug])
          company = Company.new(attrs.merge(status: :draft))
          return render_invalid(company) unless company.save

          audit!("company.create", subject: company)
          render json: { data: AdminCompanySerializer.new(Company.with_report.find(company.id)).as_json }, status: :created
        end

        def update
          return render_invalid(@company) unless @company.update(detail_params)

          audit!("company.update", subject: @company, fields: @company.saved_changes.keys - %w[updated_at])
          render json: { data: AdminCompanySerializer.new(Company.with_report.find(@company.id)).as_json }
        end

        def replace_report
          result = Research::ReplaceReport.call(company: @company, payload: report_params)
          return render_errors(result.errors) unless result.ok

          audit!("company.report_replace", subject: @company, sources: @company.sources_count)
          render json: { data: AdminCompanySerializer.new(Company.with_report.find(@company.id)).as_json }
        end

        # Not named `status`: that would override ActionController's response status method.
        def update_status
          from = @company.status
          result = Research::ChangeStatus.call(company: @company, to: params.expect(:status))
          return render_errors(result.errors) unless result.ok

          audit!("company.status_change", subject: @company, from: from, to: @company.status)
          render json: { data: AdminCompanySerializer.new(Company.with_report.find(@company.id)).as_json }
        end

        private

        def set_company
          @company = Company.with_report.find_by!(slug: params[:slug].to_s)
        end

        def detail_params
          params.expect(company: DETAIL_FIELDS.keys).to_h.transform_keys { DETAIL_FIELDS.fetch(it.to_sym) }
        end

        # The report's exact shape. Unknown keys are dropped (no mass assignment).
        def report_params
          claim = [ :text, { sourceRefs: [] } ]
          params.expect(report: [
            { sources: [ [ :ref, :title, :url, :dateKind, :date ] ] },
            { summary: claim }, { problemsCore: claim },
            { clients: [ claim ] }, { competitors: [ claim ] }, { goals: [ claim ] },
            { productEngineering: [ claim ] }, { marketRisks: [ claim ] },
            { keyFacts: [ [ :label, :status, :value, { sourceRefs: [] } ] ] },
            { teamHiring: [ [ :label, :status, :value, { sourceRefs: [] } ] ] },
            { problems: [ [ :who, :problem, :solution, { sourceRefs: [] } ] ] },
            { technologies: [] },
            { people: [ [ :name, :role, :profileUrl ] ] }
          ])
        end

        def stats
          counts = Company.group(:status).count
          { published: counts.fetch("published", 0), total: counts.values.sum, waitingForReview: counts.fetch("in_review", 0),
            verdictsCorrectPercent: nil, aiCostThisMonthUsd: nil }
        end

        def render_invalid(record)
          render_errors(record.errors.map { |error| { path: error.attribute.to_s.camelize(:lower), message: error.full_message } })
        end

        def render_errors(errors)
          render json: { error: { code: "invalid", message: "Please fix the highlighted problems.", details: errors } },
                 status: :unprocessable_content
        end
      end
    end
  end
end
