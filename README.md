# CCCUX Authorization Engine

A Rails engine that provides flexible role-based authorization using CanCan and a clean admin interface.

## Features

- **Role-based authorization** with CanCan integration
- **Flexible permissions** - define permissions for any model/action combination
- **Ownership scoping** - users can access all records or only their own
- **Clean admin interface** - manage roles, permissions, and user assignments
- **Host app integration** - works with your existing User model

## Installation

1. Add to your Gemfile:
```ruby
gem 'cccux', path: 'path/to/cccux'
```

2. Run the setup task:
```bash
rails cccux:setup
```

This will:
- Check if you have a User model
- Offer to install Devise if needed
- Run database migrations
- Create default roles and permissions
- Create an admin user (if no users exist)

## Integration with Host App

### 1. Include CCCUX in your User model

```ruby
class User < ApplicationRecord
  include CccuxUserConcern
  
  # Your existing User model code...
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
end
```

### 2. Use authorization in your controllers

```ruby
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    # CanCan will automatically scope based on user permissions
    @orders = @orders.page(params[:page])
  end
  
  def create
    if @order.save
      redirect_to @order, notice: 'Order created!'
    else
      render :new
    end
  end
end
```

### 3. Check permissions in views

```erb
<% if can? :create, Order %>
  <%= link_to 'New Order', new_order_path %>
<% end %>

<% if can? :update, @order %>
  <%= link_to 'Edit', edit_order_path(@order) %>
<% end %>
```

## Usage

### User Methods

Once you include `CccuxUserConcern`, your User model gets these methods:

```ruby
user = User.first

# Role checking
user.has_role?('Administrator')
user.has_any_role?('Admin', 'Manager')
user.admin?
user.role_manager?

# Permission checking
user.can?(:create, Order)
user.cannot?(:destroy, User)

# Role management
user.assign_role('Basic User')
user.remove_role('Guest')
user.role_names
```

### Creating Permissions

Permissions are automatically created when you run the setup task, but you can also create them manually:

```ruby
# Create a permission for creating orders
Cccux::AbilityPermission.create!(
  action: 'create',
  subject: 'Order',
  description: 'Create new orders',
  active: true
)

# Assign to a role
role = Cccux::Role.find_by(name: 'Basic User')
permission = Cccux::AbilityPermission.find_by(action: 'create', subject: 'Order')

Cccux::RoleAbility.create!(
  role: role,
  ability_permission: permission,
  owned: true  # Users can only create their own orders
)
```

### Default Roles

The setup creates these default roles:

- **Guest** (priority 100) - Unauthenticated users with minimal read access
- **Basic User** (priority 50) - Standard authenticated users
- **Role Manager** (priority 25) - Can manage roles and permissions
- **Administrator** (priority 1) - Full system access

## Admin Interface

Visit `/cccux` to access the admin interface where you can:

- Manage roles and their permissions
- Assign roles to users
- Create new permissions for your models
- View system statistics

## Configuration

### Customizing the Engine

You can customize the engine by creating initializers:

```ruby
# config/initializers/cccux.rb
Cccux.configure do |config|
  config.admin_email = 'admin@example.com'
  config.default_role = 'Basic User'
end
```

### Authorization in Controllers

The engine provides a base controller with authorization:

```ruby
class MyController < Cccux::CccuxController
  # Authorization is automatically handled
end
```

## Development

### Running Tests

```bash
bundle exec rspec
```

### Local Development

1. Clone the engine
2. Add to your test app's Gemfile: `gem 'cccux', path: '../cccux'`
3. Run `bundle install`
4. Run `rails cccux:setup`

## License

MIT License - see LICENSE file for details.
