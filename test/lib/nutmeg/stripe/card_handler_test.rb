require 'test_helper'

class Nutmeg::Stripe::CardHandlerTest < ActiveSupport::TestCase
  include TestHelpers::StripeMocking

  def test_can_add_a_card_where_there_previously_was_nothing
    email = 'mal@serenity.com'
    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    Nutmeg::Stripe::CardHandler.new(users(:mal), token, email).add

    users(:mal).tap do |mal|
      assert_not_nil mal.stripe_customer(reload: true).default_source

      assert_equal email,  mal.billing_email
      assert_equal '4242', mal.card_last_four
      assert_equal 'Visa', mal.card_brand
      assert_equal 2001,   mal.card_expires_at.year
    end
  end

  def test_can_add_a_card_to_an_existing_customer
    email = 'mal@serenity.com'
    token = stripe_helper.generate_card_token brand: 'Visa', last4: '4242', exp_year: 2001

    customer = Stripe::Customer.create(email: email)
    users(:mal).update! stripe_customer_id: customer.id,
                        billing_email:      customer.email

    Nutmeg::Stripe::CardHandler.new(users(:mal), token, email).add

    users(:mal).tap do |mal|
      assert_equal customer.id, mal.stripe_customer(reload: true).id

      assert_not_nil mal.stripe_customer.default_source

      assert_equal email,  mal.billing_email
      assert_equal '4242', mal.card_last_four
      assert_equal 'Visa', mal.card_brand
      assert_equal 2001,   mal.card_expires_at.year
    end
  end

  def test_can_remove_an_existing_card
    customer = Stripe::Customer.create(email: 'mal@serenity.com',
                                       source: stripe_helper.generate_card_token)
    card = customer.sources.retrieve(customer.default_source)

    users(:mal).update! stripe_customer_id: customer.id,
                        billing_status:     :active,
                        billing_email:      customer.email,
                        card_last_four:     card.last4,
                        card_brand:         card.brand,
                        card_expires_at:    Time.utc(card.exp_year, card.exp_month)

    assert_not_nil users(:mal).stripe_customer.default_source  # sanity check
    Nutmeg::Stripe::CardHandler.new(users(:mal)).remove

    users(:mal).tap do |mal|
      assert_nil mal.stripe_customer(reload: true).default_source

      assert_nil mal.card_last_four
      assert_nil mal.card_brand
      assert_nil mal.card_expires_at
    end
  end
end
