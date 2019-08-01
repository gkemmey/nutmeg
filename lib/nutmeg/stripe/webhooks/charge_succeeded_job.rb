class Nutmeg::Stripe::Webhooks::ChargeSucceededJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_of_charge_succeeded(stripe_event).deliver_later
  end
end
