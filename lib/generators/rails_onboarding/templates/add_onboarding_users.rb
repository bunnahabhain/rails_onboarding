class AddOnboardingToUsers < ActiveRecord::Migration[Rails::VERSION::MAJOR.Rails::VERSION::MINOR]
  def change
    add_column :users, :onboarding_completed, :boolean, default: false, null: false
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_current_step, :string
    add_column :users, :onboarding_skipped, :boolean, default: false

    # Use jsonb for PostgreSQL, text for other databases
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      add_column :users, :feature_tooltips_shown, :jsonb, default: {}
    else
      add_column :users, :feature_tooltips_shown, :json
    end

    add_index :users, :onboarding_completed
  end
end
