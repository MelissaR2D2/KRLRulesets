ruleset manage_sensors {
    meta {
        provides sensors, all_temps, temp_reports, all_temp_reports, num_reports
        shares sensors, all_temps, temp_reports, all_temp_reports, num_reports

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

        all_temp_reports = function() {
            return ent:reports
        }

        num_reports = function() {
            return ent:num_reports
        }

        temp_reports = function() {
            num_reports = ent:num_reports || 0
            max_reports = ((5 > num_reports) => num_reports | 5).klog("MAX_REPORTS")
            return (max_reports == 0) => {} | (num_reports - max_reports).range(ent:num_reports).reduce(function(m, i) {
                key = "report#" + i.as("String")
                return ent:reports{key} => m.put(key, ent:reports{key}) | m
            }, {})
        }


        __testing = { "queries":
        [{"name": "sensors"}, {"name": "all_temps"}, {"name": "temp_reports"}, {"name": "num_reports"}], 
        "events":
        [ { "domain": "sensor", "name": "new_sensor", "attrs": ["name"] },
        { "domain": "sensor", "name": "unneeded_sensor", "attrs": ["name"] },
        {"domain": "sensor", "name": "introduction", "attrs": ["wellKnown", "Tx_host"]},
        {"domain": "report", "name": "new_report"}
        ]}
    }

    rule request_report {
        select when report new_report
        foreach subscription:established().filter(function(sub, k) {
            return sub{"Tx_role"} == "sensor"
          }) setting (sensor)
          pre {
            num = ent:num_reports || 0
            reportID = "report#" + num.as("String")
          }
          event:send(
              { "eci": sensor{"Tx"}, 
              "eid": "sensor report", 
              "domain": "sensor", "type": "report_request",
              "attrs": {
                  "Id": sensor{"Id"},
                  "rci": reportID
              }
            }, host=(sensor{"Tx_host"} || meta:host))
          always {
            ent:num_sensors := subscription:established().filter(function(sub, k) {
                return sub{"Tx_role"} == "sensor"
              }).length() on final
            ent:num_reports := ent:num_reports => ent:num_reports + 1 | 1 on final
            ent:reports := ent:reports => ent:reports.put({}).put([reportID, "temperature_sensors"], ent:num_sensors).put([reportID, "responding"], 0).put([reportID, "temperatures"], []) | 
                                                   {}.put([reportID, "temperature_sensors"], ent:num_sensors).put([reportID, "responding"], 0).put([reportID, "temperatures"], []) on final
          }
    }

    rule get_report {
        select when sensor report_result
        pre {
            rci = event:attrs{"rci"}
            report = ent:reports{rci}.klog("report") 
            temp = event:attrs{"report"}.klog("temp")
        }
        if report{"responding"} + 1 == report{"temperature_sensors"} then
            noop()
        always {
            ent:reports{[rci, "responding"]} := ent:reports{[rci, "responding"]} + 1
            ent:reports{[rci, "temperatures"]} := ent:reports{[rci, "temperatures"]}.append(temp)
        }
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