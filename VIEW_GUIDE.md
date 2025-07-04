# CCCUX View Guide

This guide explains how to use CCCUX authorization helper methods in your Rails views and templates.

## Setup

### Include Helpers in ApplicationController

Make sure your `ApplicationController` includes the CCCUX authorization helpers:

```ruby
class ApplicationController < ActionController::Base
  # Include CCCUX authorization helpers
  helper Cccux::AuthorizationHelper
  
  # ... other configuration
end
```

## Basic Permission Checks

### Using `can?` and `cannot?`

The most basic way to check permissions in views:

```erb
<% if can? :create, Order %>
  <%= link_to 'New Order', new_order_path %>
<% end %>

<% if can? :update, @order %>
  <%= link_to 'Edit', edit_order_path(@order) %>
<% end %>

<% if cannot? :destroy, @order %>
  <p>You cannot delete this order.</p>
<% end %>
```

### Using Specific Permission Helpers

CCCUX provides convenience methods for common actions:

```erb
<% if can_create?(Order) %>
  <%= link_to 'New Order', new_order_path %>
<% end %>

<% if can_edit?(@order) %>
  <%= link_to 'Edit', edit_order_path(@order) %>
<% end %>

<% if can_destroy?(@order) %>
  <%= link_to 'Delete', order_path(@order), method: :delete, data: { confirm: 'Are you sure?' } %>
<% end %>
```

## Conditional Links

### Link Helpers

Show links only if the user has permission:

```erb
<%= link_if_can(:create, Order, 'New Order', new_order_path) %>

<%= link_if_can_show(@order, 'View Details', order_path(@order)) %>

<%= link_if_can_edit(@order, 'Edit Order', edit_order_path(@order)) %>

<%= link_if_can_destroy(@order, 'Delete Order', order_path(@order), method: :delete) %>
```

### Button Helpers

Show buttons only if the user has permission:

```erb
<%= button_if_can(:create, Order, 'New Order', new_order_path) %>

<%= button_if_can_show(@order, 'View Details', order_path(@order)) %>

<%= button_if_can_edit(@order, 'Edit Order', edit_order_path(@order)) %>

<%= button_if_can_destroy(@order, 'Delete Order', order_path(@order), method: :delete) %>
```

## Conditional Content Blocks

### Content Helpers

Show entire content blocks only if the user has permission:

```erb
<%= content_if_can(:create, Order) do %>
  <div class="new-order-section">
    <h3>Create New Order</h3>
    <%= link_to 'New Order', new_order_path, class: 'btn btn-primary' %>
  </div>
<% end %>

<%= content_if_can_show(@order) do %>
  <div class="order-details">
    <h2><%= @order.title %></h2>
    <p><%= @order.description %></p>
  </div>
<% end %>

<%= content_if_can_edit(@order) do %>
  <div class="order-actions">
    <%= link_to 'Edit', edit_order_path(@order), class: 'btn btn-warning' %>
  </div>
<% end %>
```

## Action Buttons with Icons

### Icon Link Helpers

Create links with icons that only show if permitted:

```erb
<%= icon_link_if_can(:create, Order, 'fas fa-plus', 'New Order', new_order_path) %>

<%= icon_link_if_can(:show, @order, 'fas fa-eye', 'View', order_path(@order)) %>

<%= icon_link_if_can(:edit, @order, 'fas fa-edit', 'Edit', edit_order_path(@order)) %>

<%= icon_link_if_can(:destroy, @order, 'fas fa-trash', 'Delete', order_path(@order), method: :delete) %>
```

### Icon Button Helpers

Create buttons with icons that only show if permitted:

```erb
<%= icon_button_if_can(:create, Order, 'fas fa-plus', 'New Order', new_order_path) %>

<%= icon_button_if_can(:show, @order, 'fas fa-eye', 'View', order_path(@order)) %>

<%= icon_button_if_can(:edit, @order, 'fas fa-edit', 'Edit', edit_order_path(@order)) %>

<%= icon_button_if_can(:destroy, @order, 'fas fa-trash', 'Delete', order_path(@order), method: :delete) %>
```

## Pre-built Action Buttons

### Common Action Buttons

CCCUX provides pre-built buttons for common actions:

