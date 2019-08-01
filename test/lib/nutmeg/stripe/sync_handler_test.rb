require 'test_helper'

class Nutmeg::Stripe::SyncHandlerTest < ActiveSupport::TestCase
  include TestHelpers::StripeMocking

  def test_if_the_customer_id_is_deleted_it_clears_it
    customer = Stripe::Customer.create(email: 'mal@serenity.com')
    users(:mal).update! stripe_customer_id: customer.id,
                        billing_email:      customer.email

    Stripe::Customer.delete(customer.id)

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_nil users(:mal).stripe_customer_id
  end

  def test_if_the_customer_id_is_missing_it_clears_it_and_the_billing_email
    users(:mal).update! stripe_customer_id: 'nonexistent',
                        billing_email:      'mal@serenity.com'


    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_nil users(:mal).stripe_customer_id
    assert_nil users(:mal).billing_email
  end

  def test_it_can_add_the_customer_email
    email = 'mal@serenity.com'

    customer = Stripe::Customer.create(email: email)
    users(:mal).update! stripe_customer_id: customer.id,
                        billing_email:      'should_change@example.com'

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal customer.id, users(:mal).stripe_customer_id
    assert_equal email,       users(:mal).billing_email
  end

  def test_if_the_account_is_active_but_theres_no_subscription_we_flip_it_to_cancelled
    customer = Stripe::Customer.create(email: 'mal@serenity.com')
    users(:mal).update! stripe_customer_id: customer.id, billing_status: :active

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "cancelled", users(:mal).billing_status
  end

  def test_if_the_subscription_is_active_but_has_canceled_at_set_we_flip_the_account_to_active_until_period_end
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

    Stripe::Subscription.update(subscription.id, cancel_at_period_end: true)
    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "active_until_period_end", users(:mal).billing_status
  end

  def test_if_the_subscription_is_active_we_flip_the_account_to_active
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

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "active", users(:mal).billing_status
  end

  def test_if_the_subscription_is_trialing_we_flip_the_account_to_active
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id,
                                                               trial_end: 2.days.from_now.to_i)

    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :cancelled,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "active", users(:mal).billing_status
  end

  def test_if_the_subscription_is_past_due_we_flip_the_account_to_past_due
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

    Stripe::Subscription.update(subscription.id, force_status_using_our_monkey_patch: "past_due")
    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "past_due", users(:mal).billing_status
  end

  def test_if_the_subscription_is_unpaid_we_flip_the_account_to_past_due
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

    Stripe::Subscription.update(subscription.id, force_status_using_our_monkey_patch: "unpaid")
    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "past_due", users(:mal).billing_status
  end

  def test_if_the_subscription_is_cancelled_we_flip_the_account_to_cancelled
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

    Stripe::Subscription.update(subscription.id, force_status_using_our_monkey_patch: "canceled")
    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    assert_equal "cancelled", users(:mal).billing_status
  end

  def test_it_can_set_card_details_on_the_account
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token(brand: 'Visa',
                                                                                 last4: '4242',
                                                                                 exp_year: 2001))

    users(:mal).update! stripe_customer_id: customer.id

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    users(:mal).reload.tap do |mal|
      assert_equal '4242', mal.card_last_four
      assert_equal 'Visa', mal.card_brand
      assert_equal 2001,   mal.card_expires_at.year
    end
  end

  def test_it_removes_card_details_when_the_card_cant_be_found
    customer = Stripe::Customer.create(email: 'mal@serenity.com')

    users(:mal).update! stripe_customer_id: customer.id,
                                           card_last_four:     "4242",
                                           card_brand:         "Visa",
                                           card_expires_at:    1.year.from_now

    Nutmeg::Stripe::SyncHandler.new(users(:mal)).sync

    users(:mal).tap do |mal|
      assert_nil mal.card_last_four
      assert_nil mal.card_brand
      assert_nil mal.card_expires_at
    end
  end
end
