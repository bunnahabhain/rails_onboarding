class AddOnboardingReplayToUsers < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    # Replay mode: when set, the user is walking the flow again after a
    # restart, and a step's :complete_if is not allowed to advance them past a
    # step they have not been shown yet. See Onboardable#replaying_onboarding?.
    #
    # No DB-level default on the text column: MySQL/MariaDB reject a literal
    # DEFAULT on TEXT, and Onboardable already treats nil as an empty array.
    unless column_exists?(:users, :onboarding_replay_started_at)
      add_column :users, :onboarding_replay_started_at, :datetime
    end

    unless column_exists?(:users, :onboarding_replay_steps)
      add_column :users, :onboarding_replay_steps, :text
    end
  end

  def down
    remove_column :users, :onboarding_replay_steps if column_exists?(:users, :onboarding_replay_steps)
    remove_column :users, :onboarding_replay_started_at if column_exists?(:users, :onboarding_replay_started_at)
  end
end
