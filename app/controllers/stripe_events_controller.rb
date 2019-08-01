class StripeEventsController < ApplicationController
  protect_from_forgery except: :create

  def create
    begin
      their_event_record = Stripe::Webhook.construct_event request.body.read,
                                                           request.env['HTTP_STRIPE_SIGNATURE'],
                                                           Stripe.webhook_secret

    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      ExceptionNotifier.notify_exception(e)
      head 400
      return
    end

    # the only anticipated way this fails is if it's not unique, in which case we have nothing to
    # do because we've already processed it. we're essentially using our StripeEvent model as
    # a record of processed events
    #
    stripe_event = StripeEvent.new(stripe_id: their_event_record.id, stripe_type: their_event_record.type)
    if stripe_event.save
      self.send(handler_for(their_event_record), stripe_event)
    end

    head 200
  end

  private

    def handler_for(their_event_record)
      "handle_#{their_event_record.type.gsub('.', '_')}".to_sym
    end

    # took a look at pay to see what they were handling:
    # https://github.com/jasoncharnes/pay/tree/master/lib/pay/stripe/webhooks
    # i'm gonna add a `# implemented_by_pay` comment to methods they also implemented

    # -------- charges --------

    # https://stripe.com/docs/api/events/types#event_types-charge.refunded
    def handle_charge_refunded(stripe_event) # implemented_by_pay
      Nutmeg::Stripe::Webhooks::ChargeRefundedJob.perform_later(stripe_event)
    end

    # https://stripe.com/docs/api/events/types#event_types-charge.succeeded
    def handle_charge_succeeded(stripe_event) # implemented_by_pay
      Nutmeg::Stripe::Webhooks::ChargeSucceededJob.perform_later(stripe_event)
    end

    # -------- charge disputes --------

    # https://stripe.com/docs/api/events/types#event_types-charge.dispute.created
    def handle_charge_dispute_created(stripe_event)
      Nutmeg::Stripe::Webhooks::ChargeDisputeCreatedJob.perform_later(stripe_event)
    end

    # -------- customers --------

    # https://stripe.com/docs/api/events/types#event_types-customer.deleted
    def handle_customer_deleted(stripe_event) # implemented_by_pay
      # we have to clear the data we hold onto, because otherwise Stripe::Customer.retrieve
      # will give us a deleted user object 🙄 that doesn't respond to default_source. i'd have
      # maybe thought retrieving a deleted user_id would give you nil...
      #
      Nutmeg::Stripe::Webhooks::CustomerDeletedJob.perform_later(stripe_event)
    end

    # https://stripe.com/docs/api/events/types#event_types-customer.updated
    def handle_customer_updated(stripe_event) # implemented_by_pay
      Nutmeg::Stripe::Webhooks::CustomerUpdatedJob.perform_later(stripe_event)
    end

    # -------- customer sources --------

    # https://stripe.com/docs/api/events/types#event_types-customer.source.deleted
    def handle_customer_source_deleted(stripe_event) # implemented_by_pay
      Nutmeg::Stripe::Webhooks::CustomerSourceDeletedJob.perform_later(stripe_event)
    end

    # https://stripe.com/docs/api/events/types#event_types-customer.source.expiring
    def handle_customer_source_expiring(stripe_event)
      Nutmeg::Stripe::Webhooks::CustomerSourceExpiringJob.perform_later(stripe_event)
    end

    # -------- customer subscriptions --------

    # https://stripe.com/docs/api/events/types#event_types-customer.subscription.deleted
    def handle_customer_subscription_deleted(stripe_event)
      Nutmeg::Stripe::Webhooks::CustomerSubscriptionDeletedJob.perform_later(stripe_event)
    end

    # https://stripe.com/docs/api/events/types#event_types-customer.subscription.trial_will_end
    def handle_customer_subscription_trial_will_end(stripe_event)
      Nutmeg::Stripe::Webhooks::CustomerSubscriptionTrialWillEndJob.perform_later(stripe_event)
    end

    # ------- invoices --------

    # https://stripe.com/docs/api/events/types#event_types-invoice.upcoming
    def handle_invoice_upcoming(stripe_event) # implemented_by_pay
      # event.data.object is an invoice. for us this means a subscription is renewing.
      Nutmeg::Stripe::Webhooks::InvoiceUpcomingJob.perform_later(stripe_event)
    end
end
