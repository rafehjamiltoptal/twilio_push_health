APP_NAME = 'Twilio Project'.freeze
TWILIO_ACCOUNT_SID = if Rails.env.production?
                       'ACf559f7f04e38c3fa3ea80c713763d469'.freeze
                     elsif Rails.env.staging?
                       'ACf559f7f04e38c3fa3ea80c713763d469'.freeze
                     else
                       'ACf559f7f04e38c3fa3ea80c713763d469'.freeze
                     end

TWILIO_AUTH_TOKEN = if Rails.env.production?
                      'f8f4a1084eb7f3a8891a62c7ce78f489'.freeze
                    elsif Rails.env.staging?
                      'f8f4a1084eb7f3a8891a62c7ce78f489'.freeze
                    else
                      'f8f4a1084eb7f3a8891a62c7ce78f489'.freeze
                    end
