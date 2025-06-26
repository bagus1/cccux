class CreateCccuxAbilityPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :cccux_ability_permissions do |t|
      t.string :action, null: false
      t.string :subject, null: false
      t.text :description
      t.boolean :active, default: true

      t.timestamps null: false
    end

    add_index :cccux_ability_permissions, [:action, :subject], unique: true, name: 'index_cccux_ability_permissions_on_action_and_subject'
    add_index :cccux_ability_permissions, :subject
    add_index :cccux_ability_permissions, :action
    add_index :cccux_ability_permissions, :active
  end
end 