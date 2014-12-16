-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestGeofencesModule

module("TestSensorsModule", package.seeall)

local SENSOR_SERVICE_SIN = 128
local GPS_SIN = 20
   
-- Setup and Teardown

--- suite_setup
 -- suite_setup description
 
function suite_setup()
  
  local CONTINUOUS_PIN = 15
  
  lsf.setProperties(lsfConstants.sins.position,{
                                                {CONTINUOUS_PIN, 1 },
                                               }
                    )
  framework.delay(2)
  
end

-- executed after each test suite
function suite_teardown()
  local CONTINUOUS_PIN = 15
  
  lsf.setProperties(lsfConstants.sins.position,{
                                                {CONTINUOUS_PIN, 0 },
                                               }
                    )
end

--- setup function 
  -- setup function description 
function setup()

end

-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()
  -- disable all sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {{avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor2Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor3Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor4Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor1NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor2NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor3NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor4NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor1LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor2LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor3LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor4LpmSampleInterval, 0},
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })

end

-------------------------
-- Test Cases
-------------------------


-- Test for: Periodically sending a message 
function test_PeriodicallySendingMessageContainingSensorValues()
  
    local SENSOR_REPORTING_INTERVAL = 1 -- 60 secs 
    local AVL_RESPONSE_MIN = 74
    local SENSOR_1_EXPECTED_VALUE = 2
    local DEFAULT_TIMEOUT = 5*60
    local GPS_LAT_PIN = 6;
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({GPS_SIN, GPS_LAT_PIN}), "data" }
                                             }
                    )
  
    -- set monitored value in position service
    gps.set({  speed = 1, heading = 90, latitude = 1, longitude = 1})
    
    -- waiting for periodical report 1
    local expectedMins = {AVL_RESPONSE_MIN}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, DEFAULT_TIMEOUT+5)
    
    -- set monitored value in position service to expected value
    gps.set({  speed = 1, heading = 90, latitude = SENSOR_1_EXPECTED_VALUE, longitude = 2})

    local startTime = os.time()
    
    -- waiting for periodical report 2
    receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,60+5)
    
    -- checking if timeout between two reports is ok
    local timeDiff = os.time() - startTime
    assert_equal(timeDiff , 60, 5, "Sensor Reporting Interval test failed - wrong timeout between messages")
    
    -- checking if raported value is monitored properly
    assert_equal(SENSOR_1_EXPECTED_VALUE , tonumber(receivedMessages[AVL_RESPONSE_MIN].Sensor1), 0, "Sensor Reporting Interval test failed - wrong expected value")

end

-- TC for seting single value of sensor 1
function test_SettingSensorValue()
    local SENSOR_1_EXPECTED_VALUE = 12
    local GPS_LAT_PIN = 6;
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({GPS_SIN, GPS_LAT_PIN}), "data" }
                                             }
                    )
  
    gps.set({  speed = 1, heading = 90, latitude = SENSOR_1_EXPECTED_VALUE, longitude = 2})

    framework.delay(3)
    
    --verify properties
    currentProperties = avlHelperFunctions.propertiesToTable(lsf.getProperties(GPS_SIN, {GPS_LAT_PIN,}))
    
    print(framework.dump(currentProperties))
    
    --sensor1Value = tonumber(currentProperties[1])
    
    --checking if raported value is set properly
    --assert_equal(SENSOR_1_EXPECTED_VALUE , sensor1Value , 0, "Sensor Value set - wrong expected value")
end



-------------------------

