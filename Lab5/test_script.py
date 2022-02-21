import re
import requests
import time
import json
from jsonschema import validate


base_url = "http://localhost:3000/sky/"
cloud = "cloud/"
event = "event/"
sensors_rid = "manage_sensors"
sensors_eci = "ckzsu1y8p000hq3a269qt43gs"

def create_sensor(name):
    url = base_url + event + sensors_eci + "/create_sensor/" + "sensor/new_sensor"
    data = {"name": name}
    return requests.post(url, data=data).json()

def delete_sensor(name):
    url = base_url + event + sensors_eci + "/delete_sensor/" + "sensor/unneeded_sensor"
    data = {"name": name}
    return requests.post(url, data=data).json()

def read_temp(eci):
    url = base_url + event + eci + "/read_temp/" + "emitter/new_sensor_reading"
    return requests.post(url).json()

def get_sensors():
    url = base_url + cloud + sensors_eci + "/" + sensors_rid + "/sensors"
    return requests.get(url).json()

def get_profile(eci):
    url = base_url + cloud + eci + "/sensor_profile/" + "profile"
    return requests.get(url).json()

def get_temps(eci):
    url = base_url + cloud + eci + "/temperature_store/" + "temperatures"
    return requests.get(url).json()

def get_violations(eci):
    url = base_url + cloud + eci + "/temperature_store/" + "threshold_violations"
    return requests.get(url).json()

def get_inrange_temps(eci):
    url = base_url + cloud + eci + "/temperature_store/" + "inrange_temperatures"
    return requests.get(url).json()


def test_sensor_installation():
    validate(instance=get_sensors(), schema={}) # no sensors to start
    create_sensor("House Sensor 1")
    schema =  {"type" : "object",
        "properties" : {
            "House Sensor 1" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"}
                                }},
        },
    }
    validate(instance=get_sensors(), schema=schema) # test first sensor added

    create_sensor("House Sensor 1")
    validate(instance=get_sensors(), schema=schema) # test repeat sensor not added

    create_sensor("House Sensor 2")
    create_sensor("House Sensor 3")
    create_sensor("House Sensor 4")
    schema =  {"type" : "object",
        "properties" : {
            "House Sensor 1" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
            "House Sensor 2" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
            "House Sensor 3" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
            "House Sensor 4" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
        },
    }
    validate(instance=get_sensors(), schema=schema) # check multiple sensors added

def test_sensor_deletion():
    # deleting sensors
    delete_sensor("House Sensor 1")
    schema =  {"type" : "object",
        "properties" : {
            "House Sensor 2" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
            "House Sensor 3" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
            "House Sensor 4" : {"type" : "object",
                                "properties": {
                                    "eci": {"type": "string"},
                                    "test_eci": {"type": "string"}
                                }},
        },
    }
    validate(instance=get_sensors(), schema=schema) # check multiple sensors added

def test_sensor_profile():
    sensors = get_sensors()
    result = get_profile(sensors["House Sensor 1"]["test_eci"])
    schema = {'location': '', 'name': 'House Sensor 1', 'threshold': 75, 'sms': ''}
    assert (result == schema)
    


def test_sensors_work():
    eci = get_sensors()["House Sensor 1"]["test_eci"]
    temps = get_temps(eci)
    num_temps = len(temps)
    # tell emitter to emit a new temp reading
    read_temp(eci)
    new_temps = get_temps(eci)
    new_num_temps = len(new_temps)
    assert (new_num_temps == num_temps + 1)

    violations = get_violations(eci)
    inrange = get_inrange_temps(eci)
    if new_temps[-1]["temperature"] > 75:
        assert violations[-1]["timestamp"] == new_temps[-1]["timestamp"]
        assert len(inrange) == 0 or (inrange[-1]["timestamp"] != new_temps[-1]["timestamp"])
    else:
        assert inrange[-1]["timestamp"] == new_temps[-1]["timestamp"]
        assert len(violations) == 0 or (violations[-1]["timestamp"] != new_temps[-1]["timestamp"])

    

if __name__ == "__main__":
    test_sensor_installation()
    time.sleep(1) # to give all the picos time to be created and set up and have their profiles updated
    test_sensor_profile()
    test_sensors_work()
    test_sensor_deletion()