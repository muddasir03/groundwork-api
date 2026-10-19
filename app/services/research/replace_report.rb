module Research
  # Replaces a company's whole report (sources, claims, facts, problem rows, technologies, people) in
  # one transaction. Either everything saves, or nothing changes and every problem is returned with
  # its location, e.g. "report.clients[1]: Must cite at least one source".
  #
  # Claims, facts and problem rows cite sources by `ref`: the source's id for an existing source, or
  # any client-chosen key (e.g. "new-1") for a source added in the same request.
  class ReplaceReport
    LIMITS = { sources: 100, list: 30, facts: 20, people: 30, technologies: 50 }.freeze
    LIST_SECTIONS = { clients: "clients", competitors: "competitors", goals: "goals",
                      productEngineering: "product_engineering", marketRisks: "market_risks" }.freeze
    FACT_SECTIONS = { keyFacts: "key_facts", teamHiring: "team_hiring" }.freeze

    Result = Data.define(:ok, :errors)

    def self.call(...) = new(...).call

    def initialize(company:, payload:)
      @company = company
      @payload = payload.to_h.deep_symbolize_keys
      @errors = []
    end

    def call
      check_limits
      return Result.new(ok: false, errors: @errors) if @errors.any?

      ActiveRecord::Base.transaction do
        clear_report
        @sources = build_sources
        build_claim(@payload[:summary], "summary", 1, "summary")
        build_claim(@payload[:problemsCore], "problems_core", 1, "problemsCore")
        LIST_SECTIONS.each do |key, section|
          Array(@payload[key]).each_with_index { |claim, i| build_claim(claim, section, i + 1, "#{key}[#{i}]") }
        end
        FACT_SECTIONS.each do |key, section|
          Array(@payload[key]).each_with_index { |fact, i| build_fact(fact, section, i + 1, "#{key}[#{i}]") }
        end
        Array(@payload[:problems]).each_with_index { |row, i| build_problem(row, i + 1, "problems[#{i}]") }
        Array(@payload[:technologies]).each_with_index do |name, i|
          save(@company.technologies.build(position: i + 1, name: name.to_s.strip), "technologies[#{i}]")
        end
        Array(@payload[:people]).each_with_index { |person, i| build_person(person, i + 1, "people[#{i}]") }

        raise ActiveRecord::Rollback if @errors.any?
      end

      @company.reload
      Result.new(ok: @errors.empty?, errors: @errors)
    end

    private

    def check_limits
      { sources: :sources, people: :people, technologies: :technologies }.each do |key, limit|
        add_error(key.to_s, "Too many (maximum #{LIMITS[limit]})") if Array(@payload[key]).size > LIMITS[limit]
      end
      LIST_SECTIONS.each_key { |key| add_error(key.to_s, "Too many (maximum #{LIMITS[:list]})") if Array(@payload[key]).size > LIMITS[:list] }
      FACT_SECTIONS.each_key { |key| add_error(key.to_s, "Too many (maximum #{LIMITS[:facts]})") if Array(@payload[key]).size > LIMITS[:facts] }
      add_error("problems", "Too many (maximum #{LIMITS[:list]})") if Array(@payload[:problems]).size > LIMITS[:list]
    end

    def clear_report
      %i[sources claims facts problems technologies people].each { |association| @company.public_send(association).destroy_all }
    end

    def build_sources
      Array(@payload[:sources]).each_with_index.each_with_object({}) do |(attrs, i), by_ref|
        ref = attrs[:ref].to_s
        add_error("sources[#{i}].ref", "Must be unique") if ref.blank? || by_ref.key?(ref)
        source = @company.sources.build(position: i + 1, title: attrs[:title], url: attrs[:url],
                                        date_kind: attrs[:dateKind], date: attrs[:date])
        by_ref[ref] = source if save(source, "sources[#{i}]")
      end
    end

    def build_claim(attrs, section, position, path)
      return if attrs.blank?

      claim = @company.claims.build(section: section, position: position, text: attrs[:text])
      save(cite(claim, attrs[:sourceRefs], path), "report.#{path}")
    end

    def build_fact(attrs, section, position, path)
      status = attrs[:status].to_s
      value = status == "verified" ? attrs[:value] : nil # an unknown fact never keeps a value
      fact = @company.facts.build(section: section, position: position, label: attrs[:label], status: status.presence, value: value)
      save(cite(fact, attrs[:sourceRefs], path), "report.#{path}")
    end

    def build_problem(attrs, position, path)
      row = @company.problems.build(position: position, who: attrs[:who], problem: attrs[:problem], solution: attrs[:solution])
      save(cite(row, attrs[:sourceRefs], path), "report.#{path}")
    end

    def build_person(attrs, position, path)
      person = @company.people.build(position: position, name: attrs[:name].presence, role: attrs[:role],
                                     profile_url: attrs[:profileUrl].presence)
      save(person, path)
    end

    def cite(record, refs, path)
      Array(refs).map(&:to_s).uniq.each do |ref|
        source = @sources[ref]
        source ? record.citations.build(source: source) : add_error("report.#{path}.sourceRefs", "Unknown source \"#{ref.first(40)}\"")
      end
      record
    end

    def save(record, path)
      return true if record.save

      record.errors.full_messages.each { |message| add_error(path, message) }
      false
    end

    def add_error(path, message)
      @errors << { path: path, message: message }
    end
  end
end
