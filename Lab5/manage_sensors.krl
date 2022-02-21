ruleset manage_sensors {
    meta {
        provides sensors, all_temps
        shares sensors, all_temps

        use module io.picolabs.wrangler alias wrangler
    }
  
    global {
        default_threshold = 75

        sensors = function() {
            return ent:sensors || {}
        }

        all_temps = function() {
            return ent:sensors.map(function(v, k) {
                return wrangler:picoQuery(v{"eci"}, "temperature_store", "temperatures")
            })
        }

        __testing = { "queries":
        [{"name": "sensors"}, {"name": "all_temps"}], 
        "events":
        [ { "domain": "sensor", "name": "new_sensor", "attrs": ["name"] },
        { "domain": "sensor", "name": "unneeded_sensor", "attrs": ["name"] }
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