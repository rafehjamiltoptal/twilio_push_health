# App/Controllers/TwilioSmsController
class TwilioSmsController < ApplicationController
  include VerificationCodeGenerator
  before_action :set_user

  def new
    respond_to do |format|
      format.html
    end
  end

  def create
    verification_code = generate_code(DEFAULT_VERIFICATION_CODE_LENGTH)
    message_body      = "Your verification code is #{verification_code}"

    TwilioAPI.send_message(params[:user_number], message_body)
    @user.update(verification_code: verification_code, phone_number: params[:user_number])
    flash[:notice] = t(:twilio_sms_sent, number: params[:user_number])

    respond_to do |format|
      format.js
    end
  end

  def verify_code
    if @user.verify_user(params[:verification_code])
      flash[:notice] = t(:twilio_user_verified)
    else
      flash[:error] = t(:twilio_verification_failed)
    end
    respond_to do |format|
      format.js
    end
  end

  private

  def user_params
    params.permit(:verification_code, :phone_number)
  end

  def set_user
    @user = User.all.first
  end
end
