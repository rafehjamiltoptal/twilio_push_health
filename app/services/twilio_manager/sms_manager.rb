# app/services/twilio_manager/sms_manager.rb
module TwilioManager
  class SmsManager < ApplicationService
    attr_reader :number, :message_body

    def initialize(number, message_body)
      @number       = number
      @message_body = message_body
    end

    def call
      begin
        @client = Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        @call = @client.messages.create(
                  to:   @number,
                  from: TWILIO_NUMBER,
                  body: message_body
                )
        true
      rescue Twilio::REST::RestError => e
        logger.log(e.message)
        false
      end
    end
  end
end