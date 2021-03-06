class Agency < ActiveRecord::Base
   has_ancestry
   before_save :cache_ancestry

  #------------------------------------------------------------------
  # relationships
  #------------------------------------------------------------------
  has_many :orders
  has_many :requests, -> { where("orders.order_status=?", 'requested') }
  has_many :units, :through => :orders
  has_many :master_files, :through => :units
  has_one :primary_address, ->{where(address_type: "primary")}, :class_name => 'Address', :as => :addressable, :dependent => :destroy
  has_one :billable_address, ->{where(address_type: "billable_address")}, :class_name => 'Address', :as => :addressable, :dependent => :destroy
  has_many :customers, ->{uniq}, :through => :orders
  has_many :bibls, ->{uniq}, :through => :units

  #------------------------------------------------------------------
  # validations
  #------------------------------------------------------------------
  # Should be :case_sensitive => true, but might be a bug in 3.1-rc6
  validates :name, :presence => true, :uniqueness => true

  before_destroy :destroyable?

  #------------------------------------------------------------------
  # callbacks
  #------------------------------------------------------------------

  #------------------------------------------------------------------
  # scopes
  #------------------------------------------------------------------
  scope :no_parent, ->{ where(:ancestry => nil) }

  #------------------------------------------------------------------
  # public class methods
  #------------------------------------------------------------------
  # Returns a string containing a brief, general description of this
  # class/model.
  def Agency.class_description
    return 'Agency represents a project or organization associated with an Order.'
  end

  #------------------------------------------------------------------
  # public instance methods
  #------------------------------------------------------------------
  # Returns a boolean value indicating whether it is safe to delete this
  # Customer from the database. Returns +false+ if this record has dependent
  # records in other tables, namely associated Order records. (We do not check
  # for a BillingAddress record, because it is considered merely an extension of
  # the Customer record; it gets destroyed when the Customer is destroyed.)
  #
  # This method is public but is also called as a +before_destroy+ callback.
  # def destroyable?
  def destroyable?
    if orders? || requests?
      return false
    else
      return true
    end
  end

  # Returns a boolean value indicating whether this Customer has
  # associated Order records.
  def orders?
   return orders.any?
  end

  # Returns a boolean value indicating whether this Customer has
  # associated Request (unapproved Order) records.
  def requests?
   return requests.any?
  end

  def cache_ancestry
    cached_ancestry = String.new
    if path.empty?
      cached_ancestry = self.name
    else
      cached_ancestry = path.map(&:name).join('/')
    end
    self.names_depth_cache = cached_ancestry
  end

  def total_order_count
    # start with self.orders.size and then add all descendant agency's orders.size
    count = self.orders.size
    self.descendant_ids.each {|id| count += Agency.find(id).orders.size}
    return count
  end

  # total_class_count accepts a Sting of a class related to Agency.  Thsi method intended to
  # determine counts for both an Agency object and its descendents (see ancestry gem for more)
  # information on the 'descendent_ids' method.
  #
  # The incoming string is pluralized to be utilized with an Agency object's has_many relationships.
  # The pluralized string is sent to the Agency instance, descendant counts are summed and the value returned.
  def total_class_count(name_of_class)
    begin
      # pluralize the incoming string
      method = name_of_class.underscore.pluralize
      count = self.send("#{method}").size
      self.descendant_ids.each {|id| count += Agency.find(id).send("#{method}").size}
      return count
    rescue NoMethodError
    end
  end

  # need these becaue the call to ancestry causes junk in output like this:
  #   Corks and Curls Preservation
  #   #<Agency:0x007fadc7629c70>#<Agency:0x007fadc76299f0>#<Agency:0x007fadc7629540>#<Agency:0x007fadc7628e60>
  # Happened on the update to activeadmin pre4
  def descendant_links
     out = ""
     Agency.where('ancestry REGEXP ?', "[[:<:]]#{self.id}[[:>:]]").order(name: :asc).each do |a|
        out << "<a class='agency-ancestry' href='/admin/agencies/#{a.id}'>#{a.name}</a>"
     end
     return out
  end
  def parent_links
     out = ""
     return out if self.ancestry.blank?
     ids = self.ancestry.split("/")
     ids.each do |id|
        a = Agency.find_by(id: id)
        out << "<a class='agency-ancestry' href='/admin/agencies/#{a.id}'>#{a.name}</a>" if !a.nil?
     end
     return out
  end
end

# == Schema Information
#
# Table name: agencies
#
#  id                :integer          not null, primary key
#  name              :string(255)
#  description       :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  ancestry          :string(255)
#  names_depth_cache :string(255)
#  orders_count      :integer          default(0)
#
