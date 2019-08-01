class Nutmeg::Stripe::Webhooks::CustomerDeletedJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    stripe_event.user.update_attributes! billing_status:     :cancelled,
                                         stripe_customer_id: nil,
                                         billing_email:      nil,
                                         card_last_four:     nil,
                                         card_brand:         nil,
                                         card_expires_at:    nil
  end
end
