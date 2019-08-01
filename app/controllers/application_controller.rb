class ApplicationController < ActionController::Base

  def current_user
    @current_user ||= User.find_or_create_by!(session_user_id: session_user)
  end
  helper_method :current_user

  # classes("is-flex", is_primary: false, is_info: "true", [:hidden, :visible] => true)
  # => "is-flex is-info hidden visible"
  #
  # classes(is_primary: false, is_info: "true", [:hidden, :visible] => true)
  # => "is-info hidden visible"
  def classes(always_on_or_conditionals, conditionals = {})
    if always_on_or_conditionals.is_a?(Hash)
      always_on_or_conditionals, conditionals = nil, always_on_or_conditionals
    end

    (Array(always_on_or_conditionals) + conditionals.find_all(&:last).
                                                     map(&:first).
                                                     flatten.
                                                     map(&:to_s).
                                                     map { |c| c.gsub(/_/, '-') }).join(" ")
  end
  helper_method :classes

  private

    def session_user
      @session_user ||= session[:user_id] || generate_session_user_id
    end

    def generate_session_user_id
      session[:user_id] = SecureRandom.hex
    end
end
