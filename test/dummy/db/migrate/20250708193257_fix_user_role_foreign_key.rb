class FixUserRoleForeignKey < ActiveRecord::Migration[7.2]
  def change
    # Only run this migration if the table exists
    if table_exists?(:cccux_user_roles)
      # Remove the existing foreign key constraint if it exists
      if foreign_key_exists?(:cccux_user_roles, :cccux_users, column: :user_id)
        remove_foreign_key :cccux_user_roles, :cccux_users, column: :user_id
      end
      
      # Add the correct foreign key constraint
      add_foreign_key :cccux_user_roles, :users, column: :user_id
    end
  end
end
