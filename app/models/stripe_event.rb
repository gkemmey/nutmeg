class StripeEvent < ApplicationRecord
  validates :stripe_id,   presence: true,
                          uniqueness: true

  validates :stripe_type, presence: true

  def stripe_event_object(reload: false)
    @stripe_event_object = nil if reload

    @stripe_event_object ||= begin
      stripe_event = Stripe::Event.retrieve(stripe_id)
      stripe_event.data.object
    end
  end

  alias card         stripe_event_object
  alias charge       stripe_event_object
  alias customer     stripe_event_object
  alias dispute      stripe_event_object
  alias invoice      stripe_event_object
  alias subscription stripe_event_object

  def user
    case stripe_event_object
      when Stripe::Card
        User.find_by(stripe_customer_id: card.customer)

      when Stripe::Charge
        User.find_by(stripe_customer_id: charge.customer)

      when Stripe::Customer
        User.find_by(stripe_customer_id: customer.id)

      when Stripe::Dispute
        User.find_by(stripe_customer_id: Stripe::Charge.retrieve(dispute.charge).customer)

      when Stripe::Invoice
        User.find_by(stripe_customer_id: invoice.customer)

      when Stripe::Subscription
        User.find_by(stripe_customer_id: subscription.customer)

      else
        raise "Don't know how to resolve user from #{stripe_event_object.class}"
    end
  end
end
