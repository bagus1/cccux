# CCCUX Quick Reference

## Controller Inheritance

| Use Case | Inherit From | Features |
|----------|--------------|----------|
| CCCUX admin controllers | `CccuxController` | Admin layout, full authorization |
| Host app resource controllers | `ApplicationController` | Your layout, CCCUX authorization (inherited) |
| Custom authorization logic | `ApplicationController` | Manual setup required |

## Required Setup

### ApplicationController
```ruby
class ApplicationController < ActionController::Base
  # Include CanCanCan authorization
  include CanCan::ControllerAdditions
  
  # Include CCCUX authorization helpers
  helper Cccux::AuthorizationHelper
  
  # Make current_ability available to models for the owned scope
  before_action :set_current_ability_for_models
  
  # Handle CanCan authorization errors gracefully
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: 'Access denied.'
  end
  
  protected
  
  # Override current_ability to use CCCUX Ability class
  def current_ability
    @current_ability ||= Cccux::Ability.new(current_user)
  end
  
  # Make current_ability available to models for the owned scope
  def set_current_ability_for_models
    Thread.current[:current_ability] = current_ability
  end
end
```

### User Model
```ruby
class User < ApplicationRecord
  include Cccux::UserConcern
  # ... your existing code
end
```

## Controller Patterns

### Basic Resource Controller (Recommended)
```ruby
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    # Use the owned scope for clean, consistent authorization
    @orders = Order.owned.order(:created_at)
  end
  
  def show
    # @order automatically loaded and authorized
  end
end
```

### Custom Queries (Use owned scope)
```ruby
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    if params[:store_id]
      store = Store.find(params[:store_id])
      @orders = store.orders.owned  # Use owned scope
    else
      @orders = Order.owned  # Use owned scope
    end
  end
end
```

### Skip Authorization
```ruby
class DashboardController < ApplicationController
  skip_load_and_authorize_resource
  
  def index
    # No automatic authorization
  end
end
```

## Model Ownership Patterns

### Using Authorizable Concern (Recommended)
```ruby
class Order < ApplicationRecord
  include Cccux::Authorizable
  belongs_to :user  # user_id field
  
  # Provides convenient owned scope:
  # Order.owned  # Shorter than accessible_by(current_ability)
end
```

### Standard Ownership
```ruby
class Order < ApplicationRecord
  include Cccux::Authorizable
  belongs_to :user  # user_id field
  # CCCUX automatically handles scoping via owned scope
end
```

### Creator Ownership
```ruby
class Article < ApplicationRecord
  include Cccux::Authorizable
  belongs_to :creator, class_name: 'User'  # creator_id field
  # CCCUX automatically handles scoping via owned scope
end
```

### Custom Ownership
```ruby
class Project < ApplicationRecord
  include Cccux::Authorizable
  
  has_many :project_members
  has_many :members, through: :project_members, source: :user
  
  def owned_by?(user)
    members.include?(user) || creator == user
  end
  
  def self.scoped_for_user(user)
    joins(:project_members).where(project_members: { user: user })
      .or(where(creator: user))
  end
end
```

## View Helpers

### Permission Checks
```erb
<% if can? :create, Order %>
  <%= link_to 'New Order', new_order_path %>
<% end %>

<% if can? :update, @order %>
  <%= link_to 'Edit', edit_order_path(@order) %>
<% end %>
```

### Role Checks
```erb
<% if current_user.has_role?('Administrator') %>
  <%= link_to 'Admin Panel', cccux.root_path %>
<% end %>
```

## User Methods

### Role Management
```ruby
user.assign_role('Basic User')
user.remove_role('Guest')
user.has_role?('Administrator')
user.has_any_role?('Admin', 'Manager')
user.role_names
```

### Permission Checks
```ruby
user.can?(:create, Order)
user.cannot?(:destroy, User)
```

## Common Patterns

### Nested Resources
```ruby
# routes.rb
resources :stores do
  resources :orders
end

# controller
class OrdersController < ApplicationController
  load_and_authorize_resource
  before_action :set_store
  
  def index
    @orders = @store.orders.owned  # Use owned scope
  end
  
  private
  
  def set_store
    @store = Store.find(params[:store_id])
  end
end
```

### AJAX Authorization
```ruby
def update
  respond_to do |format|
    if @order.update(order_params)
      format.html { redirect_to @order }
      format.json { render json: @order }
    else
      format.html { render :edit }
      format.json { render json: @order.errors, status: :unprocessable_entity }
    end
  end
rescue CanCan::AccessDenied
  respond_to do |format|
    format.html { redirect_to root_path, alert: 'Access denied.' }
    format.json { render json: { error: 'Access denied' }, status: :forbidden }
  end
end
```

### Custom Actions
```ruby
class OrdersController < Cccux::AuthorizationController
  load_and_authorize_resource
  
  def process_order
    # Custom action - authorization handled by load_and_authorize_resource
    @order.process!
    redirect_to @order, notice: 'Order processed!'
  end
end
```

## Error Handling

### Authorization Errors
```ruby
# In ApplicationController
rescue_from CanCan::AccessDenied do |exception|
  redirect_to root_path, alert: 'Access denied.'
end
```

### 404 Errors
```ruby
# In ApplicationController
rescue_from ActiveRecord::RecordNotFound do |exception|
  redirect_to root_path, alert: 'Resource not found.'
end
```

## Default Roles

- **Guest** (priority 100) - Unauthenticated users
- **Basic User** (priority 50) - Standard users
- **Store Manager** (priority 20) - Store management
- **Role Manager** (priority 10) - Role/permission management
- **Administrator** (priority 1) - Full access

## Admin Interface

- **URL**: `/cccux`
- **Access**: Role Manager or Administrator role required
- **Features**: Role management, permission management, user assignments

## Authorization Patterns Summary

### Primary Pattern: Use `owned` scope
```ruby
# ✅ Recommended - Clean and consistent
@users = User.owned.order(:email)
@stores = Store.owned.order(:name)
@orders = Order.owned.order(:created_at)
```

### Legacy Pattern: Use `accessible_by` (only for complex queries)
```ruby
# ⚠️ Use sparingly - only for complex custom queries
@orders = Order.accessible_by(current_ability).where(status: 'pending')
```

### Model Setup: Include Authorizable concern
```ruby
class YourModel < ApplicationRecord
  include Cccux::Authorizable  # Provides owned scope
  # ... your associations and validations
end
``` 