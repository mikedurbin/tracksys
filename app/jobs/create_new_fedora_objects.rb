class CreateNewFedoraObjects < BaseJob

   require 'fedora'
   require 'pidable'

   def perform(message)
      Job_Log.debug "CreateNewFedoraObjectsProcessor received: #{message.to_json}"

      # Validate incoming message
      raise "Parameter 'source' is required" if message[:source].blank?
      raise "Parameter 'object_class' is required" if message[:object_class].blank?
      raise "Parameter 'object_id' is required" if message[:object_id].blank?
      raise "Parameter 'last' is required" if message[:last].blank?

      @source = message[:source]
      @object_class = message[:object_class]
      @object_id = message[:object_id]
      @last = message[:last]
      @object = @object_class.classify.constantize.find(@object_id)
      @messagable_id = message[:object_id]
      @messagable_type = message[:object_class]
      set_workflow_type()
      @pid = @object.pid
      instance_variable_set("@#{@object.class.to_s.underscore}_id", @object_id)

      # Set up REST client
      @resource = RestClient::Resource.new FEDORA_REST_URL, :user => Fedora_username, :password => Fedora_password

      # Conditional logic to determine the object label in Fedora
      if @object.is_a? Bibl
         label = @object.title
      elsif @object.is_a? MasterFile
         label = @object.title
      elsif @object.is_a? Component
         label = @object.label
      elsif @object.is_a? EadRef
         label = @object.content_desc
      else
         on_error "Object is of an unknown class.  Please check code."
      end

      # Create an object in fedora if it doesn't exist. Update if it does
      Fedora.create_or_update_object(@object, label)

      # All ingestable objects have a date_dl_ingest attribute which can be updated at this time.
      @object.update_attribute(:date_dl_ingest, Time.now)

      # This processor emits two kinds of messages:
      # 1.  Bound for creating text or XML-based datastreams
      # 2.  Bound for creating JP2 image

      # All objects get desc_metadata, rights_metadata
      default_message = { :object_class => @object_class, :object_id => @object_id, :type => 'ingest' }
      IngestDescMetadata.exec_now(default_message)

      if @object.is_a? Bibl
         if @object.catalog_key
            IngestMarc.exec_now( default_message )
         end
      end

      # MasterFiles (i.e. images)
      if @object.is_a? MasterFile
         @file_path = File.join(@source, @object.filename)
         CreateDlDeliverables.exec_now({ :mode => 'dl', :source => @file_path, :object_class => @object_class, :object_id => @object_id, :last => @last, :type => 'ingest' })
         IngestTechMetadata.exec_now( default_message )

         # Only MasterFiles with transcritpion need have
         if @object.transcription_text
            IngestTranscription.exec_now( default_message )
         end
      end
      on_success "An object created for #{@pid}"
   end
end