module Nutmeg
  module Stripe
    class Response
      attr_accessor :error

      def initialize(attributes = {})
        attributes.each { |name, value| send("#{name}=", value) }
      end

      def send_through_exception_notfier
        ExceptionNotifier.notify_exception(error)
      end

      # -------- error handling -------

      def ok?
        error.nil?
      end

      def card_error?
        error.is_a?(::Stripe::CardError)
      end

      def rate_limit_error?
        error.is_a?(::Stripe::RateLimitError)
      end

      def invalid_request_error?
        error.is_a?(::Stripe::InvalidRequestError)
      end

      def authentication_error?
        error.is_a?(::Stripe::AuthenticationError)
      end

      def api_connection_error?
        error.is_a?(::Stripe::APIConnectionError)
      end

      def stripe_error?
        error.is_a?(::Stripe::StripeError)
      end

      def active_record_error?
        error.is_a?(::ActiveRecord::ActiveRecordError)
      end

      def unknown_error?
        [
          :ok?,
          :card_error?,
          :rate_limit_error?,
          :invalid_request_error?,
          :authentication_error?,
          :api_connection_error?,
          :stripe_error?,
          :active_record_error?
        ].none? { |m| send(m) }
      end

      def status
        error.nil? ? 200 : (non_stripe_error? ? nil : error.http_status)
      end

      def error_details
        @error_details ||= begin
          OpenStruct.new(json_body[:error])
        end

        # docs have this example:
        #
        # ```rb
        # begin
        #   # Use Stripe's library to make requests...
        # rescue ::Stripe::CardError => e
        #   # Since it's a decline, ::Stripe::CardError will be caught
        #   body = e.json_body
        #   err  = body[:error]
        #
        #   puts "Status is: #{e.http_status}"
        #   puts "Type is: #{err[:type]}"
        #   puts "Charge ID is: #{err[:charge]}"
        #   # The following fields are optional
        #   puts "Code is: #{err[:code]}" if err[:code]
        #   puts "Decline code is: #{err[:decline_code]}" if err[:decline_code]
        #   puts "Param is: #{err[:param]}" if err[:param]
        #   puts "Message is: #{err[:message]}" if err[:message]
        # end
        # ```
        #
        # ☝️ we're wrapping `err` in an `OpenStruct`, so you should just be able to interogate
        # it directly like `error_details.type`
      end
    end
  end
end
