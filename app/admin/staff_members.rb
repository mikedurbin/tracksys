ActiveAdmin.register StaffMember do
  config.sort_order = 'last_name_dsc'

  menu :parent => "Miscellaneous"

  scope :all, :default => true
  actions :all

  filter :id
  filter :last_name
  filter :first_name

  index do
    selectable_column
    column :full_name
    column :computing_id
    column :email
    column("Active?") do |staff_member|
      format_boolean_as_yes_no(staff_member.is_active)
    end
    column("") do |archive|
      div do
        link_to "Details", resource_path(archive), :class => "member_link view_link"
      end
      div do
        link_to I18n.t('active_admin.edit'), edit_resource_path(archive), :class => "member_link edit_link"
      end
    end
  end

  show :title => proc { |staff| staff.full_name } do
    panel "Detailed Information" do
      attributes_table_for staff_member do
        row :full_name
        row :computing_id
        row :email
        row :is_active
        row :workflows do |staff_member|
         link_to "#{staff_member.job_statuses_count}", admin_job_statuses_path(:q => {:originator_id_eq => staff_member.id, :originator_type_eq => "StaffMember"})
       end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :computing_id
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :is_active, :as => :radio
    end

    f.actions
  end
end
