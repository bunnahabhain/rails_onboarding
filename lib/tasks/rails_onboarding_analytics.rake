namespace :rails_onboarding do
  namespace :analytics do
    desc "Clean up old analytics data based on retention policy"
    task cleanup: :environment do
      unless RailsOnboarding::AnalyticsEvent.table_exists?
        puts "Analytics table not found. Run 'rails generate rails_onboarding:install' first."
        exit 1
      end

      retention_days = RailsOnboarding.configuration.analytics_data_retention_days
      cutoff_date = retention_days.days.ago

      deleted_count = RailsOnboarding::AnalyticsEvent
        .where("occurred_at < ?", cutoff_date)
        .delete_all

      puts "Cleaned up #{deleted_count} analytics events older than #{retention_days} days"
    end

    desc "Generate analytics report for date range"
    task :report, [ :start_date, :end_date ] => :environment do |t, args|
      unless RailsOnboarding::AnalyticsEvent.table_exists?
        puts "Analytics table not found. Run 'rails generate rails_onboarding:install' first."
        exit 1
      end

      start_date = args[:start_date] ? Date.parse(args[:start_date]) : 30.days.ago.to_date
      end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current
      date_range = start_date.beginning_of_day..end_date.end_of_day

      puts "=== Onboarding Analytics Report ==="
      puts "Period: #{start_date} to #{end_date}"
      puts "=" * 40

      completion_rate = RailsOnboarding::Analytics.onboarding_completion_rate(date_range: date_range)
      skip_rate = RailsOnboarding::Analytics.onboarding_skip_rate(date_range: date_range)
      avg_time = RailsOnboarding::Analytics.average_completion_time(date_range: date_range)

      puts "Overall Metrics:"
      puts "  Completion Rate: #{completion_rate}%"
      puts "  Skip Rate: #{skip_rate}%"
      puts "  Average Completion Time: #{avg_time} seconds"
      puts

      step_rates = RailsOnboarding::Analytics.step_completion_rates(date_range: date_range)
      skip_rates = RailsOnboarding::Analytics.step_skip_rates(date_range: date_range)

      puts "Step Performance:"
      RailsOnboarding.configuration.steps.each do |step|
        step_name = step[:name].to_s
        completion = step_rates[step_name] || 0
        skips = skip_rates[step_name] || 0
        puts "  #{step[:title]} (#{step_name}): #{completion}% completion, #{skips}% skip"
      end
      puts

      tooltip_rate = RailsOnboarding::Analytics.tooltip_engagement_rate(date_range: date_range)
      puts "Tooltip Engagement Rate: #{tooltip_rate}%"

      milestone_rates = RailsOnboarding::Analytics.milestone_achievement_rates(date_range: date_range)
      if milestone_rates.any?
        puts
        puts "Milestone Achievement Rates:"
        milestone_rates.each do |milestone, rate|
          puts "  #{milestone}: #{rate}%"
        end
      end
    end

    desc "Export analytics data to CSV"
    task :export, [ :start_date, :end_date, :output_file ] => :environment do |t, args|
      unless RailsOnboarding::AnalyticsEvent.table_exists?
        puts "Analytics table not found. Run 'rails generate rails_onboarding:install' first."
        exit 1
      end

      require "csv"

      start_date = args[:start_date] ? Date.parse(args[:start_date]) : 30.days.ago.to_date
      end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current
      output_file = args[:output_file] || "onboarding_analytics_#{start_date}_to_#{end_date}.csv"

      date_range = start_date.beginning_of_day..end_date.end_of_day
      events = RailsOnboarding::AnalyticsEvent.by_date_range(date_range.begin, date_range.end)

      CSV.open(output_file, "w") do |csv|
        csv << [ "ID", "User Type", "User ID", "Event Type", "Properties", "Session ID", "Occurred At", "Created At" ]

        events.find_each do |event|
          csv << [
            event.id,
            event.user_type,
            event.user_id,
            event.event_type,
            event.properties.to_json,
            event.session_id,
            event.occurred_at,
            event.created_at
          ]
        end
      end

      puts "Exported #{events.count} analytics events to #{output_file}"
    end

    desc "Show funnel analysis"
    task :funnel, [ :start_date, :end_date ] => :environment do |t, args|
      unless RailsOnboarding::AnalyticsEvent.table_exists?
        puts "Analytics table not found. Run 'rails generate rails_onboarding:install' first."
        exit 1
      end

      start_date = args[:start_date] ? Date.parse(args[:start_date]) : 30.days.ago.to_date
      end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current
      date_range = start_date.beginning_of_day..end_date.end_of_day

      funnel = RailsOnboarding::Analytics.funnel_analysis(date_range: date_range)

      puts "=== Onboarding Funnel Analysis ==="
      puts "Period: #{start_date} to #{end_date}"
      puts "=" * 40

      puts "Total Users Started: #{funnel[:total_started]}"
      puts "Overall Completion Rate: #{funnel[:overall_completion_rate]}%"
      puts

      puts "Step-by-Step Funnel:"
      funnel[:steps].each do |step|
        puts "  #{step[:step_index] + 1}. #{step[:step_title]}"
        puts "     Users Reached: #{step[:users_reached]}"
        puts "     Retention Rate: #{step[:retention_rate]}%"
        puts
      end
    end
  end
end
