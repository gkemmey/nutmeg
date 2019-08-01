class Nutmeg::Stripe::Webhooks::InvoiceUpcomingJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_of_invoice_upcoming(stripe_event).deliver_later
  end
end
