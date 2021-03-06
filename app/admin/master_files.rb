ActiveAdmin.register MasterFile do
   config.sort_order = 'filename_asc'

   # strong paramters handling
   permit_params :filename, :title, :description, :creation_date, :primary_author, :creator_death_date, :date_archived,
      :md5, :filesize, :unit_id, :transcription_text, #:component_id,
      :pid, :indexing_scenario_id, :desc_metadata, :use_right_id

   menu :priority => 6

   scope :all, :show_count => true, :default => true
   scope :in_digital_library, :show_count => true
   scope :not_in_digital_library, :show_count => true

   config.clear_action_items!
   action_item :pdf, :only => :show do
     raw("<a href='#{Settings.pdf_url}/#{master_file.pid}' target='_blank'>Download PDF</a>")
   end
   action_item :ocr, only: :show do
      link_to "OCR", "/admin/ocr?mf=#{master_file.id}"  if !current_user.viewer? && ocr_enabled?
   end
   action_item :transcribe, only: :show do
      link_to "Transcribe", "/admin/transcribe?mf=#{master_file.id}"  if !current_user.viewer?
   end
   action_item :edit, only: :show do
      link_to "Edit", edit_resource_path  if !current_user.viewer?
   end

   batch_action :download_from_archive do |selection|
      MasterFile.find(selection).each {|s| s.get_from_stornext }
      flash[:notice] = "Master Files #{selection.join(", ")} are now being downloaded to #{PRODUCTION_SCAN_FROM_ARCHIVE_DIR}."
      redirect_to :back
   end

   filter :id
   filter :filename
   filter :title
   filter :description
   filter :transcription_text
   filter :desc_metadata
   filter :pid
   filter :md5, :label => "MD5 Checksum"
   filter :unit_id, :as => :numeric, :label => "Unit ID"
   filter :order_id, :as => :numeric, :label => "Order ID"
   filter :customer_id, :as => :numeric, :label => "Customer ID"
   filter :bibl_id, :as => :numeric, :label => "Bibl ID"
   filter :customer_last_name, :as => :string, :label => "Customer Last Name"
   filter :bibl_title, :as => :string, :label => "Bibl Title"
   filter :bibl_creator_name, :as => :string, :label => "Author"
   filter :bibl_call_number, :as => :string, :label => "Call Number"
   filter :bibl_barcode, :as => :string, :label => "Barcode"
   filter :bibl_catalog_key, :as => :string, :label => "Catalog Key"
   filter :use_right, :as => :select, label: 'Right Statement'
   filter :academic_status, :as => :select
   filter :indexing_scenario
   filter :date_archived
   filter :date_dl_ingest
   filter :date_dl_update
   filter :agency, :as => :select

   index :id => 'master_files' do
      selectable_column
      column :filename, :sortable => false
      column :title do |mf|
         truncate_words(mf.title)
      end
      column :description do |mf|
         truncate_words(mf.description)
      end
      column :date_archived do |mf|
         format_date(mf.date_archived)
      end
      column :date_dl_ingest do |mf|
         format_date(mf.date_dl_ingest)
      end
      column :pid, :sortable => false
      column ("Bibliographic Record") do |mf|
         div do
            link_to "#{mf.bibl_title}", admin_bibl_path("#{mf.bibl_id}")
         end
         div do
            mf.bibl_call_number
         end
      end
      column :unit
      column("Thumbnail") do |mf|
         link_to image_tag(mf.link_to_static_thumbnail, :height => 125), "#{mf.link_to_static_thumbnail}", :rel => 'colorbox', :title => "#{mf.filename} (#{mf.title} #{mf.description})"
      end
      column("") do |mf|
         div do
            link_to "Details", resource_path(mf), :class => "member_link view_link"
         end
         div do
            link_to "PDF", "#{Settings.pdf_url}/#{mf.pid}", target: "_blank"
         end
         if !current_user.viewer?
            div do
               link_to I18n.t('active_admin.edit'), edit_resource_path(mf), :class => "member_link edit_link"
            end
            if ocr_enabled?
               div do
                  link_to "OCR", "/admin/ocr?mf=#{mf.id}"
               end
            end
         end
         if mf.date_archived
            div do
               link_to "Download", copy_from_archive_admin_master_file_path(mf.id), :method => :put
            end
         end
      end
   end

   show :title => proc {|mf| mf.filename } do
      div :class => 'two-column' do
         panel "General Information" do
            attributes_table_for master_file do
               row :filename
               row :title
               row :description
               row :date_archived do |master_file|
                  format_date(master_file.date_archived)
               end
               row :intellectual_property_notes do |master_file|
                  if master_file.creation_date or master_file.primary_author or master_file.creator_death_date
                     "Event Creation Date: #{master_file.creation_date} ; Author: #{master_file.primary_author} ; Author Death Date: #{master_file.creator_death_date}"
                  else
                     "no data"
                  end
               end
            end
         end

         panel "Transcription Text", :toggle => 'show' do
            div :class=>'mf-transcription' do
               simple_format(master_file.transcription_text)
            end
         end
      end


      div :class => 'two-column' do
         panel "Technical Information", :id => 'master_files', :toggle => 'show' do
            attributes_table_for master_file do
               row :md5
               row :filesize do |master_file|
                  "#{master_file.filesize / 1048576} MB"
               end
               if master_file.image_tech_meta
                  attributes_table_for master_file.image_tech_meta do
                     row :image_format
                     row("Height x Width"){|mf| "#{mf.height} x #{mf.width}"}
                     row :resolution
                     row :depth
                     row :compression
                     row :color_space
                     row :color_profile
                     row :equipment
                     row :model
                     row :iso
                     row :exposure_bias
                     row :exposure_time
                     row :aperture
                     row :focal_length
                     row :software
                  end
               end
            end
         end
      end

      div :class => 'columns-none', :toggle => 'hide' do
         panel "Digital Library Information", :id => 'master_files', :toggle => 'show' do
            attributes_table_for master_file do
               row :pid
               row :date_dl_ingest
               row :date_dl_update
               row('Right Statement'){ |r| r.use_right.name }
               row :indexing_scenario
               row :discoverability do |mf|
                  case mf.discoverability
                  when false
                     "Not uniquely discoverable"
                  when true
                     "Uniquely discoverable"
                  else
                     "Unknown"
                  end
               end
            end

            div :id => "desc_meta_div" do
               div :id=>"master-file-desc-metadata" do "DESC METADATA" end
               span :class => "click-advice" do
                  "click in the code window to expand/collapse display"
               end
               pre :id => "desc_meta", :class => "no-whitespace code-window" do
                  code :'data-language' => 'html' do
                     word_wrap(master_file.desc_metadata.to_s, :line_width => 200)
                  end
               end
            end
         end
      end
   end

   form do |f|
      f.inputs "General Information", :class => 'panel two-column ' do
         f.input :filename
         f.input :title
         f.input :description, :as => :text, :input_html => { :rows => 3 }
         f.input :creation_date, :as => :text, :input_html => { :rows => 1 }
         f.input :primary_author, :as => :text, :input_html => { :rows => 1 }
         f.input :creator_death_date, :as => :string, :input_html => { :rows => 1 }
         f.input :date_archived, :as => :string, :input_html => {:class => :datepicker}
      end

      f.inputs "Technical Information", :class => 'two-column panel', :toggle => 'show' do
         f.input :md5, :input_html => { :disabled => true }
         f.input :filesize, :as => :number
      end

      f.inputs "Related Information", :class => 'panel two-column', :toggle => 'show' do
         f.input :unit_id, :as => :number
         # f.input :component_id, :as => :number
      end

      f.inputs "Digital Library Information", :class => 'panel columns-none', :toggle => 'hide' do
         f.input :pid, :input_html => { :disabled => true }
         f.input :use_right, label: "Right Statement"
         f.input :indexing_scenario
         f.input :desc_metadata, :input_html => { :rows => 10}
      end

      f.inputs :class => 'columns-none' do
         f.actions
      end
   end

   sidebar "Thumbnail", :only => [:show] do
      div :style=>"text-align:center" do
         link_to image_tag(master_file.link_to_static_thumbnail, :height => 250), "#{master_file.link_to_static_thumbnail}", :rel => 'colorbox', :title => "#{master_file.filename} (#{master_file.title} #{master_file.description})"
      end
   end

   sidebar "Related Information", :only => [:show] do
      attributes_table_for master_file do
         row :unit do |master_file|
            link_to "##{master_file.unit.id}", admin_unit_path(master_file.unit.id)
         end
         row :bibl
         row :order do |master_file|
            link_to "##{master_file.order.id}", admin_order_path(master_file.order.id)
         end
         row :customer
         # row :component do |master_file|
         #    if master_file.component
         #       link_to "#{master_file.component.name}", admin_component_path(master_file.component.id)
         #    end
         # end
         row :agency
         row "Legacy Identifiers" do |master_file|
            raw(master_file.legacy_identifier_links)
         end
      end
   end

   sidebar "Digital Library Workflow", :only => [:show],  if: proc{ !current_user.viewer? } do
      if master_file.in_dl?
         div :class => 'workflow_button' do button_to "Publish",
           publish_admin_master_file_path(:datastream => 'all'), :method => :put end
      else
         "No options available.  Master File is not in DL."
      end
   end

   action_item :previous, :only => :show do
      link_to("Previous", admin_master_file_path(master_file.previous)) unless master_file.previous.nil?
   end

   action_item :next, :only => :show do
      link_to("Next", admin_master_file_path(master_file.next)) unless master_file.next.nil?
   end

   action_item :download, :only => :show do
      if master_file.date_archived
         link_to "Download", copy_from_archive_admin_master_file_path(master_file.id), :method => :put
      end
   end

   member_action :transcribe, :method => :get do
   end

   member_action :publish, :method => :put do
     mf = MasterFile.find(params[:id])
     mf.update_attribute(:date_dl_update, Time.now)
     logger.info "Master File #{mf.id} has been flagged for an update in the DL"
     redirect_to :back, :notice => "Master File flagged for Publication"
   end

   member_action :copy_from_archive, :method => :put do
      mf = MasterFile.find(params[:id])
      mf.get_from_stornext(current_user.computing_id)
      redirect_to :back, :notice => "Master File #{mf.filename} is now being downloaded to #{PRODUCTION_SCAN_FROM_ARCHIVE_DIR}."
   end

   # Specified in routes.rb to return the XML partial mods.xml.erb
   member_action :mods do
      @master_file = MasterFile.find(params[:id])
      @page_title = "MODS Record for MasterFile ##{@master_file.id}"
      render template: "admin/master_files/mods.xml.erb"
   end

   member_action :solr do
      @master_file = MasterFile.find(params[:id])
   end
end
