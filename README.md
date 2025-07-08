# CCCUX - Simplified Role-Based Authorization Engine

CCCUX is a Rails engine that provides comprehensive role-based authorization with CanCanCan integration. It's designed to be **incredibly simple** - just add one line to your controllers and configure permissions through the web interface.

## Features

- **One-Line Controller Setup**: Just add `load_and_authorize_resource` to any controller
- **No Model Code Required**: Models need no special concerns or methods
- **UI-Driven Configuration**: Set up complex ownership patterns through the web interface
- **Automatic Setup**: Configures your ApplicationController automatically
- **CanCanCan Integration**: Built on the proven CanCanCan authorization library
- **Flexible Ownership**: Handle simple user ownership or complex manager hierarchies
- **Admin Interface**: Clean, intuitive interface for role and permission management
- **Rails 8 Compatible**: Works with Rails 8 and modern Rails applications

## Quick Start

### 1. Install the Engine

Add to your Gemfile:
```ruby
gem 'cccux', path: 'path/to/cccux'
```

Run:
```bash
bundle install
```

### 2. Run the Setup Task

```bash
rails cccux:setup
```

**What the setup task does:**

1. **Checks for Devise**: Verifies Devise is installed, guides you through installation if needed
2. **Mounts the Engine**: Adds `mount Cccux::Engine => '/cccux'` to your routes
3. **Configures ApplicationController**: Automatically adds the CCCUX authorization concern to your ApplicationController
4. **Creates Database Tables**: Runs migrations for roles, permissions, and user assignments
5. **Seeds Default Data**: Creates default roles (Guest, Basic User, Role Manager, Administrator)
6. **Creates Admin User**: Sets up a "Role Manager" user account for admin access

The setup task automatically configures your `ApplicationController` with:
- CanCanCan integration
- CCCUX Ability class
- Error handling for authorization failures
- View helpers for authorization checks

### 3. Add Authorization to Controllers

**The only requirement: Add `load_and_authorize_resource` to your controllers**

#### Basic Controller
```ruby
class ProductsController < ApplicationController
  load_and_authorize_resource
  
  def index
    @products = @products.order(:name)
  end
  
  def show
    # @product is automatically loaded and authorized
  end
end
```

#### Nested Resource Controller
```ruby
class OrdersController < ApplicationController
  # Load parent resource when present
  load_and_authorize_resource :store, if: -> { params[:store_id].present? }
  
  # Load main resource through parent or directly
  load_and_authorize_resource :order, through: :store, if: -> { params[:store_id].present? }
  load_and_authorize_resource :order, unless: -> { params[:store_id].present? }
  
  def index
    if params[:store_id].present?
      @orders = @store.orders.order(:created_at)
    else
      @orders = @orders.order(:created_at)
    end
  end
end
```

### 4. Managing Permissions and Roles

Start your server, login as the Role Manager user you created and navigate to `http://localhost:3000/cccux`. You should see links in the footer on your homepage.

## Permission Configuration

1. **Model Discovery**: Click "Model Discovery" to automatically detect your models and create permissions
2. **CRUD Actions added by default**: The Model Discovery process will add permissions for Read, Create, Update and Delete. 
3. **Additional Actions**: The Permissions page shows each model and all their permisssions. Click the "Create New xxx Permission" for a model and it will discover any additional actions that your controller and routes support. Add them and they'll be available for any role. 

## Role Creation


Once you've created all the permissions from the Model Discovery page, you can assign them to Roles. By default, CCCUX creates three roles. Guest, Basic User and Role Manager. For additional Roles, click the Create Role button and fill out the simple form. Once it's created, edit it to configure its abilities. 

 CCCUX supports two access types for each Crud Action. Global and Owned. 


### Global Access
- **What it does**: Access to the to all records for a model for the individual action. 
- **Use case**: Allowing Read access to the role for all items in a model.
- **Use case**: Allowing Create access to create an item in a model.
- **Configuration**: Select "Global" access type

