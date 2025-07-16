# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-01-27

### Added
- **Multi-level Ownership Support**: Enhanced ownership system to support ownership chains (e.g., ProjectManager → Project → Task)
- **Improved Model Discovery**: Enhanced model discovery to include all application models in role editing interface
- **Enhanced Authorization Logic**: Improved Ability class to handle complex ownership relationships correctly
- **Project Management Integration**: Added support for Project, Task, and ProjectManager models with proper authorization
- **Comprehensive Test Coverage**: Added extensive test coverage for all major components and edge cases

### Fixed
- **Model Loading Issues**: Fixed Zeitwerk autoloading issues with empty model files
- **Ownership Chain Logic**: Fixed ownership checking logic to properly traverse ownership relationships
- **User Registration**: Fixed ActiveModel::UnknownAttributeError during user signup process
- **Permission Inheritance**: Corrected permission inheritance for project managers and task ownership
- **Debug Output Removal**: Cleaned up all debug output statements from production code
- **Test Assertion Warnings**: Fixed auto-generated test methods and missing HTTP requests in tests

### Technical Improvements
- **Enhanced Test Coverage**: Improved test coverage for complex ownership scenarios
- **Better Error Handling**: Enhanced error handling for missing models and invalid ownership configurations
- **Performance Optimizations**: Improved model loading and authorization checking performance
- **Code Quality**: Removed all debug statements and improved code organization

## [0.1.2] - 2025-01-27

### Added
- **Multi-level Ownership Support**: Enhanced ownership system to support ownership chains (e.g., ProjectManager → Project → Task)
- **Improved Model Discovery**: Enhanced model discovery to include all application models in role editing interface
- **Enhanced Authorization Logic**: Improved Ability class to handle complex ownership relationships correctly
- **Project Management Integration**: Added support for Project, Task, and ProjectManager models with proper authorization

### Fixed
- **Model Loading Issues**: Fixed Zeitwerk autoloading issues with empty model files
- **Ownership Chain Logic**: Fixed ownership checking logic to properly traverse ownership relationships
- **User Registration**: Fixed ActiveModel::UnknownAttributeError during user signup process
- **Permission Inheritance**: Corrected permission inheritance for project managers and task ownership

### Technical Improvements
- **Enhanced Test Coverage**: Improved test coverage for complex ownership scenarios
- **Better Error Handling**: Enhanced error handling for missing models and invalid ownership configurations
- **Performance Optimizations**: Improved model loading and authorization checking performance

## [0.1.1] - 2025-07-07

### Added
- **Comprehensive Test Suite**: Added extensive test coverage for all major components
  - Model tests for User, Role, RoleAbility with validations and associations
  - Ability class tests covering all authorization scenarios
  - Controller tests for admin interface functionality  
  - View helper tests for authorization-aware UI components
  - Integration tests for complete authorization workflows
  - Rake task tests for setup and configuration automation
- **Test Fixtures**: Created comprehensive test data fixtures for users and roles
- **Test Documentation**: Detailed test scenarios covering edge cases and security

### Fixed
- **Rails Version Compatibility**: Fixed schema version compatibility with Rails 7.2
- **Dependency Constraints**: Removed incompatible RSpec dependency, using built-in Rails testing

### Technical Improvements
- **Security Testing**: Tests verify deny-by-default security model
- **Ownership Testing**: Comprehensive tests for both direct and contextual ownership
- **Multi-role Testing**: Tests verify cumulative permissions from multiple roles
- **Guest User Testing**: Ensures proper handling of unauthenticated users

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

[0.1.1]: https://github.com/bagus1/cccux/releases/tag/v0.1.1
[0.1.0]: https://github.com/bagus1/cccux/releases/tag/v0.1.0 