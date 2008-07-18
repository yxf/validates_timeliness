module ValidatesTimeliness
  # Adds ActiveRecord validation methods for date, time and datetime validation.
  # The validity of values can be restricted to be before and/or certain dates
  # or times.
  module Validations    
        
    # Error messages added to AR defaults to allow global override if you need.  
    def self.included(base)
      base.extend ClassMethods
      
      error_messages = {
        :invalid_datetime => "is not a valid %s",
        :before           => "must be before %s",
        :on_or_before     => "must be on or before %s",
        :after            => "must be after %s",
        :on_or_after      => "must be on or after %s"
      }      
      ActiveRecord::Errors.default_error_messages.update(error_messages)
      ValidatesTimeliness::Formats.compile_format_expressions
    end
    
    module ClassMethods
      # loop through format regexps and call proc on matches if available. Allow
      # pre or post match strings if bounded is false. Lastly fills out 
      # time_array to full 7 part datetime array.
      def extract_date_time_values(time_string, type, bounded=true)
        expressions = ValidatesTimeliness::Formats.send("#{type}_expressions")
        time_array = nil
        expressions.each do |(regexp, processor)|
          matches = regexp.match(time_string.strip)
          if !matches.nil? && (!bounded || (matches.pre_match == "" && matches.post_match == ""))
            time_array = processor.call(*matches[1..7])
            break
          end
        end
        return time_array
      end

      # Override this method to use any date parsing algorithm you like such as 
      # Chronic. Just return nil for an invalid value and a Time object for a 
      # valid parsed value. 
      # 
      # Remember Rails, since version 2, will automatically handle the fallback
      # to a DateTime when you create a time which is out of range.      
      def timeliness_date_time_parse(raw_value, type, strict=true)
        return raw_value.to_time if raw_value.acts_like?(:time) || raw_value.is_a?(Date)
        
        time_array = extract_date_time_values(raw_value, type, strict)
        raise if time_array.nil?
        
        if type == :time
          # Rails dummy time date part is defined as 2000-01-01
          time_array[0..2] = 2000, 1, 1
        elsif type == :date
          # throw away time part and check date
          time_array[3..5] = 0, 0, 0
        end

        # Date.new enforces days per month, unlike Time
        Date.new(*time_array[0..2]) unless type == :time
        
        # Check time part, and return time object
        Time.local(*time_array)
      rescue
        nil
      end
      
      
      # The main validation method which can be used directly or called through
      # the other specific type validation methods.      
      def validates_timeliness_of(*attr_names)
        configuration = { :on => :save, :type => :datetime, :allow_nil => false, :allow_blank => false }
        configuration.update(timeliness_default_error_messages)
        configuration.update(attr_names.extract_options!)
        
        # we need to check raw value for blank or nil
        allow_nil   = configuration.delete(:allow_nil)
        allow_blank = configuration.delete(:allow_blank)
        
        validates_each(attr_names, configuration) do |record, attr_name, value|          
          raw_value = record.send("#{attr_name}_before_type_cast")

          next if (raw_value.nil? && allow_nil) || (raw_value.blank? && allow_blank)

          record.errors.add(attr_name, configuration[:blank_message]) and next if raw_value.blank?
          
          column = record.column_for_attribute(attr_name)
          begin
            unless time = timeliness_date_time_parse(raw_value, configuration[:type])
              record.send("#{attr_name}=", nil)
              record.errors.add(attr_name, configuration[:invalid_datetime_message] % configuration[:type])
              next
            end
           
            validate_timeliness_restrictions(record, attr_name, time, configuration)
          rescue Exception => e          
            record.send("#{attr_name}=", nil)
            record.errors.add(attr_name, configuration[:invalid_datetime_message] % configuration[:type])            
          end          
        end
      end   
      
      # Use this validation to force validation of values and restrictions 
      # as dummy time
      def validates_time(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :time
        validates_timeliness_of(attr_names, configuration)
      end
      
      # Use this validation to force validation of values and restrictions 
      # as Date
      def validates_date(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :date
        validates_timeliness_of(attr_names, configuration)
      end
      
      # Use this validation to force validation of values and restrictions
      # as Time/DateTime
      def validates_datetime(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :datetime
        validates_timeliness_of(attr_names, configuration)
      end
      
     private
      
      # Validate value against the restrictions. Restriction values maybe of 
      # mixed type so evaluate them and convert them all to common type as
      # defined by type param.
      def validate_timeliness_restrictions(record, attr_name, value, configuration)
        restriction_methods = {:before => '<', :after => '>', :on_or_before => '<=', :on_or_after => '>='}
        
        conversion_method = case configuration[:type]
          when :time     then :to_dummy_time
          when :date     then :to_date
          when :datetime then :to_time
        end
                
        value = value.send(conversion_method)
        
        restriction_methods.each do |option, method|
          next unless restriction = configuration[option]
          begin
            compare = case restriction
              when Time, Date, DateTime
                restriction
              when Symbol
                record.send(restriction)
              when Proc
                restriction.call(record)
              else
                timeliness_date_time_parse(restriction, configuration[:type], false)
            end            
            
            next if compare.nil?
            
            compare = compare.send(conversion_method)
            record.errors.add(attr_name, configuration["#{option}_message".to_sym] % compare) unless value.send(method, compare)
          rescue
            record.errors.add(attr_name, "restriction '#{option}' value was invalid")
          end
        end
      end
      
      # Map error message keys to *_message to merge with validation options
      def timeliness_default_error_messages
        defaults = ActiveRecord::Errors.default_error_messages.slice(:blank, :invalid_datetime, :before, :on_or_before, :after, :on_or_after)
        returning({}) do |messages|
          defaults.each {|k, v| messages["#{k}_message".to_sym] = v }
        end
      end
                  
    end
  end
end
