# frozen_string_literal: true
class HttpRequester

  class ResponseError < RuntimeError

    def self.new_from_response(response)
      new("#{response.status}:#{response.body}", response)
    end

    def initialize(message, response=nil)
      super(message)
      @response = response
    end

    def response_success?
      @response.success?
    end

    def response_status
      @response.status
    end

    def response_body
      @response.body
    end

    def response_headers
      @response.headers.to_h
    end

    def response_json
      response_body.presence && JSON.parse(response_body)
    rescue
      nil
    end

  end # ResponseError


  class << self

    def get(url:, **options)
      do_it(:get, url: url, **options)
    end

    def post(url:, body:, **options)
      do_it(:post, url: url, body: body, **options)
    end

    def put(url:, body:, **options)
      do_it(:put, url: url, body: body, **options)
    end

    def patch(url:, body:, **options)
      do_it(:patch, url: url, body: body, **options)
    end

    def delete(url:, **options)
      do_it(:delete, url: url, **options)
    end

    def request(http_method, url:, **options)
      do_it(http_method, url: url, **options)
    end


    def file_param(contents, content_type=nil, basename=nil)
      Faraday::UploadIO.new(StringIO.new(contents), content_type.presence || 'application/octet-stream', basename)
    end

    def file_param_pdf(pdf_param, basename=nil)
      pdf = pdf_param
      # UploadIO takes filename_or_io. Only convert non-filename Strings.
      is_data = false
      if pdf.is_a?(String)
        is_data = false
        begin
          is_data = !File.exist?(pdf) # Could raise #<ArgumentError: string contains null byte>
        rescue => _e
          is_data = true
        end
      end
      if is_data
        # Attempt base64 decoding.
        begin
          pdf = Base64.strict_decode64(pdf.delete("\n"))
        rescue => _e # rubocop:disable Lint/HandleExceptions
          # Assume it's already binary.
        end
        filename_or_io = StringIO.new(pdf)
      elsif pdf.is_a?(Pathname)
        filename_or_io = pdf.to_s
      else
        filename_or_io = pdf
      end
      Faraday::UploadIO.new(filename_or_io, 'application/pdf', basename)
    rescue => e
      dump = pdf_param.inspect.truncate(50, omission: '...')
      dump += '>' unless dump.end_with?('>')
      dump_pre = "#<#{pdf_param.class}:"
      dump = "#{dump_pre}#{dump}" unless dump.start_with?(dump_pre)
      raise RuntimeError, "Invalid argument to send as pdf: #{dump} (#{e.class}: #{e.message})", caller(2)
    end


    private

    # Keep this private for better stack trace on errors.
    def do_it(http_method, url:, **options)
      err = nil
      timing = {}
      timing[:start] = Time.now
      begin
        faraday_init = {url: url}
        faraday_init[:ssl] = {verify: false} if options[:https_allow_unverified]
        faraday_init[:request] = {timeout: options[:timeout]} if options[:timeout]
        conn = Faraday.new(faraday_init) do |faraday|
          # Request encoders are relatively safe, as they have built-in checks for suitability.
          # faraday.request(:multipart) # multipart first, takes priority over url_encoded.
          faraday.request(:url_encoded)
          # faraday.response(:logger, nil, bodies: {response: true}) if Rails.env.development?
          faraday.proxy = options[:proxy] if options[:proxy]
          faraday.adapter(Faraday.default_adapter) # must be after middlewares
          faraday.basic_auth(options[:basic_auth][:username], options[:basic_auth][:password]) if options[:basic_auth]
        end
        timing[:start] = Time.now
        response = conn.run_request(http_method, nil, options[:body], options[:headers])
      rescue => e
        err = e
      end
      timing[:end] = Time.now
      timing[:duration] = timing[:end] - timing[:start]
      log_url = options[:log_url] || url
      if err
        Rails.logger.error(http_method.to_s.upcase+" #{log_url} ERROR (#{(timing[:duration]*1000).round}ms): #{err.class}: #{err.message}")
        raise err.class, err.message, caller(2)
      else
        Rails.logger.info(http_method.to_s.upcase+" #{log_url} response (#{(timing[:duration]*1000).round}ms): #{response.status} "+response.body.inspect.truncate(350, omission: "... (#{response.body.to_s.length} total)\"")) #"
      end
      unless options[:return_failed_response] || response.success?
        err = ResponseError.new_from_response(response)
        err.set_backtrace(caller(2))
        raise err
      end
      {success: response.success?, status: response.status, body: response.body, headers: response.headers.to_h, timing: timing}
    end

  end # class << self

end
