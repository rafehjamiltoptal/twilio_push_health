module VerificationCodeGenerator
  def generate_code(length)
    length += 2
    rand.to_s[2..length]
  end
end