```erb
<%= new_button_if_can(Order) %>
<%= new_button_if_can(Order, 'Create New Order', new_order_path, class: 'btn btn-success') %>

<%= view_button_if_can(@order) %>
<%= view_button_if_can(@order, 'View Details', order_path(@order), class: 'btn btn-info') %>

<%= edit_button_if_can(@order) %>
<%= edit_button_if_can(@order, 'Edit Order', edit_order_path(@order), class: 'btn btn-warning') %>

<%= delete_button_if_can(@order) %>
<%= delete_button_if_can(@order, 'Delete Order', order_path(@order), class: 'btn btn-danger') %>
```

### Table Action Helpers

For table rows, use the table actions helper:

```erb
<table class="table">
  <thead>
    <tr>
      <th>Title</th>
      <th>Status</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @orders.each do |order| %>
      <tr>
        <td><%= order.title %></td>
        <td><%= order.status %></td>
        <td>
          <%= table_actions_if_can(Order, order) %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

## Role-based Content

### Checking User Roles

Show content based on user roles:

```erb
<% if current_user.has_role?('Administrator') %>
  <%= link_to 'Admin Panel', cccux.root_path %>
<% end %>

<% if current_user.has_role?('Role Manager') %>
  <%= link_to 'Manage Roles', cccux.roles_path %>
<% end %>

<% if current_user.has_any_role?('Administrator', 'Role Manager') %>
  <div class="admin-section">
    <h3>Administrative Functions</h3>
    <!-- Admin content -->
  </div>
<% end %>
```

### Role Priority Checks

Check for specific role priorities:

```erb
<% if current_user.highest_priority_role&.name == 'Administrator' %>
  <div class="full-admin-access">
    <!-- Full admin content -->
  </div>
<% end %>
```

## Navigation Menus

### Conditional Navigation

Build navigation menus that adapt to user permissions:

```erb
<nav class="navbar">
  <ul class="nav">
    <li class="nav-item">
      <%= link_to 'Home', root_path, class: 'nav-link' %>
    </li>
    
    <%= content_if_can(:index, Order) do %>
      <li class="nav-item">
        <%= link_to 'Orders', orders_path, class: 'nav-link' %>
      </li>
    <% end %>
    
    <%= content_if_can(:index, Store) do %>
      <li class="nav-item">
        <%= link_to 'Stores', stores_path, class: 'nav-link' %>
      </li>
    <% end %>
    
    <% if current_user.has_role?('Role Manager') %>
      <li class="nav-item">
        <%= link_to 'Admin', cccux.root_path, class: 'nav-link' %>
      </li>
    <% end %>
  </ul>
</nav>
```

## Forms and Inputs

### Conditional Form Fields

Show form fields based on permissions:

```erb
<%= form_with model: @order do |form| %>
  <div class="field">
    <%= form.label :title %>
    <%= form.text_field :title %>
  </div>
  
  <%= content_if_can(:update, Order) do %>
    <div class="field">
      <%= form.label :status %>
      <%= form.select :status, Order.statuses.keys %>
    </div>
  <% end %>
  
  <%= content_if_can(:create, Order) do %>
    <div class="actions">
      <%= form.submit 'Create Order' %>
    </div>
  <% end %>
<% end %>
```

## Index Pages

### Conditional Index Actions

Show different actions based on permissions:

```erb
<div class="index-header">
  <h1>Orders</h1>
  
  <div class="actions">
    <%= new_button_if_can(Order, 'New Order', new_order_path, class: 'btn btn-primary') %>
  </div>
</div>

<div class="orders-list">
  <% @orders.each do |order| %>
    <div class="order-card">
      <h3><%= order.title %></h3>
      <p><%= order.description %></p>
      
      <div class="order-actions">
        <%= view_button_if_can(order, 'View', order_path(order), class: 'btn btn-sm btn-info') %>
        <%= edit_button_if_can(order, 'Edit', edit_order_path(order), class: 'btn btn-sm btn-warning') %>
        <%= delete_button_if_can(order, 'Delete', order_path(order), class: 'btn btn-sm btn-danger') %>
      </div>
    </div>
  <% end %>
