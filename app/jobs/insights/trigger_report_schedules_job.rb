# Finds report schedules that are due and hands each one to DeliverReportScheduleJob
class Insights::TriggerReportSchedulesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ReportSchedule.due.find_each do |schedule|
      # Moving the next run first, only if nothing else already has, means each run goes out once even when this job overlaps itself
      moved = ReportSchedule.where(id: schedule.id, next_run_at: schedule.next_run_at)
                            .update_all(next_run_at: schedule.next_run_after(Time.current)) # rubocop:disable Rails/SkipsModelValidations
      Insights::DeliverReportScheduleJob.perform_later(schedule.id) if moved == 1
    end
  end
end
