
import React, {useState, useEffect} from 'react'
import axios from 'axios'
import './App.css';

const Profile = (props) => {
  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [threshold, setThreshold] = useState(0);
  const [sms, setSMS] = useState("");

  const submit = async () => {
    try {
      let url = 'http://localhost:3000/sky/event/ckyqcvvst00isada25bv83fgt/1000/sensor/profile_updated'
      let form = new URLSearchParams()
      form.append('name', name)
      form.append('location', location)
      form.append('threshold', threshold)
      form.append('sms', sms)
      const result = await axios.post(url, form)
    } catch (err) {
      console.log(err)
    }

  }

  const getProfile = async () => {
    try {
      let url = 'http://localhost:3000/sky/cloud/ckyqcvvst00isada25bv83fgt/sensor_profile/profile'
      const result = await axios(url);
      setName(result.data.name)
      setLocation(result.data.location)
      setThreshold(result.data.threshold)
      setSMS(result.data.sms)
    } catch (err) {
      console.log(err)
    }
  }

  useEffect(() => {
    getProfile()
  }, [])

  return (
    <div className='Profile'>
      <h2>Profile:</h2>
      <EditField label="Sensor Name: " value={name} onChange={(value) => {
                setName(value)}}></EditField>
      <EditField label="Location: " value={location} onChange={(value) => {
                setLocation(value)}}></EditField>
      <EditField label="Threshold: " value={threshold} onChange={(value) => {
                setThreshold(value)}}></EditField>
      <EditField label="SMS Notifications: " value={sms} onChange={(value) => {
                setSMS(value)}}></EditField>
      <button onClick={submit}>Submit</button>
    </div>
  )

}

const EditField = (props) => {
    return (
      <div className='Profile-Row'>
      <p>{props.label}</p>
      <input
        className="value"
        onChange={(event) => props.onChange(event.target.value)}
        value={props.value}
      />
    </div>
    )
}

class Temp extends React.Component {
  render() {
    return (
      <div className="temp-list">
        <li style={this.props.temp.violation ? {color: "red"} : {}}>{this.props.temp.temperature}°F at {this.props.temp.timestamp}</li>
      </div>
    );
  }
}

class TempList extends React.Component {
  render() {
    return (
      <div className="temp-list">
        <ul style={{"list-style-type": "none"}}>
        {this.props.list.reverse().map((i) => {
          return (
            <Temp temp={i}></Temp>
          )
          })}
        </ul>
      </div>
    );
  }
}


function App() {
  const [temps, setTemps] = useState([{"timestamp": 13432, "temperature": 85.1}])
  const [violations, setViolations] = useState([{"timestamp": 13432, "temperature": 85.1}])
  const [currTemp, setCurrTemp] = useState({"timestamp": 243543, "temperature": 75})

  const getProfile = () => {

  }

  const getTemps = async () => {
    try {
      let url = 'http://localhost:3000/sky/cloud/ckyqcvvst00isada25bv83fgt/temperature_store/temperatures'
      const result = await axios(url);
      setTemps(result.data.slice(0, result.data.length-1))
      setCurrTemp(result.data[result.data.length - 1])
    } catch (err) {
      console.log(err)
    }
  }

  const getViolations = async () => {
    try {
      let url = 'http://localhost:3000/sky/cloud/ckyqcvvst00isada25bv83fgt/temperature_store/threshold_violations'
      const result = await axios(url);
      setViolations(result.data)
    } catch (err) {
      console.log(err)
    }
  }

  

  useEffect(() => {
    getTemps()
    getViolations()
  }, [])

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          Temperature Tracker
        </h1>
      </header>
      <div>
        <Profile></Profile>
      </div>
      <h1>Current Temperature:</h1>
      <h1>{currTemp.temperature}°F</h1>
      <h1>Past Temperatures: </h1>
      <TempList list={temps.map(i => (violations.filter(j => i.timestamp === j.timestamp).length > 0) ? {...i, "violation": true} : {...i, "violation": false})}
      ></TempList>
    </div>
  );
}

export default App;
