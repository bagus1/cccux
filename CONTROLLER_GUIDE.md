# CCCUX Controller Guide

This guide explains the controller inheritance patterns, authorization requirements, and best practices for using CCCUX in your Rails application.

## Controller Inheritance Hierarchy

CCCUX provides several base controller classes to choose from depending on your needs:

### 1. CCCUX Admin Controllers (Engine Controllers)

For controllers within the CCCUX engine that manage roles, permissions, and users:

```ruby
module Cccux
  class YourController < CccuxController
    # Automatically includes:
    # - CanCanCan authorization
    # - CCCUX admin layout
    # - Error handling for authorization failures
    # - Automatic resource loading and authorization
  end
end
```

**Features:**
- Uses `cccux/admin` layout
- Includes `load_and_authorize_resource` by default
- Handles authorization errors gracefully
- Overrides `current_ability` to use `Cccux::Ability`
- Provides proper namespacing for engine models

### 2. Host App Controllers with CCCUX Authorization

For controllers in your host application that need CCCUX authorization:

```ruby
class YourController < ApplicationController
  # Your controller logic here
  # Authorization is automatically available from ApplicationController
end
```

**Features:**
- Uses your application's default layout
- Includes CanCanCan authorization (inherited from ApplicationController)
- Overrides `current_ability` to use `Cccux::Ability` (inherited from ApplicationController)
- Handles authorization errors with redirects (inherited from ApplicationController)
- Makes `current_ability` available to models for the `owned` scope (inherited from ApplicationController)

### 3. Manual CCCUX Integration

For controllers that need custom authorization logic:

```ruby
class YourController < ApplicationController
  # Include CanCanCan
  include CanCan::ControllerAdditions
  
  # Override current_ability to use CCCUX
  def current_ability
    @current_ability ||= Cccux::Ability.new(current_user)
  end
  
  # Handle authorization errors
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: 'Access denied.'
  end
end
```

## Required Controller Setup

### 1. ApplicationController Setup

Your main `ApplicationController` should include CCCUX authorization:

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

This provides:
- CanCanCan authorization
- CCCUX authorization helpers
- Error handling for authorization failures
- `current_ability` override to use `Cccux::Ability`
- `current_ability` availability to models for the `owned` scope

### 2. Resource Controllers

For controllers that manage resources with CCCUX authorization:

```ruby
class OrdersController < ApplicationController
  # Automatically loads and authorizes resources
  load_and_authorize_resource
  
  def index
    # Use the owned scope for clean, consistent authorization
    @orders = Order.owned.order(:created_at)
  end
  
  def show
    # @order is automatically loaded and authorized
  end
  
  def create
    # Authorization is automatically checked before action
    @order = Order.new(order_params)
    @order.user = current_user
    
    if @order.save
      redirect_to @order, notice: 'Order created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

## Authorization Patterns

### 1. Using the `owned` Scope (Recommended)

The `owned` scope is the primary and recommended way to handle authorization in CCCUX:

```ruby
class ProductsController < ApplicationController
  load_and_authorize_resource
  
  def index
    # Clean, simple, and consistent
    @products = Product.owned.order(:name)
  end
  
  def show
    # @product is automatically loaded and authorized
  end
end
```

**Benefits of the `owned` scope:**
- **Shorter syntax**: `Product.owned` vs `Product.accessible_by(current_ability)`
- **Consistent across all models**: Same pattern for User, Store, Order, etc.
- **Automatic ownership detection**: CCCUX automatically applies the correct ownership logic
- **Performance optimized**: Includes proper eager loading and joins

### 2. Automatic Resource Authorization

The `load_and_authorize_resource` directive automatically:

- Loads the resource for `show`, `edit`, `update`, `destroy` actions
- Authorizes the action before it executes
- Scopes collections based on user permissions
- Handles authorization failures

```ruby
class ProductsController < ApplicationController
  load_and_authorize_resource
  
  def index
    # @products is automatically scoped using the owned scope:
    # - All products if user has "All Records" permission
    # - User's products if user has "Owned Records Only" permission
    @products = Product.owned.order(:name)
  end
end
```

### 3. Manual Authorization with accessible_by (Legacy)

For custom queries or when you need more control (use sparingly):

```ruby
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    if params[:store_id]
      store = Store.find(params[:store_id])
      @orders = store.orders.owned  # Use owned scope instead
    else
      @orders = Order.owned  # Use owned scope instead
    end
  end
end
```

### 4. Custom Authorization Checks

For complex authorization logic:

```ruby
class ProjectsController < ApplicationController
  load_and_authorize_resource
  
  def show
    # Additional custom authorization
    unless @project.visible_to?(current_user)
      raise CanCan::AccessDenied.new("Project is not visible to you")
    end
  end
  
  def update
    # Custom authorization for specific conditions
    if @project.locked? && !current_user.can_edit_locked_projects?
      raise CanCan::AccessDenied.new("Cannot edit locked projects")
    end
    
    if @project.update(project_params)
      redirect_to @project, notice: 'Project updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

## Ownership and Scoping

