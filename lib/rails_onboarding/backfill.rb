# frozen_string_literal: true

module RailsOnboarding
  # One-shot data fixes for applications that installed RailsOnboarding on top
  # of an existing users table.
  #
  # Users who signed up before the gem was installed have NULL onboarding
  # columns, so the admin reports them as "Not Started" and - depending on the
  # +onboarding_required_for+ strategy - they can be pushed back through a flow
  # they have no business seeing. Backfilling marks them as already onboarded.
  #
  # Everything here writes with +update_all+ in batches: no callbacks, no
  # validations, and deliberately no analytics events. Backfilled users never
  # went through onboarding, so recording completion events for them would put
  # fiction into the funnel metrics.
  module Backfill
    DEFAULT_BATCH_SIZE = 1_000

    REQUIRED_COLUMNS = %w[
      onboarding_completed
      onboarding_completed_at
      onboarding_current_step
    ].freeze

    Result = Struct.new(:matched, :updated, :dry_run, keyword_init: true) do
      def dry_run?
        dry_run
      end
    end

    class << self
      # Marks pre-existing users as having finished onboarding.
      #
      # Only users who have never engaged with onboarding are touched: not
      # completed, not skipped, and sitting on no current step. Anyone
      # mid-flow is left alone so a backfill can be re-run safely while the
      # app is live.
      #
      # @param created_before [Time, Date, String, nil] restrict to users
      #   created before this moment. Users with a NULL +created_at+ are
      #   always included when a cutoff is given - a row with no creation
      #   timestamp predates any cutoff worth naming, and those rows are
      #   exactly the legacy ones this task exists for.
      # @param completed_at [Time] timestamp used for users whose +created_at+
      #   is NULL. Users with a +created_at+ get their own signup time, which
      #   keeps completion-over-time charts from spiking on backfill day.
      # @param batch_size [Integer] rows per UPDATE statement.
      # @param dry_run [Boolean] count the affected rows without writing.
      # @return [Result]
      def mark_existing_users_onboarded(created_before: nil, completed_at: Time.current,
        batch_size: DEFAULT_BATCH_SIZE, dry_run: false)
        ensure_columns!

        scope = pending_scope(created_before: created_before)
        matched = scope.count
        return Result.new(matched: matched, updated: 0, dry_run: true) if dry_run

        updated = 0
        scope.in_batches(of: batch_size) do |batch|
          updated += batch.update_all(completion_assignment(completed_at))
        end

        Result.new(matched: matched, updated: updated, dry_run: false)
      end

      # Users the backfill would touch. Exposed so callers can inspect or
      # further narrow the set before running.
      def pending_scope(created_before: nil)
        scope = user_class
          .where(onboarding_current_step: nil)
          .where(onboarding_completed: [ false, nil ])

        scope = scope.where(onboarding_skipped: [ false, nil ]) if column?("onboarding_skipped")
        return scope unless created_before

        cutoff = normalize_time(created_before)
        scope.where("#{quoted_table}.created_at < ? OR #{quoted_table}.created_at IS NULL", cutoff)
      end

      def user_class
        RailsOnboarding.configuration.user_class_name.constantize
      end

      private

      def completion_assignment(fallback_completed_at)
        assignments = [
          "onboarding_completed = ?",
          "onboarding_completed_at = COALESCE(#{quoted_table}.created_at, ?)"
        ]
        values = [ true, normalize_time(fallback_completed_at) ]

        # Columns added with `default: false` but no NOT NULL constraint can
        # still hold NULL on rows written before the default landed, which
        # makes `onboarding_skipped?` return nil-ish garbage in the admin.
        if column?("onboarding_skipped")
          assignments << "onboarding_skipped = COALESCE(#{quoted_table}.onboarding_skipped, ?)"
          values << false
        end

        user_class.sanitize_sql_for_assignment([ assignments.join(", "), *values ])
      end

      def ensure_columns!
        missing = REQUIRED_COLUMNS.reject { |name| column?(name) }
        return if missing.empty?

        raise ArgumentError,
          "#{user_class.name} is missing onboarding columns: #{missing.join(', ')}. " \
          "Run the RailsOnboarding install migrations first."
      end

      def column?(name)
        user_class.column_names.include?(name)
      end

      def quoted_table
        user_class.connection.quote_table_name(user_class.table_name)
      end

      def normalize_time(value)
        case value
        when String then Time.zone ? Time.zone.parse(value) : Time.parse(value)
        when Date then value.to_time
        else value
        end
      end
    end
  end
end
