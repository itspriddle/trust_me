require "spec_helper"

describe TrustMe do
  let :trust_me do
    TrustMe.new
  end

  let :now do
    Time.utc 2014, 11, 13, 12, 20, 00
  end

  let :now_rfc1123 do
    "Thu, 13 Nov 2014 12:20:00 GMT"
  end

  let :uuid do
    "3846B06C-C3C1-4C36-9426-2317B5C96C78"
  end

  before do
    allow(Time).to receive(:now) { now }
    allow(SecureRandom).to receive(:uuid) { uuid }
  end

  shared_examples_for "api_call" do |method, extra_request_params = {}|
    let :response_body do
      File.read("spec/fixtures/verify-#{method}-success.json")
    end

    let :request_headers do
      {
        "Authorization"    => /TSA custid:.*/,
        "x-ts-date"        => now_rfc1123,
        "x-ts-auth-method" => "HMAC-SHA256",
        "x-ts-nonce"       => uuid,
        "Content-Type"     => "application/x-www-form-urlencoded",

        # Set automatically by Net::HTTP
        "Accept"           => "*/*",
        "Accept-Encoding"  => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "User-Agent"       => "Ruby"
      }
    end

    let :request_body do
      {
        "language"     => "en-US",
        "phone_number" => "15554443333",
        "ucid"         => "TRVF",
        "verify_code"  => "12345"
      }.merge(extra_request_params)
    end

    before do
      allow(trust_me).to receive(:generate_code) { "12345" }
    end

    let! :stub do
      stub_request(:post, "#{TrustMe::API_URL}/v1/verify/#{method}")
        .with(:headers => request_headers, :body => request_body)
        .to_return(:body => response_body)
    end
  end

  describe "#send_verification_call!" do
    it_behaves_like "api_call", "call" do
      it "submits the request" do
        trust_me.send_verification_call! "15554443333"

        expect(stub).to have_been_made
      end

      it "returns the the data and code" do
        response = trust_me.send_verification_call! "15554443333"

        expect(response[:code]).to eq("12345")
        expect(response[:data]).to eq(JSON.parse(response_body))
      end
    end
  end

  describe "#send_verification_sms!" do
    it_behaves_like "api_call", "sms", { :template => "CODE: $$CODE$$" } do
      it "submits the request" do
        trust_me.send_verification_sms! "15554443333", :template => "CODE: $$CODE$$"

        expect(stub).to have_been_made
      end

      it "returns the the data and code" do
        response = trust_me.send_verification_sms! "15554443333", :template => "CODE: $$CODE$$"

        expect(response[:code]).to eq("12345")
        expect(response[:data]).to eq(JSON.parse(response_body))
      end
    end
  end

  describe "#generate_headers" do
    let :hash do
      OpenSSL::Digest.new("sha256", "abc")
    end

    let :params do
      "a=1&b=2"
    end

    let :resource do
      "/some/resource"
    end

    before do
      allow(OpenSSL::Digest::SHA256).to receive(:digest) { hash }
    end

    let :auth do
      content = [
        "POST",
        "application/x-www-form-urlencoded",
        "",
        "x-ts-auth-method:HMAC-SHA256",
        "x-ts-date:#{now_rfc1123}",
        "x-ts-nonce:#{uuid}",
        params,
        resource
      ].join("\n")

      Base64.encode64 OpenSSL::HMAC.digest(hash, "secret", content)
    end

    it "returns proper headers" do
      headers = trust_me.generate_headers(:params => params, :resource => resource)

      expect(headers["Authorization"]).to eq "TSA custid:#{auth}"
      expect(headers["Content-Type"]).to eq "application/x-www-form-urlencoded"
      expect(headers["x-ts-date"]).to eq now_rfc1123
      expect(headers["x-ts-auth-method"]).to eq "HMAC-SHA256"
      expect(headers["x-ts-nonce"]).to eq uuid
    end
  end
end
