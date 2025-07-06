# CCCUX - Role-Based Authorization Engine

CCCUX is a Rails engine that provides comprehensive role-based authorization with CanCanCan integration, flexible permissions, ownership scoping, and a clean admin interface.

## Features

- **UX for Creating and Managing Roles**: Intuitive web interface for role creation and permission management
- **Role-Based Authorization**: Define roles with granular permissions
- **CanCanCan Integration**: Seamless integration with CanCanCan authorization library
- **Flexible Permissions**: CRUD permissions with global and contextual access types
- **Context-Aware Authorization**: Support for route-based context scoping
- **Nested Resource Support**: Automatic handling of nested routes with CanCanCan's `:through` option
- **Admin Interface**: Clean, intuitive interface for role management
- **Drag & Drop Reordering**: Visual role priority management
- **Rails 8 Compatible**: Works with Rails 8 and Propshaft asset pipeline

## Quick Start

### 1. Install the Engine

Add to your Gemfile:
```ruby
gem 'cccux', path: 'path/to/cccux'
```

### 2. Run the Installer

```bash
rails cccux:setup
```

This command will:
1. Check if Devise is installed and guide you through installation if needed
2. Create a "Role Manager" user account for admin access
3. Mount the CCCUX engine in your application
4. Set up initial database tables and seed data

### 4. Configure Your Application

Start your server and navigate to `http://localhost:3000/cccux`:

1. **Model Discovery**: Click "Model Discovery" to select which models should have role-based authorization
2. **Roles Management**: Go to "Roles" to see the default roles (Role Manager, Basic User, Guest)
3. **Create Custom Roles**: Create new roles and assign fine-grained permissions
4. **Permission Management**: Visit "Permissions" to add new actions for your models

**Pro Tip**: When you add new controller actions, visit the "Permissions" section, select your model, and click "Create new Permission" to make the new action available for role assignment. 


### 3. Set Up Your Models

#### Basic Model Setup

Include the authorization concern in your models:

```ruby
class User < ApplicationRecord
  include Cccux::Authorizable
  # ... your model code
end

class Store < ApplicationRecord
  include Cccux::Authorizable
  # ... your model code
end
```

#### Advanced Ownership Patterns

For models with complex ownership relationships, use the `ScopedOwnership` concern:

```ruby
class Product < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :user
  belongs_to :store
  
  # Configure ownership patterns
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
end

class Order < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :user
  belongs_to :store
  
  # Configure ownership patterns
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
end
```

### 4. Create Controllers

#### Standard Controllers

For host app controllers with basic authorization:

```ruby
class UsersController < Cccux::AuthorizationController
  load_and_authorize_resource
  
  def index
    @users = @users.order(:name)
  end
  
  def show
    # @user is automatically loaded and authorized
  end
end
```

#### Nested Resource Controllers

For controllers with nested resources and context-aware authorization:

```ruby
class ProductsController < Cccux::AuthorizationController
  # Load store when store_id is present (nested routes)
  load_and_authorize_resource :store, if: -> { params[:store_id].present? }
  # Load product through store for nested routes, directly for standalone routes  
  load_and_authorize_resource :product, through: :store, if: -> { params[:store_id].present? }
  load_and_authorize_resource :product, unless: -> { params[:store_id].present? }

  def index
    if params[:store_id].present?
      # Nested route: /stores/:store_id/products
      @products = @store.products.order(:name)
    else
      # Standalone route: /products
      @products = @products.order(:name)
    end
  end

  private

  # Override current_ability to provide store context for scoped permissions
  def current_ability
    context = {}
    context[:store_id] = @store.id if @store
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end
```

#### CCCUX Admin Controllers

For controllers within the CCCUX admin interface:

```ruby
module Cccux
  class RolesController < CccuxController
    before_action :ensure_role_manager
    
    def index
      # @roles is automatically loaded and authorized
      # Uses Cccux::Role model automatically
    end
  end
end
```

### 5. Use Authorization in Views

#### Basic Authorization Helpers

```erb
<% if can? :read, @user %>
  <%= link_to "View User", user_path(@user) %>
<% end %>

<% if can? :update, @store %>
  <%= link_to "Edit Store", edit_store_path(@store) %>
<% end %>
```

#### CCCUX Authorization Helpers

```erb
<%= link_if_can_show @product, "View", product_path(@product) %>
<%= link_if_can_edit @product, "Edit", edit_product_path(@product) %>
<%= button_if_can_destroy @product, "Delete", product_path(@product), method: :delete %>

<!-- For creation links, use build to provide context -->
<%= link_if_can_create @store.products.build, "Add New Product", new_store_product_path(@store) %>
```

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

## Model Configuration

### Basic Models

For simple models with direct user ownership:

```ruby
class User < ApplicationRecord
  include Cccux::Authorizable
  
  # Required methods for ownership
  def owned_by?(user)
    return false unless user&.persisted?
    id == user.id
  end
  
  def self.scoped_for_user(user)
    return none unless user&.persisted?
    where(id: user.id)
  end
end
```

### Models with Nested Resources

For models that belong to other resources (like products belonging to stores):

```ruby
class Product < ApplicationRecord
  belongs_to :user
  belongs_to :store
  
  # Implement ownership check for contextual permissions
  def owned_by?(user)
    return false unless user&.persisted?
    user_id == user.id || store.store_managers.exists?(user: user)
  end
end
```

This provides:
- `owned_by?(user)` method that checks both direct ownership and store management
- Automatic filtering when accessed through nested routes

