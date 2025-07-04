# CCCUX User Guide

This guide explains how to use the CCCUX admin interface to manage roles, permissions, and users in your Rails application.

## Accessing the Dashboard

### Prerequisites
- You must have a **Role Manager** or **Administrator** role assigned to your user account
- You must be logged into the application

### Dashboard URL
Navigate to `/cccux` in your browser to access the CCCUX admin dashboard.

### Dashboard Overview
The dashboard provides:
- **System Statistics**: User count, role count, permission count, and total assignments
- **Quick Actions**: Links to create users, roles, manage permissions, and access model discovery
- **Navigation**: Access to all CCCUX management features

## Model Discovery & Permission Management

### What is Model Discovery?
Model Discovery automatically scans your Rails application to find models that need permissions. This tool helps you:
- Identify which models have permissions configured
- Find models that are missing permissions
- Bulk-create permissions for multiple models at once

### Accessing Model Discovery
1. Go to the CCCUX dashboard (`/cccux`)
2. Click the **"🔍 Model Discovery"** button in the Quick Actions section
3. Or navigate directly to `/cccux/model_discovery`

### Understanding the Model Discovery Page

#### Detected Models Section
- Shows all models found in your application
- Each model is marked with either:
  - **✓ Has Permissions** (green badge) - Model already has permissions configured
  - **⚠ Missing Permissions** (yellow badge) - Model needs permissions to be created

#### Models with Permissions Section
- Lists all models that already have permissions
- Shows the number of permissions each model has

#### Add Permissions for Missing Models Section
- Appears only when there are models missing permissions
- Allows you to select which models to create permissions for
- Each selected model will get **read, create, update, destroy** permissions
- Use **Select All** or **Select None** buttons for bulk selection
- Click **Create Permissions** to generate the permissions

### Adding New Models
When you create a new model in your application:

1. **Visit the model's page first** (e.g., `/products`) to ensure Rails loads it
2. **Refresh the Model Discovery page** (`/cccux/model_discovery`)
3. **The new model will appear** in the "Missing Permissions" section
4. **Select the model** and click "Create Permissions"

> **💡 Tip**: If a new model doesn't appear in Model Discovery, visit its page first (e.g., `/products`) to ensure Rails loads it, then refresh the Model Discovery page.

### Quick Actions from Model Discovery
- **View All Permissions**: See all permissions in the system
- **Manage Roles**: Access role management
- **User Management**: Manage user accounts and role assignments
- **Refresh Detection**: Re-scan for new models

## Creating and Managing Roles

### Creating a New Role

1. **From the Dashboard**: Click **"Create New Role"** in Quick Actions
2. **From Roles List**: Go to `/cccux/roles` and click **"New Role"**

#### Role Creation Form
- **Name**: Unique name for the role (e.g., "Store Manager", "Content Editor")
- **Description**: Brief description of what this role can do
- **Priority**: Lower numbers = higher priority (1 = highest, 100 = lowest)
- **Active**: Whether the role is currently active

#### After Creating a Role
- The role is created but has **no permissions assigned**
- You'll be redirected to the role's detail page
- **Click "Manage Permissions"** to assign abilities to the role

### Editing Role Permissions

#### Accessing Role Permissions
1. Go to `/cccux/roles` to see all roles
2. Click **"Edit"** next to the role you want to modify
3. Or click **"Manage Permissions"** from the role's detail page

#### Permission Assignment Interface
The role edit page shows a **permission matrix** with:
- **Models** (subjects) listed as rows
- **Actions** (permissions) listed as columns
- **Checkboxes** to select which actions the role can perform

#### Available Actions
- **read**: View records (index, show actions)
- **create**: Create new records (new, create actions)
- **update**: Modify existing records (edit, update actions)
- **destroy**: Delete records (destroy action)
- **Custom actions**: Any additional actions defined in your routes

#### Ownership Scoping
For each model, you can set:
- **All Records**: Role can access all records of this type
- **Owned Records Only**: Role can only access records they own/created

#### Saving Role Permissions
1. **Check the boxes** for the permissions you want to grant
2. **Set ownership scope** for each model if needed
3. **Click "Update Role"** to save changes

### Role Management Tips

#### Default Roles
CCCUX creates these default roles:
- **Guest** (priority 100): Unauthenticated users with minimal access
- **Basic User** (priority 50): Standard authenticated users
- **Store Manager** (priority 20): Can manage stores and related data
- **Role Manager** (priority 10): Can manage roles and permissions
- **Administrator** (priority 1): Full system access

#### Role Priority
- Lower priority numbers = higher authority
- When a user has multiple roles, the highest priority role's permissions take precedence
- Use priorities to create role hierarchies

## Managing Permissions (Ability Permissions)

### When to Use Permission Management
Use the Ability Permissions section when:
- You need **custom actions** not covered by standard CRUD
- You want to **fine-tune permissions** for specific use cases
- You need to **add permissions** that aren't showing up in role editing

### Accessing Permission Management
1. Go to `/cccux/ability_permissions`
2. Or click **"Manage Permissions"** from the dashboard

