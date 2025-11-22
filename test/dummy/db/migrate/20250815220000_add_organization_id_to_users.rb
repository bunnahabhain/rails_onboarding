# frozen_string_literal: true

class AddOrganizationIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :organization_id, :integer
    add_index :users, :organization_id
  end
end
