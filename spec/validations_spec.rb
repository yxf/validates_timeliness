require File.dirname(__FILE__) + '/spec_helper'

describe ValidatesTimeliness::Validations do
  before :all do
    # freezes time using time_travel plugin
    Time.now = Time.utc(2008, 1, 1, 12, 0, 0)
  end
  
  after :all do
    Time.now = nil
  end
  
  describe "with no restrictions" do
    before :all do
      class BasicValidation < Person
        validates_timeliness_of :birth_date_and_time, :allow_blank => true, :type => :datetime
        validates_timeliness_of :birth_date, :allow_blank => true, :type => :date
        validates_timeliness_of :birth_time, :allow_blank => true, :type => :time
      end
    end

    before :each do
      @person = BasicValidation.new
    end

    it "should have error for invalid date component for datetime column" do
      @person.birth_date_and_time = "1980-02-30 01:02:03"
      @person.should_not be_valid
      @person.errors.on(:birth_date_and_time).should == "is not a valid datetime"
    end

    it "should have error for invalid time component for datetime column" do
      @person.birth_date_and_time = "1980-02-30 25:02:03"
      @person.should_not be_valid 
      @person.errors.on(:birth_date_and_time).should == "is not a valid datetime"
    end

    it "should have error for invalid date value for date column" do
      @person.birth_date = "1980-02-30"
      @person.should_not be_valid
      @person.errors.on(:birth_date).should == "is not a valid date"
    end

    it "should have error for invalid time value for time column" do
      @person.birth_time = "25:00"
      @person.should_not be_valid
      @person.errors.on(:birth_time).should == "is not a valid time"
    end

    it "should be valid with valid values" do
      @person.birth_date_and_time = "1980-01-31 12:12:12"
      @person.birth_date = "1980-01-31"
      @person.should be_valid
    end
    
    it "should be valid with values before epoch" do
      @person.birth_date_and_time = "1960-01-31 12:12:12"
      @person.birth_date = "1960-01-31"
      @person.birth_time = "23:59"
      @person.should be_valid
    end
    
    it "should be valid with nil values when allow_blank si true" do
      @person.birth_date_and_time = nil
      @person.birth_date = nil
      @person.birth_time = nil      
      @person.should be_valid
    end
  end
  
  describe "for datetime type" do
    
    describe "with before and after restrictions" do
      before :all do
        class DateTimeBeforeAfter < Person
          validates_timeliness_of :birth_date_and_time, :type => :datetime,
            :before => Time.now, :after => 1.day.ago
        end
      end

      before :each do
        @person = DateTimeBeforeAfter.new
      end
      
      it "should have error when past :before restriction" do
        @person.birth_date_and_time = 1.minute.from_now
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be before/)
      end

      it "should have error when before :after restriction" do
        @person.birth_date_and_time = 2.days.ago
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be after/)
      end
      
      it "should have error when on boundary of :before restriction" do
        @person.birth_date_and_time = Time.now
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be before/)
      end

      it "should have error when on boundary of :after restriction" do
        @person.birth_date_and_time = 1.day.ago
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be after/)
      end
    end

    describe "with on_or_before and on_or_after restrictions" do
      before :all do
        class DateTimeOnOrBeforeAndAfter < Person
          validates_timeliness_of :birth_date_and_time, :type => :datetime,
            :on_or_before => Time.now.at_midnight, 
            :on_or_after => 1.day.ago
        end
      end
      
      before do  
        @person = DateTimeOnOrBeforeAndAfter.new
      end
        
      it "should have error when past :on_or_before restriction" do
        @person.birth_date_and_time = Time.now.at_midnight + 1
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be on or before/)
      end

      it "should have error when before :on_or_after restriction" do
        @person.birth_date_and_time = 1.days.ago - 1
        @person.should_not be_valid
        @person.errors.on(:birth_date_and_time).should match(/must be on or after/)
      end
      
      it "should be valid when value equal to :on_or_before restriction" do
        @person.birth_date_and_time = Time.now.at_midnight
        @person.should be_valid
      end

      it "should be valid when value equal to :on_or_after restriction" do
        @person.birth_date_and_time = 1.day.ago
        @person.should be_valid        
      end 
    end

  end
  
  describe "for date type" do
