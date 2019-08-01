module Nutmeg
  module Stripe
    FLASHES = {
      card_declined:          "Hmmm, looks like that card was declined 😬 If you don't think it should " \
                              "have been, you could try again. Or try another card.".freeze,

      cant_connect_to_stripe: "Hmmm, our payment provider (Stripe) dropped out on us. Do you mind trying " \
                              "again?".freeze,

      unexpected_error:       "Well, that was unexpected. Something didn't work right 😞, but we've pinged " \
                              "our team about it, and hopefully we can get things fixed soon!".freeze
    }.freeze

    def self.flash_for(key)
      FLASHES[key]
    end

    # NOTE - this needs adjustment if / when there's more than one plan
    def self.plan_id
      ENV.fetch("PLAN_ID")
    end

    def self.with_stripe_error_handling(&block)
      begin
        yield

      # docs: https://stripe.com/docs/api/errors/handling
      rescue ::Stripe::CardError,                   # card declined
             ::Stripe::RateLimitError,              # too many requests made to the api too quickly
             ::Stripe::InvalidRequestError,         # invalid parameters were supplied to Stripe's api
             ::Stripe::AuthenticationError,         # authentication with stripe's api failed
             ::Stripe::APIConnectionError,          # network communication with stripe failed
             ::Stripe::StripeError,                 # generic error
             ::ActiveRecord::ActiveRecordError => e # something broke saving our records

        Response.new(error: e).tap(&:send_through_exception_notfier)
      end
    end

    def self.font_awesome_icon_for(stripe_brand)
      # list from here: https://support.stripe.com/questions/find-the-type-of-card-a-customer-is-using
      case stripe_brand
        when "Visa"             then "cc-visa"
        when "American Express" then "cc-amex"
        when "MasterCard"       then "cc-mastercard"
        when "Discover"         then "cc-discover"
        when "JCB"              then "cc-jcb"
        when "Diners Club"      then "cc-diners-club"
        else                         "credit-card"
      end
    end

    def self.subscribe(user, stripe_token = nil, email = nil)
      with_stripe_error_handling do
        Nutmeg::Stripe::SubscriptionHandler.new(user, stripe_token, email).start
      end
    end

    def self.cancel_subscription(user)
      with_stripe_error_handling do
        Nutmeg::Stripe::SubscriptionHandler.new(user, nil, nil).cancel
      end
    end

    def self.add_card(user, stripe_token, email)
      with_stripe_error_handling do
        Nutmeg::Stripe::CardHandler.new(user, stripe_token, email).add
      end
    end

    def self.remove_card(user)
      with_stripe_error_handling do
        Nutmeg::Stripe::CardHandler.new(user, nil, nil).remove
      end
    end

    def self.sync(user)
      Nutmeg::Stripe::SyncHandler.new(user).sync
    end
  end
end
