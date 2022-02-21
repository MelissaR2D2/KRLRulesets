ruleset sensor_setup {
    meta {
      use module io.picolabs.wrangler alias wrangler
    }
  
    global {
        default_threshold = 75

        sensors = function() {
            return ent:sensors || {}
        }

        __testing = { "queries":
        [{"name": "sensors"}], 
        "events":
        [ { "domain": "sensor", "name": "new_sensor", "attrs": ["name"] },
        { "domain": "sensor", "name": "unneeded_sensor", "attrs": ["name"] }
        ]}
    }


    rule install_twilio {
        select when wrangler ruleset_installed where event:attrs{"rid"} == "sensor_setup"
        pre {
            name = event:attr("name")
        }          
        fired {
          raise wrangler event "install_ruleset_request" attributes {
            "absoluteURL": "file:///Users/student/Documents/College/Winter 2022/CS462/Lab1/",
            "rid": "twilio",
            "config": {},
            "name": name
          }
        }
    }

    rule install_emitter {
      select when wrangler ruleset_installed where event:attrs{"rid"} == "twilio"
      pre {
        name = event:attr("name")
      }       
      fired {
        raise wrangler event "install_ruleset_request" attributes {
          "absoluteURL": "https://raw.githubusercontent.com/windley/temperature-network/main/",
          "rid": "io.picolabs.wovyn.emitter",
          "config": {},
          "name": name
        }
      }
    }

    rule install_profile {
      select when wrangler ruleset_installed where event:attrs{"rid"} == "io.picolabs.wovyn.emitter"
      pre {
        name = event:attr("name")
      }       
      fired {
        raise wrangler event "install_ruleset_request" attributes {
          "absoluteURL": "file:///Users/student/Documents/College/Winter 2022/CS462/Lab4/rulesets/",
          "rid": "sensor_profile",
          "config": {},
          "name": name
        }
      }
    }

    rule install_wovyn {
      select when wrangler ruleset_installed where event:attrs{"rid"} == "sensor_profile"
      pre {
        name = event:attr("name")
      }       
      fired {
        raise wrangler event "install_ruleset_request" attributes {
          "absoluteURL": "file:///Users/student/Documents/College/Winter 2022/CS462/Lab2/",
          "rid": "wovyn_base",
          "config": {},
          "name": name
        }
      }
    }

    rule install_temp_store {
      select when wrangler ruleset_installed where event:attrs{"rid"} == "wovyn_base"
      pre {
        name = event:attr("name")
      }       
      fired {
        raise wrangler event "install_ruleset_request" attributes {
          "absoluteURL": "file:///Users/student/Documents/College/Winter 2022/CS462/Lab3/",
          "rid": "temperature_store",
          "config": {},
          "name": name
        }
      }
    }

    rule query_channel_added {
      select when wrangler ruleset_installed where event:attrs{"rid"} == "temperature_store"
      pre {
          name = event:attrs{"name"}
          tags = ["test"]
          eventPolicy = {"allow": [{"domain": "*", "name": "*"}], "deny": []}
          queryPolicy = {"allow":[{"rid": "*", "name": "*"}], "deny": []}
      }
      every {
        wrangler:createChannel(tags,eventPolicy,queryPolicy) setting(channel)
        send_directive("new channel",{"eci": channel{"id"}})
      }
      fired {
        raise channel event "read_channel_added" attributes {
          "name": name,
          "test_eci": channel{"id"}
        }
      }
    }
  

    rule finished_install_notify {
      select when channel read_channel_added
      pre {
        name = event:attr("name")
        test_eci = event:attr("test_eci")
      }       
      event:send(
        { "eci": wrangler:parent_eci(), 
          "eid": "notify-install", 
          "domain": "sensor", "type": "install_finished",
          "attrs": {
            "name": name,
            "eci": event:eci,
            "test_eci": test_eci
          }
        }
      )
    }
}