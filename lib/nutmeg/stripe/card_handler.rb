module Nutmeg
  module Stripe
    class CardHandler
      attr_accessor :user, :stripe_token, :email,
                    # stripe objects created by helper methods we then wanna access elsewhere
                    :customer, :card


      def initialize(user, stripe_token = nil, email = nil)
        self.user      = user
        self.customer     = user.stripe_customer
        self.stripe_token = stripe_token
        self.email        = email
      end

      def add
        they_have_no_stripe_customer_data? ? create_stripe_customer_and_card : update_stripe_customer

        user.update!(user_params(for: :add))
        Nutmeg::Stripe::Response.new
      end

      def remove
        customer.sources.retrieve(customer.default_source).delete

        user.update!(user_params(for: :remove))
        Nutmeg::Stripe::Response.new
      end

      private

        def they_have_no_stripe_customer_data?
          user.stripe_customer.nil?
        end

        def create_stripe_customer_and_card
          self.customer = ::Stripe::Customer.create(email: email, source: stripe_token)
          self.card = customer.sources.retrieve(customer.default_source)
        end

        def update_stripe_customer
          ::Stripe::Customer.update(user.stripe_customer.id, email: email, source: stripe_token)

          self.customer = user.stripe_customer(reload: true)
          self.card = customer.sources.retrieve(customer.default_source)
        end

        def user_params(options = {})
          if options[:for] == :add
            {
              billing_email:   email,
              card_last_four:  card.last4,
              card_brand:      card.brand,
              card_expires_at: Time.utc(card.exp_year, card.exp_month)
            }.tap do |update_params|
              update_params.merge!(stripe_customer_id: customer.id) if they_have_no_stripe_customer_data?
            end
          else
            {
              card_last_four:  nil,
              card_brand:      nil,
              card_expires_at: nil
            }
          end
        end
    end
  end
end
