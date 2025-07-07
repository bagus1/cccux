# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-07-07

### Added

#### Core Features
- **Role-Based Access Control (RBAC)**: Complete RBAC system with Users, Roles, and RoleAbilities models
- **Admin Interface**: Comprehensive admin controllers for managing users, roles, and permissions
- **CanCanCan Integration**: Seamless integration with CanCanCan authorization framework
- **Unified Ownership System**: Simplified ownership model supporting both direct and contextual ownership

#### Models
- `Cccux::User` - User management with role assignments
- `Cccux::Role` - Role definition and management
- `Cccux::RoleAbility` - Permission configuration with flexible ownership patterns
- `Cccux::UserRole` - Join table for user-role associations

#### Controllers
- `Cccux::UsersController` - User management interface
- `Cccux::RolesController` - Role creation and editing
- `Cccux::RoleAbilitiesController` - Permission configuration interface
- `Cccux::ApplicationControllerConcern` - Authorization concern for host applications

#### Setup and Configuration
- **Automated Setup Task**: `rails cccux:setup` for one-command installation
- **Status Task**: `rails cccux:status` for configuration verification
- **View Conversion Tool**: `rails cccux:convert_views[directory]` for automated view helper conversion
- **ApplicationController Integration**: Automatic configuration of authorization concerns

#### View Helpers
- `link_if_can_show` - Conditional show links based on permissions
- `link_if_can_edit` - Conditional edit links based on permissions
- `link_if_can_create` - Conditional create links based on permissions
- `button_if_can_destroy` - Conditional delete buttons based on permissions
- Support for nested resource routes and complex authorization patterns

#### Authorization Features
- **Flexible Ownership Configuration**: Support for multiple ownership patterns via UI
- **Contextual Permissions**: Users can have permissions within specific contexts (e.g., store managers)
- **Fallback Mechanisms**: Multiple ownership detection methods (custom `owned_by?`, `user_id`, `creator_id`)
- **Security by Default**: Deny access when no permissions are configured

#### Documentation
- Comprehensive README with setup instructions and examples
- Unified Ownership Guide explaining the simplified permission model
- Generators documentation for scaffolding
- Controller setup examples and best practices

### Technical Details
- **Rails Compatibility**: Supports Rails 7.1+ 
- **Ruby Compatibility**: Requires Ruby 3.0+
- **Database Agnostic**: Works with any Rails-supported database
- **Engine Architecture**: Implemented as a Rails engine for easy integration
- **Zeitwerk Compatible**: Fully compatible with Rails' autoloading system

### Migration Path
- Automatic migration from complex contextual/owned permission types to unified "owned" type
- Backward compatibility maintained during transition period
- Clear upgrade path for existing installations

[0.1.0]: https://github.com/yourusername/cccux/releases/tag/v0.1.0 