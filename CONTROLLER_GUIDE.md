# CCCUX Controller Guide

This guide explains how to use CCCUX controllers in your Rails application for proper authorization and resource management.

## Controller Hierarchy

CCCUX provides three controller classes with increasing functionality:

### 1. `Cccux::ApplicationController`
**Base controller with shared functionality:**
- CanCanCan integration (`include CanCan::ControllerAdditions`)
- Common error handling (`CanCan::AccessDenied`, `ActiveRecord::RecordNotFound`)
- CCCUX Ability class integration (`current_ability`)
- User setup (`set_current_user`)
- Devise parameter sanitization for `first_name` and `last_name`

**Use when:** You need basic CCCUX functionality without automatic resource loading.

### 2. `Cccux::AuthorizationController`
**Host app authorization controller:**
- Inherits all functionality from `ApplicationController`
- Uses host app layout (`layout 'application'`)
- Automatic resource loading and authorization (`load_and_authorize_resource`)

**Use when:** Creating controllers in your host app that need CCCUX authorization.

### 3. `Cccux::CccuxController`
**Full CCCUX admin interface controller:**
- Inherits all functionality from `ApplicationController`
- Dedicated admin layout (`layout 'cccux/admin'`)
- Enhanced error handling for admin interface
- Namespaced model handling (`resource_class` override)
- Role Manager access control (`ensure_role_manager`)

**Use when:** Creating controllers within the CCCUX admin interface.

## Controller Requirements

### Required Setup

All controllers using CCCUX authorization must:

1. **Override `current_ability`** (handled automatically by base controllers)
2. **Set up proper error handling** (handled automatically by base controllers)
3. **Include user authentication** (handled by Devise integration)

### Host App Controllers

For controllers in your main application:

```ruby
class UsersController < Cccux::AuthorizationController
  # Automatically gets:
  # - CanCanCan integration
  # - Error handling
  # - Resource loading and authorization
  # - Host app layout
  
  def index
    @users = User.owned.includes(:cccux_roles)
  end
  
  def show
    # @user is automatically loaded and authorized
  end
  
  def create
    if @user.save
      redirect_to @user, notice: 'User created successfully.'
    else
      render :new
    end
  end
end
```

### CCCUX Admin Controllers

For controllers within the CCCUX admin interface:

```ruby
module Cccux
  class RolesController < CccuxController
    # Automatically gets:
    # - All base functionality
    # - Admin layout
    # - Enhanced error handling
    # - Namespaced model handling
    # - Role Manager access control
    
    before_action :ensure_role_manager
    
    def index
      # @roles is automatically loaded and authorized
      # Uses Cccux::Role model automatically
    end
  end
end
```

## Authorization Patterns

### Primary: `Model.owned(ability)`

Use the `owned` scope for automatic ownership filtering:

```ruby
class UsersController < Cccux::AuthorizationController
  def index
    @users = User.owned(current_ability).includes(:cccux_roles)
  end
  
  def show
    # @user is automatically loaded and authorized
  end
end
```

### Legacy: `accessible_by(current_ability)`

For complex queries that can't use the `owned` scope:

```ruby
class UsersController < Cccux::AuthorizationController
  def index
    @users = User.accessible_by(current_ability).includes(:cccux_roles)
  end
end
```

**Note:** The `owned` scope requires an explicit ability parameter for reliability. This ensures proper authorization regardless of thread context.

### Custom Authorization

For custom authorization logic:

```ruby
class OrdersController < Cccux::AuthorizationController
  def index
    if params[:store_id]
      store = Store.find(params[:store_id])
      authorize! :read, store
      @orders = store.orders.owned
    else
      @orders = Order.owned
    end
  end
end
```

## Error Handling

CCCUX controllers automatically handle common errors:

### Authorization Errors
- `CanCan::AccessDenied` → Redirects to root with "Access denied" message
- Admin controllers show "Only Role Managers can access the admin interface"

### Not Found Errors
- `ActiveRecord::RecordNotFound` → Redirects to root with "Resource not found" message

