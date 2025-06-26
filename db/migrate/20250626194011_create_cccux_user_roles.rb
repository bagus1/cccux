class CreateCccuxUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_user_roles do |t|
      t.references :user, null: false, foreign_key: { to_table: :cccux_users }
      t.references :role, null: false, foreign_key: { to_table: :cccux_roles }

      t.timestamps
    end
  end
end
