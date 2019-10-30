# app/services/twilio_manager/call_manager.rb
module TwilioManager
  class CallManager < ApplicationService
    attr_reader :number_from, :number_to

    def initialize(number_from, number_to)
      @number_from = number_from
      @number_to   = number_to
    end

    def call
      begin
        @client = Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        @call = @client.calls.create(
                  to:   @number_from,
                  from: TWILIO_NUMBER,
                  url: "#{API_HOST}/twilio/connect?number_to=#{@number_to}" # Fetch instructions from this URL when the call connects
                )
        true
      rescue Twilio::REST::RestError => e
        logger.log(e.message)
        false
      end
    end
  end
end
