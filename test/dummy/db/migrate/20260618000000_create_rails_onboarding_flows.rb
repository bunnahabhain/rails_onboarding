class CreateRailsOnboardingFlows < ActiveRecord::Migration[8.1]
  def change
    create_table :rails_onboarding_flows do |t|
      t.string :name, null: false
      t.text :description
      t.text :steps, null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :rails_onboarding_flows, :active
  end
end
