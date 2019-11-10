class TwilioController < ApplicationController
  before_action :permit_params, only: :create
  before_action :authenticate_twilio_request, only: :connect

  def new
    respond_to do |format|
      format.html
    end
  end

  def create
    TwilioAPI.call_number(params[:number_from], params[:number_to])
    flash[:notice] = t(:twilio_call_success, number: params[:number_from])

    respond_to do |format|
      format.js
    end
  end

  def connect
    response = TwilioAPI.call_forwarding_response(params[:number_to])
    render(xml: response.to_s)
  end

  private

  def permit_params
    params.permit(:number_from, :number_to)
  end

  def authenticate_twilio_request
    return true if TwilioAPI.twilio_req?(request, params)

    response = TwilioAPI.hangup_response

    render xml: response.to_s, status: :unauthorized
    false
  end
end
