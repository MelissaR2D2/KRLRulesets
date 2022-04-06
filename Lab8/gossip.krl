ruleset gossip {
    meta {
      use module io.picolabs.wrangler alias wrangler
      use module io.picolabs.subscription alias subscription

      provides getSensorID, get_needed_rumors, temperatures, getPeers, getRumors, send_seen_to, getSeen, getOthersSeen, heartbeat_period, operating_state, violations, getViolationSequenceNum
      shares getSensorID, get_needed_rumors, temperatures, getPeers, getRumors, send_seen_to, getSeen, getOthersSeen, heartbeat_period, operating_state, violations, getViolationSequenceNum
    }
  
    global {

        getSensorID = function() {
            return ent:sensorID
        }
       
        temperatures = function() {
            return ent:seen{"temperatures"}.keys().reduce(function(m, k) {
                v = ent:seen{["temperatures", k]}.klog("V: ")
                latest_rumor = ent:rumors{k + ":temperatures:" + v.as("String")}
                return latest_rumor => m.put(k, {"Sequence Number": v, "Temperature": latest_rumor{"Temperature"}, "Timestamp": latest_rumor{"Timestamp"}}) | m
            }, {})
        }

        getRumors = function() {
            return ent:rumors
        }

        getSeen = function() {
            return ent:seen
        }

        getOthersSeen = function() {
            return ent:others_seen
        }

        getPeers = function() {
            return ent:peers
        }

        violations = function() {
            return ent:violations
        }

        getViolationSequenceNum = function() {
            return ent:violation_sequence_num
        }

        get_needed_rumors = function() {
            /* 
                take each subscription & check its "seen"
                if we have more information than it for any of its peers, 
                we add that rumor to the list of potential ones to send.
            */
            subs = subscription:established().filter(function(sub, k) {
                return sub{"Tx_role"} == "sensor"
            }).reduce(function(needed, sub) {
                sensorID = ent:peers{sub{"Id"}}.klog("a sub")
                seen = ent:others_seen{sensorID}.klog("what we know")

                //check if we know about any sensors it doesn't know about
                not_known_map = ent:seen.map(function(v,type) {
                    return v.keys().filter(function(k){
                       return ent:seen{[type, k]} && not (seen >< [type, k]) // => not seen{[type, k]} | false
                    }).map(function(unknownID) {
                        rumor = ent:rumors{unknownID + ":" + type + ":1"}
                        return rumor.put("Tx", sub{"Tx"}).put("Tx_host", sub{"Tx_host"})
                    })
                })
                // flatten map into all first rumors about sensors this sensor doesn't know about
                not_known = not_known_map.keys().reduce(function(rumors, key) {
                    return rumors.append(not_known_map{key})
                }, [])

                // now make list of all the next rumors needed
                // defaulting to our first messages if we don't know what the other sensor has seen
                next_known = seen.keys().reduce(function(rumors, key) {
                    seen_of_type = seen{key}.klog("seen of type")
                    return rumors.append(seen_of_type.keys().reduce(function(sensor_rumors, sensor) {
                        next_num = seen_of_type{sensor} + 1
                        rumor = ent:rumors{sensor + ":" + key + ":" + next_num.as("String")}
                        return rumor => sensor_rumors.append([rumor.put("Tx", sub{"Tx"}).put("Tx_host", sub{"Tx_host"})]) | sensor_rumors
                    }, []))
                }, []).klog("next known:")

                return needed.append(not_known).append(next_known)
            }, [])
            return subs
        }

        send_seen_to = function() {
            subs = subscription:established().filter(function(sub, k) {
                return sub{"Tx_role"} == "sensor"
            })
            // rank which sensor is most likely to have info we need
            // if we don't know about any of the other sensors, we'll just send to one of our subscriptions
            ranking = subs.map(function(sub){
                sensorID = ent:peers{sub{"Id"}}.klog("sensorID: ")
                seen = ent:others_seen{sensorID}.klog("others seen: ")
            
                return (seen => seen.keys().reduce(function(sum, type) {
                    type_seen = seen{type}
                    return sum + type_seen.keys().reduce(function(sum, key) {
                        other_num = seen{[type, key]}
                        my_num = ent:seen{[type, key]}
                        return sum + (my_num => (other_num > my_num => (other_num - my_num) | 0) | other_num)
                    }, 0).klog("sum for this type")
                }, 0) | 0).klog("sum for this sub")
            }).klog("rankings: ")
            max_val = ranking.reduce(function(max, rank, i, arr) {
                return rank > max => rank | max
            }, 0)
            // if multiple have the same ranking, we'll randomly choose from them
            res = ranking.reduce(function(idxs, val, i, arr) {
                return (val == max_val) => idxs.append([i]) | idxs
            }, []).map(function(i) {
                return subs[i]
            })
            return res
        }

        schedule = function(){schedule:list()};

        heartbeat_period = function(){ent:heartbeat_period};
    
        operating_state = function(){ent:gossiper_state};
    
        default_heartbeat_period = 1; //seconds
    
        my_rid = function(){meta:rid};
    

        __testing = { "queries":
        [{"name": "getSensorID"}, {"name": "temperatures"}, {"name": "violations"}, {"name": "getSeen"},
        {"name": "getRumors"}, {"name": "get_needed_rumors"}, {"name": "getPeers"},  
        {"name": "heartbeat_period"},
        {"name": "send_seen_to"}, {"name": "getOthersSeen"}, {"name": "operating_state"},  {"name": "getViolationSequenceNum"}], 
        "events":
        [ { "domain": "gossip", "name": "initialize", "attrs": [] },
          { "domain": "gossip", "name": "new_heartbeat_period", "attrs": ["heartbeat_period"] },
          { "domain": "gossip", "name": "new_state", "attrs": ["pause"] }
        ]}
    }

    rule set_period {
        select when gossip new_heartbeat_period
        schedule:remove(ent:scheduled_event)
        fired {
          ent:heartbeat_period := event:attr("heartbeat_period")
          .klog("Heartbeat period: "); // in seconds
          period = ent:heartbeat_period
          schedule gossip event "heartbeat" repeat << */#{period} * * * * * >>  attributes { } setting(scheduled_event)
          ent:scheduled_event := scheduled_event
        }
    }

    rule pause_processing {
        select when gossip new_state
        if(event:attr("pause")) then noop();
        fired {
        ent:gossiper_state := "paused";
        } else {
        ent:gossiper_state := "running";
        }
    }

    rule gate {
        select when wrangler ruleset_installed where event:attrs{"rid"} == "gossip"
        always {
            raise gossip event "initialize"
        }
    }

    rule initialize {
        select when gossip initialize
        pre {
            period = ent:heartbeat_period
               .defaultsTo(event:attr("heartbeat_period") || default_heartbeat_period)
               .klog("Initilizing heartbeat period: "); // in seconds
        }
        always {
            ent:sensorID := "sensor:" + random:uuid()
            ent:rumors := {}
            ent:seen := {"temperatures": {}, "violations": {}}
            ent:others_seen := {}
            ent:temp_sequence_num := 0
            ent:violation_sequence_num := 0
            ent:in_violation := false
            ent:violations := 0
            ent:heartbeat_period := period if ent:heartbeat_period.isnull();
            ent:gossiper_state := "running" if ent:gossiper_state.isnull();
            ent:peers := {}
            schedule gossip event "heartbeat" repeat << */#{period} * * * * * >>  attributes { } setting(scheduled_event)
            ent:scheduled_event := scheduled_event
        }
    }

    //peers contains a mapping of the subscription ID to the sensorID
    rule add_peer {
        select when gossip new_peer
        pre {
            id = event:attrs{"Id"}
            sensorID = event:attrs{"sensorID"}.klog("what sensor?")
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
            ent:peers{id} := sensorID
            ent:seen{["temperatures", sensorID]} := 0
            ent:seen{["violations", sensorID]} := 0
        }
    }

    rule do_gossip_gate {
        select when gossip heartbeat
        if ent:gossiper_state == "running" then
            noop()
        fired {
            raise gossip event "heartbeat_gated"
        }
    }

    rule do_gossip {
        select when gossip heartbeat_gated
        pre {
            which = random:integer(1).klog("which one to do: ")
            rumors = get_needed_rumors().klog("all rumors")
            rumor = (rumors.length() => rumors[random:integer(rumors.length() - 1)] | {}).klog("rumor: ")
        }
        if which && rumors.length() then 
            event:send(
                { "eci": rumor{"Tx"}.klog("sending TX"), 
                "eid": "gossip-rumor", 
                "domain": "gossip", "type": "rumor",
                "attrs": {
                    "rumor": rumor
                }
                }, host=(rumor{"Tx_host"} || meta:host))
        notfired {
            raise gossip event "do_seen"
        }
    }

    rule send_seen {
        select when gossip do_seen
        pre {
            options = send_seen_to().klog("send to: ")
            send_to = (options.length() => options[random:integer(options.length() - 1)] | {}).klog("send_to: ")
        }
        if send_to.length() then
        event:send(
            { "eci": send_to{"Tx"}, 
            "eid": "gossip-rumor", 
            "domain": "gossip", "type": "seen",
            "attrs": {
               "sensorID": ent:sensorID,
               "seen": ent:seen
            }
            }, host=(send_to{"Tx_host"} || meta:host))
    }

    // updates own current temp when new temp reading
    rule new_temp {
        select when wovyn new_temperature_reading
        pre {
          temp = event:attr("temperature")
          time = event:attr("timestamp")
          messageID = ent:sensorID + ":temperatures:" + (ent:temp_sequence_num + 1).as("String")

          violationMessageID = ent:sensorID + ":violations:" + (ent:violation_sequence_num + 1)
            message = {
                "MessageID": violationMessageID,
                "SensorID": ent:sensorID,
                "Update": -1,
                "Type": "violation"
            }
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
          ent:rumors{messageID} := {"MessageID": messageID,
          "SensorID": ent:sensorID,
          "Temperature": temp,
          "Timestamp": time,
          "Type": "temperature"
         }
          ent:temp_sequence_num := ent:temp_sequence_num + 1
          ent:seen{["temperatures", ent:sensorID]} := ent:temp_sequence_num

          // if we were in violation, assume that now we're not, so add update
          // this is dumb because the violation count will decrement for every message
          // only to increment immediately after receiving the threshold_violation if it was a violation
          // but there's no way of finding out if it was a violation otherwise
          ent:rumors := ent:in_violation => ent:rumors.put([violationMessageID], message) | ent:rumors
          ent:violations := ent:in_violation => ent:violations - 1 | ent:violations
          ent:violation_sequence_num := ent:in_violation => ent:violation_sequence_num + 1 | ent:violation_sequence_num
          ent:in_violation := false
          ent:seen{["violations", ent:sensorID]} := ent:violation_sequence_num
        }
      }

    rule threshold_violation_received {
        select when wovyn threshold_violation
        pre {
            messageID = ent:sensorID + ":violations:" + (ent:violation_sequence_num + 1)
            message = {
                "MessageID": messageID,
                "SensorID": ent:sensorID,
                "Update": 1,
                "Type": "violation"
            }
        }
        if ent:gossiper_state == "running" then 
            noop()
        fired {
           // if we weren't in violation, now we are, so add update
          ent:rumors := ent:in_violation => ent:rumors | ent:rumors.put([messageID], message)
          ent:violations := ent:in_violation => ent:violations | ent:violations + 1
          ent:violation_sequence_num := ent:in_violation => ent:violation_sequence_num | ent:violation_sequence_num + 1
          ent:in_violation := true
          ent:seen{["violations", ent:sensorID]} := ent:violation_sequence_num
        }
    }

    rule received_rumor {
        select when gossip rumor
        pre {
            // todo: make sure type is being sent
            type = event:attrs{["rumor", "Type"]}
        }
        if type == "temperature" then 
            noop()
        fired {
            raise gossip event "temp_rumor" attributes event:attrs
        } else {
            raise gossip event "violation_rumor" attributes event:attrs
        }
    }

    rule received_temp_rumor {
        select when gossip temp_rumor
        pre {
            rumor = event:attrs{"rumor"}
            messageID = rumor{"MessageID"}
            sensorID = rumor{"SensorID"}
            temp = rumor{"Temperature"}
            time = rumor{"Timestamp"}
            seqNum = messageID.split(re#:#)[3].as("Number").klog("seqNum")
            hasSeenNum = ent:seen{["temperatures", sensorID]}.klog("hasSeenNum") || 0
            new_seen = ((hasSeenNum == seqNum - 1) => seqNum | hasSeenNum).klog("new seen")
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
            ent:seen{["temperatures", sensorID]} := new_seen
            ent:rumors{messageID} := rumor
        }
    }

    rule recieved_violation_rumor {
        select when gossip violation_rumor
        pre {
            rumor = event:attrs{"rumor"}
            messageID = rumor{"MessageID"}.klog("messageID")
            sensorID = rumor{"SensorID"}
            update = rumor{"Update"}
            seqNum = messageID.split(re#:#)[3].as("Number")
            hasSeenNum = ent:seen{["violations", sensorID]} || 0
        }
        if ent:gossiper_state == "running" && (hasSeenNum == seqNum - 1) then  //only update if this is the next message in the sequence
            noop()
        fired {
            ent:seen{["violations", sensorID]} := seqNum
            ent:violations := ent:violations + update
            ent:rumors{messageID} := rumor
        }
    }

    rule received_seen {
        select when gossip seen 
        pre {
            seen = event:attrs{"seen"}
            sensorID = event:attrs{"sensorID"}
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
            ent:others_seen{sensorID} := seen
        }
    }
}