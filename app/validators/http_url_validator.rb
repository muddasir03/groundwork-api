# Accepts only absolute http(s) URLs with a host. These URLs end up as links in the client, so
# anything else (javascript:, data:, relative paths) would be an XSS or phishing risk.
#
#   validates :url, http_url: true
class HttpUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_nil]

    uri = URI.parse(value.to_s)
    valid = uri.is_a?(URI::HTTP) && uri.host.present?
    record.errors.add(attribute, :invalid_url, message: "must be an http(s) URL") unless valid
  rescue URI::InvalidURIError
    record.errors.add(attribute, :invalid_url, message: "must be an http(s) URL")
  end
end
