module Api
  module V1
    # Public, read-only company research. Only published companies exist as far as this controller
    # is concerned: an unpublished company returns the same 404 as one that doesn't exist, so the
    # research pipeline can't be probed from outside.
    class CompaniesController < BaseController
      FILTERS = %i[country sector city size].freeze

      # GET /api/v1/companies?country=Spain&sector=…&city=…&size=51-200&page=1&per_page=20
      def index
        companies = FILTERS.reduce(Company.published) do |scope, filter|
          value = params[filter].presence
          value ? scope.where(filter => value.to_s) : scope
        end
        page = pagination
        total = companies.count
        records = companies.order(:name, :id).limit(page[:per_page]).offset(page[:offset])

        render json: {
          data: records.map { |company| CompanySummarySerializer.new(company).as_json },
          meta: { page: page[:page], perPage: page[:per_page], total: total }
        }
      end

      # GET /api/v1/companies/:slug
      def show
        company = Company.published.with_report.find_by!(slug: params[:slug].to_s)
        render json: { data: CompanySerializer.new(company).as_json }
      end
    end
  end
end
