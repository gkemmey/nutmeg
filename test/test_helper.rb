ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

require 'minitest/mock'

# -------- files we require ourselves --------
Dir.glob(File.join(Rails.root, 'test/test_helpers/**/', '*.rb')).
    reject { |f| f.end_with?("_test.rb") }.
    each do |helper_file|

  require helper_file
end

# -------- test-only monkey patches --------
Object.include(TestHelpers::MonkeyPatches::Object)
StripeMock::TestStrategies::Base.include(TestHelpers::MonkeyPatches::StripeMock::TestStrategies::Base)
StripeMock::Instance.include(TestHelpers::MonkeyPatches::StripeMock::Instance)

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  def login_as(user)
    SecureRandom.stub(:hex, user.session_user_id) do
      get settings_path
    end
  end
end
