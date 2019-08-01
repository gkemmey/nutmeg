module TestHelpers
  module StripeMocking
    def self.included(base)
      base.attr_accessor(:stripe_helper, :default_mocked_customer_id, :default_plan_id)

      base.setup do
        StripeMock.start
        StripeMock.toggle_debug(true) if ENV.fetch("STRIPE_DEBUG") { false }

        self.stripe_helper = StripeMock.create_test_helper
        self.default_mocked_customer_id = 'cus_00000000000000'
        self.default_plan_id = stripe_helper.create_plan(id: Nutmeg::Stripe.plan_id, amount: 4900).id
      end

      base.teardown do
        StripeMock.stop
      end
    end
  end
end
