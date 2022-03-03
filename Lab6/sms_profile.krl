ruleset sms_profile {
    meta {
      use module twilio.sdk alias sdk
        with
          apiKey = meta:rulesetConfig{"api_key"}
          sessionID = meta:rulesetConfig{"session_id"}
    }
  
    global {
        fr = "+18305810809"
        to = "+7192471427"
    }
     

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            body = ("Temperature threshold violated! Temperature: " + event:attr("temperature") + "F").klog("TEXT_BODY")
        }
        every {
            sdk:sendSMS(to, fr, body) setting(response)
            send_directive("response", response)
        }
    }
    
}