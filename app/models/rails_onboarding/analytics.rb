module RailsOnboarding
  class Analytics
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
        
        return 0.0 if completion_events.empty?
        
        total_time = completion_events.sum do |event|
          event.properties&.dig('completion_time_seconds').to_f
        end
        
        (total_time / completion_events.count).round(2)
      end

      def step_completion_rates(date_range: nil)
        events = base_events_query(date_range)
        
        step_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_COMPLETED)
        
        step_counts = step_events.group_by { |e| e.properties&.dig('step_name') }
                                .transform_values(&:count)
        
        total_users = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return {} if total_users.zero?
        
        step_counts.transform_values do |count|
          (count.to_f / total_users * 100).round(2)
        end
      end

      def step_skip_rates(date_range: nil)
        events = base_events_query(date_range)
        
        skip_events = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_SKIPPED)
        
        step_skips = skip_events.group_by { |e| e.properties&.dig('step_name') }
                               .transform_values(&:count)
        
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
        
        step_times = step_events.group_by { |e| e.properties&.dig('step_name') }
        
        step_times.transform_values do |events_for_step|
          times = events_for_step.map { |e| e.properties&.dig('time_spent_seconds').to_f }
          times.any? ? (times.sum / times.count).round(2) : 0.0
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
        
        features = tooltip_events.map { |e| e.properties&.dig('tooltip_feature') }.compact.uniq
        
        features.map do |feature|
          feature_events = tooltip_events.select { |e| e.properties&.dig('tooltip_feature') == feature }
          
          shown = feature_events.count { |e| e.event_type == AnalyticsEvent::TOOLTIP_SHOWN }
          clicked = feature_events.count { |e| e.event_type == AnalyticsEvent::TOOLTIP_CLICKED }
          dismissed = feature_events.count { |e| e.event_type == AnalyticsEvent::TOOLTIP_DISMISSED }
          
          engagement_rate = shown > 0 ? (clicked.to_f / shown * 100).round(2) : 0.0
          
          {
            feature: feature,
            shown: shown,
            clicked: clicked,
            dismissed: dismissed,
            engagement_rate: engagement_rate
          }
        end
      end

      def milestone_achievement_rates(date_range: nil)
        events = base_events_query(date_range)
        
        milestone_events = events.by_event_type(AnalyticsEvent::MILESTONE_ACHIEVED)
        
        milestone_counts = milestone_events.group_by { |e| e.properties&.dig('milestone_key') }
                                          .transform_values(&:count)
        
        total_users = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        return {} if total_users.zero?
        
        milestone_counts.transform_values do |count|
          (count.to_f / total_users * 100).round(2)
        end
      end

      def funnel_analysis(date_range: nil)
        events = base_events_query(date_range)
        
        started = events.by_event_type(AnalyticsEvent::ONBOARDING_STARTED).count
        
        steps = RailsOnboarding.configuration.steps.map.with_index do |step, index|
          completed = events.by_event_type(AnalyticsEvent::ONBOARDING_STEP_COMPLETED)
                           .select { |e| e.properties&.dig('step_name').to_s == step[:name].to_s }
                           .count
          
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