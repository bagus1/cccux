# CCCUX Context DRY Guide

This guide shows how to use CCCUX's new concerns to eliminate boilerplate code when working with context-aware authorization and nested resources.

## Overview

CCCUX now provides three powerful concerns to DRY up your code:

1. **`Cccux::ContextAware`** - Handles context detection and current_ability override
2. **`Cccux::NestedResource`** - Manages nested resource patterns and routing
3. **`Cccux::ScopedOwnership`** - Provides ownership and scoping patterns for models
4. **`Cccux::NestedAuthorizationController`** - Combines all concerns with ready-to-use CRUD actions

## Key Principles

**🎯 Generic & Configurable**: No hardcoded entity names - works with any parent/child relationship
**🔧 Declarative**: Configure behavior through simple method calls
**🚀 Extensible**: Easy to override for custom scenarios

## Model Configuration Examples

### Basic Owner + Parent Relationship
```ruby
class Product < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :user
  belongs_to :store
  
  # Generic configuration - works with any owner + parent + manager relationship
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
end
```

### Different Parent Relationships
```ruby
class Task < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :user
  belongs_to :project
  
  # Works with any parent entity
  scoped_ownership owner: :user, parent: :project, manager_through: :project_members
end

class Document < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :author, class_name: 'User'
  belongs_to :department
  
  # Custom owner association name
  scoped_ownership owner: :author, parent: :department, manager_through: :department_managers
end
```

### Owner-Only Models
```ruby
class Profile < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :user
  
  # Only owner ownership, no parent relationship
  owner_ownership owner: :user
end
```

### Parent-Only Models
```ruby
class Inventory < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :store
  
  # Only parent ownership, no direct owner
  parent_ownership parent: :store, manager_through: :store_managers
end
```

### Indirect Relationships
```ruby
class LineItem < ApplicationRecord
  include Cccux::ScopedOwnership
  
  belongs_to :order
  # order belongs_to :store
  
  # Access store through order
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers, through: :order
end
```

## Controller Configuration Examples

### Generic Context Awareness
```ruby
class ReportsController < Cccux::AuthorizationController
  include Cccux::ContextAware
  
  # Automatically detects any *_id parameters for context
  # Works with store_id, project_id, department_id, etc.
end
```

### Custom Context Mappings
```ruby
class DashboardController < Cccux::AuthorizationController
  include Cccux::ContextAware
  
  # Map specific parameters to context keys
  context_mapping :show, id: :department_id
  context_mapping :analytics, workspace_id: :workspace_id
end
```

### Nested Resource Controllers
```ruby
class ProductsController < Cccux::NestedAuthorizationController
  # Generic nested resource configuration
  nested_resource :product, parent: :store
  
  def index
    nested_index
  end
  
  # ... other actions use nested_* methods
end

class TasksController < Cccux::NestedAuthorizationController
  # Works with any parent/child relationship
  nested_resource :task, parent: :project
end
```

## Real-World Examples

### E-commerce System
```ruby
# Product belongs to store, managed by store managers
class Product < ApplicationRecord
  include Cccux::ScopedOwnership
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
end

class ProductsController < Cccux::NestedAuthorizationController
  nested_resource :product, parent: :store
end
```

### Project Management System
```ruby
# Task belongs to project, managed by project members
class Task < ApplicationRecord
  include Cccux::ScopedOwnership
  scoped_ownership owner: :assignee, parent: :project, manager_through: :project_memberships
end

class TasksController < Cccux::NestedAuthorizationController
  nested_resource :task, parent: :project
end
```

### Multi-tenant SaaS
```ruby
# Document belongs to workspace, managed by workspace admins
class Document < ApplicationRecord
  include Cccux::ScopedOwnership
  scoped_ownership owner: :author, parent: :workspace, manager_through: :workspace_memberships
end

class DocumentsController < Cccux::NestedAuthorizationController
  nested_resource :document, parent: :workspace
end
```

### Educational Platform
```ruby
# Assignment belongs to course, managed by instructors
class Assignment < ApplicationRecord
  include Cccux::ScopedOwnership
  scoped_ownership owner: :creator, parent: :course, manager_through: :course_instructors
end

class AssignmentsController < Cccux::NestedAuthorizationController
  nested_resource :assignment, parent: :course
end
```

## Advanced Configuration

### Multiple Context Types
```ruby
class AnalyticsController < Cccux::AuthorizationController
  include Cccux::ContextAware

  private

  def build_context
    context = super
    # Add custom context logic
    context[:date_range] = params[:date_range] if params[:date_range]
    context[:region_id] = params[:region_id] if params[:region_id]
    context
  end
end
```

### Complex Ownership Logic
```ruby
class Project < ApplicationRecord
  include Cccux::ScopedOwnership
  
  has_many :project_members
  has_many :users, through: :project_members
  
  # Use generic configuration as base
  scoped_ownership owner: :creator, parent: :organization, manager_through: :organization_admins
  
  # Override for custom logic
  def owned_by?(user)
    return false unless user&.persisted?
    
    # Check creator
    return true if creator_id == user.id
    
    # Check project membership with admin role
    return true if project_members.where(user: user, role: ['admin', 'owner']).exists?
    
    # Fall back to organization management
    organization&.organization_admins&.exists?(user: user)
  end
end
```

## Migration from Hardcoded Approach

### Before (Hardcoded)
```ruby
# Old hardcoded approach
class Product < ApplicationRecord
  def owned_by?(user)
    user_id == user.id || store.managed_by?(user)
  end
  
  def self.scoped_for_user(user)
    # Hardcoded store logic...
  end
  
  def self.in_current_scope?(record, user, context)
    if context[:store_id]
      record.store_id.to_s == context[:store_id].to_s
    # ...
  end
end
```

### After (Generic)
```ruby
# New generic approach
class Product < ApplicationRecord
  include Cccux::ScopedOwnership
  scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
end
```

## Configuration Reference

### ScopedOwnership Options
- `owner:` - The direct owner association (default: `:user`)
- `parent:` - The parent entity association (e.g., `:store`, `:project`)
- `manager_through:` - The association that defines parent managers (e.g., `:store_managers`)
- `through:` - For indirect parent relationships (e.g., `:order` to access store through order)

### ContextAware Options
- `context_mapping(action, mappings)` - Map parameters to context keys for specific actions
- `nested_context(parent_resource)` - Set up standard nested resource context

### NestedResource Options
- `parent:` - Parent resource name (required)
- `class_name:` - Custom resource class name
- `parent_class:` - Custom parent class name

## Benefits

- **🎯 Truly Generic**: Works with any domain model, not just stores/products
- **🔧 Highly Configurable**: Adapt to any ownership pattern
- **📝 Self-Documenting**: Clear intent through declarative configuration
- **🚀 Extensible**: Easy to override for edge cases
- **🛡️ Consistent**: Same patterns across different domains

The concerns are designed to handle 90% of common use cases while remaining completely generic and flexible for any domain model. 