</div>
```

## Show Pages

### Conditional Show Actions

Show different actions on detail pages:

```erb
<div class="show-header">
  <h1><%= @order.title %></h1>
  
  <div class="show-actions">
    <%= edit_button_if_can(@order, 'Edit Order', edit_order_path(@order), class: 'btn btn-warning') %>
    <%= delete_button_if_can(@order, 'Delete Order', order_path(@order), class: 'btn btn-danger') %>
  </div>
</div>

<div class="order-details">
  <p><strong>Description:</strong> <%= @order.description %></p>
  <p><strong>Status:</strong> <%= @order.status %></p>
  
  <%= content_if_can(:index, Order) do %>
    <p><%= link_to '← Back to Orders', orders_path %></p>
  <% end %>
</div>
```

## Error Handling

### Graceful Permission Denials

Handle cases where users don't have permission:

```erb
<% if can? :create, Order %>
  <%= link_to 'New Order', new_order_path %>
<% else %>
  <p class="text-muted">You don't have permission to create orders.</p>
<% end %>

<% if can? :edit, @order %>
  <%= link_to 'Edit', edit_order_path(@order) %>
<% else %>
  <span class="text-muted">Read-only</span>
<% end %>
```

## Best Practices

### 1. Use Semantic Helpers

Prefer semantic helpers over raw `can?` checks:

```erb
<!-- Good -->
<%= new_button_if_can(Order) %>

<!-- Less ideal -->
<% if can? :create, Order %>
  <%= button_to 'New Order', new_order_path %>
<% end %>
```

### 2. Group Related Actions

Use content blocks for related actions:

```erb
<%= content_if_can(:manage, Order) do %>
  <div class="order-management">
    <h3>Order Management</h3>
    <%= new_button_if_can(Order) %>
    <%= link_to 'Bulk Actions', bulk_orders_path %>
  </div>
<% end %>
```

### 3. Consistent Styling

Use consistent CSS classes across your application:

```erb
<%= new_button_if_can(Order, 'New Order', new_order_path, class: 'btn btn-primary') %>
<%= edit_button_if_can(@order, 'Edit', edit_order_path(@order), class: 'btn btn-warning') %>
<%= delete_button_if_can(@order, 'Delete', order_path(@order), class: 'btn btn-danger') %>
```

### 4. Handle Edge Cases

Always provide fallbacks for users without permissions:

```erb
<% if @orders.any? %>
  <% @orders.each do |order| %>
    <!-- Order display -->
  <% end %>
<% else %>
  <p>No orders found.</p>
  <%= content_if_can(:create, Order) do %>
    <p><%= link_to 'Create your first order', new_order_path %></p>
  <% end %>
<% end %>
```

## Complete Example

Here's a complete example of an index view using CCCUX helpers:

```erb
<div class="orders-index">
  <div class="page-header">
    <h1>Orders</h1>
    
    <div class="header-actions">
      <%= new_button_if_can(Order, 'New Order', new_order_path, class: 'btn btn-primary') %>
      
      <% if current_user.has_role?('Administrator') %>
        <%= link_to 'Admin Panel', cccux.root_path, class: 'btn btn-secondary' %>
      <% end %>
    </div>
  </div>
  
  <% if @orders.any? %>
    <div class="orders-grid">
      <% @orders.each do |order| %>
        <div class="order-card">
          <div class="order-header">
            <h3><%= order.title %></h3>
            <span class="status <%= order.status %>"><%= order.status %></span>
          </div>
          
          <div class="order-content">
            <p><%= order.description %></p>
            <p><strong>Created:</strong> <%= order.created_at.strftime('%B %d, %Y') %></p>
          </div>
          
          <div class="order-actions">
            <%= view_button_if_can(order, 'View', order_path(order), class: 'btn btn-sm btn-info') %>
            <%= edit_button_if_can(order, 'Edit', edit_order_path(order), class: 'btn btn-sm btn-warning') %>
            <%= delete_button_if_can(order, 'Delete', order_path(order), class: 'btn btn-sm btn-danger') %>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="empty-state">
      <p>No orders found.</p>
      <%= content_if_can(:create, Order) do %>
        <p><%= link_to 'Create your first order', new_order_path, class: 'btn btn-primary' %></p>
      <% end %>
    </div>
  <% end %>
</div>
```

This comprehensive view guide covers all the authorization helper methods provided by CCCUX and shows how to use them effectively in your Rails views. 