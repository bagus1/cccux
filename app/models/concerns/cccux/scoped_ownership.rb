# frozen_string_literal: true

module Cccux
  module ScopedOwnership
    extend ActiveSupport::Concern

    included do
      # Ensure the model includes Cccux::Authorizable
      include Cccux::Authorizable unless included_modules.include?(Cccux::Authorizable)
    end

    class_methods do
      # Configure scoped ownership for models with multiple ownership patterns
      # Example: scoped_ownership owner: :user, parent: :store, manager_through: :store_managers
      def scoped_ownership(owner: :user, parent: nil, manager_through: nil, through: nil)
        owner_association = owner
        parent_association = parent
        manager_through_association = manager_through
        through_association = through

        # Define ownership method
        define_method :owned_by? do |user|
          return false unless user&.persisted?
          
          # Direct owner ownership
          owner_owned = respond_to?("#{owner_association}_id") && 
                       send("#{owner_association}_id") == user.id
          
          # Parent management ownership (if configured)
          parent_owned = if parent_association && manager_through_association
                          if through_association
                            # Indirect parent relationship (e.g., through order)
                            related_record = send(through_association)
                            parent_record = related_record&.send(parent_association)
                            parent_record&.send(manager_through_association)&.exists?(user: user)
                          else
                            # Direct parent relationship
                            parent_record = send(parent_association)
                            parent_record&.send(manager_through_association)&.exists?(user: user)
                          end
                        else
                          false
                        end
          
          owner_owned || parent_owned
        end

        # Define scoped_for_user class method
        define_singleton_method :scoped_for_user do |user|
          return none unless user&.persisted?
          
          # Get records owned by user
          owner_records = where("#{owner_association}_id" => user.id)
          
          # Get records from parents managed by user (if configured)
          if parent_association && manager_through_association
            if through_association
              # Indirect parent relationship
              parent_records = joins(through_association => parent_association)
                              .where("#{parent_association.to_s.pluralize}" => { 
                                id: user.send(manager_through_association).select("#{parent_association}_id")
                              })
            else
              # Direct parent relationship
              parent_records = joins(parent_association)
                              .where("#{table_name}.#{parent_association}_id" => 
                                user.send(manager_through_association).select("#{parent_association}_id"))
            end
            
            # Combine with UNION for efficiency
            owner_ids = owner_records.pluck(:id)
            parent_ids = parent_records.pluck(:id)
            where(id: (owner_ids + parent_ids).uniq)
          else
            # Only owner records if no parent management configured
            owner_records
          end
        end

        # Define context scope method
        define_singleton_method :in_current_scope? do |record, user, context|
          # Check each context key for matches
          context.each do |context_key, context_value|
            association_name = context_key.to_s.sub(/_id$/, '')
            
            if through_association
              # Indirect relationship - check through association
              related_record = record.send(through_association)
              if related_record&.respond_to?("#{association_name}_id")
                return true if related_record.send("#{association_name}_id")&.to_s == context_value.to_s
              end
            else
              # Direct relationship - check direct association
              if record.respond_to?("#{association_name}_id")
                return true if record.send("#{association_name}_id")&.to_s == context_value.to_s
              end
            end
          end
          
          false
        end
      end

      # For models that only have owner ownership (no parent relationship)
      def owner_ownership(owner: :user)
        owner_association = owner

        define_method :owned_by? do |user|
          return false unless user&.persisted?
          send("#{owner_association}_id") == user.id
        end

        define_singleton_method :scoped_for_user do |user|
          return none unless user&.persisted?
          where("#{owner_association}_id" => user.id)
        end

        define_singleton_method :in_current_scope? do |record, user, context|
          context.each do |context_key, context_value|
            association_name = context_key.to_s.sub(/_id$/, '')
            if association_name == owner_association.to_s
              return true if record.send("#{owner_association}_id")&.to_s == context_value.to_s
            end
          end
          false
        end
      end

      # For models that only have parent ownership (no direct owner relationship)
      def parent_ownership(parent: :parent, manager_through: :managers, through: nil)
        parent_association = parent
        manager_through_association = manager_through
        through_association = through

        define_method :owned_by? do |user|
          return false unless user&.persisted?
          
          if through_association
            related_record = send(through_association)
            parent_record = related_record&.send(parent_association)
            parent_record&.send(manager_through_association)&.exists?(user: user)
          else
            parent_record = send(parent_association)
            parent_record&.send(manager_through_association)&.exists?(user: user)
          end
        end

        define_singleton_method :scoped_for_user do |user|
          return none unless user&.persisted?
          
          if through_association
            joins(through_association => parent_association)
              .where("#{parent_association.to_s.pluralize}" => { 
                id: user.send(manager_through_association).select("#{parent_association}_id")
              })
          else
            joins(parent_association)
              .where("#{table_name}.#{parent_association}_id" => 
                user.send(manager_through_association).select("#{parent_association}_id"))
          end
        end

        define_singleton_method :in_current_scope? do |record, user, context|
          context.each do |context_key, context_value|
            association_name = context_key.to_s.sub(/_id$/, '')
            
            if through_association
              related_record = record.send(through_association)
              if related_record&.respond_to?("#{association_name}_id")
                return true if related_record.send("#{association_name}_id")&.to_s == context_value.to_s
              end
            else
              if association_name == parent_association.to_s
                return true if record.send("#{parent_association}_id")&.to_s == context_value.to_s
              end
            end
          end
          false
        end
      end
    end
  end
end 