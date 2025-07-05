# CCCUX Context Guide

This guide explains how to use CCCUX's context-based permissions to control where users can perform actions.

## Overview

CCCUX's context system allows you to control not just **what** users can do, but **where** they can do it. This is perfect for scenarios like:

- **Mall Manager**: Can manage all orders from `/orders`
- **Store Manager**: Can only manage orders from `/stores/X/orders`
- **User**: Can only manage their own orders from `/users/X/orders`

## Context Types

### 1. Global Context
- **What it means**: Can access the resource from anywhere
- **Example**: Mall manager can update any order from `/orders`
- **Use case**: Administrative access

### 2. Owned Context  
- **What it means**: Can only access through owned relationships
- **Example**: User can only access their own orders via `/users/X/orders`
- **Use case**: Personal data access

### 3. Scoped Context
- **What it means**: Can only access through specific route contexts
- **Example**: Store manager can only access orders via `/stores/X/orders`
- **Use case**: Hierarchical access control

## Setting Up Context-Based Permissions

### Step 1: Configure Your Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Global routes (mall manager access)
  resources :orders
  
  # Scoped routes (store manager access)
  resources :stores do
    resources :orders
  end
  
  # Owned routes (user access)
  resources :users do
    resources :orders
  end
end
```

### Step 2: Set Up Your Models

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  include Cccux::Authorizable
  
  belongs_to :store
  belongs_to :user
  
  def owned_by?(user)
    self.user_id == user.id
  end
  
  def self.scoped_for_user(user)
    where(user_id: user.id)
  end
  
  def self.in_current_scope?(record, user, context)
    if context[:store_id]
      record.store_id.to_s == context[:store_id].to_s
    elsif context[:user_id]
      record.user_id.to_s == context[:user_id].to_s
    else
      false
    end
  end
end

# app/models/store.rb
class Store < ApplicationRecord
  include Cccux::Authorizable
  
  has_many :orders
  belongs_to :manager, class_name: 'User'
  
  def owned_by?(user)
    self.manager_id == user.id
  end
end
```

### Step 3: Configure Your Controllers

```ruby
# app/controllers/orders_controller.rb (Global access)
class OrdersController < Cccux::AuthorizationController
  def index
    @orders = Order.owned(current_ability).includes(:store, :user)
  end
end

# app/controllers/stores/orders_controller.rb (Scoped access)
class Stores::OrdersController < Cccux::AuthorizationController
  before_action :set_store
  
  def index
    @orders = @store.orders.owned(current_ability).includes(:user)
  end
  
  private
  
  def set_store
    @store = Store.find(params[:store_id])
    authorize! :read, @store
  end
  
  def current_ability
    context = { store_id: params[:store_id] }
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end

# app/controllers/users/orders_controller.rb (Owned access)
class Users::OrdersController < Cccux::AuthorizationController
  before_action :set_user
  
  def index
    @orders = @user.orders.owned(current_ability)
  end
  
  private
  
  def set_user
    @user = User.find(params[:user_id])
    authorize! :read, @user
  end
  
  def current_ability
    context = { user_id: params[:user_id] }
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end
```

### Step 4: Configure Roles in CCCUX Admin

#### Mall Manager Role
1. Go to `/cccux/roles` and create/edit "Mall Manager"
2. For "Order" permissions:
   - **Context**: `Global`
   - **Scope**: `All`
   - **Actions**: `read`, `create`, `update`, `destroy`

#### Store Manager Role  
1. Go to `/cccux/roles` and create/edit "Store Manager"
2. For "Order" permissions:
   - **Context**: `Scoped`
   - **Scope**: `All` (or `Owned` if you want them to only see their store's orders)
   - **Actions**: `read`, `create`, `update`, `destroy`

#### Basic User Role
1. Go to `/cccux/roles` and create/edit "Basic User"
2. For "Order" permissions:
   - **Context**: `Owned`
   - **Scope**: `Owned`
   - **Actions**: `read`, `create`, `update`, `destroy`

## How It Works

### Context Detection

The context is determined by the controller's `current_ability` method:

```ruby
def current_ability
  context = {}
  context[:store_id] = params[:store_id] if params[:store_id]
  context[:user_id] = params[:user_id] if params[:user_id]
  
  @current_ability ||= Cccux::Ability.new(current_user, context)
end
```

### Permission Checking

When a user tries to access a resource, CCCUX checks:

1. **Does the user have the permission?** (action + model)
2. **Is the user in the correct context?** (global/scoped/owned)
3. **Does the user have the right scope?** (all/owned)

### Example Scenarios

#### Mall Manager Accessing `/orders`
1. ✅ Has "update" permission on Order
2. ✅ Context is "global" (matches role setting)
3. ✅ Scope is "all" (matches role setting)
4. **Result**: Can update any order

#### Store Manager Accessing `/stores/1/orders`
1. ✅ Has "update" permission on Order  
2. ✅ Context is "scoped" (matches role setting)
3. ✅ Scope is "all" (matches role setting)
4. ✅ Record is in current scope (store_id matches)
5. **Result**: Can update any order in store 1

#### Store Manager Accessing `/orders` (Global)
1. ✅ Has "update" permission on Order
2. ❌ Context is "global" (but role requires "scoped")
3. **Result**: Access denied

#### User Accessing `/users/1/orders`
1. ✅ Has "update" permission on Order
2. ✅ Context is "owned" (matches role setting)  
3. ✅ Scope is "owned" (matches role setting)
4. **Result**: Can update their own orders

## Advanced Usage

### Custom Context Types

You can extend the context system for custom scenarios:

```ruby
# In your controller
def current_ability
  context = {}
  context[:department_id] = params[:department_id] if params[:department_id]
  context[:project_id] = params[:project_id] if params[:project_id]
  
  @current_ability ||= Cccux::Ability.new(current_user, context)
end

# In your model
def self.in_current_scope?(record, user, context)
  if context[:department_id]
    record.department_id.to_s == context[:department_id].to_s
  elsif context[:project_id]
    record.project_id.to_s == context[:project_id].to_s
  else
    false
  end
end
```

### Mixed Context Permissions

A user can have multiple roles with different contexts:

```ruby
# User has both "Store Manager" and "Basic User" roles
# - Can access orders via /stores/X/orders (scoped context)
# - Can access their own orders via /users/X/orders (owned context)
```

### Context-Aware Views

Use the context-aware helpers in your views:

```erb
<% if can_in_scoped_context?(:update, @order) %>
  <%= link_to 'Edit', edit_store_order_path(@store, @order) %>
<% end %>

<% if can_in_owned_context?(:update, @order) %>
  <%= link_to 'Edit', edit_user_order_path(@user, @order) %>
<% end %>
```

## Troubleshooting

### "Access Denied" in Scoped Context
- Check that the user's role has the correct context setting
- Verify the `in_current_scope?` method is implemented in your model
- Ensure the controller's `current_ability` method passes the correct context

### Context Not Detected
- Make sure your controller overrides `current_ability` to pass context
- Check that route parameters are named correctly (e.g., `store_id`, `user_id`)
- Verify the `in_current_scope?` method handles the context properly

### Performance Considerations
- Context is passed explicitly, no global state
- Consider caching context information for complex scenarios
- Use database indexes on foreign key columns for scoped queries

## Best Practices

1. **Use descriptive context names** that match your business logic
2. **Test all context combinations** thoroughly
3. **Document context requirements** for each role
4. **Use consistent route naming** conventions
5. **Consider security implications** of each context type
6. **Keep context simple** - avoid complex nested contexts

This context system provides powerful, flexible authorization that adapts to your application's structure and business requirements without relying on global state. 