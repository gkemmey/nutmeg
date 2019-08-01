class Settings::BillingsController < ApplicationController
  before_action :validate_email, only: [:create]

  def show
  end

  def new
  end

  def create
    response = Nutmeg::Stripe.add_card(current_user, params[:stripeToken],
                                                           params[:billing][:email])
    if response.ok?
      flash[:success] = "Credit card updated"
      redirect_to settings_billing_path

    elsif response.card_error?
      flash[:danger] = Nutmeg::Stripe.flash_for(:card_declined)
      redirect_to new_settings_billing_path

    elsif response.api_connection_error?
      flash[:warning] = Nutmeg::Stripe.flash_for(:cant_connect_to_stripe)
      redirect_to new_settings_billing_path

    elsif response.active_record_error?
      flash[:warning] = "Something went wrong updating our records, but your card should be updated. " \
                        "This page might not display right, but don't try again. We've pinged our " \
                        "team about it, and hopefully we can get things fixed soon!"
      redirect_to settings_billing_path

    else
      flash[:danger] = Nutmeg::Stripe.flash_for(:unexpected_error)
      redirect_to settings_billing_path
    end
  end

  def destroy
    response = Nutmeg::Stripe.remove_card(current_user)

    if response.ok?
      flash[:success] = "Credit card removed"
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

    def user_status
      color = current_user.instance_eval do
                if    trialing?                           then 'has-text-link'
                elsif trial_over? || past_due?            then 'has-text-warning'
                elsif active? || active_until_period_end? then 'has-text-success'
                elsif cancelled?                          then 'has-text-danger'
                else                                           'has-text-link' # shouldn't happen
                end
              end
      status = (current_user.trial_over? ? "trial_over" : current_user.billing_status).humanize

      helpers.content_tag(:p, status, class: "title is-4 #{color}")
    end
    helper_method :user_status

    def card_details(options = {})
      helpers.render partial: "card_details", locals: { for: options[:for] }
    end
    helper_method :card_details

    def i_manage_payment_and_subscription_info?
      true # TODO - you could do something more involved here
    end
    helper_method :i_manage_payment_and_subscription_info?

    def validate_email
      if params[:billing][:email].blank?
        flash[:crib_flash_to_show_email_error_through_redirect] = "Can't be blank"

      elsif !params[:billing][:email].match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
        flash[:crib_flash_to_show_email_error_through_redirect] = "Invalid format"
      end

      redirect_to new_settings_billing_path if flash[:crib_flash_to_show_email_error_through_redirect].present?
    end
end