-- Check if Message is sent if sensor value goes above threshold and then goes back below it
function generic_test_Sensors_SendMessageWhenValueAboveThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueAboveThreshold using sensor " .. sensorNo)
  local SENSOR_NO = sensorNo
  
  local GPSCONV = 60000
  local INITIAL = 0.05
  local MIN = 0.03
  local MAX = 0.07
  local GPSFIX = {INITIAL = {speed = 0, heading = 0, latitude = INITIAL, longitude = 0},
                  ABOVE_MAX = {speed = 0, heading = 0, latitude = MAX + 0.01, longitude = 0},
                  MAX = {speed = 0, heading = 0, latitude = MAX, longitude = 0},
                  BELOW_MAX = {speed = 0, heading = 0, latitude = MAX - 0.01, longitude = 0},
                  ABOVE_MIN = {speed = 0, heading = 0, latitude = MIN + 0.01, longitude = 0},
                  MIN = {speed = 0, heading = 0, latitude = MIN, longitude = 0},
                  BELOW_MIN = {speed = 0, heading = 0, latitude = MIN - 0.01, longitude = 0},
                 }
  
  local SENSOR = {NAME = "Sensor"..SENSOR_NO, SIN = 20, PIN = 6, MAX = MAX * GPSCONV, MIN = MIN * GPSCONV, INITIAL = INITIAL * GPSCONV, CHANGE = 0, SAMPLE = 1, LPMSAMPLE = 3}
  SENSOR.props = {MaxStart = SENSOR.NAME .. "MaxStart",
                  MaxEnd = SENSOR.NAME .. "MaxEnd",
                  MinStart = SENSOR.NAME .. "MinStart",
                  MinEnd = SENSOR.NAME .. "MinEnd",
                  Source = SENSOR.NAME .. "Source",
                  ChangeThld = SENSOR.NAME .. "ChangeThld",
                  MinThld = SENSOR.NAME .. "MinThld",
                  MaxThld = SENSOR.NAME .. "MaxThld",
                  MaxReportInterval = SENSOR.NAME .. "MaxReportInterval",
                  NormalSampleInterval = SENSOR.NAME .. "NormalSampleInterval",}
  
  gps.set(GPSFIX.INITIAL) 
  framework.delay(GPS_READ_INTERVAL)
  
  -- configure sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    { {avlConstants.pins[SENSOR.props.Source], framework.base64Encode({SENSOR.SIN, SENSOR.PIN}), "data"},
                      {avlConstants.pins[SENSOR.props.ChangeThld], SENSOR.CHANGE},
                      {avlConstants.pins[SENSOR.props.MinThld], SENSOR.MIN},
                      {avlConstants.pins[SENSOR.props.MaxThld], SENSOR.MAX},
                      {avlConstants.pins[SENSOR.props.MaxReportInterval], 0},
                      {avlConstants.pins[SENSOR.props.NormalSampleInterval], SENSOR.SAMPLE},
                    })

  gps.set(GPSFIX.ABOVE_MAX)

  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MaxStart]}, GATEWAY_TIMEOUT)  
  local msg = receivedMessages[avlConstants.mins[SENSOR.props.MaxStart]]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(GPSFIX.ABOVE_MAX.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")

  gps.set(GPSFIX.BELOW_MAX)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MaxEnd]}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins[SENSOR.props.MaxEnd]]
  assert_not_nil(msg, 'Sensor did not send Max End message')
  assert_equal(GPSFIX.ABOVE_MAX.latitude * GPSCONV, tonumber(msg.SensorMax), 0.001, "SensorMax has incorrect value")
  assert_equal(GPSFIX.BELOW_MAX.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")
  
end

-- Check if Message is sent if sensor value goes below threshold and then goes back above it
function generic_test_Sensors_SendMessageWhenValueBelowThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueBelowThreshold using sensor " .. sensorNo)
  local SENSOR_NO = sensorNo
  
  local GPSCONV = 60000
  local INITIAL = 0.05
  local MIN = 0.03
  local MAX = 0.07
  local GPSFIX = {INITIAL = {speed = 0, heading = 0, latitude = INITIAL, longitude = 0},
                  ABOVE_MAX = {speed = 0, heading = 0, latitude = MAX + 0.01, longitude = 0},
                  MAX = {speed = 0, heading = 0, latitude = MAX, longitude = 0},
                  BELOW_MAX = {speed = 0, heading = 0, latitude = MAX - 0.01, longitude = 0},
                  ABOVE_MIN = {speed = 0, heading = 0, latitude = MIN + 0.01, longitude = 0},
                  MIN = {speed = 0, heading = 0, latitude = MIN, longitude = 0},
                  BELOW_MIN = {speed = 0, heading = 0, latitude = MIN - 0.01, longitude = 0},
                 }
  
  local SENSOR = {NAME = "Sensor"..SENSOR_NO, SIN = 20, PIN = 6, MAX = MAX * GPSCONV, MIN = MIN * GPSCONV, INITIAL = INITIAL * GPSCONV, CHANGE = 0, SAMPLE = 1, LPMSAMPLE = 3}
  SENSOR.props = {MaxStart = SENSOR.NAME .. "MaxStart",
                  MaxEnd = SENSOR.NAME .. "MaxEnd",
                  MinStart = SENSOR.NAME .. "MinStart",
                  MinEnd = SENSOR.NAME .. "MinEnd",
                  Source = SENSOR.NAME .. "Source",
                  ChangeThld = SENSOR.NAME .. "ChangeThld",
                  MinThld = SENSOR.NAME .. "MinThld",
                  MaxThld = SENSOR.NAME .. "MaxThld",
                  MaxReportInterval = SENSOR.NAME .. "MaxReportInterval",
                  NormalSampleInterval = SENSOR.NAME .. "NormalSampleInterval",}
  
  gps.set(GPSFIX.INITIAL) 
  framework.delay(GPS_READ_INTERVAL)
  
  -- configure sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    { {avlConstants.pins[SENSOR.props.Source], framework.base64Encode({SENSOR.SIN, SENSOR.PIN}), "data"},
                      {avlConstants.pins[SENSOR.props.ChangeThld], SENSOR.CHANGE},
                      {avlConstants.pins[SENSOR.props.MinThld], SENSOR.MIN},
                      {avlConstants.pins[SENSOR.props.MaxThld], SENSOR.MAX},
                      {avlConstants.pins[SENSOR.props.MaxReportInterval], 0},
                      {avlConstants.pins[SENSOR.props.NormalSampleInterval], SENSOR.SAMPLE},
                    })

  gps.set(GPSFIX.BELOW_MIN)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MinStart]}, GATEWAY_TIMEOUT)  
  local msg = receivedMessages[avlConstants.mins[SENSOR.props.MinStart]]
  assert_not_nil(msg, 'Sensor did not send Min Start message')
  assert_equal(GPSFIX.BELOW_MIN.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")

  gps.set(GPSFIX.ABOVE_MIN)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MinEnd]}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins[SENSOR.props.MinEnd]]
  assert_not_nil(msg, 'Sensor did not send Min End message')
  assert_equal(GPSFIX.BELOW_MIN.latitude * GPSCONV, tonumber(msg.SensorMin), 0.001, "SensorMin has incorrect value")
  assert_equal(GPSFIX.ABOVE_MIN.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")
  
end

-- Check if correnct Messages are sent if sensor value goes below min threshold and then jumps above max threshold
function generic_test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold using sensor " .. sensorNo)
  local SENSOR_NO = sensorNo
  
  local GPSCONV = 60000
  local INITIAL = 0.05
  local MIN = 0.03
  local MAX = 0.07
  local GPSFIX = {INITIAL = {speed = 0, heading = 0, latitude = INITIAL, longitude = 0},
                  ABOVE_MAX = {speed = 0, heading = 0, latitude = MAX + 0.01, longitude = 0},
                  MAX = {speed = 0, heading = 0, latitude = MAX, longitude = 0},
                  BELOW_MAX = {speed = 0, heading = 0, latitude = MAX - 0.01, longitude = 0},
                  ABOVE_MIN = {speed = 0, heading = 0, latitude = MIN + 0.01, longitude = 0},
                  MIN = {speed = 0, heading = 0, latitude = MIN, longitude = 0},
                  BELOW_MIN = {speed = 0, heading = 0, latitude = MIN - 0.01, longitude = 0},
                 }
  
  local SENSOR = {NAME = "Sensor"..SENSOR_NO, SIN = 20, PIN = 6, MAX = MAX * GPSCONV, MIN = MIN * GPSCONV, INITIAL = INITIAL * GPSCONV, CHANGE = 0, SAMPLE = 1, LPMSAMPLE = 3}
  SENSOR.props = {MaxStart = SENSOR.NAME .. "MaxStart",
                  MaxEnd = SENSOR.NAME .. "MaxEnd",
                  MinStart = SENSOR.NAME .. "MinStart",
                  MinEnd = SENSOR.NAME .. "MinEnd",
                  Source = SENSOR.NAME .. "Source",
                  ChangeThld = SENSOR.NAME .. "ChangeThld",
                  MinThld = SENSOR.NAME .. "MinThld",
                  MaxThld = SENSOR.NAME .. "MaxThld",
                  MaxReportInterval = SENSOR.NAME .. "MaxReportInterval",
                  NormalSampleInterval = SENSOR.NAME .. "NormalSampleInterval",}
  
  gps.set(GPSFIX.INITIAL) 
  framework.delay(GPS_READ_INTERVAL)
  
  -- configure sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    { {avlConstants.pins[SENSOR.props.Source], framework.base64Encode({SENSOR.SIN, SENSOR.PIN}), "data"},
                      {avlConstants.pins[SENSOR.props.ChangeThld], SENSOR.CHANGE},
                      {avlConstants.pins[SENSOR.props.MinThld], SENSOR.MIN},
                      {avlConstants.pins[SENSOR.props.MaxThld], SENSOR.MAX},
                      {avlConstants.pins[SENSOR.props.MaxReportInterval], 0},
                      {avlConstants.pins[SENSOR.props.NormalSampleInterval], SENSOR.SAMPLE},
                    })

  gps.set(GPSFIX.BELOW_MIN)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MinStart]}, GATEWAY_TIMEOUT)  
  local msg = receivedMessages[avlConstants.mins[SENSOR.props.MinStart]]
  assert_not_nil(msg, 'Sensor did not send Min Start message')
  assert_equal(GPSFIX.BELOW_MIN.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")

  gps.set(GPSFIX.ABOVE_MAX)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins[SENSOR.props.MinEnd], 
                                                             avlConstants.mins[SENSOR.props.MaxStart]}, GATEWAY_TIMEOUT)
  -- check if min end message was sent
  msg = receivedMessages[avlConstants.mins[SENSOR.props.MinEnd]]
  assert_not_nil(msg, 'Sensor did not send Min End message')
  assert_equal(GPSFIX.BELOW_MIN.latitude * GPSCONV, tonumber(msg.SensorMin), 0.001, "SensorMin has incorrect value")
  assert_equal(GPSFIX.ABOVE_MAX.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")
  
  msg = receivedMessages[avlConstants.mins[SENSOR.props.MaxStart]]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(GPSFIX.ABOVE_MAX.latitude * GPSCONV, tonumber(msg[SENSOR.NAME]), 0.001, SENSOR.NAME.. " has incorrect value")
  
end


function test_Sensors_SendMessageWhenValueAboveThreshold()
  return generic_test_Sensors_SendMessageWhenValueAboveThreshold(math.random(1,4))
end

function test_Sensors_SendMessageWhenValueBelowThreshold()
  return generic_test_Sensors_SendMessageWhenValueBelowThreshold(math.random(1,4))
end

function test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold()
  return generic_test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold(math.random(1,4))
end
