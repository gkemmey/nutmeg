require "application_system_test_case"

class StripeFormsTest < ApplicationSystemTestCase
  def setup
    @mal = users(:mal)
  end

  def test_the_new_card_form_works
    # we seem to have to stub all the way at the top. i'm not sure why, but have observed the
    # stub not applying when we try to stub closer to the actual request. i think maybe all this
    # iframe page switching is the culprit.
    #
    top_level_stub_called = false
    Nutmeg::Stripe.stub(:add_card, ->(account, token, email) {
                                     top_level_stub_called = true
                                     assert_not_nil token
                                     assert_equal email, 'mal@serenity.com'
                                     OpenStruct.new(ok?: true)
                                   }) do
      login_as(@mal)
      visit new_settings_billing_path

      wait_for_stripe_to_mount

      in_iframe_for(:card_number) do
        fill_in("cardnumber", with: "4242")
      end

      assert_equal "Your card number is incomplete.", error_for(:card_number)

      in_iframe_for(:card_number) do
        # slow down inputting so stripe can keep up
        3.times { [4, 2, 4, 2].each { |n| find("input").native.send_keys(n) } }
      end

      assert no_error_for(:card_number)

      in_iframe_for(:card_expiry) do
        fill_in("exp-date", with: "12")
      end

      assert_equal "Your card's expiration date is incomplete.", error_for(:card_expiry)

      in_iframe_for(:card_expiry) do
        [2, 1].each { |n| find("input").native.send_keys(n) }
      end

      assert no_error_for(:card_expiry)

      in_iframe_for(:card_cvc) do
        fill_in("cvc", with: "1")
      end

      assert_equal "Your card's security code is incomplete.", error_for(:card_cvc)

      in_iframe_for(:card_cvc) do
        [2, 3].each { |n| find("input").native.send_keys(n) }
      end

      assert no_error_for(:card_cvc)

      fill_in :billing_email, with: 'mal@serenity.com'

      click_button "Save"

      assert page.has_content?("Credit card updated") # successful flash message
      assert top_level_stub_called
    end
  end

  def test_the_new_subscription_form_works
    # we seem to have to stub all the way at the top. i'm not sure why, but have observed the
    # stub not applying when we try to stub closer to the actual request. i think maybe all this
    # iframe page switching is the culprit.
    #
    top_level_stub_called = false
    Nutmeg::Stripe.stub(:subscribe, ->(account, token, email) {
                                      top_level_stub_called = true
                                      assert_not_nil token
                                      assert_equal email, 'mal@serenity.com'
                                      OpenStruct.new(ok?: true)
                                    }) do
      login_as(@mal)
      visit new_settings_subscription_path

      wait_for_stripe_to_mount

      in_iframe_for(:card_number) do
        fill_in("cardnumber", with: "4242")
      end

      assert_equal "Your card number is incomplete.", error_for(:card_number)

      in_iframe_for(:card_number) do
        # slow down inputting so stripe can keep up
        3.times { [4, 2, 4, 2].each { |n| find("input").native.send_keys(n) } }
      end

      assert no_error_for(:card_number)

      in_iframe_for(:card_expiry) do
        fill_in("exp-date", with: "12")
      end

      assert_equal "Your card's expiration date is incomplete.", error_for(:card_expiry)

      in_iframe_for(:card_expiry) do
        [2, 1].each { |n| find("input").native.send_keys(n) }
      end

      assert no_error_for(:card_expiry)

      in_iframe_for(:card_cvc) do
        fill_in("cvc", with: "1")
      end

      assert_equal "Your card's security code is incomplete.", error_for(:card_cvc)

      in_iframe_for(:card_cvc) do
        [2, 3].each { |n| find("input").native.send_keys(n) }
      end

      assert no_error_for(:card_cvc)

      fill_in :subscription_email, with: 'mal@serenity.com'

      click_button "Start subscription"

      assert page.has_content?("Subscription started 🌳") # successful flash message
      assert top_level_stub_called
    end
  end

  private

    def wait_for_stripe_to_mount
      assert page.has_css?(".__PrivateStripeElement")
    end

    def in_iframe_for(input, &block)
      current_window = page.driver.current_window_handle
      selector = case input
                   when :card_number
                     '[data-target="credit-card-form.number"]'
                   when :card_expiry
                     '[data-target="credit-card-form.expiry"]'
                   when :card_cvc
                     '[data-target="credit-card-form.cvc"]'
                 end

      page.driver.switch_to_frame(find(selector).find("iframe"))
      yield

    ensure
      page.driver.switch_to_window(current_window)
      blur
    end

    def error_for(input)
      selector = case input
                   when :card_number
                     '[data-target="credit-card-form.number"]'
                   when :card_expiry
                     '[data-target="credit-card-form.expiry"]'
                   when :card_cvc
                     '[data-target="credit-card-form.cvc"]'
                 end

      # parent element      👇
      find(selector).first(:xpath,".//..", visible: false).find("p").text
    end

    def no_error_for(input)
      selector = case input
                   when :card_number
                     '[data-target="credit-card-form.number"]'
                   when :card_expiry
                     '[data-target="credit-card-form.expiry"]'
                   when :card_cvc
                     '[data-target="credit-card-form.cvc"]'
                 end

      # parent element      👇
      find(selector).first(:xpath,".//..", visible: false).has_no_css?("p")
    end
end
