class AddActiveToCccuxUserRoles < ActiveRecord::Migration[7.2]
  def change
    # Only add the column if the table exists
    if table_exists?(:cccux_user_roles)
      add_column :cccux_user_roles, :active, :boolean
    end
  end
end
