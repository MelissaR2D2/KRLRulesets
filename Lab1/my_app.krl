ruleset my_app {
    meta {
      use module twilio.sdk alias sdk
        with
          apiKey = meta:rulesetConfig{"api_key"}
          sessionID = meta:rulesetConfig{"session_id"}
    }

    global {
        
          
    }
    
    rule send_message {
        select when send message
        pre {
            to = event:attr("to").klog("to: ")
            fr = event:attr("from").klog("from: ")
            body = event:attr("body").klog("body: ")
          }
          every {
            sdk:sendSMS(to, fr, body) setting(response)
            send_directive("response", response)
        }
      }
    
    rule get_messages {
        select when get messages
        pre {
            pageSize = event:attr("page_size").klog("pageSize: ")
            fr = event:attr("from").klog("from: ")
            to = event:attr("to").klog("to: ")
            response = sdk:messages(pageSize, fr, to)
          }
        send_directive("response", response)
      }
  }