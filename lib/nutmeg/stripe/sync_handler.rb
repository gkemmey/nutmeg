module Nutmeg
  module Stripe
    class SyncHandler
      attr_accessor :user

      def initialize(user)
        self.user = user
      end

      def sync
        params = {}

        # ---- stripe_customer_id ---
        params[:stripe_customer_id] = if stripe_customer
                                        stripe_customer.id
                                      else
                                        nil
                                      end

        # ---- billing_email ----
        params[:billing_email] = if stripe_customer
                                   stripe_customer.email
                                 else
                                   nil
                                 end

        # ---- billing_status -----
        if stripe_subscription
          case stripe_subscription.status
            when "trialing", "active"
              if stripe_subscription.canceled_at
                params[:billing_status] = :active_until_period_end
              else
                params[:billing_status] = :active
              end

            when "past_due", "unpaid"
              params[:billing_status] = :past_due

            when "canceled"
              params[:billing_status] = :cancelled
          end
        else
          if user.active?
            # if it's currently active, but we don't have a stripe subscription, something's afoot
            params[:billing_status] = :cancelled
          end
        end

        # ---- card details ----
        if stripe_card
          params.merge!(card_last_four:  stripe_card.last4,
                        card_brand:      stripe_card.brand,
                        card_expires_at: Time.utc(stripe_card.exp_year, stripe_card.exp_month))
        else
          params.merge!(card_last_four:  nil,
                        card_brand:      nil,
                        card_expires_at: nil)
        end

        user.update!(params)
      end

      private

        def nil_if_bad_stripe_id(&block)
          yield
        rescue ::Stripe::InvalidRequestError => e
          raise e unless e.message.include?("No such")
          nil
        end

        def stripe_customer
          return @stripe_customer if defined?(@stripe_customer)

          @stripe_customer ||= begin
            nil_if_bad_stripe_id { user.stripe_customer }.
              then { |customer_or_nil| customer_or_nil.try(:deleted) ? nil : customer_or_nil }
          end
        end

        def stripe_subscription
          return @stripe_subscription if defined?(@stripe_subscription)
          @stripe_subscription ||= stripe_customer &&
                                     nil_if_bad_stripe_id { stripe_customer.subscriptions.data.first }
        end

        def stripe_card
          return @stripe_card if defined?(@stripe_card)
          @stripe_card ||= stripe_customer.try(:default_source) &&
                             nil_if_bad_stripe_id {
                               stripe_customer.sources.retrieve(stripe_customer.default_source)
                             }
        end
    end
  end
end
