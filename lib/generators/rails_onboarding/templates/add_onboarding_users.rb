class AddOnboardingToUsers < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    add_column :users, :onboarding_completed, :boolean, default: false, null: false
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_current_step, :string
    add_column :users, :onboarding_skipped, :boolean, default: false

    # Use jsonb for PostgreSQL, text for other databases
    if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      add_column :users, :feature_tooltips_shown, :jsonb, default: {}
    else
      add_column :users, :feature_tooltips_shown, :json
    end

    # Performance indexes
    add_index :users, :onboarding_completed
    add_index :users, :onboarding_current_step
    add_index :users, [:onboarding_completed, :created_at], name: 'index_users_on_onboarding_status_and_created'
  end

  def down
    remove_index :users, name: 'index_users_on_onboarding_status_and_created' if index_exists?(:users, [:onboarding_completed, :created_at], name: 'index_users_on_onboarding_status_and_created')
    remove_index :users, :onboarding_current_step if index_exists?(:users, :onboarding_current_step)
    remove_index :users, :onboarding_completed if index_exists?(:users, :onboarding_completed)

    remove_column :users, :feature_tooltips_shown if column_exists?(:users, :feature_tooltips_shown)
    remove_column :users, :onboarding_skipped if column_exists?(:users, :onboarding_skipped)
    remove_column :users, :onboarding_current_step if column_exists?(:users, :onboarding_current_step)
    remove_column :users, :onboarding_completed_at if column_exists?(:users, :onboarding_completed_at)
    remove_column :users, :onboarding_completed if column_exists?(:users, :onboarding_completed)
  end
end
