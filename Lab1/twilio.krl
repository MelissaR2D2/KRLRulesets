ruleset twilio.sdk {
    meta {
      configure using
        apiKey = ""
        sessionID = ""

      provides sendSMS, messages
    }
    global {
        baseURL = "https://api.twilio.com"
        uri = "/2010-04-01/Accounts/" + sessionID + "/Messages.json"
    
        messages = function(page_size = 0, send_num = 0, rec_num = 0) {
            form = {}
            form1 = (page_size > 0) => form.put("PageSize", page_size) | form
            form2 = (send_num != 0) => form1.put("From", send_num) | form1
            form3 = ((rec_num != 0) => form2.put("To", rec_num) | form2).klog("final form")

            response = http:get(baseURL + uri, auth = {"username": sessionID, "password": apiKey}, qs = form3, parseJSON = true)
            response
        }
      
      sendSMS = defaction(to, fr, body) {
        url = "https://api.twilio.com/2010-04-01/Accounts/" + sessionID + "/Messages.json"
        http:post(url, auth = {"username": sessionID, "password": apiKey}, form = {"To": to, "From": fr, "Body": body}) setting(response)
        return response
      }
    }
  }