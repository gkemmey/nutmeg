require 'test_helper'

class Settings::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  include TestHelpers::StripeMocking

  def setup
    @user = users(:mal)
  end

  def test_can_start_a_subscription
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'mal@serenity.com' } }

    users(:mal).reload.yield_self do |mal|
      assert_not_nil mal.stripe_customer_id

      assert_equal "active",           mal.billing_status
      assert_equal 'mal@serenity.com', mal.billing_email
      assert_equal '4242',             mal.card_last_four
      assert_equal 'Visa',             mal.card_brand
      assert_equal 2001,               mal.card_expires_at.year
    end

    assert_equal "Subscription started 🌳", flash[:success]
  end

  def test_catches_card_error_when_starting_a_subscription
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:card_declined), :new_customer)

    post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'mal@serenity.com' } }

    assert_nil users(:mal).reload.stripe_customer_id
    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:card_declined), flash[:danger]
  end

  def test_catches_api_error_when_starting_a_subscription
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:api_connection), :new_customer)

    post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'mal@serenity.com' } }

    assert_nil users(:mal).reload.stripe_customer_id
    assert_not_nil flash[:warning]
    assert_equal Nutmeg::Stripe.flash_for(:cant_connect_to_stripe), flash[:warning]
  end

  def test_catches_active_record_error_attempting_to_update_the_user_when_starting_a_subscription
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    User.stub_any_instance(:update!, ->(*) { raise ActiveRecord::ActiveRecordError.new }) do
      post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'mal@serenity.com' } }
    end

    assert_nil users(:mal).reload.stripe_customer_id
    assert flash[:warning].include?("Something went wrong updating our records")
  end

  def test_catches_unexpected_stripe_error_when_starting_a_subscription
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:unexpected), :new_customer)

    post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'mal@serenity.com' } }

    assert_nil users(:mal).reload.stripe_customer_id
    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:unexpected_error), flash[:danger]
  end

  def test_can_stop_a_subscription
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)


    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    delete settings_subscription_path

    users(:mal).reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_equal card.last4,    mal.card_last_four
      assert_equal card.brand,    mal.card_brand
      assert_equal card.exp_year, mal.card_expires_at.year

      assert_equal "active_until_period_end", mal.billing_status
      assert mal.stripe_subscription.cancel_at_period_end
    end

    assert_equal "Subscription cancelled", flash[:success]
  end

  def test_catches_api_error_when_stopping_a_subscription
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)


    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    StripeMock.prepare_error(stripe_helper.error_for(:api_connection), :update_subscription)

    delete settings_subscription_path

    users(:mal).reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_equal card.last4,    mal.card_last_four
      assert_equal card.brand,    mal.card_brand
      assert_equal card.exp_year, mal.card_expires_at.year

      assert_equal "active", mal.billing_status
      assert_not mal.stripe_subscription.cancel_at_period_end
    end

    assert_not_nil flash[:warning]
    assert_equal Nutmeg::Stripe.flash_for(:cant_connect_to_stripe), flash[:warning]
  end

  def test_catches_unexpected_stripe_error_when_stopping_a_subscription
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)
    subscription = Stripe::Subscription.create(plan: default_plan_id, customer: customer.id)


    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    StripeMock.prepare_error(stripe_helper.error_for(:unexpected), :update_subscription)

    delete settings_subscription_path

    users(:mal).reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_equal card.last4,    mal.card_last_four
      assert_equal card.brand,    mal.card_brand
      assert_equal card.exp_year, mal.card_expires_at.year

      assert_equal "active", mal.billing_status
      assert_not mal.stripe_subscription.cancel_at_period_end
    end

    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:unexpected_error), flash[:danger]
  end

  def test_the_billing_email_is_required_and_has_its_format_validated
    login_as(@user)
    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    stripe_handler_called = false

    # this test only works so long as this method name is sync with the controller. makes the
    # test a little brittle to false positiving in the future 🤷‍
    Nutmeg::Stripe.stub(:subscribe, ->(*) { stripe_handler_called = true }) do
      post settings_subscription_path, params: { stripeToken: token, subscription: { email: '' } }
    end

    assert_not stripe_handler_called
    assert_response :redirect
    follow_redirect!

    assert css_select("p.help.is-danger").collect(&:text).any? { |t| t.include?("Can't be blank") }

    Nutmeg::Stripe.stub(:add_card, ->(*) { stripe_handler_called = true }) do
      post settings_subscription_path, params: { stripeToken: token, subscription: { email: 'bad_email@' } }
    end

    assert_not stripe_handler_called
    assert_response :redirect
    follow_redirect!

    assert css_select("p.help.is-danger").collect(&:text).any? { |t| t.include?("Invalid format") }
  end
end
