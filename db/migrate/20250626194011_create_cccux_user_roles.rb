class CreateCccuxUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_user_roles do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :role, null: false, foreign_key: { to_table: :cccux_roles }

      t.timestamps
    end
    
    # Add unique index to prevent duplicate user-role assignments
    add_index :cccux_user_roles, [:user_id, :role_id], unique: true
  end
end
