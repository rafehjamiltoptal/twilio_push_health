class SendSmsToUserJob < ApplicationJob
  queue_as :default

  def perform(*args)
    options = args.extract_options!
    TwilioManager::SmsManager.call(options[:user_number], options[:message_body])
  end
end
