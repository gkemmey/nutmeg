require 'test_helper'

class UserTest < ActiveSupport::TestCase
  include TestHelpers::StripeMocking

  def test_can_fetch_and_reload_customer
    mal = users(:mal)
    assert_nil mal.stripe_customer

    customer_one = Stripe::Customer.create
    users(:mal).update!(stripe_customer_id: customer_one.id)

    assert_equal customer_one.id, mal.stripe_customer.id

    customer_two = Stripe::Customer.create
    users(:mal).update!(stripe_customer_id: customer_two.id)

    assert_equal customer_one.id, mal.stripe_customer.id, "Expected it to be memoized"
    assert_equal customer_two.id, mal.stripe_customer(reload: true).id
  end

  def test_can_fetch_and_reload_subscription
    mal = users(:mal)
    assert_nil mal.stripe_subscription

    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)


    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    assert_equal subscription.id, mal.stripe_subscription.id

    # hack to avoid creating a new mocked subscription and getting it properly assoicated with the
    # mocked customer
    mal.instance_variable_set(:@stripe_subscription, OpenStruct.new(id: 'doesnt_match'))
    assert mal.stripe_subscription.id != subscription.id

    assert_equal subscription.id, mal.stripe_subscription(reload: true).id
  end

  def test_can_fetch_and_reload_payments
    mal = users(:mal)
    assert_equal [], mal.stripe_payments

    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)


    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)
    charged_at = Time.current
    charge = Stripe::Charge.create(customer: customer.id, currency: "USD", amount: 1000, created_at: charged_at.to_i)

    assert_equal [1000, 4900], mal.stripe_payments.collect(&:amount) # 4900 == subscription charge

    Stripe::Charge.create(customer: customer.id, currency: "USD", amount: 1500, created_at: Time.current.to_i)

    assert_equal [1000, 4900], mal.stripe_payments.collect(&:amount), "Expected it to be memoized"
    assert_equal [1500, 1000, 4900], mal.stripe_payments(reload: true).collect(&:amount)
  end
end
