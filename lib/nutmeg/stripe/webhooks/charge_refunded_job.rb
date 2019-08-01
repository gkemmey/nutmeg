class Nutmeg::Stripe::Webhooks::ChargeRefundedJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_of_charge_refunded(stripe_event).deliver_later
  end
end
