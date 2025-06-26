# CCCUX (CanCanCan UX)

A comprehensive Rails engine that provides admin interface and user experience enhancements for CanCanCan authorization. CCCUX adds role-based access control (RBAC) models, admin controllers for managing permissions, and a clean interface for authorization management.

## Features

- **Complete RBAC System**: User, Role, Ability, and Permission models with proper associations
- **Admin Interface**: Ready-to-use controllers and views for managing authorization
- **CanCanCan Integration**: Seamlessly extends CanCanCan with UX improvements
- **Database Migrations**: Automated setup of authorization tables
- **Flexible Permissions**: Support for action-based and resource-based permissions
- **Role Management**: Hierarchical role system with inheritance
- **User Management**: User-role assignment interface

## Models Included

- `Cccux::User` - User management with role associations
- `Cccux::Role` - Role definitions and hierarchies  
- `Cccux::Ability` - Permission definitions linked to actions/resources
- `Cccux::AbilityPermission` - Join table for ability-permission relationships
- `Cccux::RoleAbility` - Join table for role-ability relationships
- `Cccux::UserRole` - Join table for user-role assignments

## Installation

Add this line to your application's Gemfile:

```ruby
gem "cccux"
```

And then execute:
```bash
$ bundle install
```

Run the installation generator:
```bash
$ rails generate cccux:install
```

Run the migrations:
```bash
$ rails db:migrate
```

## Usage

### 1. Mount the Engine

Add to your `config/routes.rb`:
```ruby
Rails.application.routes.draw do
  mount Cccux::Engine => "/admin"
  # your other routes
end
```

### 2. Configure CanCanCan

In your `app/models/ability.rb`:
```ruby
class Ability
  include CanCan::Ability
  include Cccux::AbilityExtensions

  def initialize(user)
    load_cccux_abilities(user)
    # your custom abilities
  end
end
```

### 3. Admin Interface

Visit `/admin` to access the CCCUX admin interface for managing:
- Users and their roles
- Roles and their abilities
- Abilities and permissions
- Permission assignments

### 4. Integration

Use in your controllers:
```ruby
class ApplicationController < ActionController::Base
  include Cccux::Authorization
  
  before_action :authenticate_user!
  check_authorization
end
```

## Development

After checking out the repo, run:
```bash
$ bundle install
$ cd test/dummy
$ rails db:migrate
$ rails server
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