#    it "should validate with invalid time part" do
#      person = BasicValidation.new
#      person.birth_date = "1980-01-01 25:61:61"
#      person.should be_valid
#    end
    
    describe "with before and after restrictions" do
      before :all do
        class DateBeforeAfter < Person
          validates_timeliness_of :birth_date, :type => :date,
            :before => 1.day.from_now, 
            :after => 1.day.ago
        end        
      end

      before :each do
        @person = DateBeforeAfter.new
      end
      
      it "should have error when past :before restriction" do
        @person.birth_date = 2.days.from_now
        @person.should_not be_valid
        @person.errors.on(:birth_date).should match(/must be before/)
      end

      it "should have error when before :after restriction" do
        @person.birth_date = 2.days.ago
        @person.should_not be_valid
        @person.errors.on(:birth_date).should match(/must be after/)
      end
    end

    describe "with on_or_before and on_or_after restrictions" do
      before :all do
        class DateOnOrBeforeAndAfter < Person
          validates_timeliness_of :birth_date, :type => :date, 
            :on_or_before => 1.day.from_now,
            :on_or_after => 1.day.ago
        end
      end
      
      before :each do
        @person = DateOnOrBeforeAndAfter.new
      end
        
      it "should have error when past :on_or_before restriction" do
        @person.birth_date = 2.days.from_now
        @person.should_not be_valid
        @person.errors.on(:birth_date).should match(/must be on or before/)
      end

      it "should have error when before :on_or_after restriction" do
        @person.birth_date = 2.days.ago
        @person.should_not be_valid
        @person.errors.on(:birth_date).should match(/must be on or after/)
      end
      
      it "should be valid when value equal to :on_or_before restriction" do
        @person.birth_date = 1.day.from_now
        @person.should be_valid
      end

      it "should be valid when value equal to :on_or_after restriction" do
        @person.birth_date = 1.day.ago
        @person.should be_valid        
      end      
    end 
  end
  
  describe "for time type" do
#    it "should validate with invalid date part" do
#      person = BasicValidation.new
#      person.birth_time = "1980-02-30 23:59:59"
#      person.should be_valid
#    end
  
    describe "with before and after restrictions" do
      before :all do
        class TimeBeforeAfter < Person
          validates_timeliness_of :birth_time, :type => :time,
            :before => "23:00", 
            :after => "06:00"
        end        
      end

      before :each do
        @person = TimeBeforeAfter.new
      end
      
      it "should have error when on boundary of :before restriction" do
        @person.birth_time = "23:00"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be before/)
      end

      it "should have error when on boundary of :after restriction" do
        @person.birth_time = "06:00am"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be after/)
      end
      
      it "should have error when past :before restriction" do
        @person.birth_time = "23:01"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be before/)
      end

      it "should have error when before :after restriction" do
        @person.birth_time = "05:59"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be after/)
      end
      
      it "should not have error when before :before restriction" do
        @person.birth_time = "22:59"
        @person.should be_valid
      end

      it "should have error when before :after restriction" do
        @person.birth_time = "06:01"
        @person.should be_valid
      end
    end

    describe "with on_or_before and on_or_after restrictions" do
      before :all do
        class TimeOnOrBeforeAndAfter < Person
          validates_timeliness_of :birth_time, :type => :time,
            :on_or_before => "23:00",
            :on_or_after => "06:00"
        end
      end
      
      before :each do
        @person = TimeOnOrBeforeAndAfter.new
      end
        
      it "should have error when past :on_or_before restriction" do
        @person.birth_time = "23:01"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be on or before/)
      end

      it "should have error when before :on_or_after restriction" do
        @person.birth_time = "05:59"
        @person.should_not be_valid
        @person.errors.on(:birth_time).should match(/must be on or after/)
      end
      
      it "should be valid when on boundary of :on_or_before restriction" do
        @person.birth_time = "23:00"
        @person.should be_valid
      end

      it "should be valid when on boundary of :on_or_after restriction" do
        @person.birth_time = "06:00"
        @person.should be_valid        
      end      
    end 
  end
  
  
  describe "with mixed value and restriction types" do
    before :all do
      class MixedBeforeAndAfter < Person
        validates_timeliness_of :birth_date_and_time, :before => Date.new(2008,1,2), :after => lambda { Time.mktime(2008, 1, 1) }
        validates_timeliness_of :birth_date, :type => :date, :on_or_before => Time.mktime(2008, 1, 2), :on_or_after => :birth_date_and_time
      end
    end
    
    before :each do
      @person = MixedBeforeAndAfter.new
    end
    
    it "should correctly validate time attribute with Date restriction" do
      @person.birth_date_and_time = "2008-01-03 00:00:00"
      @person.should_not be_valid
      @person.errors.on(:birth_date_and_time).should match(/must be before/)
    end
    
    it "should correctly validate with proc restriction" do
      @person.birth_date_and_time = "2008-01-01 00:00:00"
      @person.should_not be_valid
      @person.errors.on(:birth_date_and_time).should match(/must be after/)
    end

    it "should correctly validate date attribute with Time restriction" do
      @person.birth_date = "2008-01-03"      
      @person.should_not be_valid
      @person.errors.on(:birth_date).should match(/must be on or before/)
    end

    it "should correctly validate date attribute with symbol restriction" do
      @person.birth_date = "2008-01-01"
      @person.birth_date_and_time = "2008-01-02 12:00:00"
      @person.should_not be_valid
      @person.errors.on(:birth_date).should match(/must be on or after/)
    end

  end  
end
