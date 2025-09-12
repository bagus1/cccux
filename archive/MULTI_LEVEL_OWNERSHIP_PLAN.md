# Multi-Level Ownership System Plan

## Overview

This document outlines the plan to extend CCCUX's ownership system from single-level indirect ownership to multi-level ownership chains, supporting complex hierarchical relationships like `Topic Managers → Topics → Posts → Comments`.

## Current System

### Single-Level Ownership
- **Direct**: `User → Post` (user owns posts directly)
- **Indirect**: `User → PostManager → Post` (user owns posts through a join table)

### Current Permission Structure
```json
{
  "ownership_source": "ProjectManager",
  "ownership_conditions": {
    "foreign_key": "project_id",
    "user_key": "user_id"
  }
}
```

## Proposed Multi-Level System

### Ownership Chains
Support for complex ownership relationships:
```
User → TopicManager → Topic → Post → Comment
User → ProjectManager → Project → Task → Subtask
User → StoreManager → Store → Product → Review
```

### New Permission Structure
```json
{
  "ownership_source": "TopicManager",
  "ownership_conditions": {
    "ownership_chain": [
      {"model": "TopicManager", "foreign_key": "topic_id", "user_key": "user_id"},
      {"model": "Post", "foreign_key": "topic_id", "target_key": "topic_id"},
      {"model": "Comment", "foreign_key": "post_id", "target_key": "post_id"}
    ]
  }
}
```

## Technical Implementation

### 1. Enhanced Ability Class

#### Current Logic
```ruby
def apply_owned_ability(action, model_class, user, role_ability = nil)
  if role_ability && role_ability.ownership_source.present?
    ownership_model = role_ability.ownership_source.constantize
    conditions = JSON.parse(role_ability.ownership_conditions)
    foreign_key = conditions["foreign_key"]
    user_key = conditions["user_key"] || "user_id"
    
    owned_ids = ownership_model.where(user_key => user.id).pluck(foreign_key)
    can action, model_class, foreign_key.to_sym => owned_ids
  end
end
```

#### New Logic
```ruby
def apply_owned_ability(action, model_class, user, role_ability = nil)
  if role_ability && role_ability.ownership_source.present?
    conditions = JSON.parse(role_ability.ownership_conditions)
    
    if conditions["ownership_chain"]
      apply_ownership_chain_ability(action, model_class, user, role_ability)
    else
      apply_single_level_ability(action, model_class, user, role_ability)
    end
  end
end

def apply_ownership_chain_ability(action, model_class, user, role_ability)
  chain = JSON.parse(role_ability.ownership_conditions)["ownership_chain"]
  owned_ids = [user.id]
  
  chain.each do |step|
    ownership_model = step["model"].constantize
    foreign_key = step["foreign_key"]
    user_key = step["user_key"] || "user_id"
    target_key = step["target_key"] || foreign_key
    
    owned_ids = ownership_model.where(user_key => owned_ids).pluck(target_key)
    break if owned_ids.empty?
  end
  
  if owned_ids.any?
    can action, model_class, id: owned_ids
  else
    can action, model_class, id: []
  end
end
```

### 2. Model Structure Examples

#### Topic Management System
```ruby
class TopicManager < ApplicationRecord
  belongs_to :user
  belongs_to :topic
  validates :user_id, uniqueness: { scope: :topic_id }
end

class Topic < ApplicationRecord
  has_many :topic_managers, dependent: :destroy
  has_many :managers, through: :topic_managers, source: :user
  has_many :posts, dependent: :destroy
end

class Post < ApplicationRecord
  belongs_to :topic
  has_many :comments, dependent: :destroy
end

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
end
```

#### Project Management System
```ruby
class ProjectManager < ApplicationRecord
  belongs_to :user
  belongs_to :project
  validates :user_id, uniqueness: { scope: :project_id }
end

class Project < ApplicationRecord
  has_many :project_managers, dependent: :destroy
  has_many :managers, through: :project_managers, source: :user
  has_many :tasks, dependent: :destroy
end

class Task < ApplicationRecord
  belongs_to :project
  has_many :subtasks, dependent: :destroy
end

class Subtask < ApplicationRecord
  belongs_to :task
end
```

### 3. Permission Setup Examples

#### Topic Manager Permissions
```ruby
# Topic Manager can edit comments in posts within topics they manage
topic_manager_role.role_abilities.create!(
  ability_permission: comment_update_permission,
  owned: true,
  ownership_source: "TopicManager",
  ownership_conditions: {
    "ownership_chain": [
      {"model": "TopicManager", "foreign_key": "topic_id", "user_key": "user_id"},
      {"model": "Post", "foreign_key": "topic_id", "target_key": "topic_id"},
      {"model": "Comment", "foreign_key": "post_id", "target_key": "post_id"}
    ]
  }.to_json
)
```

#### Project Manager Permissions
```ruby
# Project Manager can edit subtasks in tasks within projects they manage
project_manager_role.role_abilities.create!(
  ability_permission: subtask_update_permission,
  owned: true,
  ownership_source: "ProjectManager",
  ownership_conditions: {
    "ownership_chain": [
      {"model": "ProjectManager", "foreign_key": "project_id", "user_key": "user_id"},
      {"model": "Task", "foreign_key": "project_id", "target_key": "project_id"},
      {"model": "Subtask", "foreign_key": "task_id", "target_key": "task_id"}
    ]
  }.to_json
)
```

## User Interface Changes

### 1. Role-Edit Interface

#### Current Interface
```
Role: Project Manager
Permissions:
- Read Tasks (Global)
- Create Tasks (Owned via ProjectManager)
- Update Tasks (Owned via ProjectManager)
- Delete Tasks (Owned via ProjectManager)
```

