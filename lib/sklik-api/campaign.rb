# -*- encoding : utf-8 -*-
class SklikApi
  class Campaign

    NAME = "campaign"

    include Object
=begin
Example of input hash
{
  :campaign_id => 12345, #(OPTIONAL) -> when setted it will on save do update of existing campaign
  :name => "my campaign name - #{Time.now.strftime("%Y.%m.%d %H:%M:%S")}",
  :status => :running,
  :cpc => 3,
  :budget => 50,

  :network_setting => {
    :content => true,
    :search => true
  },
  
  :ad_groups => [
    {
      :name => "my adgroup name",
      :ads => [ 
        {
          :headline => "Super headline",
          :description1 => "Trying to do ",
          :description2 => "best description ever",
          :display_url => "my_test_url.cz",
          :url => "http://my_test_url.cz"
        }
      ],
      :keywords => [
        "\"some funny keyword\"",
        "[phrase keyword]",
        "broad keyword for me",
        "test of diarcritics âô"
      ]
    }
  ]
}
=end
    
    def initialize args
      #variable where are saved current data from system
      @campaign_data = nil
      
      #variable for storing errors
      @errors = []
      
      #initialize adgroups
      @adgroups = []
      if args[:ad_groups] && args[:ad_groups].size > 0
        args[:ad_groups].each do |adgroup|
          @adgroups << SklikApi::Adgroup.new(self, adgroup)
        end
      end
      
      @customer_id = args[:customer_id]
      super args
    end
    
    def errors
      @errors 
    end
    
    def self.find args = {}
      out = []
      super(NAME, args[:customer_id]).each do |campaign|
        if args[:campaign_id].nil? || (args[:campaign_id] && args[:campaign_id].to_i == campaign[:id].to_i)
          out << SklikApi::Campaign.new( 
            :campaign_id => campaign[:id],
            :customer_id => args[:customer_id], 
            :budget => campaign[:dayBudget].to_f/100.0, 
            :name => campaign[:name], 
            :status => fix_status(campaign)
          )
        end
      end
      out
    end
    
    def self.list_search_services
      connection.call("listSearchServices") do |param|
        return param[:searchServices].collect{|c| c.symbolize_keys}
      end      
    end
    
    def self.fix_status campaign
      if campaign[:removed] == true
        return :stopped
      elsif campaign[:status] == "active"
        return :running
      elsif campaign[:status] == "suspend"
        return :paused
      else
        return :unknown
      end
    end

    def status_for_update
      if @args[:status] == :running
        return "active"
      elsif @args[:status] == :paused
        return "suspend"
      else
        return nil
      end
    end
    
    def to_hash
      if @campaign_data
        @campaign_data
      else
        @campaign_data = @args
        @campaign_data[:ad_groups] = Adgroup.find(self).collect{|a| a.to_hash}
        @campaign_data
      end
    end
    
    def update_args
      out = []

      #add campaign id on which will be performed update
      out << @args[:campaign_id]
      
      #prepare campaign struct
      args = {}
      args[:name] = @args[:name] if @args[:name]
      args[:status] = status_for_update if status_for_update
      args[:dayBudget] = (@args[:budget] * 100).to_i if @args[:budget]
      args[:context] = @args[:network_setting][:context] ||= true if @args[:network_setting]
      args[:excludedSearchServices] = @args[:excluded_search_services] if @args[:excluded_search_services]

      out << args

      out
    end
    
    def create_args
      out = []
      
      #prepare campaign struct
      args = {}
      args[:name] = @args[:name]
      args[:dayBudget] = (@args[:budget] * 100).to_i if @args[:budget]
      args[:context] = @args[:network_setting][:context] ||= true if @args[:network_setting]
      args[:excludedSearchServices] = @args[:excluded_search_services] if @args[:excluded_search_services]
      out << args
      
      #add customer id on which account campaign should be created
      out << @customer_id if @customer_id
      out
    end
    
    def self.get_current_status args = {}
      raise ArgumentError, "Campaign_id is required" unless args[:campaign_id]
      campaigns = self.find(args)
      pp campaigns
      if campaigns.size == 1
        campaigns.first.args[:status]
      else
        raise ArgumentError, "Campaign by #{args.inspect} couldn't be found!"
      end
    end

    def get_current_status
      self.class.get_current_status :campaign_id => @args[:campaign_id], :customer_id => @customer_id
    end

    def update args = {}
      @args.merge!(args)
      save
    end
    
    def save 
      if @args[:campaign_id]  #do update
        #get current status of campaign
        before_status = get_current_status
        
        #restore campaign before update 
        restore if before_status == :stopped
        
        #update campaign
        update_object
        
        #remove it if new status is stopped or status doesn't changed and before it was stopped
        remove if (@args[:status] == :stopped) || (@args[:status].nil? && before_status == :stopped)
        
        return true
      else                    #do save
        #create campaign
        begin
          create
        rescue Exception => e
          @errors << e.message
          return false
        end
        
        begin
          #create adgroups
          @adgroups.each{ |adgroup| adgroup.save }
        
          @campaign_data = @args
          raise ArgumentError, "Problem with creating campaign datas" unless @errors.size == 0
          return true
        rescue Exception => e
          @errors << e.message
          #update name
          update :name => "#{@args[:name]} FAILED ON CREATION - #{Time.now.strftime("%Y.%m.%d %H:%M:%S")}"
          #remove campaign
          remove
          #return false because error occured
          return false
        end
      end
    end
  end
end

#include campaign parts
["keyword", "adtext", "adgroup"].each { |file| require File.join(File.dirname(__FILE__), "campaign_parts/#{file}.rb") }
