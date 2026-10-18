# Be sure to restart your server when you modify this file.

# Allow the groundwork-client frontend to call this API from the browser.
# Set CORS_ORIGINS to a comma-separated list of origins in each environment;
# defaults to the Next.js dev server. A "*" matches any characters, which covers
# per-PR preview URLs, e.g. https://groundwork-client-*-muddasir03s-projects.vercel.app

# Read more: https://github.com/cyu/rack-cors

cors_origins = ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",").map(&:strip).map do |origin|
  origin.include?("*") ? /\A#{Regexp.escape(origin).gsub('\*', '[^.]*')}\z/ : origin
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_origins)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
