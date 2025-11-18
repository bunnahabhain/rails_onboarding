module RailsOnboarding
  class Analytics
    # Default pagination settings to prevent memory issues
    DEFAULT_PAGE_SIZE = 1000
    MAX_PAGE_SIZE = 10000

    class << self
      # Summary methods for analytics reporting
      
      def onboarding_completion_rate(date_range: nil)
        events = base_events_query(date_range)
        
        started_count = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return 0.0 if started_count.zero?
        
        completed_count = events.by_event_type(AnalyticsEvent::ONBOARDING_COMPLETED).count
        
        (completed_count.to_f / started_count * 100).round(2)
      end

      def onboarding_skip_rate(date_range: nil)
        events = base_events_query(date_range)
        
        started_count = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return 0.0 if started_count.zero?
        
        skipped_count = events.by_event_type(AnalyticsEvent::ONBOARDING_SKIPPED).count
        
        (skipped_count.to_f / started_count * 100).round(2)
      end

      def average_completion_time(date_range: nil)
        events = base_events_query(date_range)

        completion_events = events.by_event_type(AnalyticsEvent::ONBOARDING_COMPLETED)
                                  .where("JSON_EXTRACT(properties, '$.completion_time_seconds') IS NOT NULL")

        count = completion_events.count
        return 0.0 if count.zero?

        # Process in batches to prevent memory issues
        total_time = 0.0
        completion_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          total_time += event.properties&.dig('completion_time_seconds').to_f
        end

        (total_time / count).round(2)
      end

      def step_completion_rates(date_range: nil)
        events = base_events_query(date_range)

        step_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_COMPLETED)

        # Process in batches to prevent memory issues
        step_counts = Hash.new(0)
        step_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          step_name = event.properties&.dig('step_name')
          step_counts[step_name] += 1 if step_name
        end

        total_users = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return {} if total_users.zero?

        step_counts.transform_values do |count|
          (count.to_f / total_users * 100).round(2)
        end
      end

      def step_skip_rates(date_range: nil)
        events = base_events_query(date_range)

        skip_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_SKIPPED)

        # Process in batches to prevent memory issues
        step_skips = Hash.new(0)
        skip_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          step_name = event.properties&.dig('step_name')
          step_skips[step_name] += 1 if step_name
        end

        total_users = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return {} if total_users.zero?

        step_skips.transform_values do |count|
          (count.to_f / total_users * 100).round(2)
        end
      end

      def average_step_completion_times(date_range: nil)
        events = base_events_query(date_range)

        step_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_COMPLETED)
                           .where("JSON_EXTRACT(properties, '$.time_spent_seconds') IS NOT NULL")

        # Process in batches to prevent memory issues
        step_times = Hash.new { |h, k| h[k] = { total: 0.0, count: 0 } }
        step_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          step_name = event.properties&.dig('step_name')
          time_spent = event.properties&.dig('time_spent_seconds').to_f
          if step_name && time_spent > 0
            step_times[step_name][:total] += time_spent
            step_times[step_name][:count] += 1
          end
        end

        step_times.transform_values do |data|
          data[:count] > 0 ? (data[:total] / data[:count]).round(2) : 0.0
        end
      end

      def tooltip_engagement_rate(date_range: nil)
        events = base_events_query(date_range)
        
        shown_count = events.by_event_type(AnalyticsEvent::TOOLTIP_SHOWN).count
        return 0.0 if shown_count.zero?
        
        clicked_count = events.by_event_type(AnalyticsEvent::TOOLTIP_CLICKED).count
        
        (clicked_count.to_f / shown_count * 100).round(2)
      end

      def tooltip_metrics_by_feature(date_range: nil)
        events = base_events_query(date_range)

        tooltip_events = events.where(event_type: [
          AnalyticsEvent::TOOLTIP_SHOWN,
          AnalyticsEvent::TOOLTIP_CLICKED,
          AnalyticsEvent::TOOLTIP_DISMISSED
        ])

        # Process in batches to prevent memory issues
        feature_metrics = Hash.new { |h, k| h[k] = { shown: 0, clicked: 0, dismissed: 0 } }
        tooltip_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          feature = event.properties&.dig('tooltip_feature')
          next unless feature

          case event.event_type
          when AnalyticsEvent::TOOLTIP_SHOWN
            feature_metrics[feature][:shown] += 1
          when AnalyticsEvent::TOOLTIP_CLICKED
            feature_metrics[feature][:clicked] += 1
          when AnalyticsEvent::TOOLTIP_DISMISSED
            feature_metrics[feature][:dismissed] += 1
          end
        end

        feature_metrics.map do |feature, metrics|
          engagement_rate = metrics[:shown] > 0 ? (metrics[:clicked].to_f / metrics[:shown] * 100).round(2) : 0.0

          {
            feature: feature,
            shown: metrics[:shown],
            clicked: metrics[:clicked],
            dismissed: metrics[:dismissed],
            engagement_rate: engagement_rate
          }
        end
      end

      def milestone_achievement_rates(date_range: nil)
        events = base_events_query(date_range)

        milestone_events = events.by_event_type(AnalyticsEvent::MILESTONE_ACHIEVED)

        # Process in batches to prevent memory issues
        milestone_counts = Hash.new(0)
        milestone_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          milestone_key = event.properties&.dig('milestone_key')
          milestone_counts[milestone_key] += 1 if milestone_key
        end

        total_users = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return {} if total_users.zero?

        milestone_counts.transform_values do |count|
          (count.to_f / total_users * 100).round(2)
        end
      end

      def funnel_analysis(date_range: nil)
        events = base_events_query(date_range)

        started = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count

        # Build step completion counts in batches
        step_completed_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_COMPLETED)
        step_completion_counts = Hash.new(0)
        step_completed_events.find_each(batch_size: DEFAULT_PAGE_SIZE) do |event|
          step_name = event.properties&.dig('step_name').to_s
          step_completion_counts[step_name] += 1 if step_name.present?
        end

        steps = RailsOnboarding.configuration.steps.map.with_index do |step, index|
          completed = step_completion_counts[step[:name].to_s] || 0
          retention_rate = started > 0 ? (completed.to_f / started * 100).round(2) : 0.0

          {
            step_name: step[:name],
            step_index: index,
            step_title: step[:title],
            users_reached: completed,
            retention_rate: retention_rate
          }
        end

        completed = events.by_event_type(AnalyticsEvent::ONBOARDING_COMPLETED).count
        overall_completion = started > 0 ? (completed.to_f / started * 100).round(2) : 0.0

        {
          total_started: started,
          overall_completion_rate: overall_completion,
          steps: steps
        }
      end

      def daily_summary(date: Date.current)
        date_range = date.beginning_of_day..date.end_of_day
        
        {
          date: date,
          onboarding_started: base_events_query(date_range).by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count,
          onboarding_completed: base_events_query(date_range).by_event_type(AnalyticsEvent::ONBOARDING_COMPLETED).count,
          onboarding_skipped: base_events_query(date_range).by_event_type(AnalyticsEvent::ONBOARDING_SKIPPED).count,
          tooltips_shown: base_events_query(date_range).by_event_type(AnalyticsEvent::TOOLTIP_SHOWN).count,
          tooltips_clicked: base_events_query(date_range).by_event_type(AnalyticsEvent::TOOLTIP_CLICKED).count,
          milestones_achieved: base_events_query(date_range).by_event_type(AnalyticsEvent::MILESTONE_ACHIEVED).count
        }
      end

      private

      def base_events_query(date_range = nil)
        return AnalyticsEvent.none unless AnalyticsEvent.table_exists?
        
        query = AnalyticsEvent.all
        query = query.by_date_range(date_range.begin, date_range.end) if date_range
        query
      rescue ActiveRecord::StatementInvalid
        # Return empty relation if table doesn't exist
        AnalyticsEvent.none
      end
    end
  end
end