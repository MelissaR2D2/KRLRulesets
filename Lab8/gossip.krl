ruleset gossip {
    meta {
      use module io.picolabs.wrangler alias wrangler
      use module io.picolabs.subscription alias subscription

      provides getSensorID, get_needed_rumors, temperatures, getPeers, getRumors, send_seen_to, getSeen, getOthersSeen, heartbeat_period, operating_state
      shares getSensorID, get_needed_rumors, temperatures, getPeers, getRumors, send_seen_to, getSeen, getOthersSeen, heartbeat_period, operating_state
    }
  
    global {

        getSensorID = function() {
            return ent:sensorID
        }
       
        temperatures = function() {
            return ent:seen.keys().reduce(function(m, k) {
                v = ent:seen{k}
                latest_rumor = ent:rumors{k + ":" + v.as("String")}
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

        update_seen = function(sensorID, seen) {
            old_seen = ent:others_seen{sensorID} || {}
            return seen.map(function(v,k) {
                return (isnull(old_seen{k}) || (old_seen{k} == v - 1)) => v | old_seen{k}
            })
            
        }

        getPeers = function() {
            return ent:peers
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
                sensorID = ent:peers{sub{"Id"}.klog("a sub")}
                seen = ent:others_seen{sensorID}.klog("what we know")
                //check if we know about any sensors it doesn't know about
                not_known = ent:seen.keys().filter(function(k){
                    ent:seen{k} && seen => not seen{k} | false
                }).map(function(unknownID) {
                    rumor = ent:rumors{unknownID + ":1"}
                    return rumor.put("Tx", sub{"Tx"}.put("Tx_host", sub{"Tx_host"}))
                }).klog("not_known")

                return needed.append(not_known).append(seen => seen.keys().reduce(function(all, key) {
                    next_num = seen{key} + 1
                    rumor = ent:rumors{key + ":" + next_num.as("String")}
                    return rumor => all.append([rumor.put("Tx", sub{"Tx"}).put("Tx_host", sub{"Tx_host"})]) | all
                }, []) | ent:rumors{ent:sensorID + ":1"}.put("Tx", sub{"Tx"}.put("Tx_host", sub{"Tx_host"})).defaultsTo([])) // if we don't know anything about what it's seen, just send our own first message
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
                return (seen => seen.keys().reduce(function(sum, key) {
                    other_num = seen{key}.klog("other num")
                    my_num = ent:seen{key}.klog("my num")
                    return sum + (my_num => (other_num > my_num => (other_num - my_num) | 0) | other_num).klog("add: ")
                }, 0) | 0).klog("value: ")
            }).klog("rankings: ")
            max_val = ranking.reduce(function(max, rank, i, arr) {
                return rank > max => rank | max
            }, 0)
            // if multiple have the same ranking, we'll randomly choose
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
    
        default_heartbeat_period = 5; //seconds
    
        my_rid = function(){meta:rid};
    

        __testing = { "queries":
        [{"name": "getSensorID"}, {"name": "get_needed_rumors"}, {"name": "temperatures"}, {"name": "getPeers"}, {"name": "getRumors"}, 
        {"name": "heartbeat_period"},
        {"name": "send_seen_to"}, {"name": "getSeen"}, {"name": "getOthersSeen"}, {"name": "operating_state"}], 
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
            ent:seen := {}
            ent:others_seen := {}
            ent:sequence_num := 0
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
            ent:seen{sensorID} := 0
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
                    "MessageID": rumor{"MessageID"},
                    "SensorID": rumor{"SensorID"},
                    "Temperature": rumor{"Temperature"},
                    "Timestamp": rumor{"Timestamp"},
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
          messageID = ent:sensorID + ":" + (ent:sequence_num + 1).as("String")
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
          ent:rumors{messageID} := {"MessageID": messageID,
          "SensorID": ent:sensorID,
          "Temperature": temp,
          "Timestamp": time,
         }
          ent:sequence_num := ent:sequence_num + 1
          ent:seen{ent:sensorID} := ent:sequence_num
        }
      }

    rule received_rumor {
        select when gossip rumor
        pre {
            messageID = event:attrs{"MessageID"}
            sensorID = event:attrs{"SensorID"}
            temp = event:attrs{"Temperature"}
            time = event:attrs{"Timestamp"}
            seqNum = messageID.split(re#:#)[2].as("Number").klog("seqNum")
            hasSeenNum = ent:seen{sensorID}.klog("hasSeenNum") || 0
        }
        if ent:gossiper_state == "running" then
            noop()
        fired {
            ent:seen{sensorID} := ((hasSeenNum == seqNum - 1) => seqNum | hasSeenNum).klog("new seen")
            ent:rumors{messageID} := {"MessageID": messageID,
            "SensorID": sensorID,
            "Temperature": temp,
            "Timestamp": time,
           }

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