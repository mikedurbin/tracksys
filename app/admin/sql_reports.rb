ActiveAdmin.register SqlReport do
   menu :parent => "Miscellaneous"

   # strong paramters handling
   permit_params :name, :description, :sql

   config.clear_action_items!
   action_item :new, :only => :index do
      raw("<a href='/admin/intended_uses/new'>New</a>") if !current_user.viewer?
   end
   action_item :edit, only: :show do
      link_to "Edit", edit_resource_path  if !current_user.viewer?
   end

   config.batch_actions = false

   filter :name
   filter :description
   filter :sql

   index do
      column :name
      column :description
      column("Links") do |sql_report|
         div {link_to "Details", resource_path(sql_report)}
         if !current_user.viewer?
            div {link_to I18n.t('active_admin.edit'), edit_resource_path(sql_report)}
         end
         if current_user.admin?
            div {link_to "Delete", resource_path(sql_report),
               data: {:confirm => "Are you sure you want to delete this Sql Report?"}, :method => :delete}
            end
         end
      end
   end
