module TestHelpers
  module MonkeyPatches
    module StripeMock
      module TestStrategies
        module Base
          def error_for(error_symbol)
            if (params = ::StripeMock::CardErrors.argument_map[error_symbol])
              ::Stripe::CardError.new(*params)

            elsif error_symbol == :api_connection
              ::Stripe::APIConnectionError.new

            elsif error_symbol == :unexpected
              ::Stripe::StripeError.new

            elsif error_symbol == :signature_verification
              ::Stripe::SignatureVerificationError.new("message", "bad_header")

            else
              raise "Dunno how to build that error"
            end
          end
        end
      end
    end
  end
end