### Owned Access

There are two types of Owned Access. When you click 'owned' for a permission (Update) for a model (Product) for a role ("Basic User"), by default, any user with that role will be able only update records they created. However additional fields will be displayed for 'Owned' role permissions. These allow you to allow access to a manager (Project Manager) if you have an appropriate model and relationships set up in your application. This is best used for nested routes (see the setup for nested routes above) so that for instance a Project Manager can manage all the Tasks in a Project. 

#### Basic Owned Access

- **By Default**: Access to records for the user that created them.
- **Use case**: Users editing their own records

#### Advanced Owned Access

- **First** select 'Owned' for a permission on a model for a role. 
- **Next** Select an Ownership Model (ProjectManager), and enter a foreign key (project_id) and a User Key (user_id)
- **Result**: Now if managers (Project Managers) are assigned to the parent item (A Project), they can manage all the items (Tasks) within (their Project).

## Ownership Configuration Examples

### Simple User Ownership
**Scenario**: Users can only edit products they created

- **Access Type**: Owned
- **Ownership Model**: (leave blank)
- **Foreign Key**: (leave blank - auto-detects `user_id`)
- **User Key**: (leave blank - defaults to `user_id`)

### Manager Ownership
**Scenario**: Store managers can edit all orders in stores they manage

- **Access Type**: Owned
- **Ownership Model**: `ProjectManager`
- **Foreign Key**: `project_id`
- **User Key**: `user_id`

This configuration tells CCCUX: "Find all ProjectManager records where user_id matches the current user, get their project_id values, and allow access to tasks with those project_id values."

### Complex Hierarchies
**Scenario**: Regional managers can edit products in all stores in their region

- **Access Type**: Owned
- **Ownership Model**: `RegionalManager`
- **Foreign Key**: `region_id`
- **User Key**: `user_id`

## Model Requirements

**Models need NO special code!** CCCUX works with standard Rails models:

```ruby
class Order < ApplicationRecord
  belongs_to :store
  belongs_to :user
  # That's it! No concerns, no special methods needed
end

class Product < ApplicationRecord
  belongs_to :user
  # Works with simple user_id ownership
end

class Store < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  has_many :store_managers
  # CCCUX handles complex ownership through configuration
end
```

**How it works:**
- CCCUX automatically detects `user_id` and `creator_id` columns for simple ownership
- Complex ownership patterns are handled through the UI configuration
- The CCCUX Ability class dynamically queries your join tables based on your settings

## View Helpers

CCCUX provides convenient view helpers that automatically handle authorization checks:

### Authorization-Aware Helpers

```erb
<!-- These helpers only render if user has permission -->
<%= link_if_can_show @product, "View Product", product_path(@product) %>
<%= link_if_can_edit @product, "Edit Product", edit_product_path(@product) %>
<%= link_if_can_create Product.new, "New Product", new_product_path %>
<%= button_if_can_destroy @product, "Delete", product_path(@product), method: :delete %>
```

### Traditional CanCanCan Helpers

You can also use standard CanCanCan patterns:

```erb
<% if can? :read, @product %>
  <%= link_to "View Product", product_path(@product) %>
<% end %>

<% if can? :update, @product %>
  <%= link_to "Edit Product", edit_product_path(@product) %>
<% end %>

<% if can? :create, Product %>
  <%= link_to "New Product", new_product_path %>
<% end %>

<% if can? :destroy, @product %>
  <%= link_to "Delete", product_path(@product), method: :delete, 
              confirm: "Are you sure?" %>
<% end %>
```

### Converting Existing Views

CCCUX includes a development tool to convert existing Rails views to use authorization helpers:

```bash
# Convert all views in a directory
rails cccux:convert_views[app/views/products]
rails cccux:convert_views[app/views/stores]

# See conversion examples
rails cccux:view_examples
```

**What it converts:**
- `link_to` patterns → `link_if_can_show`, `link_if_can_edit`
- `button_to` delete patterns → `button_if_can_destroy`  
- "New" links → `link_if_can_create`
- Complex nested conditionals → context-aware helpers
- Handles nested resource routes automatically

