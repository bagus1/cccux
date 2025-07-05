# CCCUX - Role-Based Authorization Engine

CCCUX is a Rails engine that provides comprehensive role-based authorization with CanCanCan integration, flexible permissions, ownership scoping, and a clean admin interface.

## Features

- **Role-Based Authorization**: Define roles with granular permissions
- **CanCanCan Integration**: Seamless integration with CanCanCan authorization library
- **Flexible Permissions**: CRUD permissions with ownership scoping options
- **Ownership Scoping**: Automatic filtering based on user ownership
- **Admin Interface**: Clean, intuitive interface for role management
- **Drag & Drop Reordering**: Visual role priority management
- **Rails 8 Compatible**: Works with Rails 8 and Propshaft asset pipeline

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

## Quick Start

### 1. Install the Engine

Add to your Gemfile:
```ruby
gem 'cccux', path: 'path/to/cccux'
```

### 2. Run the Installer

```bash
rails generate cccux:install
```

### 3. Set Up Your Models

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

### 4. Create Controllers

For host app controllers:
```ruby
class UsersController < Cccux::AuthorizationController
  # Automatically gets authorization, error handling, and resource loading
end
```

For CCCUX admin controllers:
```ruby
module Cccux
  class RolesController < CccuxController
    # Gets full admin functionality with Role Manager access control
  end
end
```

### 5. Use Authorization in Views

```erb
<% if can? :read, @user %>
  <%= link_to "View User", user_path(@user) %>
<% end %>

<% if can? :update, @store %>
  <%= link_to "Edit Store", edit_store_path(@store) %>
<% end %>
```

## Authorization Patterns

### Primary Pattern: `Model.owned`

Use the `owned` scope for automatic ownership filtering:

```ruby
class UsersController < Cccux::AuthorizationController
  def index
    @users = User.owned.includes(:cccux_roles)
  end
end
```

### Legacy Pattern: `accessible_by(current_ability)`

For complex queries that can't use the `owned` scope:

```ruby
class UsersController < Cccux::AuthorizationController
  def index
    @users = User.accessible_by(current_ability).includes(:cccux_roles)
  end
end
```

## Model Requirements

### Required Methods

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

## Role Management

### Creating Roles

```ruby
# Create a basic user role
role = Cccux::Role.create!(
  name: 'Basic User',
  priority: 1,
  permissions_attributes: [
    { resource: 'User', actions: ['read', 'update'], ownership_scope: 'owned' },
    { resource: 'Store', actions: ['read'], ownership_scope: 'owned' }
  ]
)
```

### Assigning Roles to Users

```ruby
user.add_role('Basic User')
user.add_role('Role Manager')
```

### Checking Permissions

```ruby
user.can?(:read, User)           # => true/false
user.can?(:update, @store)       # => true/false
user.has_role?('Role Manager')   # => true/false
```

## Asset Pipeline

CCCUX is compatible with Rails 8's Propshaft asset pipeline. Assets are automatically included when the engine is mounted.

## Development

### Running Tests

```bash
cd cccux
bundle exec rspec
```

### Local Development

```bash
# In the engine directory
bundle install
rails server

# In the host app
bundle exec rails server
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
