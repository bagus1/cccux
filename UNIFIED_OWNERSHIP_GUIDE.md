# CCCUX Unified Ownership Guide

## Overview

CCCUX now uses a simplified, unified approach to ownership permissions. Instead of separate "contextual" and "owned" access types, there is now a single **"owned"** access type that can handle both direct ownership and contextual ownership patterns.

## Access Types

### Global
- **What it does:** Access to all records everywhere
- **Use case:** Administrators, managers with broad access
- **Configuration:** No additional configuration needed

### Owned
- **What it does:** Access to records you own, or records you have access to via a parent/manager relationship
- **Use case:** Users who own records directly, or managers who should access records in their scope
- **Configuration:** Configure ownership model and keys to define what "owned" means

## Ownership Configuration

When you select "Owned" access for a permission, you can configure:

### Ownership Model
The model that defines the ownership relationship (optional).
- Leave blank for simple `user_id` ownership
- Set to a join model like `StoreManager` for complex relationships

### Foreign Key
The field that links the main model to the ownership model.
- Auto-detected if blank (usually the model's foreign key)
- Example: `store_id` for orders managed through stores

### User Key
The field in the ownership model that identifies the user.
- Defaults to `user_id` if blank
- Example: `user_id` in the `StoreManager` join table

## Examples

### Simple Direct Ownership
**Scenario:** Users can only edit candles they created

- **Access Type:** Owned
- **Ownership Model:** (leave blank)
- **Foreign Key:** (leave blank - auto-detects `user_id`)
- **User Key:** (leave blank - defaults to `user_id`)

### Store Manager Ownership
**Scenario:** Store managers can edit all orders in stores they manage

- **Access Type:** Owned
- **Ownership Model:** `StoreManager`
- **Foreign Key:** `store_id`
- **User Key:** `user_id`

### Complex Hierarchy
**Scenario:** Regional managers can edit products in all stores in their region

- **Access Type:** Owned
- **Ownership Model:** `RegionalManager`
- **Foreign Key:** `region_id`
- **User Key:** `user_id`

## Migration from Previous Versions

If you were using "contextual" permissions in previous versions, they have been automatically converted to "owned" permissions. You may need to configure the ownership model and keys for proper functionality.

## Model Requirements

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

## Benefits of the Unified Approach

- **Simpler mental model:** One "owned" concept covers all ownership patterns
- **More flexible:** Configure any ownership relationship via the UI
- **Less confusing:** No more wondering whether to use "contextual" or "owned"
- **Consistent behavior:** All ownership patterns work the same way under the hood 