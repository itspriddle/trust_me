require "rspec"
require "webmock/rspec"
require "trust_me"

RSpec.configure do |config|
  config.color     = true
  config.order     = "rand"
  config.formatter = "progress"
end

TrustMe.config do |c|
  c.customer_id = "custid"
  c.secret_key  = Base64.encode64("secret")
end
