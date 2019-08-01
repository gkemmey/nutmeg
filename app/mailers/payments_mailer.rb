class PaymentsMailer < ApplicationMailer
  default from: 'billing@nutmeg.com', bcc: 'gray.kemmey@gmail.com'

  def notify_of_charge_refunded(stripe_event)
    @charge  = stripe_event.charge
    @user = stripe_event.user

    mail(to: @user.billing_email, subject: '[Nutmeg] Payment Refunded')
  end

  def notify_of_charge_succeeded(stripe_event)
    @charge  = stripe_event.charge
    @user = stripe_event.user

    mail(to: @user.billing_email, subject: '[Nutmeg] Payment Receipt')
  end

  def notify_of_customer_source_expiring(stripe_event)
    @user = stripe_event.user

    mail(to: @user.billing_email, bcc: nil, subject: '[Nutmeg] Card Expiring')
  end

  def notify_of_customer_subscription_trial_will_end(stripe_event)
    @subscription = stripe_event.subscription
    @user = stripe_event.user

    mail(to: @user.billing_email, bcc: nil, subject: '[Nutmeg] Trial Ending')
  end

  def notify_of_invoice_upcoming(stripe_event)
    @subscription = Stripe::Subscription.retrieve(stripe_event.invoice.subscription)
    @user = stripe_event.user

    mail(to: @user.billing_email, bcc: nil, subject: '[Nutmeg] Subscription Renewing')
  end

  # ------- administrative notifications --------

  def notify_nutmeg_of_charge_dispute_created(stripe_event)
    @stripe_event = stripe_event

    mail(to: 'gray.kemmey@gmail.com', bcc: nil, subject: '[Nutmeg] Charge Dispute Created')
  end
end
