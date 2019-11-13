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
      # for testing
      # {"answered_by": null, "price_unit": "USD", "parent_call_sid": null, "caller_name": null, "group_sid": null, "duration": null, "from": "+12052368178", "to": "+923015182390", "annotation": null, "date_updated": null, "sid": "CAa8a44a42dd7c07f8b629e12bc16ee46d", "price": null, "api_version": "2010-04-01", "status": "queued", "direction": "outbound-api", "start_time": null, "date_created": null, "from_formatted": "(205) 236-8178", "forwarded_from": null, "uri": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Calls/CAa8a44a42dd7c07f8b629e12bc16ee46d.json", "account_sid": "ACf559f7f04e38c3fa3ea80c713763d469", "end_time": null, "to_formatted": "+923015182390", "phone_number_sid": "PNb46a5c5da73a699bb038509074c891cf", "subresource_uris": {"notifications": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Calls/CAa8a44a42dd7c07f8b629e12bc16ee46d/Notifications.json", "recordings": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Calls/CAa8a44a42dd7c07f8b629e12bc16ee46d/Recordings.json", "feedback": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Calls/CAa8a44a42dd7c07f8b629e12bc16ee46d/Feedback.json", "feedback_summaries": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Calls/FeedbackSummary.json"}}
      twilio_api(:post, 'Calls', params)
    end

    def send_message(number, message_body)
      params = {
        'From' => ENV['TWILIO_NUMBER'],
        'To'   => number,
        'Body' => message_body
      }
      # for testing
      # {"sid": "SM9905a2f7f8c840dea4dfe7d71e8714b1", "date_created": "Tue, 12 Nov 2019 19:21:04 +0000", "date_updated": "Tue, 12 Nov 2019 19:21:04 +0000", "date_sent": null, "account_sid": "ACf559f7f04e38c3fa3ea80c713763d469", "to": "+923015182390", "from": "+12052368178", "messaging_service_sid": null, "body": "Sent from your Twilio trial account - 123123", "status": "queued", "num_segments": "1", "num_media": "0", "direction": "outbound-api", "api_version": "2010-04-01", "price": null, "price_unit": "USD", "error_code": null, "error_message": null, "uri": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Messages/SM9905a2f7f8c840dea4dfe7d71e8714b1.json", "subresource_uris": {"media": "/2010-04-01/Accounts/ACf559f7f04e38c3fa3ea80c713763d469/Messages/SM9905a2f7f8c840dea4dfe7d71e8714b1/Media.json"}}
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

    # Following functions have been copied from Twilio Gem security/request_validator.rb file
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
      params_hash = params.to_unsafe_h
      expected = build_signature_for(url, params_hash)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
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
  end
end
