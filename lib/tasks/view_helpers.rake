namespace :cccux do
  desc "Convert standard Rails view helpers to CCCUX authorization helpers in a directory"
  task :convert_views, [:view_path] => :environment do |task, args|
    view_path = args[:view_path]
    
    if view_path.blank?
      puts "❌ Please provide a view path"
      puts "Usage: rails cccux:convert_views[app/views/products]"
      puts "       rails cccux:convert_views[app/views/stores]"
      exit 1
    end
    
    # Normalize the path
    view_path = view_path.gsub(/^\/+/, '').gsub(/\/+$/, '')
    full_path = Rails.root.join(view_path)
    
    unless Dir.exist?(full_path)
      puts "❌ Directory not found: #{full_path}"
      exit 1
    end
    
    puts "🔍 Converting view helpers in: #{full_path}"
    puts ""
    
    # Find all .erb files in the directory
    erb_files = Dir.glob(File.join(full_path, "**", "*.erb"))
    
    if erb_files.empty?
      puts "❌ No .erb files found in #{full_path}"
      exit 1
    end
    
    conversions_made = 0
    files_modified = 0
    
    erb_files.each do |file_path|
      relative_path = file_path.gsub("#{Rails.root}/", "")
      puts "📝 Processing: #{relative_path}"
      
      original_content = File.read(file_path)
      modified_content = original_content.dup
      file_conversions = 0
      
      # Convert complex nested conditional patterns for edit/show links
      # Pattern: <% if @project %><%= link_to "Edit this task", edit_project_task_path(@project, @task) %><% else %><%= link_to "Edit this task", edit_task_path(@task) %><% end %>
      modified_content.gsub!(/<%\s*if\s+@(\w+)\s*%>\s*<%=\s*link_to\s+"([^"]+)",\s*edit_(\w+)_(\w+)_path\(@\w+,\s*(@\w+)\)\s*%>\s*<%\s*else\s*%>\s*<%=\s*link_to\s+"[^"]*",\s*edit_(\w+)_path\((@\w+)\)\s*%>\s*<%\s*end\s*%>/m) do |match|
        parent_var, text, parent_model, child_model, model1, child_singular, model2 = $1, $2, $3, $4, $5, $6, $7
        file_conversions += 1
        "<%= link_if_can_edit #{model1}, \"#{text}\", @#{parent_var} ? edit_#{parent_model}_#{child_model}_path(@#{parent_var}, #{model1}) : edit_#{child_singular}_path(#{model1}) %>"
      end
      
      # Convert complex nested conditional patterns for show links
      # Pattern: <% if @project %><%= link_to "Show this task", project_task_path(@project, @task) %><% else %><%= link_to "Show this task", @task %><% end %>
      modified_content.gsub!(/<%\s*if\s+@(\w+)\s*%>\s*<%=\s*link_to\s+"([^"]+)",\s*(\w+)_(\w+)_path\(@\w+,\s*(@\w+)\)\s*%>\s*<%\s*else\s*%>\s*<%=\s*link_to\s+"[^"]*",\s*(@\w+)\s*%>\s*<%\s*end\s*%>/m) do |match|
        parent_var, text, parent_model, child_model, model1, model2 = $1, $2, $3, $4, $5, $6
        file_conversions += 1
        "<%= link_if_can_show #{model1}, \"#{text}\", @#{parent_var} ? #{parent_model}_#{child_model}_path(@#{parent_var}, #{model1}) : #{model1} %>"
      end
      
      # Convert complex nested conditional patterns for destroy buttons
      # Pattern: <% if @project %><%= button_to "Destroy this task", project_task_path(@project, @task), method: :delete %><% else %><%= button_to "Destroy this task", @task, method: :delete %><% end %>
      modified_content.gsub!(/<%\s*if\s+@(\w+)\s*%>\s*<%=\s*button_to\s+"([^"]+)",\s*(\w+)_(\w+)_path\(@\w+,\s*(@\w+)\),\s*method:\s*:delete[^%]*%>\s*<%\s*else\s*%>\s*<%=\s*button_to\s+"[^"]*",\s*(@\w+),\s*method:\s*:delete[^%]*%>\s*<%\s*end\s*%>/m) do |match|
        parent_var, text, parent_model, child_model, model1, model2 = $1, $2, $3, $4, $5, $6
        file_conversions += 1
        "<%= button_if_can_destroy #{model1}, \"#{text}\", @#{parent_var} ? #{parent_model}_#{child_model}_path(@#{parent_var}, #{model1}) : #{model1}, method: :delete %>"
      end
      
      # Convert complex nested conditional patterns for "Back to" links
      # Pattern: <% if @project %><%= link_to "Back to tasks", project_tasks_path(@project) %><% else %><%= link_to "Back to tasks", tasks_path %><% end %>
      modified_content.gsub!(/<%\s*if\s+@(\w+)\s*%>\s*<%=\s*link_to\s+"([^"]+)",\s*(\w+)_(\w+)_path\(@\w+\)\s*%>\s*<%\s*else\s*%>\s*<%=\s*link_to\s+"[^"]*",\s*(\w+)_path\s*%>\s*<%\s*end\s*%>/m) do |match|
        parent_var, text, parent_model, child_model, simple_model = $1, $2, $3, $4, $5
        file_conversions += 1
        
        # Extract the model name from the path
        model_name = simple_model.singularize.camelize
        "<%= link_if_can_index #{model_name}, \"#{text}\", @#{parent_var} ? #{parent_model}_#{child_model}_path(@#{parent_var}) : #{simple_model}_path %>"
      end
      
      # Convert complex nested conditional patterns for new links
      # Pattern: <% if @project %><%= link_to "New task", new_project_task_path(@project) %><% else %><%= link_to "New task", new_task_path %><% end %>
      modified_content.gsub!(/<%\s*if\s+@(\w+)\s*%>\s*<%=\s*link_to\s+"(?:New|Add)\s+(\w+)",\s*new_(\w+)_(\w+)_path\(@\w+\)\s*%>\s*<%\s*else\s*%>\s*<%=\s*link_to\s+"[^"]*",\s*new_(\w+)_path\s*%>\s*<%\s*end\s*%>/m) do |match|
        parent_var, model_name, parent_model, child_model, simple_model = $1, $2, $3, $4, $5
        file_conversions += 1
        
        # Use the child model name for the creation check
        model_class = child_model.camelize
        "<%= link_if_can_create #{model_class}.new, \"New #{model_name}\", @#{parent_var} ? new_#{parent_model}_#{child_model}_path(@#{parent_var}) : new_#{simple_model}_path %>"
      end
      
      # Convert link_to with conditions to link_if_can helpers
      # Pattern: <% if can? :show, @model %><%= link_to ... %><% end %>
      modified_content.gsub!(/<%\s*if\s+can\?\s*[:\(](\w+)[:\)]?,\s*(@\w+)\s*%>\s*<%=\s*link_to\s+"([^"]+)",\s*(\w+_path\(@\w+\))\s*%>\s*<%\s*end\s*%>/m) do |match|
        action, model, text, path = $1, $2, $3, $4
        file_conversions += 1
        case action
        when 'show', 'read'
          "<%= link_if_can_show #{model}, \"#{text}\", #{path} %>"
        when 'edit', 'update'
          "<%= link_if_can_edit #{model}, \"#{text}\", #{path} %>"
        when 'destroy', 'delete'
          "<%= button_if_can_destroy #{model}, \"#{text}\", #{path}, method: :delete %>"
        else
          match # Keep original if we don't recognize the action
        end
      end
      
      # Convert simple link_to edit patterns
      modified_content.gsub!(/<%=\s*link_to\s+"Edit(?:\s+this\s+\w+)?",\s*edit_(\w+)_path\((@\w+)\)\s*%>/) do |match|
        model = $2
        file_conversions += 1
        "<%= link_if_can_edit #{model}, \"Edit this #{$1}\", edit_#{$1}_path(#{model}) %>"
      end
      
      # Convert simple link_to show patterns
      modified_content.gsub!(/<%=\s*link_to\s+"(?:Show|View)(?:\s+this\s+\w+)?",\s*(\w+_path\((@\w+)\))\s*%>/) do |match|
        path, model = $1, $2
        file_conversions += 1
        "<%= link_if_can_show #{model}, \"Show this #{path.split('_').first}\", #{path} %>"
      end
      
      # Convert simple link_to show patterns with just the model
      modified_content.gsub!(/<%=\s*link_to\s+"Show this (\w+)",\s*(@\w+)\s*%>/) do |match|
        model_name, model = $1, $2
        file_conversions += 1
        "<%= link_if_can_show #{model}, \"Show this #{model_name}\", #{model} %>"
      end
      
      # Convert simple link_to new patterns
      modified_content.gsub!(/<%=\s*link_to\s+"(?:New|Add)\s*(\w+)",\s*new_(\w+)_path\s*%>/) do |match|
        model_name, model_singular = $1, $2
        file_conversions += 1
        "<%= link_if_can_create #{model_singular.camelize}.new, \"New #{model_name}\", new_#{model_singular}_path %>"
      end
      
      # Convert link_to with method: :delete to button_if_can_destroy
      modified_content.gsub!(/<%=\s*link_to\s+"(?:Delete|Destroy)(?:\s+this\s+\w+)?",\s*(\w+_path\((@\w+)\)),\s*method:\s*:delete(?:,\s*[^%]+)?\s*%>/) do |match|
        path, model = $1, $2
        file_conversions += 1
        "<%= button_if_can_destroy #{model}, \"Delete this #{path.split('_').first}\", #{path}, method: :delete %>"
      end
      
      # Convert button_to with method: :delete to button_if_can_destroy
      modified_content.gsub!(/<%=\s*button_to\s+"(?:Delete|Destroy)(?:\s+this\s+\w+)?",\s*(\w+_path\((@\w+)\)),\s*method:\s*:delete(?:,\s*[^%]+)?\s*%>/) do |match|
        path, model = $1, $2
        file_conversions += 1
        "<%= button_if_can_destroy #{model}, \"Destroy this #{path.split('_').first}\", #{path}, method: :delete %>"
      end
      
      # Convert button_to with just model to button_if_can_destroy
      modified_content.gsub!(/<%=\s*button_to\s+"(?:Delete|Destroy)(?:\s+this\s+\w+)?",\s*(@\w+),\s*method:\s*:delete(?:,\s*[^%]+)?\s*%>/) do |match|
        model = $1
        file_conversions += 1
        "<%= button_if_can_destroy #{model}, \"Destroy this #{model.gsub('@', '').singularize}\", #{model}, method: :delete %>"
      end
      
      # Convert form_with authorization checks
      modified_content.gsub!(/<%\s*if\s+can\?\s*[:\(](\w+)[:\)]?,\s*(@\w+)\s*%>\s*(<%=\s*form_with[^%]+%>.*?<%\s*end\s*%>)\s*<%\s*end\s*%>/m) do |match|
        action, model, form_block = $1, $2, $3
        if action == 'update' || action == 'edit'
          file_conversions += 1
          "<% content_if_can_edit #{model} do %>\n  #{form_block}\n<% end %>"
        elsif action == 'create' || action == 'new'
          file_conversions += 1
          "<% content_if_can_create #{model} do %>\n  #{form_block}\n<% end %>"
        else
          match # Keep original if we don't recognize the action
        end
      end
      
      # Convert nested resource links (e.g., store_product_path)
      modified_content.gsub!(/<%=\s*link_to\s+"New\s+(\w+)",\s*new_(\w+)_(\w+)_path\((@\w+)\)\s*%>/) do |match|
        child_name, parent_singular, child_singular, parent_model = $1, $2, $3, $4
        file_conversions += 1
        "<%= link_if_can_create #{parent_model}.#{child_singular.pluralize}.build, \"New #{child_name}\", new_#{parent_singular}_#{child_singular}_path(#{parent_model}) %>"
      end
      
      if file_conversions > 0
        File.write(file_path, modified_content)
        files_modified += 1
        conversions_made += file_conversions
        puts "  ✅ Made #{file_conversions} conversions"
      else
        puts "  ⏭️  No conversions needed"
      end
    end
    
    puts ""
    puts "🎉 Conversion complete!"
    puts "📊 Files processed: #{erb_files.length}"
    puts "📝 Files modified: #{files_modified}"
    puts "🔄 Total conversions: #{conversions_made}"
    
    if conversions_made > 0
      puts ""
      puts "📋 Summary of conversions made:"
      puts "   • Standard link_to → link_if_can_show, link_if_can_edit"
      puts "   • Delete links → button_if_can_destroy"
      puts "   • New links → link_if_can_create"
      puts "   • Conditional forms → content_if_can_edit/create"
      puts "   • Nested resource links → context-aware helpers"
      puts "   • Complex nested conditionals → smart context-aware helpers"
      puts ""
      puts "⚠️  Please review the changes and test your views!"
      puts "💡 You may need to adjust some conversions manually for complex cases."
    end
  end
  
  desc "Show examples of view helper conversions"
  task :view_examples => :environment do
    puts "🎯 CCCUX View Helper Conversion Examples"
    puts ""
    
    puts "📝 BEFORE → AFTER conversions:"
    puts ""
    
    puts "1️⃣ Show links:"
    puts "   <%= link_to \"Show\", product_path(@product) %>"
    puts "   → <%= link_if_can_show @product, \"Show\", product_path(@product) %>"
    puts ""
    
    puts "2️⃣ Edit links:"
    puts "   <%= link_to \"Edit\", edit_product_path(@product) %>"
    puts "   → <%= link_if_can_edit @product, \"Edit\", edit_product_path(@product) %>"
    puts ""
    
    puts "3️⃣ Delete links:"
    puts "   <%= link_to \"Delete\", product_path(@product), method: :delete %>"
    puts "   → <%= button_if_can_destroy @product, \"Delete\", product_path(@product), method: :delete %>"
    puts ""
    
    puts "4️⃣ New links:"
    puts "   <%= link_to \"New Product\", new_product_path %>"
    puts "   → <%= link_if_can_create Product.new, \"New Product\", new_product_path %>"
    puts ""
    
    puts "5️⃣ Conditional links:"
    puts "   <% if can? :edit, @product %><%= link_to \"Edit\", edit_product_path(@product) %><% end %>"
    puts "   → <%= link_if_can_edit @product, \"Edit\", edit_product_path(@product) %>"
    puts ""
    
    puts "6️⃣ Nested resources:"
    puts "   <%= link_to \"New Product\", new_store_product_path(@store) %>"
    puts "   → <%= link_if_can_create @store.products.build, \"New Product\", new_store_product_path(@store) %>"
    puts ""
    
    puts "7️⃣ Complex nested conditionals:"
    puts "   <% if @project %>"
    puts "     <%= link_to \"Edit this task\", edit_project_task_path(@project, @task) %>"
    puts "   <% else %>"
    puts "     <%= link_to \"Edit this task\", edit_task_path(@task) %>"
    puts "   <% end %>"
    puts "   →"
    puts "   <%= link_if_can_edit @task, \"Edit this task\", @project ? edit_project_task_path(@project, @task) : edit_task_path(@task) %>"
    puts ""
    
    puts "8️⃣ Conditional forms:"
    puts "   <% if can? :edit, @product %>"
    puts "     <%= form_with model: @product do |f| %>"
    puts "       <!-- form fields -->"
    puts "     <% end %>"
    puts "   <% end %>"
    puts "   →"
    puts "   <% content_if_can_edit @product do %>"
    puts "     <%= form_with model: @product do |f| %>"
    puts "       <!-- form fields -->"
    puts "     <% end %>"
    puts "   <% end %>"
    puts ""
    
    puts "🚀 To convert your views:"
    puts "   rails cccux:convert_views[app/views/products]"
    puts "   rails cccux:convert_views[app/views/stores]"
  end
end 