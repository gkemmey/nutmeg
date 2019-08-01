class Nutmeg::Stripe::Webhooks::CustomerSourceDeletedJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    Nutmeg::Stripe.sync(stripe_event.user)
  end
end
