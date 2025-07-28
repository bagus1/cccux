# Megabar Complex Hierarchy Authorization Plan

## Overview
This document outlines approaches for handling Page Manager authorization across the complex hierarchy:
`Page → Layout → Block → Model-Display → Field-Display`

## The Challenge
A Page Manager needs to control access to resources 5 levels deep in the hierarchy, which exceeds CanCanCan's typical single-level ownership model.

## Solution Options

### Option 1: Custom Authorization Service (Recommended)

Create a dedicated authorization service that understands the hierarchy:

```ruby
class MegabarAuthorizationService
  def initialize(user, resource)
    @user = user
    @resource = resource
  end

  def can_manage?
    return false unless @user
    
    # Check if user is a page manager for this resource's page
    page = find_owning_page(@resource)
    return false unless page
    
    @user.roles.any? do |role|
      role.role_abilities.any? do |ra|
        ra.ability_permission.subject == 'Page' &&
        ra.ability_permission.action == 'manage' &&
        ra.ownership_type == 'owned' &&
        ra.ownership_source == 'page_managers' &&
        ra.foreign_key == page.id
      end
    end
  end

  private

  def find_owning_page(resource)
    case resource
    when Page
      resource
    when Layout
      resource.page
    when Block
      resource.layout.page
    when ModelDisplay
      resource.block.layout.page
    when FieldDisplay
      resource.model_display.block.layout.page
    end
  end
end
```

### Option 2: Enhanced CanCanCan Ability Class

Extend the current Ability class to handle complex hierarchies:

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    user.roles.each do |role|
      role.role_abilities.each do |ra|
        permission = ra.ability_permission
        
        case permission.subject
        when 'Page'
          if permission.action == 'manage' && ra.ownership_type == 'owned'
            # Page managers can manage everything under their pages
            can permission.action.to_sym, permission.subject.constantize, 
                id: user.page_manager_pages.pluck(:id)
            
            # Also allow access to all child resources
            can permission.action.to_sym, [Layout, Block, ModelDisplay, FieldDisplay] do |resource|
              resource.page_id.in?(user.page_manager_pages.pluck(:id))
            end
          end
        end
      end
    end
  end
end
```

### Option 3: Database-Level Hierarchy Tracking

Add hierarchy tracking to the database:

```ruby
# Migration to add hierarchy tracking
class AddHierarchyTrackingToMegabarResources < ActiveRecord::Migration[7.1]
  def change
    add_column :layouts, :page_id, :integer
    add_column :blocks, :page_id, :integer
    add_column :model_displays, :page_id, :integer
    add_column :field_displays, :page_id, :integer
    
    add_index :layouts, :page_id
    add_index :blocks, :page_id
    add_index :model_displays, :page_id
    add_index :field_displays, :page_id
  end
end
```

### Option 4: Simplified Role-Based Approach

Instead of complex hierarchy traversal, use simpler role-based permissions:

```ruby
# Define specific roles for each level
ROLES = {
  'Page Manager' => ['Page'],
  'Layout Manager' => ['Layout'],
  'Block Manager' => ['Block'],
  'Display Manager' => ['ModelDisplay', 'FieldDisplay']
}

# Users can have multiple roles
# A Page Manager role gives access to everything under their pages
# A Layout Manager role gives access to layouts and their children
# etc.
```

## Recommended Implementation

### Phase 1: Custom Authorization Service
1. Create `MegabarAuthorizationService` class
2. Implement hierarchy traversal logic
3. Add to controllers and views

### Phase 2: Database Optimization
1. Add `page_id` to all child tables
2. Update models to maintain these relationships
3. Add database indexes for performance

### Phase 3: Integration with CCCUX
1. Extend CCCUX to support custom authorization services
2. Add UI for configuring complex permissions
3. Create admin interface for hierarchy management

## Performance Considerations

### Caching Strategy
```ruby
class MegabarAuthorizationService
  def can_manage?
    Rails.cache.fetch("megabar_auth_#{@user.id}_#{@resource.class}_#{@resource.id}", expires_in: 1.hour) do
      # Authorization logic here
    end
  end
end
```

### Database Optimization
- Add composite indexes on hierarchy columns
- Use counter caches for relationship counts
- Consider materialized views for complex queries

## UI/UX Considerations

### Role Assignment Interface
- Tree view showing hierarchy
- Checkbox interface for selecting managed resources
- Visual indicators for inherited permissions

### Permission Testing
- Test permissions at each level
- Show what resources a user can access
- Preview changes before applying

## Migration Strategy

1. **Start Simple**: Implement basic page-level permissions
2. **Add Hierarchy**: Gradually add support for child resources
3. **Optimize**: Add caching and database optimizations
4. **Enhance UI**: Improve the admin interface

## Alternative: Consider Different Authorization Framework

If the hierarchy becomes too complex, consider:

- **Pundit**: More flexible for complex authorization logic
- **Declarative Authorization**: Better for hierarchical permissions
- **Custom Solution**: Build exactly what you need

## Conclusion

The complex hierarchy is challenging but not impossible. The custom authorization service approach provides the most flexibility while maintaining good performance. Start with a simple implementation and gradually add complexity as needed. 