class User < ApplicationRecord
  enum billing_status: {
    trialing:                0,
    active:                  1,
    active_until_period_end: 2,
    cancelled:               3,
    past_due:                4
  }

  def trial_over?
    trialing? && Time.current > trial_over_at
  end

  def stripe_customer(reload: false)
    return nil unless stripe_customer_id
    return @stripe_customer if defined?(@stripe_customer) && !reload
    @stripe_customer = nil if reload

    @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
  end

  def stripe_subscription(reload: false)
    return nil unless stripe_customer(reload: reload)
    return @stripe_subscription if defined?(@stripe_subscription) && !reload
    @stripe_subscription = nil if reload

    @stripe_subscription ||= stripe_customer.subscriptions.data.first
  end

  def stripe_payments(reload: false)
    return [] unless stripe_customer(reload: reload)
    return @stripe_payments if defined?(@stripe_payments) && !reload
    @stripe_payments = nil if reload

    # TODO - this one day maybe should be paginated, to be solved when we have customers with 100+
    #        payments
    #      - it is probably worth breaking this out, creating a controller and index action,
    #        and loading it async on the page
    @stripe_payments ||= begin
      [].tap do |payments|
        begin
          page = Stripe::Charge.list(customer: stripe_customer_id, limit: 50)

          payments.concat(
            page.data.map do |charge|
              card = charge.try(:payment_method_details).try(:card)

              OpenStruct.new id:         charge.id,
                             created_at: Time.at(charge.created).utc,
                             card:       card ? "#{card.brand.humanize} ending in #{card.last4}" : nil,
                             amount:     charge.amount
            end
          )
        end while page.has_more
      end
    end
  end
end
