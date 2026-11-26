require 'rails_helper'

RSpec.describe 'API Base', type: :request do
  describe 'request to api base url' do
    it 'returns api version' do
      get '/api/'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(Chatwoot.config[:version])
      expect(response.body).to include('queue_services')
      expect(response.body).to include('data_services')
    end

    it 'reports the database as ok when it answers' do
      get '/api/'
      expect(response.parsed_body['data_services']).to eq('ok')
    end

    it 'reports the database as failing when it does not answer' do
      allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)
      get '/api/'
      expect(response.parsed_body['data_services']).to eq('failing')
    end
  end
end
