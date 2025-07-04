# CCCUX Ownership Guide

## Overview

CCCUX supports **record-level permissions** where users can be granted access to either:
- **All Records**: Full access to all records of a model
- **Owned Records Only**: Access limited to records they own/created

## Setting Up Ownership in the UI

1. **Navigate to Role Management**: Go to `/cccux/roles` and edit a role
2. **Select Model Permissions**: Check the permissions you want to grant (index, show, create, etc.)
3. **Choose Ownership Scope**: For each non-CCCUX model, select:
   - **All Records**: User can access any record of this type
   - **Owned Records Only**: User can only access records they own

## Model Requirements

For the "Owned Records Only" feature to work, your models need to implement ownership methods. CCCUX provides the `Cccux::Authorizable` concern to make this easier:

### Option 1: Include the Authorizable Concern (Recommended)
```ruby
class Order < ApplicationRecord
  include Cccux::Authorizable
  belongs_to :user
  
  # Migration
  # add_column :orders, :user_id, :integer, null: false
  # add_foreign_key :orders, :users
end
```

This provides a convenient `owned` scope:
```ruby
# In your controller
def index
  @orders = Order.owned  # Automatically scoped based on current user's permissions
end
```

### Option 2: Manual Implementation
If you prefer not to use the concern, your models need a **user ownership field**. The most common approaches are:

#### user_id field (Most Common)
```ruby
class Order < ApplicationRecord
  belongs_to :user
  
  # Migration
  # add_column :orders, :user_id, :integer, null: false
  # add_foreign_key :orders, :users
end
```

#### creator_id field  
```ruby
class Article < ApplicationRecord
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  
  # Migration
  # add_column :articles, :creator_id, :integer, null: false
  # add_foreign_key :articles, :users, column: :creator_id
end
```

#### Custom ownership logic
```ruby
class Project < ApplicationRecord
  has_many :project_members
  has_many :users, through: :project_members
  
  def owned_by?(user)
    project_members.where(user: user, role: 'owner').exists?
  end
end
```

## Controller Requirements

### Basic Implementation (user_id field)

For models with a `user_id` field, no controller changes are needed. CCCUX will automatically scope queries using CanCanCan:

```ruby
class OrdersController < ApplicationController
  include Cccux::AuthorizationController
  load_and_authorize_resource  # CanCanCan handles scoping automatically
  
  def index
    # @orders is automatically scoped to current_user.orders if "Owned Records Only"
    # @orders contains all orders if "All Records"
  end
end
```

### Using the Authorizable Concern

If you're using the `Cccux::Authorizable` concern in your models, you can use the convenient `owned` scope:

```ruby
class OrdersController < ApplicationController
  include Cccux::AuthorizationController
  
  def index
    @orders = Order.owned  # Shorter than accessible_by(current_ability)
  end
end
```

### Custom Ownership Logic

For models with custom ownership logic, update your Ability class:

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    
    # Let CCCUX handle basic permissions, then add custom ownership logic
    apply_cccux_permissions(user)
    
    # Override with custom ownership rules if needed
    if user.role&.name == 'Project Member'
      can :read, Project do |project|
        project.owned_by?(user)
      end
    end
  end
  
  private
  
  def apply_cccux_permissions(user)
    return unless user.role
    
    user.role.role_abilities.includes(:ability_permission).each do |role_ability|
      permission = role_ability.ability_permission
      model_class = permission.subject.constantize
      
      if role_ability.owned?
        # Owned records only - customize this based on your ownership pattern
        case permission.subject
        when 'Order'
          can permission.action.to_sym, model_class, user_id: user.id
        when 'Article'  
          can permission.action.to_sym, model_class, creator_id: user.id
        when 'Project'
          can permission.action.to_sym, model_class do |project|
            project.owned_by?(user)
          end
        end
      else
        # All records
        can permission.action.to_sym, model_class
      end
    end
  end
end
```

## URL Scoping Patterns

### Nested Routes (Automatic Scoping)
```ruby
# routes.rb
resources :users do
  resources :orders  # /users/1/orders automatically scopes to that user
end

# controller
class OrdersController < ApplicationController
  before_action :set_user
  
  def index
    @orders = @user.orders  # Naturally scoped to the user
  end
  
  private
  
  def set_user
    @user = User.find(params[:user_id])
    authorize! :read, @user  # Ensure user can access this user's records
  end
end
```

## Testing Ownership

1. **Create two users** with "Basic User" role
2. **Set Order permissions** to "Owned Records Only" for Basic User role
3. **Create orders** with different `user_id` values
4. **Login as each user** and verify they only see their own orders at `/orders`

## Default Behavior

- **CCCUX Models**: Always default to "All Records" (users shouldn't be limited to their own roles/permissions)
- **Application Models**: Default to "All Records" but can be changed to "Owned Records Only"
- **New Permissions**: Default to "All Records" when first created

## Troubleshooting

### "No records showing up"
- Verify your model has a `user_id` field or custom ownership logic
- Check that records have the correct `user_id` set
- Ensure the user has the correct role with appropriate permissions

### "Seeing all records when should see owned only"  
- Verify the role is set to "Owned Records Only" in the CCCUX admin
- Check your Ability class is properly configured
- Ensure `load_and_authorize_resource` is used in controllers

### "Access denied errors"
- Verify the user's role has the necessary permissions (index, show, etc.)
- Check that the ownership field matches the user's ID
- Review your Ability class for any conflicting rules 