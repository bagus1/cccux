class CreateCccuxRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :cccux_roles do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true
      t.integer :priority, default: 0

      t.timestamps null: false
    end

    add_index :cccux_roles, :name, unique: true
    add_index :cccux_roles, :active
    add_index :cccux_roles, :priority
  end
end 