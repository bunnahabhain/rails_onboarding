class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.boolean :onboarding_completed
      t.datetime :onboarding_completed_at
      t.string :onboarding_current_step
      t.boolean :onboarding_skipped
      t.text :feature_tooltips_shown
      t.text :milestones_achieved
      t.integer :milestone_points
      t.datetime :last_milestone_at

      t.timestamps
    end
  end
end
