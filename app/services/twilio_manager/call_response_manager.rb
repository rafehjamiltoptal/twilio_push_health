# app/services/twilio_manager/call_manager.rb
module TwilioManager
  class CallResponseManager < ApplicationService
    attr_reader :number_to

    def initialize(number_to)
      @number_to = number_to
    end

    def call
      Twilio::TwiML::VoiceResponse.new do |r|
        r.dial(number: @number_to)
      end
    end
  end
end
