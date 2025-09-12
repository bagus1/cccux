# CCCUX Generators

CCCUX provides custom Rails generators that automatically include authorization helpers in your scaffolds.

## Available Generators

### 1. Full Scaffold Generator

Generates a complete scaffold with CCCUX authorization built-in:

```bash
rails generate cccux:scaffold Product name:string price:decimal
```

This generator:
- Creates model, controller, views, and migrations
- Adds `belongs_to :user` to the model
- Includes `Cccux::AuthorizationController` in ApplicationController
- Adds `authorize_resource` to the generated controller
- Uses CCCUX helpers (`link_if_can_*`) in all views
- Adds user reference to the migration

### 2. Scaffold Views Generator

If you've already generated a scaffold with the standard Rails generator, you can replace just the views with CCCUX-enabled versions:

```bash
rails generate cccux:scaffold_views Product name:string price:decimal
```

This generator:
- Replaces existing views with CCCUX-enabled versions
- Adds `Cccux::AuthorizationController` to ApplicationController
- Adds `authorize_resource` to the existing controller
- Adds `belongs_to :user` to the existing model

## Usage Examples

### Standard Workflow

1. Generate a scaffold with CCCUX:
```bash
rails generate cccux:scaffold Post title:string content:text
```

2. Run the migration:
```bash
rails db:migrate
```

3. Set up permissions in the CCCUX admin interface:
   - Go to `/cccux/roles`
   - Create or edit a role
   - Add permissions for the new model
   - Set access types (Global, Contextual, or Owned)

### Alternative Workflow

1. Generate standard Rails scaffold:
```bash
rails generate scaffold Post title:string content:text
```

2. Replace views with CCCUX-enabled versions:
```bash
rails generate cccux:scaffold_views Post title:string content:text
```

3. Run the migration:
```bash
rails db:migrate
```

4. Set up permissions in CCCUX admin

## Generated Views

The generators create views that use CCCUX helpers instead of standard Rails helpers:

### Index View
```erb
<%= link_if_can_show "Show", post %>
<%= link_if_can_update "Edit", edit_post_path(post) %>
<%= link_if_can_destroy "Destroy", post_path(post), method: :delete %>
<%= link_if_can_create "New Post", new_post_path %>
```

### Show View
```erb
<%= link_if_can_update "Edit", edit_post_path(@post) %>
<%= link_if_can_index "Back", posts_path %>
```

### Form Views
```erb
<%= link_if_can_show "Show", @post %>
<%= link_if_can_index "Back", posts_path %>
```

## Generated Controller

The controller automatically includes authorization:

```ruby
class PostsController < ApplicationController
  authorize_resource
  
  # ... rest of controller code
end
```

## Generated Model

The model includes user association:

```ruby
class Post < ApplicationRecord
  belongs_to :user
  # ... other associations and validations
end
```

## Benefits

- **Automatic Authorization**: All generated views respect user permissions
- **Consistent Interface**: Uses CCCUX helpers throughout
- **User Ownership**: Automatically includes user association for owned resources
- **Easy Setup**: No manual configuration needed for basic authorization
- **Flexible**: Can be used with existing scaffolds or new ones

## Notes

- The generators assume you have a `User` model with `id` as the primary key
- For complex ownership relationships, you'll need to configure them manually in the CCCUX admin interface
- The generators are designed to work with the standard Rails scaffold workflow 