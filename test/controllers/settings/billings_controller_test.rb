require 'test_helper'

class Settings::BillingsControllerTest < ActionDispatch::IntegrationTest
  include TestHelpers::StripeMocking

  def setup
    @user = users(:mal)
  end

  def test_can_add_a_card_to_the_user
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    post settings_billing_path, params: { stripeToken: token, billing: { email: 'mal@serenity.com' } }

    @user.reload.yield_self do |mal|
      assert_not_nil mal.stripe_customer_id

      assert_equal 'mal@serenity.com', mal.billing_email
      assert_equal '4242',             mal.card_last_four
      assert_equal 'Visa',             mal.card_brand
      assert_equal 2001,               mal.card_expires_at.year
    end

    assert_equal "Credit card updated", flash[:success]
  end

  def test_catches_card_error_when_adding_a_card_to_the_user
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:card_declined), :new_customer)

    post settings_billing_path, params: { stripeToken: token, billing: { email: 'mal@serenity.com' } }

    assert_nil @user.reload.stripe_customer_id
    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:card_declined), flash[:danger]
  end

  def test_catches_api_error_when_adding_a_card_to_the_user
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:api_connection), :new_customer)

    post settings_billing_path, params: { stripeToken: token, billing: { email: 'mal@serenity.com' } }

    assert_nil @user.reload.stripe_customer_id
    assert_not_nil flash[:warning]
    assert_equal Nutmeg::Stripe.flash_for(:cant_connect_to_stripe), flash[:warning]
  end

  def test_catches_active_record_error_attempting_to_update_the_user_when_adding_a_card_to_the_user
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    User.stub_any_instance(:update!, ->(*) { raise ActiveRecord::ActiveRecordError.new }) do
      post settings_billing_path, params: { stripeToken: token, billing: { email: 'mal@serenity.com' } }
    end

    assert_nil @user.reload.stripe_customer_id
    assert flash[:warning].include?("Something went wrong updating our records")
  end

  def test_catches_unexpected_stripe_error_when_adding_a_card_to_the_user
    login_as(@user)

    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001
    StripeMock.prepare_error(stripe_helper.error_for(:unexpected), :new_customer)

    post settings_billing_path, params: { stripeToken: token, billing: { email: 'mal@serenity.com' } }

    assert_nil @user.reload.stripe_customer_id
    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:unexpected_error), flash[:danger]
  end

  def test_can_remove_a_card_from_the_user
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)

    @user.update! stripe_customer_id: customer.id,
                  billing_email:      customer.email,
                  card_last_four:     card.last4,
                  card_brand:         card.brand,
                  card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    delete settings_billing_path

    @user.reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_nil mal.card_last_four
      assert_nil mal.card_brand
      assert_nil mal.card_expires_at
    end

    assert_equal "Credit card removed", flash[:success]
  end

  def test_catches_api_error_when_removing_a_card_from_the_user
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)

    @user.update! stripe_customer_id: customer.id,
                  billing_email:      customer.email,
                  card_last_four:     card.last4,
                  card_brand:         card.brand,
                  card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    StripeMock.prepare_error(stripe_helper.error_for(:api_connection), :delete_source)

    delete settings_billing_path

    @user.reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_not_nil mal.card_last_four
      assert_not_nil mal.card_brand
      assert_not_nil mal.card_expires_at
    end

    assert_not_nil flash[:warning]
    assert_equal Nutmeg::Stripe.flash_for(:cant_connect_to_stripe), flash[:warning]
  end

  def test_catches_unexpected_stripe_error_when_removing_a_card_from_the_user
    login_as(@user)

    customer = Stripe::Customer.create(email: 'mal@serenity.com', source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)

    @user.update! stripe_customer_id: customer.id,
                  billing_email:      customer.email,
                  card_last_four:     card.last4,
                  card_brand:         card.brand,
                  card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    StripeMock.prepare_error(stripe_helper.error_for(:unexpected), :delete_source)

    delete settings_billing_path

    @user.reload.yield_self do |mal|
      assert_equal customer.id,    mal.stripe_customer_id
      assert_equal customer.email, mal.billing_email

      assert_not_nil mal.card_last_four
      assert_not_nil mal.card_brand
      assert_not_nil mal.card_expires_at
    end

    assert_not_nil flash[:danger]
    assert_equal Nutmeg::Stripe.flash_for(:unexpected_error), flash[:danger]
  end

  # -------- show page (view) variations --------

  def test_without_a_credit_card_set_we_prompt_you_to_add_one
    login_as(@user)
    get settings_billing_path

    assert css_select(".button").collect(&:text).any? { |t| t.include?("Add credit card") }
  end

  def test_with_a_credit_card_set_we_offer_options_to_remove_it_or_change_it
    @user.update! card_last_four: "4242",
                                           card_brand: "Visa",
                                           card_expires_at: 2.days.from_now
    login_as(@user)
    get settings_billing_path

    assert css_select(".button").collect(&:text).any? { |t| t.include?("Remove credit card") }
    assert css_select(".button").collect(&:text).any? { |t| t.include?("Change credit card") }
  end

  def test_if_youre_trialing_or_subscription_has_been_cancelled_we_prompt_you_to_start_it
    login_as(@user)

    [:trialing, :active_until_period_end, :cancelled, :past_due].each do |status_under_test|
      @user.update! billing_status: status_under_test

      get settings_billing_path

      css_select("a[href=\"#{new_settings_subscription_path}\"]").first.tap do |link_to_new_subscription|
        assert link_to_new_subscription.present?
        assert css_select(link_to_new_subscription, ".button").first.text.include?("Start subscription")
      end
    end
  end

  define_method "test_if_youre_being_prompted_to_start_your_subscription_and_you_have_" \
                "payment_info_configured_we_can_start_it_without_taking_you_through_the_form" do
    login_as(@user)
    @user.update! billing_email: 'mal@serenity.com',
                  card_last_four: "4242",
                  card_brand: "Visa",
                  card_expires_at: 2.days.from_now

    [:trialing, :active_until_period_end, :cancelled, :past_due].each do |status_under_test|
      @user.update! billing_status: status_under_test

      get settings_billing_path

      css_select("form[action=\"#{settings_subscription_path}\"]").first.tap do |new_subscription_form|
        assert new_subscription_form.present?
        assert css_select(new_subscription_form, ".button").first.text.include?("Start subscription")
      end
    end
  end

  def test_if_you_have_an_active_subscription_we_provide_an_option_to_cancel_it
    @user.update! billing_status: :active

    login_as(@user)
    get settings_billing_path

    assert css_select('.button').collect(&:text).any? { |t| t.include?("Cancel subscription") }
  end

  def test_the_billing_email_is_required_and_has_its_format_validated
    login_as(@user)
    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    stripe_handler_called = false

    # this test only works so long as this method name is sync with the controller. makes the
    # test a little brittle to false positiving in the future 🤷‍
    Nutmeg::Stripe.stub(:add_card, ->(*) { stripe_handler_called = true }) do
      post settings_billing_path, params: { stripeToken: token, billing: { email: '' } }
    end

    assert_not stripe_handler_called
    assert_response :redirect
    follow_redirect!

    assert css_select("p.help.is-danger").collect(&:text).any? { |t| t.include?("Can't be blank") }

    Nutmeg::Stripe.stub(:add_card, ->(*) { stripe_handler_called = true }) do
      post settings_billing_path, params: { stripeToken: token, billing: { email: 'bad_email@' } }
    end

    assert_not stripe_handler_called
    assert_response :redirect
    follow_redirect!

    assert css_select("p.help.is-danger").collect(&:text).any? { |t| t.include?("Invalid format") }
  end

  private

    def can_see_link_to_start_a_new_subscription?
      css_select("a[href=\"#{new_settings_subscription_path}\"]").present?
    end
end
