require 'test_helper'

class Nutmeg::Stripe::SubscriptionHandlerTest < ActiveSupport::TestCase
  include TestHelpers::StripeMocking

  def test_can_create_new_customer_and_subscription
    email = 'mal@serenity.com'
    token = stripe_helper.generate_card_token(brand: 'Visa', last4: '4242', exp_year: 2001)

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal), token, email).start

    users(:mal).reload.tap do |mal|
      assert_not_nil mal.stripe_customer
      assert_not_nil mal.stripe_subscription

      assert_equal "active", mal.billing_status
      assert_equal '4242',   mal.card_last_four
      assert_equal 'Visa',   mal.card_brand
      assert_equal 2001,     mal.card_expires_at.year
    end
  end

  def test_can_just_create_the_subscription_when_they_already_have_customer_and_card_info
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)

    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :cancelled,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal)).start

    assert_not_nil users(:mal).stripe_subscription(reload: true)
  end

  def test_can_add_a_subscription_and_card_to_an_existing_customer
    customer = Stripe::Customer.create(email: 'mal@serenity.com')
    users(:mal).update!(stripe_customer_id: customer.id, billing_email: customer.email)

    token = stripe_helper.generate_card_token(brand: 'Visa', last4: '4242', exp_year: 2001)

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal), token, customer.email).start

    assert_equal customer.id, users(:mal).stripe_customer(reload: true).id
    assert_equal customer.email, users(:mal).billing_email
    assert_not_nil users(:mal).stripe_subscription(reload: true)

    users(:mal).reload.tap do |mal|
      assert_equal "active", mal.billing_status
      assert_equal '4242',   mal.card_last_four
      assert_equal 'Visa',   mal.card_brand
      assert_equal 2001,     mal.card_expires_at.year
    end
  end

  def test_reactivates_a_cancel_at_period_end_but_still_active_subscription
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)
    Stripe::Subscription.update(subscription.id, cancel_at_period_end: true)

    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :cancelled,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    assert_not_nil users(:mal).stripe_subscription(reload: true) # sanity check
    assert users(:mal).stripe_subscription.cancel_at_period_end  # sanity check

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal)).start

    assert_equal subscription.id, users(:mal).stripe_subscription(reload: true).id
    assert_not users(:mal).stripe_subscription.cancel_at_period_end
  end

  def test_creates_a_brand_new_subscription_when_the_subscription_has_been_fully_deleted
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)
    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :cancelled,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    assert_not_nil users(:mal).stripe_subscription(reload: true) # sanity check

    Stripe::Subscription.delete(subscription.id)

    # gotta reload the memozied value after deleting. normally, records aren't going through so
    # many changes back-to-back and each request is gonna re-newup the object, so this is basically
    # simulating this change occurring in some subsequent request
    users(:mal).stripe_subscription(reload: true)

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal)).start

    assert subscription.id != users(:mal).stripe_subscription(reload: true).id

    assert_equal "active", users(:mal).stripe_subscription.status
    assert_not users(:mal).stripe_subscription.cancel_at_period_end
  end

  def test_subscriptions_are_started_with_the_correct_trial_end_date
    # every should get their free two weeks regardless of when they activate their account
    trial_over_at = 2.days.from_now
    users(:mal).update!(billing_status: :trialing, trial_over_at: trial_over_at)

    email = 'mal@serenity.com'
    token = stripe_helper.generate_card_token(brand: 'Visa', last4: '4242', exp_year: 2001)

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal), token, email).start

    users(:mal).reload.tap do |mal|
      assert_not_nil mal.stripe_customer
      assert_not_nil mal.stripe_subscription

      assert_equal "active",   mal.billing_status
      assert_equal "trialing", mal.stripe_subscription.status

      # to_s just to side-step whack time equality comparisons
      assert_equal trial_over_at.to_s, Time.at(mal.stripe_subscription.trial_end).utc.in_time_zone.to_s
    end
  end

  def test_cancelling_a_subscription_sets_cancel_at_period_end_and_flips_status_to_active_until_period_end
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)

    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :cancelled,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    assert_not_nil users(:mal).stripe_subscription(reload: true) # sanity check
    assert_not users(:mal).stripe_subscription.cancel_at_period_end  # sanity check

    Nutmeg::Stripe::SubscriptionHandler.new(users(:mal)).cancel

    assert users(:mal).stripe_subscription(reload: true).cancel_at_period_end
    assert_equal "active_until_period_end", users(:mal).billing_status
  end
end
