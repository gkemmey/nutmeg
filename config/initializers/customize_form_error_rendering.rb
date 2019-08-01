# -------------------------------------------------------------------------------------------------
# monkey patches ActionView::Helpers::Tags module and adds a wrapper tag. additionally,
# patches ActionView::Helpers::FormBuilder to add a `wrapper` method. this will allow you to
# use the following in your forms:
#
#   <%= f.wrapper :email, :div, class: "control" do %>
#     <%= f.email_field :email, placeholder: "you@example.com", class: "input is-danger" %>
#   <% end %>
#
# we do it this way, so the wrapper is aware of the model object it's building, and thus the
# wrapped html is passed to the `field_error_proc` so we can customize it if the field has an error
#
# this is heavily synthesized from the ActionView::Helpers::Tags::Label code that's invoked
# when you use `f.label :email ...` in a form here:
# https://github.com/rails/rails/blob/master/actionview/lib/action_view/helpers/tags/label.rb
#
# other relevant files:
# https://github.com/rails/rails/blob/master/actionview/lib/action_view/helpers/form_helper.rb -- where
# the ActionView::Helpers::FormBuilder class and the ActionView::Helpers::FormHelper module are
# defined, and of course the `FormBuilder#label` method
#
module ActionView
  module Helpers
    module Tags
      class Wrapper < Base
        def initialize(object_name, method_name, template_object, tag, options)
          @tag = tag
          super(object_name, method_name, template_object, options)
        end

        def render(&block)
          if block_given?
            content_tag @tag, @template_object.capture(&block), @options
          else
            content_tag @tag, nil, @options
          end
        end
      end
    end
  end
end

class ActionView::Helpers::FormBuilder
  def wrapper(method, tag = :div, options = {}, &block)
    tag, options = :div, tag if tag.is_a?(Hash)
    ActionView::Helpers::Tags::Wrapper.new(@object_name, method, @template, tag, objectify_options(options)).render(&block)
  end
end
# -------------------------------------------------------------------------------------------------

# inspired by: https://rubyplus.com/articles/3401-Customize-Field-Error-in-Rails-5
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  result = html_tag

  if instance.is_a?(ActionView::Helpers::Tags::Wrapper) # ok, we're dealing with our custom helper 💪
    _html_tag = Nokogiri::HTML::DocumentFragment.parse(html_tag)
    wrapper = _html_tag.elements.first

    wrapper['class'] = [wrapper['class'], "is-danger"].compact.join(" ")

    Array(instance.error_message).map(&:humanize).uniq.each do |error|
      _html_tag.add_child(%(<p class="help is-danger">#{error}</p>))
    end

    result = _html_tag.to_s

  else
    form_fields = ['textarea', 'input', 'select']
    elements = Nokogiri::HTML::DocumentFragment.parse(html_tag).css((['label'] + form_fields).join(', '))

    elements.each do |e|
      if e.node_name == 'label'
        # not doing anything, but wanted to capture how to do something for futures 🔮

      elsif form_fields.include?(e.node_name)
        _html_tag = Nokogiri::HTML::DocumentFragment.parse(html_tag)
        form_field = _html_tag.elements.first
        form_field['class'] = [form_field['class'], "is-danger"].compact.join(" ")

        result = _html_tag.to_s
      end
    end
  end

  result.html_safe
end
