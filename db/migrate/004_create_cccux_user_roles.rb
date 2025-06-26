class CreateCccuxUserRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :cccux_user_roles do |t|
      t.references :user, null: false, foreign_key: { to_table: :cccux_users }
      t.references :role, null: false, foreign_key: { to_table: :cccux_roles }

      t.timestamps null: false
    end

    add_index :cccux_user_roles, [:user_id, :role_id], unique: true, name: 'index_cccux_user_roles_on_user_id_and_role_id'
  end
end