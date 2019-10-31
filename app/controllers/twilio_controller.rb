class TwilioController < ApplicationController
  before_action :permit_params, only: :create
  before_action :authenticate_twilio_request, only: :connect
  def new
    respond_to do |format|
      format.html
    end
  end

  def create
    if TwilioManager::CallManager.call(params[:number_from], params[:number_to])
      flash[:notice] = t(:twilio_call_success, number: params[:number_from])
    else
      flash[:error] = t(:twilio_call_failed)
      # raise Twilio::REST::RestError.new
    end
    respond_to do |format|
      format.js
    end
  end

  def connect
    response = TwilioManager::CallResponseManager.call(params[:number_to])
    render(xml: response.to_s)
  end

  private

  def permit_params
    params.permit(:number_from, :number_to)
  end

  def authenticate_twilio_request
    return true if twilio_req?

    response = Twilio::TwiML::VoiceResponse.new(&:hangup)

    render xml: response.to_s, status: unauthorized
    false
  end

  def twilio_req?
    validator = Twilio::Security::RequestValidator.new(TWILIO_AUTH_TOKEN)

    post_vars = params.reject { |k, _| k.downcase == k }
    twilio_signature = request.headers['HTTP_X_TWILIO_SIGNATURE']

    validator.validate(request.url, post_vars, twilio_signature)
  end
end
