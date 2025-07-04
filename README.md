# CCCUX Authorization Engine

A Rails engine that provides flexible role-based authorization using CanCan and a clean admin interface.

## Features

- **Role-based authorization** with CanCan integration
- **Flexible permissions** - define permissions for any model/action combination
- **Ownership scoping** - users can access all records or only their own
- **Clean admin interface** - manage roles, permissions, and user assignments
- **Host app integration** - works with your existing User model

## Installation

### Prerequisites
- Rails 7.0+ application
- Ruby 3.0+ 
- Database (SQLite, PostgreSQL, MySQL, etc.)

### Step 1: Add CCCUX to Your Gemfile

Add the CCCUX gem to your application's Gemfile:

```ruby
# For local development (recommended for testing)
gem 'cccux', path: '../cccux'

# Or specify the full path to the CCCUX directory
gem 'cccux', path: '/path/to/your/cccux/directory'
```

### Step 2: Install Dependencies

Run bundle install to add CCCUX and its dependencies:

```bash
bundle install
```

### Step 3: Run the Setup Task

Execute the CCCUX setup task:

```bash
rails cccux:setup
```

The setup task will:

1. **Check for User Model**: Verify you have a User model in your application
2. **Devise Detection**: If Devise is not detected, it will prompt you to install it:
   ```
   Devise not detected. Would you like to install Devise? (y/n)
   ```
   - If you choose 'y', it will run `rails generate devise:install`
   - If you choose 'n', you'll need to set up authentication manually

3. **Database Setup**: Run CCCUX migrations to create the necessary tables
4. **Default Data**: Create default roles and permissions
5. **Role Manager User**: If no users exist, it will prompt you to create a Role Manager user:
   ```
   No users found. Would you like to create a Role Manager user? (y/n)
   ```
   - If you choose 'y', it will prompt for email and password
   - This user will have full access to the CCCUX admin interface

### Step 4: Start Your Server

Start your Rails server:

```bash
rails server
```

### Step 5: Access the Admin Interface

1. **Navigate to the dashboard**: Go to `http://localhost:3000/cccux`
2. **Login**: Use the Role Manager credentials you created during setup
3. **Begin configuration**: Use the dashboard to manage roles, permissions, and users

### What Gets Created

The setup process creates:

- **Database Tables**: `cccux_roles`, `cccux_ability_permissions`, `cccux_user_roles`, `cccux_role_abilities`
- **Default Roles**: Guest, Basic User, Store Manager, Role Manager, Administrator
- **Default Permissions**: Basic CRUD permissions for common models
- **Role Manager User**: Admin user with full CCCUX access (if created during setup)

### Troubleshooting

#### "Could not locate Gemfile" Error
Make sure you're in your Rails application directory when running bundle commands.

#### Devise Installation Issues
If Devise installation fails, you can install it manually:
```bash
rails generate devise:install
rails generate devise User
rails db:migrate
```

#### Migration Errors
If migrations fail, ensure your database is properly configured:
```bash
rails db:create
rails db:migrate
```

#### Permission Issues
If you can't access `/cccux`, ensure:
- You're logged in with a user that has the Role Manager role
- The user was created successfully during setup
- Your User model includes the CCCUX concern (should be automatic)

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
    # Use the owned scope for clean, consistent authorization
    if params[:store_id]
      store = Store.find(params[:store_id])
      @orders = store.orders.owned
    else
      @orders = Order.owned
    end
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

### Authorization Patterns

CCCUX provides a clean, consistent authorization pattern using the `owned` scope:

```ruby
# Include the Authorizable concern in your models
class Order < ApplicationRecord
  include Cccux::Authorizable
  belongs_to :user
end

class Store < ApplicationRecord
  include Cccux::Authorizable
  has_many :store_managers
  has_many :managers, through: :store_managers, source: :user
end

# Use the owned scope in your controllers
class OrdersController < ApplicationController
  load_and_authorize_resource
  
  def index
    @orders = Order.owned.order(:created_at)  # Clean and consistent
  end
end

class StoresController < ApplicationController
  load_and_authorize_resource
  
  def index
    @stores = Store.owned.order(:name)  # Clean and consistent
  end
end
```

**Benefits of the `owned` scope:**
- **Shorter syntax**: `Order.owned` vs `Order.accessible_by(current_ability)`
- **Consistent across all models**: Same pattern for User, Store, Order, etc.
- **Automatic ownership detection**: CCCUX automatically applies the correct ownership logic
- **Performance optimized**: Includes proper eager loading and joins

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

The engine provides several base controller classes for different use cases:

```ruby
# For CCCUX admin functionality
class MyController < Cccux::CccuxController
  # Uses CCCUX admin layout and authorization
end

# For host app controllers with CCCUX authorization
class OrdersController < Cccux::AuthorizationController
  load_and_authorize_resource
  # Uses your app's layout with CCCUX authorization
end
```

For detailed controller patterns and inheritance requirements, see [CONTROLLER_GUIDE.md](CONTROLLER_GUIDE.md).

For a quick reference of common patterns, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md).

For detailed user documentation on using the admin interface, see [USER_GUIDE.md](USER_GUIDE.md).

For comprehensive view helper documentation and examples, see [VIEW_GUIDE.md](VIEW_GUIDE.md).

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
