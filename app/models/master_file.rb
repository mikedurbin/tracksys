require "#{Hydraulics.models_dir}/master_file"

class MasterFile

  include Pidable
  #------------------------------------------------------------------
  # scopes
  #------------------------------------------------------------------  
  scope :tiff, where(:type => 'Tiff').order("master_files.id DESC")
  scope :jpeg2000, where(:type => 'JpegTwoThousand').order("master_files.id DESC")

#  after_update :fix_updated_counters

  # Within the scope of a current MasterFile's Unit, return the MasterFile object
  # that follows self.  Used to create links and relationships between objects.
  def next
    master_files_sorted = self.sorted_set
    if master_files_sorted.find_index(self) < master_files_sorted.length
      return master_files_sorted[master_files_sorted.find_index(self)+1]
    else
      return nil
    end
  end


  # Within the scope of a current MasterFile's Unit, return the MasterFile object
  # that preceedes self.  Used to create links and relationships between objects.
  def previous
    master_files_sorted = self.sorted_set
    if master_files_sorted.find_index(self) > 0
      return master_files_sorted[master_files_sorted.find_index(self)-1]
    else
      return nil
    end
  end

  def sorted_set
    master_files_sorted = self.unit.master_files.sort_by {|mf| mf.filename}
  end

  def link_to_dl_thumbnail
    return "http://fedoraproxy.lib.virginia.edu/fedora/get/#{self.pid}/djatoka:jp2SDef/getRegion?scale=125"
  end

  def link_to_dl_page_turner
    return "#{VIRGO_URL}/#{self.bibl.pid}/view?&page=#{self.pid}"
  end

  def path_to_archved_version
    return "#{self.archive.directory}/" + "#{'%09d' % self.unit_id}/" + "#{self.filename}"
  end

  def link_to_static_thumbnail
    thumbnail_name = self.filename.gsub(/(tif|jp2)/, 'jpg')
    unit_dir = "%09d" % self.unit_id
	begin
    # Get the contents of /digiserv-production/metadata and exclude directories that don't begin with and end with a number.  Hopefully this
    # will eliminate other directories that are of non-Tracksys managed content.
    metadata_dir_contents = Dir.entries(PRODUCTION_METADATA_DIR).delete_if {|x| x == '.' or x == '..' or not /^[0-9](.*)[0-9]$/ =~ x}
    metadata_dir_contents.each {|dir|
      range = dir.split('-')
      if self.unit_id.to_i.between?(range.first.to_i, range.last.to_i)
        @range_dir = dir
      end
    }
	rescue
		@range_dir="fixme"
	end
    return "/metadata/#{@range_dir}/#{unit_dir}/Thumbnails_(#{unit_dir})/#{thumbnail_name}"
  end

  def mime_type
    "image/tiff"
  end

  # alias_attributes as CYA for legacy migration.  
  alias_attribute :name_num, :title
  alias_attribute :staff_notes, :description

  # Processor information
  require 'activemessaging/processor'
  include ActiveMessaging::MessageSender

  publishes_to :copy_archived_files_to_production

  def get_from_stornext(computing_id)
    message = ActiveSupport::JSON.encode( {:workflow_type => 'patron', :unit_id => self.unit_id, :master_file_filename => self.filename, :computing_id => computing_id })
    publish :copy_archived_files_to_production, message
  end
  
  def update_thumb_and_tech
    if self.image_tech_meta
      self.image_tech_meta.destroy
    end
    sleep(0.1)

    message = ActiveSupport::JSON.encode( { :master_file_id => self.id, :source => self.path_to_archved_version})
    publish :create_image_technical_metadata_and_thumbnail, message
  end

  # single-table inheritance override to ensure child users parent's routes
  # so JpegTwoThousand.model_name should return "MasterFile"
  # http://www.alexreisner.com/code/single-table-inheritance-in-rails
  def self.inherited(child)
    child.instance_eval do
      def model_name
        MasterFile.model_name
      end
    end
    super
  end
end
# == Schema Information
#
# Table name: master_files
#
#  id                        :integer(4)      not null, primary key
#  unit_id                   :integer(4)      default(0), not null
#  component_id              :integer(4)
#  tech_meta_type            :string(255)
#  filename                  :string(255)
#  filesize                  :integer(4)
#  title                     :string(255)
#  date_archived             :datetime
#  description               :string(255)
#  pid                       :string(255)
#  created_at                :datetime
#  updated_at                :datetime
#  transcription_text        :text
#  desc_metadata             :text
#  rels_ext                  :text
#  solr                      :text(2147483647
#  dc                        :text
#  rels_int                  :text
#  discoverability           :boolean(1)      default(FALSE)
#  md5                       :string(255)
#  indexing_scenario_id      :integer(4)
#  availability_policy_id    :integer(4)
#  automation_messages_count :integer(4)      default(0)
#  use_right_id              :integer(4)
#  date_dl_ingest            :datetime
#  date_dl_update            :datetime
#  dpla                      :boolean(1)      default(FALSE)
#  type                      :string(255)
#  creator_death_date        :string(255)
#  creation_date             :string(255)
#  primary_author            :string(255)
#

