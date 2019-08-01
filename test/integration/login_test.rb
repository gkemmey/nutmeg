require 'test_helper'

class LoginTest < ActionDispatch::IntegrationTest
  setup { login_as(users(:mal)) }

  def test_can_login_as_an_existing_user_in_tests
    assert_no_difference "User.count" do
      get settings_path
    end

    assert_not_equal users(:mal).session_user_id, SecureRandom.hex, "Expected it to not be stubbed anymore"
  end
end
