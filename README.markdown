# TrustMe

This library is a wrapper for the TeleSign REST API. Currently the Verify Call
and Verify SMS web services are supported. The Verify Call web service sends a
verification code to a user in a voice message with a phone call. The Verify
SMS web service sends a verification code to a user in a text message via SMS.
The user enters this code in a web application to verify their identity.

See also:
  - <http://docs.telesign.com/rest/content/verify-call.html>
  - <http://docs.telesign.com/rest/content/verify-sms.html>

## Configuration

Set global credentials:

```ruby
TrustMe.config do |c|
  c.customer_id = "1234"
  c.secret_key  = "secret"
end
```

If you need different credentials per-instance:

```ruby
trust_me = TrustMe.new "5678", "secret2"
```

## Usage

Send a verification call to a customer and save the verification code:

```ruby
class VerifyController < ApplicationController
  def create
    trust_me = TrustMe.new
    call     = trust_me.send_verification_call! current_user.phone

    current_user.update_attribute! :verification_code, call[:code]
  end
end
```

Or send a verification SMS to a customer:

```ruby
class VerifyController < ApplicationController
  def create
    trust_me = TrustMe.new
    sms     = trust_me.send_verification_sms! current_user.phone

    current_user.update_attribute! :verification_code, sms[:code]
  end
end
```

The customer verifies the code:

```ruby
class VerifyController < ApplicationController
  def update
    if params[:code] == current_user.verification_code
      current_user.set_verified!
    end
  end
end
```

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so we don't break it in a future version
  unintentionally.
* Commit, do not bump version. (If you want to have your own version, that is
  fine but bump version in a commit by itself we can ignore when we pull).
* Send us a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2014 WWWH, LLC. See LICENSE for details.