### 1. Automatic Ownership Detection

CCCUX automatically detects ownership patterns in your models:

```ruby
class Order < ApplicationRecord
  include Cccux::Authorizable  # Include the concern for the owned scope
  
  belongs_to :user  # Standard user_id ownership
  
  # CCCUX automatically applies user_id scoping for "Owned Records Only" permissions
  # The owned scope will automatically use the correct ownership logic
end

class Article < ApplicationRecord
  include Cccux::Authorizable
  
  belongs_to :creator, class_name: 'User'  # Creator ownership
  
  # CCCUX automatically applies creator_id scoping
end

class Project < ApplicationRecord
  include Cccux::Authorizable
  
  has_many :project_members
  has_many :members, through: :project_members, source: :user
  
  # Custom ownership method
  def owned_by?(user)
    members.include?(user) || creator == user
  end
  
  # Class method for scoping collections
  def self.scoped_for_user(user)
    joins(:project_members).where(project_members: { user: user })
      .or(where(creator: user))
  end
end
```

### 2. Custom Ownership Methods

For complex ownership patterns, implement these methods in your models:

```ruby
class Store < ApplicationRecord
  include Cccux::Authorizable
  
  has_many :store_managers
  has_many :managers, through: :store_managers, source: :user
  
  # Instance method for individual record authorization
  def owned_by?(user)
    managers.include?(user) || user_id == user.id
  end
  
  # Class method for collection scoping (used in index actions)
  def self.scoped_for_user(user)
    joins(:store_managers).where(store_managers: { user: user })
      .or(where(user: user))
  end
end
```

## Error Handling

### 1. Authorization Errors

CCCUX provides automatic error handling for authorization failures:

```ruby
# In ApplicationController or CCCUX base controllers
rescue_from CanCan::AccessDenied do |exception|
  redirect_to root_path, alert: 'Access denied.'
end
```

### 2. AJAX Authorization Errors

For AJAX requests, handle authorization errors appropriately:

```ruby
class OrdersController < Cccux::AuthorizationController
  load_and_authorize_resource
  
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to @order, notice: 'Order updated.' }
        format.json { render json: @order }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  rescue CanCan::AccessDenied
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'Access denied.' }
      format.json { render json: { error: 'Access denied' }, status: :forbidden }
    end
  end
end
```

## Best Practices

### 1. Controller Organization

- Use `Cccux::AuthorizationController` for most resource controllers
- Use `CccuxController` only for CCCUX admin functionality
- Inherit from `ApplicationController` only when you need custom authorization logic

### 2. Resource Loading

- **Use the `owned` scope as your primary authorization pattern**
- Use `load_and_authorize_resource` for standard CRUD operations
- Use `accessible_by(current_ability)` only for complex custom queries
- Avoid manual authorization checks when possible

### 3. Model Design

- Include `Cccux::Authorizable` in your models to get the `owned` scope
- Implement `owned_by?(user)` for custom ownership logic
- Implement `scoped_for_user(user)` for collection scoping
- Use standard `user_id` or `creator_id` fields when possible

### 4. Error Handling

- Always handle `CanCan::AccessDenied` exceptions
- Provide appropriate responses for both HTML and JSON requests
- Use consistent error messages across your application

## Examples

### Complete Controller Example

```ruby
class ProductsController < Cccux::AuthorizationController
  load_and_authorize_resource
  before_action :set_category, only: [:index, :new, :create]
  
  def index
    @products = if @category
      @category.products.owned  # Use owned scope
    else
      Product.owned  # Use owned scope
    end
  end
  
  def show
    # @product is automatically loaded and authorized
  end
  
  def new
    @product = @category ? @category.products.build : Product.new
  end
  
  def create
    @product = @category ? @category.products.build(product_params) : Product.new(product_params)
    @product.creator = current_user
    
    if @product.save
      redirect_to @product, notice: 'Product created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    if @product.update(product_params)
      redirect_to @product, notice: 'Product updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @product.destroy
    redirect_to products_path, notice: 'Product deleted successfully.'
  end
  
  private
  
  def set_category
    @category = Category.find(params[:category_id]) if params[:category_id]
  end
  
  def product_params
    params.require(:product).permit(:name, :description, :price, :category_id)
  end
end
```

### Model with Custom Ownership

```ruby
class Project < ApplicationRecord
  include Cccux::Authorizable  # Include for owned scope
  
  belongs_to :creator, class_name: 'User'
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

### Consistent Controller Pattern

All your controllers should follow this consistent pattern:

```ruby
# Users Controller
class UsersController < ApplicationController
  load_and_authorize_resource
  
  def index
    @users = User.includes(:cccux_roles).owned.order(:email)
  end
end

# Stores Controller  
class StoresController < ApplicationController
  load_and_authorize_resource
  
  def index
    @stores = Store.owned.order(:name)
  end
end

# Orders Controller
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    @orders = Order.owned.order(:created_at)
  end
end
```

This guide covers all the essential patterns for using CCCUX in your controllers. The `owned` scope provides a clean, consistent, and performant way to handle authorization across your entire application. 