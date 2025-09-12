# CCCUX Advanced Features

This document covers advanced CCCUX features including complex ownership patterns, multi-level hierarchies, and MegaBar integration.

## Table of Contents

- [Unified Ownership System](#unified-ownership-system)
- [Multi-Level Ownership (Planned)](#multi-level-ownership-planned)
- [MegaBar Integration](#megabar-integration)
- [Custom Authorization Patterns](#custom-authorization-patterns)

---

## Unified Ownership System

CCCUX uses a simplified, unified approach to ownership permissions. Instead of separate "contextual" and "owned" access types, there is now a single **"owned"** access type that can handle both direct ownership and contextual ownership patterns.

### Access Types

#### Global

- **What it does:** Access to all records everywhere
- **Use case:** Administrators, managers with broad access
- **Configuration:** No additional configuration needed

#### Owned

- **What it does:** Access to records you own, or records you have access to via a parent/manager relationship
- **Use case:** Users who own records directly, or managers who should access records in their scope
- **Configuration:** Configure ownership model and keys to define what "owned" means

### Ownership Configuration

When you select "Owned" access for a permission, you can configure:

#### Ownership Model

The model that defines the ownership relationship (optional).

- Leave blank for simple `user_id` ownership
- Set to a join model like `StoreManager` for complex relationships

#### Foreign Key

The field that links the main model to the ownership model.

- Auto-detected if blank (usually the model's foreign key)
- Example: `store_id` for orders managed through stores

#### User Key

The field in the ownership model that identifies the user.

- Defaults to `user_id` if blank
- Example: `user_id` in the `StoreManager` join table

### Examples

#### Simple Direct Ownership

**Scenario:** Users can only edit candles they created

- **Access Type:** Owned
- **Ownership Model:** (leave blank)
- **Foreign Key:** (leave blank - auto-detects `user_id`)
- **User Key:** (leave blank - defaults to `user_id`)

#### Store Manager Ownership

**Scenario:** Store managers can edit all orders in stores they manage

- **Access Type:** Owned
- **Ownership Model:** `StoreManager`
- **Foreign Key:** `store_id`
- **User Key:** `user_id`

#### Complex Hierarchy

**Scenario:** Regional managers can edit products in all stores in their region

- **Access Type:** Owned
- **Ownership Model:** `RegionalManager`
- **Foreign Key:** `region_id`
- **User Key:** `user_id`

### Model Requirements

For "owned" permissions to work, your models should either:

1. **Include the `Cccux::ScopedOwnership` concern:**

   ```ruby
   class Order < ApplicationRecord
     include Cccux::ScopedOwnership

     belongs_to :store
     belongs_to :user

     # Configure both direct and contextual ownership
     scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
   end
   ```

2. **Have a simple `user_id` column** (for basic ownership)

3. **Implement custom `owned_by?` and `scoped_for_user` methods** (advanced)

### Benefits of the Unified Approach

- **Simpler mental model:** One "owned" concept covers all ownership patterns
- **More flexible:** Configure any ownership relationship via the UI
- **Less confusing:** No more wondering whether to use "contextual" or "owned"
- **Consistent behavior:** All ownership patterns work the same way under the hood

---

## Multi-Level Ownership (Planned)

### Overview

This feature will extend CCCUX's ownership system from single-level indirect ownership to multi-level ownership chains, supporting complex hierarchical relationships like `Topic Managers → Topics → Posts → Comments`.

### Current System

#### Single-Level Ownership

- **Direct**: `User → Post` (user owns posts directly)
- **Indirect**: `User → PostManager → Post` (user owns posts through a join table)

### Proposed Multi-Level System

#### Ownership Chains

Support for complex ownership relationships:

```
User → TopicManager → Topic → Post → Comment
User → ProjectManager → Project → Task → Subtask
User → StoreManager → Store → Product → Review
```

#### New Permission Structure

```json
{
  "ownership_source": "TopicManager",
  "ownership_conditions": {
    "ownership_chain": [
      {
        "model": "TopicManager",
        "foreign_key": "topic_id",
        "user_key": "user_id"
      },
      { "model": "Post", "foreign_key": "topic_id", "target_key": "topic_id" },
      { "model": "Comment", "foreign_key": "post_id", "target_key": "post_id" }
    ]
  }
}
```

### Implementation Status

This feature is **planned for future development**. The current unified ownership system handles most use cases effectively.

---

## MegaBar Integration

### Overview

CCCUX integrates seamlessly with MegaBar to provide authorization for dynamic form generation and layout management.

### Current Integration

#### Automatic Permission Creation

When models are created through MegaBar UX, CCCUX automatically creates permissions for:

- Standard CRUD actions (`read`, `create`, `update`, `destroy`)
- MegaBar-specific actions (`administer_page`, `administer_block`, `move`)

#### Controller Integration

MegaBar controllers automatically include CCCUX authorization:

```ruby
class RunbacksController < MegaBar::ApplicationController
  include MegaBar::MegaBarConcern
  # load_and_authorize_resource is automatically configured with proper exclusions
end
```

#### Admin Actions

MegaBar provides special admin actions that work with CCCUX:

- **`administer_page`**: Toggle admin mode for a page
- **`administer_block`**: Toggle admin mode for a block
- **`move`**: Reorder items with position management

### Configuration

#### Model Setup

MegaBar models automatically get CCCUX permissions when created:

```ruby
# This happens automatically when creating a model through MegaBar UX
def create_cccux_permissions_for_model
  # Creates permissions for: read, create, update, destroy, administer_page, administer_block, move
  # Assigns all permissions to "Mega Role"
end
```

#### Controller Setup

MegaBar controllers use `MegaBarConcern` which handles authorization:

```ruby
module MegaBar
  module MegaBarConcern
    included do
      if defined?(Cccux::ApplicationControllerConcern)
        load_and_authorize_resource(except: [:administer_page, :administer_block])
      end
    end
  end
end
```

### Benefits

- **Zero configuration**: Works out of the box
- **Automatic permissions**: No manual setup needed
- **Consistent authorization**: Same patterns across all MegaBar apps
- **Admin functionality**: Built-in admin mode toggles

---

## Custom Authorization Patterns

### Overriding Ability Logic

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

### Custom Ownership Methods

For complex ownership scenarios, implement custom methods in your models:

```ruby
class Order < ApplicationRecord
  belongs_to :store
  belongs_to :user

  def owned_by?(user)
    # Direct ownership
    return true if user_id == user.id

    # Store manager ownership
    return true if store.store_managers.exists?(user: user)

    # Regional manager ownership
    return true if store.region.regional_managers.exists?(user: user)

    false
  end
end
```

### Context-Aware Permissions

Use context to provide different permissions based on the current situation:

```ruby
class ProjectsController < ApplicationController
  load_and_authorize_resource

  def current_ability
    context = {
      project_id: params[:project_id],
      team_id: params[:team_id],
      organization_id: current_user.organization_id
    }
    @current_ability ||= Cccux::Ability.new(current_user, context)
  end
end
```

### Advanced Role Logic

Create complex role-based logic using CCCUX's flexible permission system:

```ruby
# In your Ability class
def initialize(user, context = {})
  @user = user
  @context = context

  # Base permissions
  can :read, :all if user.has_role?('Guest')
  can :manage, :all if user.has_role?('Administrator')

  # Context-specific permissions
  if context[:project_id]
    can :manage, Task, project_id: context[:project_id] if user.has_role?('Project Manager')
  end
end
```

---

## Migration from Previous Versions

If you were using "contextual" permissions in previous versions, they have been automatically converted to "owned" permissions. You may need to configure the ownership model and keys for proper functionality.

## Getting Help

1. Check the `/cccux/status` page for configuration issues
2. Review the Rails logs for authorization errors
3. Use the Rails console to test permissions: `current_user.can?(:read, Product)`
4. See the main [README.md](README.md) for basic setup and usage
