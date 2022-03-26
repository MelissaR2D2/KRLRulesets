ruleset subscriptions {

  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    use module gossip
  }

  rule introduceSensor {
    select when sensor introduction
    if event:attr("wellKnown") then
     noop()
    fired {
     raise wrangler event "subscription" attributes {
         "name":"sensor_sub",
         "Rx_role":"sensor",
         "Tx_role":"sensor",
         "Tx_host": event:attrs{"Tx_host"} || meta:host,     
         "wellKnown_Tx": event:attr("wellKnown"),
         "sensorID": gossip:getSensorID()
       }
    }
  }

  rule acceptSensorSubscriptions {
    select when wrangler inbound_pending_subscription_added
    //telling the other sensor our sensorID
    event:send(
      { "eci": event:attrs{"Tx"}, 
          "eid": "send-sensorID", 
          "domain": "gossip", "type": "new_peer",
          "attrs": {
          "sensorID": gossip:getSensorID().klog("which sensor is this?"),
          "Id": event:attrs{"Id"}
          }
      })
    always {
      raise wrangler event "pending_subscription_approval" attributes event:attrs; 
      raise gossip event "new_peer" attributes event:attrs;
    }
  }
}