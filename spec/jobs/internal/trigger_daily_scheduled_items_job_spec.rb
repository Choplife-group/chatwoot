require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  it 'does not schedule the Chatwoot hub version check, even in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Internal::CheckNewVersionsJob).to receive(:set)

    described_class.perform_now

    expect(Internal::CheckNewVersionsJob).not_to have_received(:set)
  end
end
