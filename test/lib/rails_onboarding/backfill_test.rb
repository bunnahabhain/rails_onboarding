# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  class BackfillTest < ActiveSupport::TestCase
    def setup
      # Fixture users sit mid-flow; the backfill must ignore those, so build
      # the legacy population explicitly instead of relying on fixtures.
      @legacy = User.create!(
        email: "legacy@example.com",
        created_at: 2.years.ago,
        onboarding_completed: false,
        onboarding_current_step: nil
      )
    end

    test "marks users who never started onboarding as completed" do
      result = Backfill.mark_existing_users_onboarded

      assert_equal 1, result.updated
      assert_predicate @legacy.reload, :onboarding_completed?
    end

    test "dates completion from the user's own created_at" do
      Backfill.mark_existing_users_onboarded

      assert_in_delta @legacy.created_at.to_i,
        @legacy.reload.onboarding_completed_at.to_i,
        1
    end

    test "falls back to the given timestamp when created_at is NULL" do
      null_created_at_user!(@legacy)
      fallback = Time.current.change(usec: 0)

      Backfill.mark_existing_users_onboarded(completed_at: fallback)

      assert_in_delta fallback.to_i, @legacy.reload.onboarding_completed_at.to_i, 1
    end

    test "leaves users who are mid-flow alone" do
      in_progress = User.create!(
        email: "in_progress@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome"
      )

      Backfill.mark_existing_users_onboarded

      refute_predicate in_progress.reload, :onboarding_completed?
      assert_equal "welcome", in_progress.onboarding_current_step
    end

    test "leaves users who deliberately skipped onboarding alone" do
      skipped = User.create!(
        email: "skipped@example.com",
        onboarding_completed: false,
        onboarding_current_step: nil,
        onboarding_skipped: true
      )

      Backfill.mark_existing_users_onboarded

      refute_predicate skipped.reload, :onboarding_completed?
    end

    test "is idempotent - a second run matches nothing" do
      Backfill.mark_existing_users_onboarded
      completed_at = @legacy.reload.onboarding_completed_at

      second_run = Backfill.mark_existing_users_onboarded

      assert_equal 0, second_run.matched
      assert_equal completed_at.to_i, @legacy.reload.onboarding_completed_at.to_i
    end

    test "normalizes a NULL onboarding_skipped to false" do
      @legacy.update_columns(onboarding_skipped: nil)

      Backfill.mark_existing_users_onboarded

      assert_equal false, @legacy.reload.onboarding_skipped
    end

    test "BEFORE cutoff excludes users created after it" do
      recent = User.create!(
        email: "recent@example.com",
        created_at: 1.day.ago,
        onboarding_completed: false,
        onboarding_current_step: nil
      )

      Backfill.mark_existing_users_onboarded(created_before: 1.month.ago)

      assert_predicate @legacy.reload, :onboarding_completed?
      refute_predicate recent.reload, :onboarding_completed?
    end

    test "a cutoff still includes users with a NULL created_at" do
      null_created_at_user!(@legacy)

      Backfill.mark_existing_users_onboarded(created_before: 1.month.ago)

      assert_predicate @legacy.reload, :onboarding_completed?
    end

    test "accepts a string cutoff" do
      Backfill.mark_existing_users_onboarded(created_before: 1.month.ago.to_date.to_s)

      assert_predicate @legacy.reload, :onboarding_completed?
    end

    test "dry run reports the count without writing" do
      result = Backfill.mark_existing_users_onboarded(dry_run: true)

      assert_predicate result, :dry_run?
      assert_equal 1, result.matched
      assert_equal 0, result.updated
      refute_predicate @legacy.reload, :onboarding_completed?
    end

    test "records no analytics events for backfilled users" do
      assert_no_difference -> { AnalyticsEvent.count } do
        Backfill.mark_existing_users_onboarded
      end
    end

    test "spans multiple batches" do
      3.times { |i| User.create!(email: "batched_#{i}@example.com", onboarding_completed: false) }

      result = Backfill.mark_existing_users_onboarded(batch_size: 2)

      assert_equal 4, result.matched
      assert_equal 4, result.updated
    end

    private

    # update_columns rather than update! - Rails' timestamp handling would
    # write created_at straight back.
    def null_created_at_user!(user)
      user.update_columns(created_at: nil)
    end
  end
end
