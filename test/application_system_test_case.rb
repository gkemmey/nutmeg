require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  def login_as(user)
    SecureRandom.stub(:hex, user.session_user_id) do
      visit settings_path
    end

    assert page.has_content?("Settings")
  end

  def blur
    page.execute_script('return document.activeElement.blur()')
  end
end
