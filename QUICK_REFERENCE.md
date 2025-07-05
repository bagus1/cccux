# CCCUX Quick Reference

Quick reference for common CCCUX patterns and usage.

## Controller Inheritance

### Host App Controllers
```ruby
class UsersController < Cccux::AuthorizationController
  # Gets: CanCanCan, error handling, resource loading, host app layout
end
```

### CCCUX Admin Controllers
```ruby
module Cccux
  class RolesController < CccuxController
    before_action :ensure_role_manager
    # Gets: All base functionality + admin layout + Role Manager access
  end
end
```

## Authorization Patterns

### Primary: `Model.owned(ability)`
```ruby
def index
  @users = User.owned(current_ability).includes(:cccux_roles)
end
```

### Legacy: `accessible_by(current_ability)`
```ruby
def index
  @users = User.accessible_by(current_ability).includes(:cccux_roles)
end
```

## Model Setup

### Required Methods
```ruby
class Store < ApplicationRecord
  include Cccux::Authorizable
  
  def owned_by?(user)
    user_id == user.id
  end
  
  def self.scoped_for_user(user)
    where(user_id: user.id)
  end
end
```

### Optional: Include Authorizable Concern
```ruby
class Store < ApplicationRecord
  include Cccux::Authorizable
  # Automatically provides Store.owned scope
end
```

## User Methods

### Role Checking
```ruby
user.has_role?('Role Manager')
user.has_any_role?('Admin', 'Manager')
user.role_names
```

### Permission Checking
```ruby
user.can?(:read, User)
user.can?(:update, @store)
user.cannot?(:destroy, User)
```

### Role Management
```ruby
user.add_role('Basic User')
user.remove_role('Guest')
```

## View Helpers

### Authorization Checks
```erb
<% if can? :read, @user %>
  <%= link_to "View", user_path(@user) %>
<% end %>

<% if can? :update, @store %>
  <%= link_to "Edit", edit_store_path(@store) %>
<% end %>
```

### Role Checks
```erb
<% if current_user.has_role?('Role Manager') %>
  <%= link_to "Admin", cccux.roles_path %>
<% end %>
```

## CRUD Controller Pattern

```ruby
class StoresController < Cccux::AuthorizationController
  def index
    @stores = Store.owned.order(:name)
  end
  
  def show
    # @store is automatically loaded and authorized
  end
  
  def new
    # @store is automatically built
  end
  
  def create
    if @store.save
      redirect_to @store, notice: 'Store created successfully.'
    else
      render :new
    end
  end
  
  def edit
    # @store is automatically loaded and authorized
  end
  
  def update
    if @store.update(store_params)
      redirect_to @store, notice: 'Store updated successfully.'
    else
      render :edit
    end
  end
  
  def destroy
    @store.destroy
    redirect_to stores_path, notice: 'Store deleted successfully.'
  end
  
  private
  
  def store_params
    params.require(:store).permit(:name, :address)
  end
end
```

## Error Handling

### Automatic Error Handling
- `CanCan::AccessDenied` → Redirects to root with "Access denied"
- `ActiveRecord::RecordNotFound` → Redirects to root with "Resource not found"
- Admin controllers show "Only Role Managers can access the admin interface"

### Custom Error Handling
```ruby
rescue_from CanCan::AccessDenied do |exception|
  redirect_to root_path, alert: 'Custom access denied message.'
end
```

## Performance

### Eager Loading
```ruby
@users = User.owned.includes(:cccux_roles)
@stores = Store.owned.includes(:user)
```

### Batch Operations
```ruby
users = User.accessible_by(current_ability).where(id: params[:user_ids])
users.update_all(active: params[:active])
```

## Testing

### Controller Tests
```ruby
RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user) }
  
  before { sign_in user }
  
  describe 'GET #index' do
    it 'shows only owned users' do
      get :index
      expect(assigns(:users)).to contain_exactly(user)
    end
  end
end
```

### Model Tests
```ruby
RSpec.describe Store, type: :model do
  let(:user) { create(:user) }
  let(:store) { create(:store, user: user) }
  
  describe '#owned_by?' do
    it 'returns true for owner' do
      expect(store.owned_by?(user)).to be true
    end
  end
end
```

## Common Patterns

### Nested Resources
```ruby
class OrdersController < Cccux::AuthorizationController
  before_action :set_store
  
  def index
    @orders = @store.orders.owned.order(:created_at)
  end
  
  private
  
  def set_store
    @store = Store.owned.find(params[:store_id])
  end
end
```

### Custom Authorization
```ruby
def show
  unless @store.visible_to?(current_user)
    raise CanCan::AccessDenied.new("Store is not visible")
  end
end
```

### Role-Based Access Control
```ruby
before_action :ensure_admin, only: [:destroy]

private

def ensure_admin
  unless current_user.has_role?('Administrator')
    redirect_to root_path, alert: 'Administrator access required.'
  end
end
```

## Default Roles

- **Guest** (priority 100) - Unauthenticated users
- **Basic User** (priority 50) - Standard authenticated users
- **Store Manager** (priority 25) - Can manage stores
- **Role Manager** (priority 10) - Can manage roles and permissions
- **Administrator** (priority 1) - Full system access

## Default Permissions

Common CRUD permissions are automatically created for:
- User (read, update - owned)
- Store (read, create, update, destroy - owned)
- Order (read, create, update, destroy - owned)

## Routes

### Host App Routes
```ruby
Rails.application.routes.draw do
  resources :users
  resources :stores
  resources :orders
end
```

### CCCUX Admin Routes
```ruby
Rails.application.routes.draw do
  mount Cccux::Engine => '/cccux'
end
```

## Configuration

### ApplicationController Setup
```ruby
class ApplicationController < ActionController::Base
  # CCCUX functionality is inherited from Cccux::ApplicationController
  # when using Cccux::AuthorizationController or CccuxController
end
```

### Model Configuration
```ruby
# config/initializers/cccux.rb
Cccux.configure do |config|
  config.default_role = 'Basic User'
  config.admin_email = 'admin@example.com'
end
```

This quick reference covers the most common patterns and usage for CCCUX. For detailed documentation, see the main README and other guides. 