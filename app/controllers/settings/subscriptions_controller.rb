class Settings::SubscriptionsController < ApplicationController
  before_action :validate_email_if_its_needed, only: [:create]

  def new
  end

  def create
    response = Nutmeg::Stripe.subscribe(current_user, params[:stripeToken],
                                                            params.dig(:subscription, :email))

    if response.ok?
      flash[:success] = "Subscription started 🌳"
      redirect_to settings_billing_path

    elsif response.card_error?
      flash[:danger] = Nutmeg::Stripe.flash_for(:card_declined)
      redirect_to new_settings_subscription_path

    elsif response.api_connection_error?
      flash[:warning] = Nutmeg::Stripe.flash_for(:cant_connect_to_stripe)
      redirect_to new_settings_subscription_path

    elsif response.active_record_error?
      flash[:warning] = "Something went wrong updating our records, but your payment is fine. This " \
                        "page might not display right, but don't try again. We've pinged our team  " \
                        "about it, and hopefully we can get things fixed soon!"
      redirect_to settings_billing_path

    else
      flash[:danger] = Nutmeg::Stripe.flash_for(:unexpected_error)
      redirect_to settings_billing_path
    end
  end

  def destroy
    response = Nutmeg::Stripe.cancel_subscription(current_user)

    if response.ok?
      flash[:success] = "Subscription cancelled"
      redirect_to settings_billing_path

    elsif response.api_connection_error?
      flash[:warning] = Nutmeg::Stripe.flash_for(:cant_connect_to_stripe)
      redirect_to settings_billing_path

    else
      flash[:danger] = Nutmeg::Stripe.flash_for(:unexpected_error)
      redirect_to settings_billing_path
    end
  end

  private

    def validate_email_if_its_needed
      # if you already have payment info configure, we post straight to create with stripeToken
      # and [:subscription][:email] blank. so only check if the stripeToken is set.
      return if params[:stripeToken].blank?

      if params[:subscription][:email].blank?
        flash[:crib_flash_to_show_email_error_through_redirect] = "Can't be blank"

      elsif !params[:subscription][:email].match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
        flash[:crib_flash_to_show_email_error_through_redirect] = "Invalid format"
      end

      if flash[:crib_flash_to_show_email_error_through_redirect].present?
        redirect_to new_settings_subscription_path
      end
    end
end
