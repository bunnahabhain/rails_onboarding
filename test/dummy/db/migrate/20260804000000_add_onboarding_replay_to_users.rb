class AddOnboardingReplayToUsers < ActiveRecord::Migration[8.0]
  def up
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
