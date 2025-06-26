class CreateCccuxRoleAbilities < ActiveRecord::Migration[7.1]
  def change
    create_table :cccux_role_abilities do |t|
      t.references :role, null: false, foreign_key: { to_table: :cccux_roles }
      t.references :ability_permission, null: false, foreign_key: { to_table: :cccux_ability_permissions }

      t.timestamps null: false
    end

    add_index :cccux_role_abilities, [:role_id, :ability_permission_id], unique: true, name: 'index_cccux_role_abilities_on_role_and_permission'
  end
end