class CreateCccuxUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :cccux_users do |t|
      t.string :email, null: false, default: ""
      t.string :first_name
      t.string :last_name
      t.boolean :active, default: true
      t.text :notes

      t.timestamps null: false
    end

    add_index :cccux_users, :email, unique: true
    add_index :cccux_users, :active
  end
end 