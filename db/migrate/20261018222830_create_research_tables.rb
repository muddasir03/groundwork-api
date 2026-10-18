# Company research: the published reports users read. The product rules from docs/PRODUCT.md are
# enforced here as well as in the models, so bad data can't get in through any path:
# - unknown facts are explicit: a fact has a value only when it is verified;
# - links are http(s) only (no javascript: or data: URLs reaching the client);
# - statuses, sizes and sections are limited to known values.
# "Every claim cites a source" spans two tables, so the models enforce it (see Citable).
class CreateResearchTables < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :description, null: false
      t.string :city, null: false
      t.string :country, null: false
      t.string :sector, null: false
      t.string :size, null: false
      t.string :stage
      t.string :status, null: false, default: "draft"
      t.date :researched_at
      t.date :people_verified_at
      t.datetime :published_at
      t.integer :sources_count, null: false, default: 0
      t.timestamps

      t.index :slug, unique: true
      t.index [ :status, :country ]
      t.index :sector
      t.index :city
      t.check_constraint "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "companies_slug_format"
      t.check_constraint "status IN ('draft', 'researching', 'in_review', 'published')", name: "companies_status_values"
      t.check_constraint "size IN ('1-50', '51-200', '201-1000', '1000+')", name: "companies_size_values"
      t.check_constraint "status <> 'published' OR (researched_at IS NOT NULL AND published_at IS NOT NULL)",
                         name: "companies_published_needs_dates"
    end

    create_table :sources do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.string :date_kind, null: false
      t.date :date, null: false
      t.timestamps

      t.index [ :company_id, :position ], unique: true
      t.check_constraint "url ~ '^https?://'", name: "sources_url_http"
      t.check_constraint "date_kind IN ('published', 'accessed')", name: "sources_date_kind_values"
    end

    create_table :claims do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.string :section, null: false
      t.integer :position, null: false
      t.text :text, null: false
      t.timestamps

      t.index [ :company_id, :section, :position ], unique: true
      t.check_constraint "section IN ('summary', 'problems_core', 'clients', 'competitors', 'goals', 'product_engineering', 'market_risks')",
                         name: "claims_section_values"
    end

    create_table :facts do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.string :section, null: false
      t.integer :position, null: false
      t.string :label, null: false
      t.text :value
      t.string :status, null: false
      t.timestamps

      t.index [ :company_id, :section, :position ], unique: true
      t.check_constraint "section IN ('key_facts', 'team_hiring')", name: "facts_section_values"
      t.check_constraint "status IN ('verified', 'unconfirmed', 'not_public')", name: "facts_status_values"
      t.check_constraint "(status = 'verified') = (value IS NOT NULL)", name: "facts_value_only_when_verified"
    end

    create_table :problems do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :who, null: false
      t.text :problem, null: false
      t.text :solution, null: false
      t.timestamps

      t.index [ :company_id, :position ], unique: true
    end

    create_table :technologies do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :name, null: false
      t.timestamps

      t.index [ :company_id, :position ], unique: true
      t.index [ :company_id, :name ], unique: true
    end

    create_table :people do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :name # NULL means the name is not public. Never guess one.
      t.string :role, null: false
      t.string :profile_url
      t.timestamps

      t.index [ :company_id, :position ], unique: true
      t.check_constraint "profile_url IS NULL OR profile_url ~ '^https?://'", name: "people_profile_url_http"
    end

    # Which sources back which claim, fact or problem row.
    create_table :citations do |t|
      t.references :source, null: false, foreign_key: { on_delete: :cascade }
      t.references :citable, polymorphic: true, null: false
      t.timestamps

      t.index [ :source_id, :citable_type, :citable_id ], unique: true, name: "index_citations_uniqueness"
      t.check_constraint "citable_type IN ('Claim', 'Fact', 'Problem')", name: "citations_citable_type_values"
    end
  end
end
