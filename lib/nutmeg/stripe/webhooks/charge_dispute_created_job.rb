class Nutmeg::Stripe::Webhooks::ChargeDisputeCreatedJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_Nutmeg_of_charge_dispute_created(stripe_event).deliver_later
  end
end
