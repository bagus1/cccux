class CreateCccuxRoleAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_role_abilities do |t|
      t.references :role, null: false, foreign_key: { to_table: :cccux_roles }
      t.references :ability_permission, null: false, foreign_key: { to_table: :cccux_ability_permissions }

      t.timestamps
    end
  end
end
