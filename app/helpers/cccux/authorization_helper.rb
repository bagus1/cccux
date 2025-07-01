module Cccux
  module AuthorizationHelper
    # Link helpers for common actions
    def link_if_can_index(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:index, subject)
    end

    def link_if_can_show(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:show, subject)
    end

    def link_if_can_create(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:create, subject)
    end

    def link_if_can_edit(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:edit, subject)
    end

    def link_if_can_update(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:update, subject)
    end

    def link_if_can_destroy(subject, text, path, **opts)
      link_to(text, path, **opts) if can?(:destroy, subject)
    end

    # Button helpers for common actions
    def button_if_can_index(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:index, subject)
    end

    def button_if_can_show(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:show, subject)
    end

    def button_if_can_create(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:create, subject)
    end

    def button_if_can_edit(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:edit, subject)
    end

    def button_if_can_update(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:update, subject)
    end

    def button_if_can_destroy(subject, text, path, **opts)
      button_to(text, path, **opts) if can?(:destroy, subject)
    end

    # Generic action helpers
    def link_if_can(action, subject, text, path, **opts)
      link_to(text, path, **opts) if can?(action, subject)
    end

    def button_if_can(action, subject, text, path, **opts)
      button_to(text, path, **opts) if can?(action, subject)
    end

    # Content helpers for conditional rendering
    def content_if_can(action, subject, &block)
      capture(&block) if can?(action, subject)
    end

    def content_if_can_index(subject, &block)
      content_if_can(:index, subject, &block)
    end

    def content_if_can_show(subject, &block)
      content_if_can(:show, subject, &block)
    end

    def content_if_can_create(subject, &block)
      content_if_can(:create, subject, &block)
    end

    def content_if_can_edit(subject, &block)
      content_if_can(:edit, subject, &block)
    end

    def content_if_can_update(subject, &block)
      content_if_can(:update, subject, &block)
    end

    def content_if_can_destroy(subject, &block)
      content_if_can(:destroy, subject, &block)
    end

    # Icon helpers (useful for action buttons)
    def icon_link_if_can(action, subject, icon_class, text, path, **opts)
      link_to(path, **opts) do
        content_tag(:i, '', class: icon_class) + ' ' + text
      end if can?(action, subject)
    end

    def icon_button_if_can(action, subject, icon_class, text, path, **opts)
      button_to(path, **opts) do
        content_tag(:i, '', class: icon_class) + ' ' + text
      end if can?(action, subject)
    end

    # Common action button helpers with icons
    def new_button_if_can(subject, text = "New #{subject.name.underscore.humanize}", path = nil, **opts)
      path ||= "new_#{subject.name.underscore}_path"
      icon_button_if_can(:create, subject, 'fas fa-plus', text, path, **opts)
    end

    def edit_button_if_can(subject, text = "Edit", path = nil, **opts)
      path ||= "edit_#{subject.name.underscore}_path(subject)"
      icon_button_if_can(:edit, subject, 'fas fa-edit', text, path, **opts)
    end

    def delete_button_if_can(subject, text = "Delete", path = nil, **opts)
      path ||= "#{subject.name.underscore}_path(subject)"
      opts[:method] ||= :delete
      opts[:data] ||= {}
      opts[:data][:confirm] ||= "Are you sure?"
      icon_button_if_can(:destroy, subject, 'fas fa-trash', text, path, **opts)
    end

    def view_button_if_can(subject, text = "View", path = nil, **opts)
      path ||= "#{subject.name.underscore}_path(subject)"
      icon_button_if_can(:show, subject, 'fas fa-eye', text, path, **opts)
    end

    # Table action helpers
    def table_actions_if_can(subject, record, **opts)
      content_if_can(:show, subject) do
        content_tag(:div, class: 'table-actions') do
          safe_join([
            view_button_if_can(subject, "View", "#{subject.name.underscore}_path(record)", **opts),
            edit_button_if_can(subject, "Edit", "edit_#{subject.name.underscore}_path(record)", **opts),
            delete_button_if_can(subject, "Delete", "#{subject.name.underscore}_path(record)", **opts)
          ].compact)
        end
      end
    end

    # Permission check helpers
    def can_index?(subject)
      can?(:index, subject)
    end

    def can_show?(subject)
      can?(:show, subject)
    end

    def can_create?(subject)
      can?(:create, subject)
    end

    def can_edit?(subject)
      can?(:edit, subject)
    end

    def can_update?(subject)
      can?(:update, subject)
    end

    def can_destroy?(subject)
      can?(:destroy, subject)
    end
  end
end 