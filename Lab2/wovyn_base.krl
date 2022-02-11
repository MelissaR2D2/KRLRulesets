ruleset wovyn_base {
  meta {
    use module twilio.sdk alias sdk
      with
        apiKey = meta:rulesetConfig{"api_key"}
        sessionID = meta:rulesetConfig{"session_id"}
    
    use module sensor_profile alias profile
  }

  global {
      fr = "+18305810809"
    
  }
  rule process_heartbeat {
      select when wovyn heartbeat where event:attrs >< "genericThing"
      pre {
        tempF = event:attr("genericThing").get("data").get("temperature")[0].get("temperatureF").klog("TEMPSENT")
        time = event:time
      }
      fired {
        raise wovyn event "new_temperature_reading" attributes {
          "temperature": tempF,
          "timestamp": time,
        }

      }
    }

   rule find_high_temps {
      select when wovyn new_temperature_reading
      pre {
        curr_temp = event:attr("temperature")
      }
      if curr_temp > profile:threshold() then
        noop()
      fired {
        raise wovyn event "threshold_violation" attributes {
          "temperature": curr_temp,
          "timestamp": event:attr("timestamp"),
        }
      }
    }
/*
    rule threshold_notification {
      select when wovyn threshold_violation
      pre {
        body = ("Temperature threshold violated! Temperature: " + event:attr("temperature") + "F").klog("TEXT_BODY")
      }
      every {
        sdk:sendSMS(profile:sms(), fr, body) setting(response)
        send_directive("response", response)
      }
    }
  */
  }