### Admin-Specific Errors
- `ActionController::RoutingError` → Redirects to root with "Page not found" message
- `ActionController::ParameterMissing` → Redirects to root with "Invalid parameters" message

## Model Integration

### Required Model Methods

Models must implement these methods for ownership scoping:

```ruby
class Store < ApplicationRecord
  include Cccux::Authorizable
  
  # Check if record is owned by user
  def owned_by?(user)
    user_id == user.id
  end
  
  # Scope records for user (owned + any global access)
  def self.scoped_for_user(user)
    where(user_id: user.id)
  end
end
```

### Optional: Include Authorizable Concern

For automatic `owned` scope support:

```ruby
class Store < ApplicationRecord
  include Cccux::Authorizable
  # Automatically provides Store.owned scope
end
```

## Layout Integration

### Host App Layout

Controllers inheriting from `AuthorizationController` use your application's layout:

```ruby
class UsersController < Cccux::AuthorizationController
  # Uses layout 'application' (your main app layout)
end
```

### Admin Layout

Controllers inheriting from `CccuxController` use the CCCUX admin layout:

```ruby
module Cccux
  class RolesController < CccuxController
    # Uses layout 'cccux/admin' (dedicated admin layout)
  end
end
```

## Namespaced Models

CCCUX admin controllers automatically handle namespaced models:

```ruby
module Cccux
  class RolesController < CccuxController
    # Automatically uses Cccux::Role model
    # No need to specify resource_class
  end
end
```

## Access Control

### Role Manager Access

Admin controllers can enforce Role Manager access:

```ruby
module Cccux
  class RolesController < CccuxController
    before_action :ensure_role_manager
    
    # Only Role Managers can access these actions
  end
end
```

### Custom Access Control

For custom access control:

```ruby
class UsersController < Cccux::AuthorizationController
  before_action :ensure_admin, only: [:destroy]
  
  private
  
  def ensure_admin
    unless current_user.has_role?('Administrator')
      redirect_to root_path, alert: 'Administrator access required.'
    end
  end
end
```

## Performance Optimization

### Eager Loading

Always include related models to avoid N+1 queries:

```ruby
class UsersController < Cccux::AuthorizationController
  def index
    @users = User.owned.includes(:cccux_roles)
  end
end
```

### Batch Operations

For batch operations, use `accessible_by`:

```ruby
class UsersController < Cccux::AuthorizationController
  def bulk_update
    users = User.accessible_by(current_ability).where(id: params[:user_ids])
    users.update_all(active: params[:active])
    redirect_to users_path, notice: 'Users updated successfully.'
  end
end
```

## Testing

### Controller Tests

Test authorization in your controller tests:

```ruby
require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  
  before { sign_in user }
  
  describe 'GET #index' do
    it 'shows only owned users' do
      get :index
      expect(assigns(:users)).to contain_exactly(user)
    end
  end
  
  describe 'GET #show' do
    it 'allows access to own user' do
      get :show, params: { id: user.id }
      expect(response).to be_successful
    end
    
    it 'denies access to other users' do
      other_user = create(:user)
      expect {
        get :show, params: { id: other_user.id }
      }.to raise_error(CanCan::AccessDenied)
    end
  end
end
```

## Common Patterns

### CRUD Controllers

Standard CRUD pattern with CCCUX:

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

### Nested Resources

For nested resources:

```ruby
class OrdersController < Cccux::AuthorizationController
  before_action :set_store
  
  def index
    @orders = @store.orders.owned.order(:created_at)
  end
  
  def create
    @order = @store.orders.build(order_params)
    @order.user = current_user
    
    if @order.save
      redirect_to store_order_path(@store, @order), notice: 'Order created successfully.'
    else
      render :new
    end
  end
  
  private
  
  def set_store
    @store = Store.owned.find(params[:store_id])
  end
  
  def order_params
    params.require(:order).permit(:amount, :description)
  end
end
```

This guide covers the essential patterns for using CCCUX controllers effectively in your Rails application. 