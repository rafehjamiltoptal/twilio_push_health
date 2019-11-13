require 'rails_helper'
include VerificationCodeGenerator

describe 'TwilioApiTest' do
  context 'Twilio Call Test' do
    before do
      @response = TwilioAPI.call_number('+923015182390', '+923008887703')
    end

    it 'calls number successfully' do
      expect(@response['from']).to eq(ENV['TWILIO_NUMBER'])
      expect(@response['to']).to eq('+923015182390')
    end
  end

  context 'Twilio SMS test' do
    before do
      verification_code = generate_code(DEFAULT_VERIFICATION_CODE_LENGTH)
      @message_body      = "Your verification code is #{verification_code}"
      @response         = TwilioAPI.send_message('+923015182390', @message_body)
    end

    it 'should send sms with verification code' do
      expect(@response['from']).to eq(ENV['TWILIO_NUMBER'])
      expect(@response['to']).to eq('+923015182390')
      expect(@response['body']).to eq(@message_body)
    end
  end
end
