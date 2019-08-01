class Nutmeg::Stripe::Webhooks::CustomerSubscriptionTrialWillEndJob < ApplicationJob
  queue_as :default

  def perform(stripe_event)
    PaymentsMailer.notify_of_customer_subscription_trial_will_end(stripe_event).deliver_later
  end
end
