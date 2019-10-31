class User < ApplicationRecord
  def verify_user(code)
    return false unless code == verification_code

    update(verified: true, enable_sms: true)
  end
end
