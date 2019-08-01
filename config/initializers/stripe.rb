# NOTE - this monkey patch 🐵 is only gonna work while there's a single endpoint
module Stripe
  class << self
    attr_accessor :webhook_secret, :public_key
  end
end

Stripe.api_key        = ENV.fetch("SECRET_API_KEY")
Stripe.public_key     = ENV.fetch("PUBLIC_API_KEY")
Stripe.webhook_secret = ENV.fetch("WEBHOOK_SECRET")
