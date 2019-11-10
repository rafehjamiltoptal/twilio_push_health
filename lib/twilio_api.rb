# frozen_string_literal: true
module TwilioAPI
  class RequestError < RuntimeError
    def http_error
      cause
    end

    def error_h
      http_error.response_json
    end
  end

  class CallNumberError < RequestError; end
  class SendMessageError < RequestError; end

  class << self
    def call_number(number_from, number_to)
      params = {
        'From' => ENV['TWILIO_NUMBER'],
        'To'   => number_from,
        'Url'  => call_back_url(number_to)
      }
      twilio_api(:post, 'Calls', params)
    end

    def send_message(number, message_body)
      params = {
        'From' => ENV['TWILIO_NUMBER'],
        'To'   => number,
        'Body' => message_body
      }
      twilio_api(:post, 'Messages', params)
    end

    def call_forwarding_response(number)
      '<Response>'\
      "<Dial>#{number}</Dial>"\
      '</Response>'
    end

    def twilio_req?(request, params)
      post_vars = params.reject { |k, _| k.downcase == k }
      twilio_signature = request.headers['HTTP_X_TWILIO_SIGNATURE'] || '--'

      validate(request.url, post_vars, twilio_signature)
    end

    def hangup_response
      '<Response>'\
        '<Hangup/>'\
      '</Response>'
    end

    private

    def twilio_api(http_method, path, body_h)
      url = "https://api.twilio.com/2010-04-01/Accounts/#{CGI.escape(ENV['TWILIO_ACCOUNT_SID'])}/#{path}.json"
      response = HttpRequester.request(http_method, url: url, body: body_h, basic_auth: { username: ENV['TWILIO_ACCOUNT_SID'], password: ENV['TWILIO_AUTH_TOKEN'] }, headers: {'Content-Type' => 'application/x-www-form-urlencoded'})
      json = response[:body]
      json.presence && JSON.parse(json)
    rescue HttpRequester::ResponseError => e
      backtrace = caller(3)
      resp_h = e.response_json || {}
      if e.response_status.between?(400, 499) && resp_h['status'] = e.response.status
        raise RequestError, resp_h['errors'] ? e.response_body : resp_h['detail'], backtrace
      end

      raise e, e.message, backtrace
    end

    def call_back_url(number_to)
      "#{ENV['APP_HOST']}/twilio/connect?number_to=#{number_to}"
    end

    # Following functions has been copied from Twilio Gem security/request_validator.rb file
    ##
    # Validates that after hashing a request with Twilio's request-signing algorithm
    # (https://www.twilio.com/docs/usage/security#validating-requests), the hash matches the signature parameter
    #
    # @param [String] url The url sent to your server, including any query parameters
    # @param [String, Hash, #to_unsafe_h] params In most cases, this is the POST parameters as a hash. If you received
    #   a bodySHA256 parameter in the query string, this parameter can instead be the POST body as a string to
    #   validate JSON or other text-based payloads that aren't x-www-form-urlencoded.
    # @param [String] signature The expected signature, from the X-Twilio-Signature header of the request
    #
    # @return [Boolean] whether or not the computed signature matches the signature parameter
    def validate(url, params, signature)
      params_hash = body_or_hash(params)
      if params_hash.is_a? Enumerable
        expected = build_signature_for(url, params_hash)
        secure_compare(expected, signature)
      else
        expected_signature = build_signature_for(url, {})
        body_hash = URI.decode_www_form(URI(url).query).to_h['bodySHA256']
        expected_hash = build_hash_for(params)
        secure_compare(expected_signature, signature) && secure_compare(expected_hash, body_hash)
      end
    end

    ##
    # Build a SHA1-HMAC signature for a url and parameter hash
    #
    # @param [String] url The request url, including any query parameters
    # @param [#join] params The POST parameters
    #
    # @return [String] A base64 encoded SHA1-HMAC
    def build_signature_for(url, params)
      data = url + params.sort.join
      digest = OpenSSL::Digest.new('sha1')
      Base64.strict_encode64(OpenSSL::HMAC.digest(digest, ENV['TWILIO_AUTH_TOKEN'], data))
    end

    ##
    # Build a SHA256 hash for a body string
    #
    # @param [String] body String to hash
    #
    # @return [String] A hex-encoded SHA256 of the body string
    def build_hash_for(body)
      hasher = OpenSSL::Digest.new('sha256')
      hasher.hexdigest(body)
    end

    # Compares two strings in constant time to avoid timing attacks.
    # Borrowed from ActiveSupport::MessageVerifier.
    # https://github.com/rails/rails/blob/master/activesupport/lib/active_support/message_verifier.rb
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C#{a.bytesize}")

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end

    # `ActionController::Parameters` no longer, as of Rails 5, inherits
    # from `Hash` so the `sort` method, used above in `build_signature_for`
    # is deprecated.
    #
    # `to_unsafe_h` was introduced in Rails 4.2.1, before then it is still
    # possible to sort on an ActionController::Parameters object.
    #
    # We use `to_unsafe_h` as `to_h` returns a hash of the permitted
    # parameters only and we need all the parameters to create the signature.
    def body_or_hash(params_or_body)
      if params_or_body.respond_to?(:to_unsafe_h)
        params_or_body.to_unsafe_h
      else
        params_or_body
      end
    end
  end
end
