require "rails_helper"

RSpec.describe "LTI endpoints", type: :request do
  describe "POST /lti/login" do
    context "with valid client_id" do
      it "redirects to Canvas OIDC auth URL" do
        post lti_login_path, params: {
          client_id:        LtiConfig::CLIENT_ID,
          login_hint:       "user_123",
          lti_message_hint: "hint_abc",
          iss:              "https://canvas.instructure.com"
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(LtiConfig::OIDC_AUTH_URL)
        expect(response.location).to include("client_id=#{LtiConfig::CLIENT_ID}")
        expect(response.location).to include("nonce=")
        expect(response.location).to include("state=")
      end

      it "stores state and nonce in session" do
        post lti_login_path, params: {
          client_id:  LtiConfig::CLIENT_ID,
          login_hint: "user_123"
        }

        expect(session[:lti_state]).to be_present
        expect(session[:lti_nonce]).to be_present
      end
    end

    context "with invalid client_id" do
      it "returns 401" do
        post lti_login_path, params: {
          client_id:  "wrong_client_id",
          login_hint: "user_123"
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /lti/launch" do
    let(:valid_claims) do
      {
        "sub"  => "canvas_user_123",
        "iss"  => "https://canvas.instructure.com",
        "aud"  => [LtiConfig::CLIENT_ID],
        "azp"  => LtiConfig::CLIENT_ID,
        "nonce" => "test_nonce",
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => LtiConfig::DEPLOYMENT_ID,
        "https://purl.imsglobal.org/spec/lti/claim/context" => {
          "id"    => "course_456",
          "label" => "CS101"
        },
        "https://purl.imsglobal.org/spec/lti/claim/roles" => [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
        ],
        "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => {
          "lineitem" => "https://canvas.example.com/api/lti/courses/1/line_items/1"
        }
      }
    end

    before do
      post lti_login_path, params: {
        client_id:  LtiConfig::CLIENT_ID,
        login_hint: "user_123"
      }
      allow_any_instance_of(LtiLaunchValidator).to receive(:validate!).and_return(valid_claims)
    end

    it "creates an LtiLaunch record and redirects to dashboard" do
      expect {
        post lti_launch_path, params: {
          id_token: "fake.jwt.token",
          state:    session[:lti_state]
        }
      }.to change(LtiLaunch, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
    end

    it "stores lti_launch_id in session" do
      post lti_launch_path, params: {
        id_token: "fake.jwt.token",
        state:    session[:lti_state]
      }

      expect(session[:lti_launch_id]).to be_present
    end

    context "with state mismatch" do
      it "returns 401" do
        post lti_launch_path, params: {
          id_token: "fake.jwt.token",
          state:    "wrong_state"
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid JWT" do
      it "returns 401" do
        allow_any_instance_of(LtiLaunchValidator).to receive(:validate!).and_raise(
          LtiLaunchValidator::ValidationError, "bad token"
        )

        post lti_launch_path, params: {
          id_token: "bad.token",
          state:    session[:lti_state]
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /.well-known/jwks.json" do
    let(:test_key) { OpenSSL::PKey::RSA.generate(2048) }
    before { allow(LtiConfig).to receive(:public_key).and_return(test_key) }

    it "returns a JWK set with the public key" do
      get jwks_path
      json = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(json["keys"]).to be_an(Array)
      expect(json["keys"].first["kty"]).to eq("RSA")
    end
  end
end
