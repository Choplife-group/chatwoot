namespace :insights do
  desc 'Fill in market, team and category on reporting events created before they were recorded on every event'
  task backfill_reporting_dimensions: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 10_000).to_i
    max_id = ReportingEvent.maximum(:id).to_i
    updated = 0

    # Old events can't know what the conversation looked like back then, so they take its current values.
    # Values an event already has are kept.
    (0..max_id).step(batch_size) do |start_id|
      updated += ActiveRecord::Base.connection.update(<<~SQL.squish)
        UPDATE reporting_events
        SET market_id = COALESCE(reporting_events.market_id, conversations.market_id),
            team_id = COALESCE(reporting_events.team_id, conversations.team_id),
            category_id = COALESCE(reporting_events.category_id, conversations.category_id)
        FROM conversations
        WHERE conversations.id = reporting_events.conversation_id
          AND reporting_events.id > #{start_id} AND reporting_events.id <= #{start_id + batch_size}
          AND (reporting_events.market_id IS NULL OR reporting_events.team_id IS NULL OR reporting_events.category_id IS NULL)
          AND (conversations.market_id IS NOT NULL OR conversations.team_id IS NOT NULL OR conversations.category_id IS NOT NULL)
      SQL
    end

    puts "Updated #{updated} reporting events"
  end
end
