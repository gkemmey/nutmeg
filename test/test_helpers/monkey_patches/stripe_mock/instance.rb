module TestHelpers
  module MonkeyPatches
    module StripeMock
      module Instance
        def self.included(base)
          base.alias_method :__monkey_patched__custom_subscription_params, :custom_subscription_params

          base.define_method(:custom_subscription_params) do |plans, cus, options = {}|
            params = __monkey_patched__custom_subscription_params(plans, cus, options)

            if (status = options[:force_status_using_our_monkey_patch])
              params.merge!(status: status)
            end

            params
          end
        end
      end
    end
  end
end