**Example conversion:**
```erb
<!-- BEFORE -->
<% if @project %>
  <%= link_to "Edit Task", edit_project_task_path(@project, @task) %>
<% else %>
  <%= link_to "Edit Task", edit_task_path(@task) %>
<% end %>

<!-- AFTER -->
<%= link_if_can_edit @task, "Edit Task", @project ? edit_project_task_path(@project, @task) : edit_task_path(@task) %>
```

This conversion tool saves significant time when adding CCCUX to existing applications.

## Admin Interface

Navigate to `/cccux` to access the admin interface:

- **Dashboard**: Overview of roles, users, and permissions
- **Roles**: Create and manage roles with drag-and-drop priority ordering
- **Permissions**: View and create permissions for your models
- **Users**: Assign roles to users
- **Model Discovery**: Automatically detect new models and create permissions

## Error Handling

CCCUX automatically handles authorization errors:

- **Access Denied**: Redirects to root path with appropriate error message
- **Record Not Found**: Handles missing records gracefully
- **Admin Access**: Restricts admin interface to Role Managers only

## Testing

Test your authorization with standard Rails testing:

```ruby
class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
    sign_in @user
  end

  test "should get index when authorized" do
    @user.add_role('Basic User')
    get products_url
    assert_response :success
  end

  test "should deny access when not authorized" do
    get products_url
    assert_redirected_to root_path
  end
end
```

## Advanced Usage

### Custom Ability Logic

If you need custom authorization logic, you can override the `current_ability` method in your controller:

```ruby
class ProductsController < ApplicationController
  load_and_authorize_resource
  
  private
  
  def current_ability
    # Add custom context for complex scenarios
    context = {}
    context[:store_id] = params[:store_id] if params[:store_id]
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end
```

### Multiple Role Assignment

Users can have multiple roles, and permissions are cumulative:

```ruby
user.add_role('Basic User')
user.add_role('Store Manager')
user.roles # => ['Basic User', 'Store Manager']
```

### Checking Roles in Code

```ruby
current_user.has_role?('Role Manager')  # => true/false
current_user.roles                      # => ['Basic User', 'Store Manager']
```

## Setup Task Details

The `rails cccux:setup` task performs these steps:

1. **Devise Check**: Ensures Devise is installed and configured
2. **Route Mounting**: Adds CCCUX routes to your application
3. **ApplicationController Configuration**: Automatically adds the CCCUX concern
4. **Database Setup**: Creates all necessary tables and indexes
5. **Default Data**: Seeds roles, permissions, and creates admin user
6. **Status Verification**: Confirms all components are properly configured

The setup task is idempotent - you can run it multiple times safely.

## Why CCCUX is Simple

Traditional authorization solutions require:
- Complex model concerns and methods
- Manual ability class configuration
- Custom ownership logic in every model
- Lots of boilerplate code

**CCCUX eliminates all of this:**
- ✅ One line per controller: `load_and_authorize_resource`
- ✅ No model code required
- ✅ UI-driven configuration
- ✅ Automatic setup and integration
- ✅ Works with standard Rails patterns

## Troubleshooting

### Common Issues

**"Access denied" for everything:**
- Check that your models have been discovered (visit `/cccux/permissions`)
- Verify user has appropriate roles assigned
- Ensure permissions are configured for the role

**Controllers not authorizing:**
- Make sure `load_and_authorize_resource` is added to the controller
- Check that the setup task configured your ApplicationController

**Complex ownership not working:**
- Verify ownership model, foreign key, and user key are correct
- Check that the join table exists and has the expected columns
- Test the ownership configuration in the Rails console

### Getting Help

1. Check the `/cccux/status` page for configuration issues
2. Review the Rails logs for authorization errors
3. Use the Rails console to test permissions: `current_user.can?(:read, Product)`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

This project is licensed under the MIT License.
