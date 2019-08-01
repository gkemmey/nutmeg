class Nutmeg::Stripe::Webhooks::CustomerSourceExpiringJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_of_customer_source_expiring(stripe_event).deliver_later
  end
end
