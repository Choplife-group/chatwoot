require 'rails_helper'

describe '/widget_tests', type: :request do
  let(:web_widget) { create(:channel_widget) }

  before { web_widget }

  describe 'GET /widget_tests' do
    it 'is not found by default' do
      get widget_tests_url

      expect(response).to have_http_status(:not_found)
    end

    it 'is not found when turned off' do
      with_modified_env ENABLE_WIDGET_TEST_PAGE: 'false' do
        get widget_tests_url

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when ENABLE_WIDGET_TEST_PAGE is true' do
      it 'renders the widget of the requested inbox' do
        with_modified_env ENABLE_WIDGET_TEST_PAGE: 'true' do
          get widget_tests_url, params: { inbox_id: web_widget.inbox.id }

          expect(response).to have_http_status(:success)
          expect(response.body).to include(web_widget.website_token)
        end
      end

      it 'does not put a signed identity in the page in production' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        hash = OpenSSL::HMAC.hexdigest('sha256', web_widget.hmac_token, '1')

        with_modified_env ENABLE_WIDGET_TEST_PAGE: 'true' do
          get widget_tests_url, params: { inbox_id: web_widget.inbox.id }

          expect(response.body).not_to include(hash)
        end
      end
    end
  end
end
