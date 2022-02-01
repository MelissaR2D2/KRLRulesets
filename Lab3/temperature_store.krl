ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }
    
    global {
        temperatures = function() {
            ent:temperatures || []
        }

        threshold_violations = function() {
            ent:violations || []
        }

        inrange_temperatures = function() {
            // have to check the variables actually exist, which is annoying 
            ent:temperatures =>
            ent:temperatures.filter(function(x){
                ent:violations =>
                ent:violations.none(function(y){x == y}) | true
            }) | []
        }
    }
    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
          temp = event:attr("temperature")
          time = event:attr("timestamp")
        }
        fired {
          ent:temperatures := ent:temperatures => ent:temperatures.append({"temperature": temp, "timestamp": time}) | [{"temperature": temp, "timestamp": time}]
            
        }
      }
  
     rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            temp = event:attr("temperature")
            time = event:attr("timestamp")
        }
        fired {
            ent:violations := ent:violations => ent:violations.append({"temperature": temp, "timestamp": time}) | [{"temperature": temp, "timestamp": time}]
        }
      }
  
      rule clear_temperatures {
        select when sensor reading_reset
        fired {
            ent:temperatures := []
            ent:violations := []
        }
      }
    
    }