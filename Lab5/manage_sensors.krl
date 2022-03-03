ruleset manage_sensors {
    meta {
        provides sensors, all_temps
        shares sensors, all_temps

        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
    }
  
    global {
        default_threshold = 75

        sensors = function() {
            return subscription:established().filter(function(sub, k) {
                return sub{"Tx_role"} == "sensor"
            })
        }

        all_temps = function() {
            return subscription:established().filter(function(sub, k) {
                return sub{"Tx_role"} == "sensor"
            }).map(function(sub, k) {
                peerChannel = sub{"Tx"}
                peerHost = (sub{"Tx_host"} || meta:host)
                name = wrangler:picoQuery(peerChannel, "sensor_profile", "profile", null, peerHost){"name"}
                result = wrangler:picoQuery(peerChannel, "temperature_store", "temperatures", null, peerHost)
                return {}.put("name", name).put("temps", result)
            })
        }

        __testing = { "queries":
        [{"name": "sensors"}, {"name": "all_temps"}], 
        "events":
        [ { "domain": "sensor", "name": "new_sensor", "attrs": ["name"] },
        { "domain": "sensor", "name": "unneeded_sensor", "attrs": ["name"] },
        {"domain": "sensor", "name": "introduction", "attrs": ["wellKnown", "Tx_host"]}
        ]}
    }

    rule sensor_installation {
        select when sensor new_sensor where event:attrs >< "name"
        pre {
            name = event:attrs{"name"}.klog("THE BIG NAME")
            exists = ent:sensors && ent:sensors >< name
        }
        if exists then
            send_directive("already exists", {"name": name})
        notfired {
            raise wrangler event "new_child_request"
                attributes {"name": name}
            ent:sensors{name} := {"eci": null, "test_eci": null}
        }
    }

    rule ruleset_installation {
        select when wrangler child_initialized
        pre {
            eci = event:attr("eci")
            name = event:attr("name").klog("THE SECOND")
        }
        if name.klog("found name")
            then event:send(
                { "eci": eci, 
                    "eid": "install-ruleset", 
                    "domain": "wrangler", "type": "install_ruleset_request",
                    "attrs": {
                    "absoluteURL": "file:///Users/student/Documents/College/Winter 2022/CS462/Lab5/",
                    "rid": "sensor_setup",
                    "config": {},
                    "name": name
                    }
                }
            )
    }


    rule createChildSubscription {
      select when sensor install_finished
      always {
        raise wrangler event "subscription" attributes {
            "name":"sensor_sub", 
            "Rx_role":"manager",
            "Tx_role":"sensor",          
            "wellKnown_Tx": event:attr("wellKnown"){"id"}
          }
      }
    }

   rule introduceSensor {
       select when sensor introduction
       if event:attr("wellKnown") then
        noop()
       fired {
        raise wrangler event "subscription" attributes {
            "name":"sensor_sub",
            "Rx_role":"manager",
            "Tx_role":"sensor",
            "Tx_host": event:attrs{"Tx_host"} || meta:host,     
            "wellKnown_Tx": event:attr("wellKnown")
          }
      }
   }
    

    rule profile_update {
        select when sensor install_finished
        pre {
            eci = event:attrs{"eci"}
            test_eci = event:attrs{"test_eci"}
            name = event:attrs{"name"}.klog("PROFILE UPDATE FIRED")
        }
        event:send(
            { "eci": eci, 
            "eid": "update_profile", 
            "domain": "sensor", "type": "profile_updated",
            "attrs": {
                "location": "", 
                "name": name, 
                "threshold": default_threshold, 
                "sms": ""
            }
          }
        )
        fired {
            ent:sensors{name} := {"eci": eci, "test_eci": test_eci}
        }
    }

    
    rule sensor_uninstall {
        select when sensor unneeded_sensor
        pre {
            name = event:attrs{"name"}
            exists = ent:sensors >< name
            eci_to_delete = ent:sensors{[name,"eci"]}
        }
        if exists && eci_to_delete then
        send_directive("deleting_sensor", {"name":name})
        fired {
            raise wrangler event "child_deletion_request" attributes {"eci": eci_to_delete}
            ent:sensors := ent:sensors.delete(name)
        }
    }
}