### Viewing All Permissions
The permissions index shows:
- **Grouped by Model**: Permissions organized by subject (model)
- **Action Types**: What actions each permission allows
- **Descriptions**: Human-readable descriptions of each permission
- **Active Status**: Whether the permission is currently active

### Creating New Permissions

#### Single Permission Creation
1. Click **"New Permission"**
2. Fill in the form:
   - **Subject**: The model this permission applies to
   - **Action**: The specific action (e.g., "reorder", "approve", "publish")
   - **Description**: Human-readable description
   - **Active**: Whether this permission is currently active

#### Bulk Permission Creation
1. Click **"New Permission"**
2. Select multiple actions for the same subject
3. All selected actions will be created as separate permissions

### Route Discovery
The permission system automatically discovers actions from your Rails routes:
- **Standard CRUD actions**: index, show, new, create, edit, update, destroy
- **Custom actions**: Any additional actions defined in your routes
- **Nested actions**: Actions for nested resources

### Permission Examples

#### Standard CRUD Permissions
```
Subject: Order
Actions: read, create, update, destroy
```

#### Custom Action Permissions
```
Subject: Order
Actions: process, cancel, refund, reorder
```

#### Model-Specific Permissions
```
Subject: User
Actions: read, update, change_password, reset_password
```

## User Management

### Viewing Users
1. Go to `/cccux/users`
2. See all users with their assigned roles
3. Click on a user to view details

### Creating Users
1. Click **"New User"** from the users index
2. Fill in user details (email, password, etc.)
3. **Assign roles** by checking the appropriate role checkboxes
4. Save the user

### Editing User Roles
1. Click **"Edit"** next to a user
2. **Check/uncheck roles** to assign or remove them
3. **Save changes** to update the user's permissions

### User Role Assignment Tips
- Users can have **multiple roles**
- **Role priority** determines which permissions take precedence
- **Active roles only** can be assigned to users
- Users with **no roles** get **Guest** permissions automatically

## Troubleshooting

### Permission Issues

#### "Access Denied" Errors
- **Check user roles**: Ensure the user has the appropriate role assigned
- **Verify permissions**: Make sure the role has the required permissions
- **Check role priority**: Higher priority roles override lower priority ones

#### Missing Actions in Role Editing
If an action isn't showing up when editing a role:
1. **Go to Ability Permissions** (`/cccux/ability_permissions`)
2. **Check if the permission exists** for that model/action
3. **Create the permission** if it doesn't exist
4. **Return to role editing** - the action should now appear

#### New Models Not Appearing
If a new model doesn't show up in Model Discovery:
1. **Visit the model's page** (e.g., `/products`) to load it
2. **Refresh Model Discovery** (`/cccux/model_discovery`)
3. **Check Rails logs** for any loading errors

### Role Management Issues

#### Can't Delete a Role
- **Check if users have the role**: Roles with assigned users cannot be deleted
- **Remove role assignments first**: Unassign the role from all users
- **Then delete the role**

#### Permission Changes Not Taking Effect
- **Clear browser cache**: Sometimes cached permissions need to be refreshed
- **Check role priority**: Higher priority roles may be overriding changes
- **Verify user logout/login**: Some permission changes require re-authentication

### Model Discovery Issues

#### No Models Detected
- **Ensure models inherit from ApplicationRecord**
- **Check for syntax errors** in model files
- **Restart the Rails server** if needed

#### Models Missing from Detection
- **Visit the model's page** to ensure Rails loads it
- **Check model inheritance** (should inherit from ApplicationRecord)
- **Verify model file exists** in `app/models/`

## Best Practices

### Role Design
- **Start with broad roles** (Admin, User, Guest)
- **Add specific roles** as needed (Store Manager, Content Editor)
- **Use descriptive names** that clearly indicate the role's purpose
- **Set appropriate priorities** to create role hierarchies

### Permission Management
- **Use standard CRUD actions** when possible (read, create, update, destroy)
- **Add custom actions** only when needed
- **Group related permissions** by model
- **Use descriptive permission names** and descriptions

### User Management
- **Assign roles immediately** when creating users
- **Review role assignments** regularly
- **Use role priorities** to handle complex permission scenarios
- **Test permissions** with different user accounts

### Model Discovery
- **Run Model Discovery** after adding new models
- **Review missing permissions** regularly
- **Create permissions in batches** for efficiency
- **Test permissions** after creation

## Quick Reference

### Common URLs
- **Dashboard**: `/cccux`
- **Model Discovery**: `/cccux/model_discovery`
- **Roles**: `/cccux/roles`
- **Permissions**: `/cccux/ability_permissions`
- **Users**: `/cccux/users`

### Default Roles
- **Guest** (100): Minimal read access
- **Basic User** (50): Standard user permissions
- **Store Manager** (20): Store management
- **Role Manager** (10): Role/permission management
- **Administrator** (1): Full access

### Standard Actions
- **read**: View records
- **create**: Create new records
- **update**: Modify records
- **destroy**: Delete records

### Ownership Options
- **All Records**: Access to all records of this type
- **Owned Records Only**: Access only to user's own records 