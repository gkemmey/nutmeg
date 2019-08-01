module Nutmeg
  module Stripe
    class SubscriptionHandler
      attr_accessor :user, :stripe_token, :email,
                    # stripe objects created by helper methods we then wanna access elsewhere
                    :customer, :card


      def initialize(user, stripe_token = nil, email = nil)
        self.user      = user
        self.customer     = user.stripe_customer
        self.stripe_token = stripe_token
        self.email        = email
      end

      def start
        if they_have_no_stripe_customer_data? && they_sent_payment_info?
          create_stripe_customer_and_card
          create_stripe_subscription

        elsif they_have_no_stripe_customer_data? && !they_sent_payment_info?
          raise "this shouldn't happen, but calling out the logical 'possiblity'"

        else
          if they_sent_payment_info?
            update_stripe_customer
          end

          if they_have_subscription_data?
            update_stripe_subscription
          else
            create_stripe_subscription
          end
        end

        user.update!(user_params(for: :start))

        Nutmeg::Stripe::Response.new
      end

      def cancel
        ::Stripe::Subscription.update(user.stripe_subscription.id, cancel_at_period_end: true)
        user.update!(user_params(for: :cancel))

        Nutmeg::Stripe::Response.new
      end

      private

        def plan_id
          Nutmeg::Stripe.plan_id
        end

        def they_sent_payment_info?
          !stripe_token.nil? # stripe_token and email will be sent together, so we needn't check
        end

        def they_have_no_stripe_customer_data?
          user.stripe_customer.nil?
        end

        def they_have_subscription_data?
          !user.stripe_subscription.nil?
        end

        def create_stripe_customer_and_card
          self.customer = ::Stripe::Customer.create(email: email, source: stripe_token)
          self.card = customer.sources.retrieve(customer.default_source)
        end

        def create_stripe_subscription
          params = { items: [{ plan: plan_id }] }.tap do |p|
                                                    if user.trialing? && !user.trial_over?
                                                      p.merge! trial_end: user.trial_over_at.to_i
                                                    end
                                                  end

          customer.create_subscription(params)
        end

        def update_stripe_customer
          # i'm expecting email and stripe_token to always be set together
          ::Stripe::Customer.update(user.stripe_customer.id, email: email, source: stripe_token)

          self.customer = user.stripe_customer(reload: true)
          self.card = customer.sources.retrieve(customer.default_source)
        end

        def update_stripe_subscription
          ::Stripe::Subscription.update(user.stripe_subscription.id, cancel_at_period_end: false)
        end

        def user_params(options = {})
          if options[:for] == :start
            { billing_status: :active, stripe_customer_id: customer.id }.tap do |p|
              if they_sent_payment_info?
                p.merge!({
                  billing_email:   email,
                  card_last_four:  card.last4,
                  card_brand:      card.brand,
                  card_expires_at: Time.utc(card.exp_year, card.exp_month)
                })
              end
            end

          else
            { billing_status: :active_until_period_end }
          end
        end
    end
  end
end
