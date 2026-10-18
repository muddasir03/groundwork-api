# Be sure to restart your server when you modify this file.

# Allow the groundwork-client frontend to call this API from the browser.
# Set CORS_ORIGINS to a comma-separated list of origins in each environment;
# defaults to the Next.js dev server.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
