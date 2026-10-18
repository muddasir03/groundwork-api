# Seeds FICTIONAL sample research, matching the client's sample data (groundwork-client
# lib/api/sampleData.ts). Every company, person and source is invented; links point to example.com.
#
# Safe to run repeatedly: each company is rebuilt from scratch.
# Refuses to run in production-mode environments unless SEED_SAMPLE_DATA=true (set on staging only),
# so fictional data can never reach the production database by accident.

if Rails.env.production? && ENV["SEED_SAMPLE_DATA"] != "true"
  puts "Skipping sample data: set SEED_SAMPLE_DATA=true to seed a production-mode environment (staging only)."
  return
end

require_relative "seeds/sample_research"

SampleResearch.seed!
puts "Seeded #{Company.count} sample companies (#{Company.published.count} published)."