#### New Interface
```
Role: Topic Manager
Permissions:
- Read Comments (Global)
- Create Comments (Owned via TopicManager → Post → Comment)
- Update Comments (Owned via TopicManager → Post → Comment)
- Delete Comments (Owned via TopicManager → Post → Comment)
```

### 2. Permission Creation Interface

#### Current
```
[Action] [Subject] [Context] [Ownership Source] [Conditions]
```

#### New
```
[Action] [Subject] [Context] [Ownership Chain]
├── Step 1: [Model] [Foreign Key] [User Key]
├── Step 2: [Model] [Foreign Key] [Target Key]
├── Step 3: [Model] [Foreign Key] [Target Key]
└── [Add Step] [Remove Step]
```

### 3. Chain Visualization
```
User → TopicManager → Topic → Post → Comment
[You] [Manages] [Contains] [Contains] [Target]
```

### 4. Permission Testing Interface
```
Test Permission: Can User update Comment 1?
Result: ✅ Yes (User → TopicManager → Topic A → Post 1 → Comment 1)
Chain: User(1) → TopicManager → Topic(5) → Post(12) → Comment(25)
```

## UX Changes

### 1. Dashboard Complexity

#### Current
```
My Projects:
- Project A (I manage)
- Project B (I manage)
```

#### New
```
My Topics:
- Topic A (I manage)
  - 15 Posts
  - 3 Active Discussions
- Topic B (I manage)
  - 8 Posts
  - 1 Active Discussion

My Projects:
- Project X (I manage directly)
- Project Y (I manage via Topic A)
```

### 2. Navigation Structure

#### Current
```
Projects → Project A → Tasks → Task 1
```

#### New
```
Topics → Topic A → Posts → Post 1 → Comments → Comment 1
```

### 3. Permission Indicators

#### Current
```
[Edit] [Delete] Task 1
```

#### New
```
[Edit] [Delete] Post 1 (via Topic A management)
[Edit] [Delete] Comment 1 (via Topic A → Post 1)
```

### 4. Content Filtering

#### Current
```
Show: All Tasks | My Tasks | Project Tasks
```

#### New
```
Show: All Content | My Content | Topic Content | Direct Content
Filter by: Topic | Project | Post | Comment
```

## Implementation Steps

### Phase 1: Backend Foundation
1. **Extend Ability class** to handle ownership chains
2. **Add chain validation** and integrity checks
3. **Create migration tools** for existing permissions
4. **Add performance optimizations** (caching, lazy loading)

### Phase 2: Database Schema
1. **Extend RoleAbility model** to support complex conditions
2. **Add chain validation** at the database level
3. **Create indexes** for efficient chain traversal
4. **Add migration scripts** for existing data

### Phase 3: User Interface
1. **Update role-edit interface** to support chain building
2. **Add visual chain builder** with drag-and-drop
3. **Create permission testing tools**
4. **Add chain visualization** and debugging tools

### Phase 4: Advanced Features
1. **Add chain inheritance** (child permissions inherit parent chain)
2. **Implement chain optimization** suggestions
3. **Add bulk permission management** for chains
4. **Create chain templates** for common patterns

## Performance Considerations

### 1. Chain Caching
```ruby
# Cache ownership chains for frequently accessed permissions
Rails.cache.fetch("ownership_chain:#{user.id}:#{model_class}") do
  calculate_ownership_chain(user, model_class)
end
```

### 2. Lazy Loading
```ruby
# Load chain steps only when needed
def load_chain_step(step, user_ids)
  model = step["model"].constantize
  model.where(step["user_key"] => user_ids).pluck(step["foreign_key"])
end
```

### 3. Chain Optimization
```ruby
# Suggest shorter chains when possible
def optimize_chain(chain)
  # Remove redundant steps
  # Combine similar operations
  # Cache intermediate results
end
```

## Migration Strategy

### 1. Backward Compatibility
- Keep existing single-level permissions working
- Support both old and new permission formats
- Provide migration tools for existing roles

### 2. Gradual Rollout
- Start with new projects using multi-level ownership
- Migrate existing projects gradually
- Provide training and documentation

### 3. Testing Strategy
- Unit tests for chain traversal logic
- Integration tests for complex ownership scenarios
- Performance tests for chain caching
- User acceptance tests for UI changes

## Benefits

### 1. Real-World Modeling
- Supports complex organizational hierarchies
- Matches how organizations actually work
- Handles cross-departmental permissions

### 2. Flexibility
- Supports any depth of ownership relationships
- Configurable chain patterns
- Extensible for future requirements

### 3. Performance
- Efficient chain traversal algorithms
- Smart caching strategies
- Optimized database queries

### 4. User Experience
- Intuitive permission management
- Clear ownership visualization
- Powerful yet simple interface

## Risks and Mitigation

### 1. Complexity
- **Risk**: System becomes too complex to understand
- **Mitigation**: Clear documentation, visual tools, gradual rollout

### 2. Performance
- **Risk**: Chain traversal becomes slow with deep hierarchies
- **Mitigation**: Caching, optimization, performance monitoring

### 3. User Adoption
- **Risk**: Users struggle with new interface
- **Mitigation**: Training, documentation, migration tools

### 4. Maintenance
- **Risk**: Complex chains become difficult to debug
- **Mitigation**: Debugging tools, chain visualization, logging

## Conclusion

Multi-level ownership would significantly enhance CCCUX's capabilities, making it suitable for complex real-world applications while maintaining the simplicity and flexibility that makes it valuable for developers.

The key to success is implementing this incrementally, with strong backward compatibility and comprehensive testing at each stage. 