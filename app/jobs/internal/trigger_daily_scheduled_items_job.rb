class Internal::TriggerDailyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  # Choplife fork: the daily Chatwoot hub version check is not scheduled, so the
  # app never contacts Chatwoot's servers on its own. Enterprise extends this job.
  def perform; end
end

Internal::TriggerDailyScheduledItemsJob.prepend_mod_with('Internal::TriggerDailyScheduledItemsJob')
