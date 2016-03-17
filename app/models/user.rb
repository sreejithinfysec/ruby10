class User < ApplicationRecord
  WHITELISTED_URI_SCHEMES = %w( http https )

  validates_presence_of :name
  validate :check_uri_scheme

  def to_xml(options={})
    if options[:builder]
      options[:builder].name name
    else
      "<name>#{name}</name>"
    end
  end

  private
    def check_uri_scheme
      begin
        uri = URI.parse(website)
        unless uri.scheme && WHITELISTED_URI_SCHEMES.include?(uri.scheme.downcase)
          errors.add :website, 'is not an allowed URI scheme'
        end
      rescue URI::InvalidURIError
        errors .add :website, 'is not a valid URI'
      end
    end
end
