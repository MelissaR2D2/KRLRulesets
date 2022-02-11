ruleset sensor_profile {
    meta {
        provides profile, threshold, sms
        shares profile, threshold, sms
    }
    
    global {
        profile = function() {
            ent:profile || {"name": "", "location": "", "threshold": 65, "sms": ""}
        }
        
        threshold = function() {
            ent:profile => ent:profile{"threshold"} | 65
        }

        sms = function() {
            ent:profile => ent:profile{"sms"} | ""
        }
        
    }
    rule update_profile {
        select when sensor profile_updated
        pre {
          location = event:attr("location")
          name = event:attr("name")
          threshold = event:attr("threshold")
          sms = event:attr("sms")
        }
        fired {
          ent:profile := {"location": location, "name": name, "threshold": threshold, "sms": sms}
        }
      }
    
    }