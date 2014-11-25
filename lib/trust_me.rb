require "trust_me/version"
require "json"
require "uri"
require "net/http"
require "base64"
require "openssl"

class TrustMe
  # Public: URL to the TeleSign REST API.
  #
  # Returns a URI::HTTPS instance.
  API_URL = URI.parse("https://rest.telesign.com")

  # Public: Gets/sets configuration info to connect to the TeleSign API.
  #
  # Example
  #
  #   TrustMe.config do |c|
  #     c.customer_id = "1234"
  #     c.secret_key  = "secret"
  #   end
  #
  # Returns a Struct.
  def self.config
    @config ||= Struct.new(:customer_id, :secret_key).new
    yield @config if block_given?
    @config
  end

  # Public: Creates a new TrustMe instance.
  #
  # customer_id - TeleSign customer ID
  # secret_key  - TeleSign secret key
  #
  # Raises RuntimeError if credentials aren't setup.
  #
  # Returns nothing.
  def initialize(customer_id = nil, secret_key = nil)
    @customer_id = customer_id || self.class.config.customer_id
    @secret_key  = secret_key  || self.class.config.secret_key

    unless @customer_id && @secret_key
      raise "You must supply API credentials. Try `TrustMe.new " \
        '"customer_id", "secret_key"` or `TrustMe.config`'
    end
  end

  # Public: Send a verification call to the given phone number.
  #
  # number  - The phone number to call
  # options - Hash of options
  #           :verify_code - Code to send the user, if not supplied a 5-digit
  #                          code is automatically generated
  #           :language    - Language to use on the call, defaults to "en-US"
  #           :ucid        - Use case ID, defaults to "TRVF"
  #                          (Transaction Verification)
  #
  # See: http://docs.telesign.com/rest/content/verify-call.html#index-5
  #
  # Returns a Hash.
  def send_verification_call!(number, options = {})
    verify_code = options.fetch(:verify_code, generate_code)

    output = api_request(
      :resource => "/v1/verify/call",
      :params   => encode_hash(
        :ucid         => options.fetch(:ucid, "TRVF"),
        :phone_number => number,
        :language     => options.fetch(:language, "en-US"),
        :verify_code  => verify_code
      )
    )

    { :data => output, :code => verify_code }
  end

  # Public: Send a verification SMS to the given phone number.
  #
  # number  - The phone number to message
  # options - Hash of options
  #           :verify_code - Code to send the user, if not supplied a 5-digit
  #                          code is automatically generated
  #           :language    - Language to use on the call, defaults to "en-US"
  #           :ucid        - Use case ID, defaults to "TRVF"
  #                          (Transaction Verification)
  #           :template    - Optional text template, must include "$$CODE$$"
  #
  # See: http://docs.telesign.com/rest/content/verify-sms.html#index-5
  #
  # Returns a Hash.
  def send_verification_sms!(number, options = {})
    verify_code = options.fetch(:verify_code, generate_code)

    output = api_request(
      :resource => "/v1/verify/sms",
      :params   => encode_hash(
        :ucid         => options.fetch(:ucid, "TRVF"),
        :phone_number => number,
        :language     => options.fetch(:language, "en-US"),
        :verify_code  => verify_code,
        :template     => options[:template]
      )
    )

    { :data => output, :code => verify_code }
  end

  # Public: Generates headers used to authenticate with the API.
  #
  # options - Hash of options
  #           :resource - API resource (required)
  #           :params   - Params to send (required)
  #
  # Raises KeyError if any required keys are missing.
  #
  # See: http://docs.telesign.com/rest/content/rest-auth.html
  #
  # Returns a Hash.
  def generate_headers(options = {})
    content_type = "application/x-www-form-urlencoded"
    date         = Time.now.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
    nonce        = `uuidgen`.chomp

    content = [
      "POST",
      content_type,
      "", # Blank spot for "Date" header, which is overridden by x-ts-date
      "x-ts-auth-method:HMAC-SHA256",
      "x-ts-date:#{date}",
      "x-ts-nonce:#{nonce}",
      options.fetch(:params),
      options.fetch(:resource)
    ].join("\n")

    hash   = OpenSSL::Digest::SHA256.new rand.to_s
    key    = Base64.decode64(@secret_key)
    digest = OpenSSL::HMAC.digest(hash, key, content)
    auth   = Base64.encode64(digest)

    {
      "Authorization"    => "TSA #{@customer_id}:#{auth}",
      "Content-Type"     => content_type,
      "x-ts-date"        => date,
      "x-ts-auth-method" => "HMAC-SHA256",
      "x-ts-nonce"       => nonce
    }
  end

  private

  # Private: Generates a random 5 digit code.
  #
  # Returns a String.
  def generate_code
    (0..4).map { (48 + rand(10)).chr }.join
  end

  # Private: URL-encodes a hash to a string for submission via HTTP.
  #
  # hash - A Hash to encode
  #
  # Returns a String.
  def encode_hash(hash)
    URI.encode_www_form hash
  end

  # Private: CA certificate file to verify SSL connection with `API_URL`
  #
  # Returns an OpenSSL::X509::Certificate instance.
  def cacert
    @cacert ||= OpenSSL::X509::Certificate.new \
      File.read(File.expand_path("../../vendor/cacert.pem", __FILE__))
  end

  # Private: Parse the given JSON string.
  #
  # string - Raw JSON string
  #
  # Returns a Hash.
  def parse_json(string)
    JSON.parse string
  end

  # Private: Submits an API request via POST.
  #
  # options - Hash of options
  #           :resource - API resource (required)
  #           :params   - Params to send (required)
  #
  # Raises KeyError if any required keys are missing.
  # Raises a Net::HTTP exception if the request is not successful.
  #
  # Returns a Hash.
  def api_request(options = {})
    http         = Net::HTTP.new(API_URL.host, API_URL.port)
    http.use_ssl = API_URL.scheme == "https"

    if http.use_ssl?
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store  = OpenSSL::X509::Store.new
      http.cert_store.add_cert cacert
    end

    headers  = generate_headers(options)
    body     = options.fetch(:params)
    resource = options.fetch(:resource)
    response = http.request_post resource, body, headers
    output   = parse_json(response.body)

    if response.is_a? Net::HTTPSuccess
      output
    else
      raise response.error_type.new(
        "#{response.code} #{response.message.dump}\n" \
        "Response body: #{output.inspect}",
        response
      )
    end
  end
end
