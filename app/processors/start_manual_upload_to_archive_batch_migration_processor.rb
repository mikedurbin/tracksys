# Written by: Andrew Curley (aec6v@virginia.edu) and Greg Murray (gpm2a@virginia.edu)
# Written: January - March 2010

class StartManualUploadToArchiveBatchMigrationProcessor < ApplicationProcessor
  require 'fileutils'

  subscribes_to :start_manual_upload_to_archive_batch_migration, {:ack=>'client', 'activemq.prefetchSize' => 1}

  def on_message(message)
    logger.debug "StartManualUploadToArchiveBatchMigrationProcessor received: " + message

    # decode JSON message into Ruby hash
    hash = ActiveSupport::JSON.decode(message).symbolize_keys

    now = Time.now
    day = now.strftime("%A")
    regex_unit = Regexp.new('\d{9}$')
    @user_id = hash[:user_id]
    @workflow_type = AutomationMessage::WORKFLOW_TYPES_HASH.fetch(self.class.name.demodulize)

    if not File.exist?(File.join(MANUAL_UPLOAD_TO_ARCHIVE_DIR_BATCH_MIGRATION, day))
      on_error "Manual upload directory #{MANUAL_UPLOAD_TO_ARCHIVE_DIR_BATCH_MIGRATION}/#{day} does not exist."
    else
      @original_source_dir = File.join(MANUAL_UPLOAD_TO_ARCHIVE_DIR_BATCH_MIGRATION, day)
      contents = Dir.entries(@original_source_dir).delete_if {|x| x == "." or x == ".."}

      if contents.empty?
        on_success "No items to upload in #{@original_source_dir}"
      else
        # Process each value in array
        contents.each { |content|
          complete_path = File.join(@original_source_dir, content)
          # Directory test
          if not File.directory?(complete_path)
             if /DS_Store/ =~ content
               # skip
             else
               on_failure "#{complete_path} is not a directory"
             end
         else
            # We are going to skp naming format test here to allow non-DSSR produced material
            # Empty directory test
            if (Dir.entries(complete_path) == [".", ".."])
              on_failure "#{complete_path} is an empty directory"
            else
              # Move directory from 'day' directory to 'in_process' directory to prevent staff from accidentally archiving the material twice in quick succession.
              FileUtils.mv File.join(@original_source_dir, content), File.join(MANUAL_ARCHIVE_IN_PROCESS_DIR_BATCH_MIGRATION, content)

              if regex_unit.match(content).nil?
                @messagable_type = "StaffMember"
                @messagable_id = @user_id
                @internal_dir = "no"
                on_success "Non-Tracking System managed content (#{content}) sent to StorNext worklfow via manual upload directory from #{MANUAL_UPLOAD_TO_ARCHIVE_DIR_BATCH_MIGRATION}/#{day}."
                SendUnitToArchive.exec_now({:unit_dir => content, :source_dir => MANUAL_ARCHIVE_IN_PROCESS_DIR_BATCH_MIGRATION, :internal_dir => @internal_dir})
              else
                @internal_dir = "yes"
                @unit_id = content.to_s.sub(/^0+/, '')
                @messagable_id = @unit_id
                @messagable_type = "Unit"
                on_success "Unit #{@unit_id} sent to StorNext workflow via manual upload directory from #{MANUAL_UPLOAD_TO_ARCHIVE_DIR_BATCH_MIGRATION}/#{day}."
                SendUnitToArchive.exec_now( { :unit_id => @unit_id, :unit_dir => content, :source_dir => MANUAL_ARCHIVE_IN_PROCESS_DIR_BATCH_MIGRATION, :internal_dir => @internal_dir})
              end
            end
          end
        }
      end
    end
  end
end
