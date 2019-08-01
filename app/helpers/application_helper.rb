module ApplicationHelper
  def fix_bulmas_default_article_spacing
    # bulma puts a 1.5rem margin-bottom on `.message:not(:last-child)`. this turns it off
    # when we're wrapping our flash messages in a container div
    content_tag(:article, nil, class: "message", style: "display: none;")
  end
  
  def load_stripe_if_this_page_needs_it
    # two things: 1) only load stripe on pages that need it. 2) do it in a way that
    # tells turbolinks to do a full page refresh when moving _on_ to a stripe-enabled page and
    # _away_ from a stripe enabled page.
    #
    # leaving on always (which i think i saw stripe recommend, but can't remember where), seems
    # to cause issues with turbolinks. specifically, you see an error like:
    #
    # ```
    # Failed to execute 'postMessage' on 'DOMWindow': The target origin provided
    # ('https://js.stripe.com') does not match the recipient window's origin ('http://localhost:3000')
    # ```
    #
    # documented here: https://github.com/turbolinks/turbolinks/issues/321
    #
    # my solution is to add data-turbolinks-track to the stripe asset and only load the asset on
    # pages that need it which _i think_ makes turbolinks reload when the asset appears in the <head>
    # or goes missing from the <head>.
    #
    # this will break if two stripe-enabled pages link to each other via turbolinks, but right now
    # they don't. i think this could be solved by also rendering a
    # `<meta name="turbolinks-visit-control" content="reload">` tag when we render the stripe
    # asset which also tells turbolinks to force reload the page.
    #
    # it's worth mentioning, this error _appeared_ to cause chromedriver to quit running tests.
    # you get a mysterious `Errno::ECONNREFUSED` or `EOFError` and the chromedriver running on
    # port (usually) 9516 quits. stripe says this error is benign, but it definitely seemed
    # to hose our system tests.
    #
    if current_page?(new_settings_billing_path) || current_page?(new_settings_subscription_path)
      content_tag(:script, nil, src: "https://js.stripe.com/v3", data: { turbolinks_track: "reload" })
    end
  end
end