## Authorization Patterns

### Nested Resource Authorization

For controllers with nested resources, use CanCanCan's `:through` option:

```ruby
class ProductsController < Cccux::AuthorizationController
  # Load store when store_id is present (nested routes)
  load_and_authorize_resource :store, if: -> { params[:store_id].present? }
  # Load product through store for nested routes, directly for standalone routes  
  load_and_authorize_resource :product, through: :store, if: -> { params[:store_id].present? }
  load_and_authorize_resource :product, unless: -> { params[:store_id].present? }

  def index
    if params[:store_id].present?
      # Nested route: /stores/:store_id/products
      @products = @store.products.order(:name)
    else
      # Standalone route: /products
      # Handle case where @products might be nil due to authorization filtering
      @products = @products&.order(:name) || Product.none
    end
  end

  private

  # Override current_ability to provide store context for contextual permissions
  def current_ability
    context = {}
    context[:store_id] = @store.id if @store
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end
```

### Standard Authorization

For simple controllers without nested resources:

```ruby
class UsersController < Cccux::AuthorizationController
  load_and_authorize_resource
  
  def index
    # Handle case where @users might be nil due to authorization filtering
    @users = @users&.order(:name) || User.none
  end
end
```

**Important**: When using `load_and_authorize_resource`, the collection might be `nil` if the user has contextual permissions but no context is provided. Always use the safe navigation operator (`&.`) and provide a fallback (like `Model.none`) to avoid `NoMethodError`.

## Role Management

### Creating Roles

```ruby
# Create a basic user role
role = Cccux::Role.create!(
  name: 'Basic User',
  priority: 50
)

# Add permissions with global access
role.role_abilities.create!(
  ability_permission: Cccux::AbilityPermission.find_by(action: 'read', subject: 'User'),
  access_type: 'global'
)

# Create a store manager role
role = Cccux::Role.create!(
  name: 'Store Manager',
  priority: 15
)

# Add permissions with contextual access
['read', 'create', 'update', 'destroy'].each do |action|
  role.role_abilities.create!(
    ability_permission: Cccux::AbilityPermission.find_by(action: action, subject: 'Product'),
    access_type: 'contextual'
  )
end
```

### Assigning Roles to Users

```ruby
user.add_role('Basic User')
user.add_role('Store Manager')
```

### Checking Permissions

```ruby
user.can?(:read, User)           # => true/false
user.can?(:update, @store)       # => true/false
user.has_role?('Role Manager')   # => true/false
```

## Permission Access Types

CCCUX supports two access types for permissions:

### 1. Global Access
- **Access**: User can access any record of this type
- **Use case**: System administrators, global managers
- **Example**: Role Manager can manage all roles

### 2. Contextual Access
- **Access**: User can access records within the current route context
- **Use case**: Store managers, project members
- **Example**: Store managers can manage products in their stores (when accessed via `/stores/:store_id/products`)

## View Helpers

### Basic Authorization Helpers

```erb
<%= link_if_can_show @product, "View", product_path(@product) %>
<%= link_if_can_edit @product, "Edit", edit_product_path(@product) %>
<%= link_if_can_create @store.products.build, "Add Product", new_store_product_path(@store) %>
<%= button_if_can_destroy @product, "Delete", product_path(@product), method: :delete %>
```

### Content Helpers

```erb
<% content_if_can_edit @product do %>
  <div class="admin-controls">
    <%= link_to "Advanced Settings", advanced_product_path(@product) %>
  </div>
<% end %>
```

### Permission Check Helpers

```erb
<% if can_edit?(@product) %>
  <%= link_to "Edit", edit_product_path(@product) %>
<% end %>

<% if can_create?(Product) %>
  <%= link_to "New Product", new_product_path %>
<% end %>
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

## Asset Pipeline

CCCUX includes CSS and JavaScript assets for the admin interface:

```ruby
# In your application.css
@import "cccux/admin";

# In your application.js
import "cccux/admin"
```

## Testing

### Testing Authorization

```ruby
# In your tests
require 'test_helper'

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @store = stores(:one)
    @product = products(:one)
    sign_in @user
  end

  test "should get index when authorized" do
    @user.add_role('Store Manager')
    get store_products_url(@store)
    assert_response :success
  end

  test "should not get index when not authorized" do
    get store_products_url(@store)
    assert_redirected_to root_path
  end
end
```

### Testing Model Scopes

```ruby
class ProductTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @store = stores(:one)
    @product = products(:one)
  end

  test "owned_by? returns true for owner" do
    assert @product.owned_by?(@product.user)
  end

  test "owned_by? returns true for store manager" do
    @store.store_managers.create!(user: @user)
    assert @product.owned_by?(@user)
  end

  test "scoped_for_user includes owned products" do
    products = Product.scoped_for_user(@product.user)
    assert_includes products, @product
  end
end
```

## Migration Guide

### From Basic CanCanCan

1. **Replace Ability class** with CCCUX role-based permissions
2. **Update controllers** to inherit from `Cccux::AuthorizationController`
3. **Add models** to include `Cccux::Authorizable` or `Cccux::ScopedOwnership`
4. **Create roles** in the admin interface
5. **Assign roles** to users

### From Custom Authorization

1. **Identify permission patterns** in your custom code
2. **Create corresponding roles** with appropriate permissions
3. **Replace custom authorization checks** with CCCUX helpers
4. **Test thoroughly** to ensure equivalent functionality

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
