class CreateRailsOnboardingFlows < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    create_table :rails_onboarding_flows do |t|
      t.string :name, null: false
      t.text :description
      t.text :steps, null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :rails_onboarding_flows, :active
  end

  def down
    drop_table :rails_onboarding_flows if table_exists?(:rails_onboarding_flows)
  end
end
