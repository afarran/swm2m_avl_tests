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

end

--- setup function 
  -- setup function description 
function setup()

end

-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end

-------------------------
-- Test Cases
-------------------------


-- Test for: Periodically sending a message 
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor1
function test_PeriodicallySendingMessageContainingSensor1Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor1', source = 'Sensor1Source'})
end

-- Test for: Periodically sending a message 
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor2
function test_PeriodicallySendingMessageContainingSensor2Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor2', source = 'Sensor2Source'})
end

-- Test for: Periodically sending a message 
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor3
function test_PeriodicallySendingMessageContainingSensor3Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor3', source = 'Sensor3Source'})
end

-- Test for: Periodically sending a message 
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor4
function test_PeriodicallySendingMessageContainingSensor4Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor4', source = 'Sensor4Source'})
end

-- Test for: Periodically sending a message 
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Test logic
function generic_test_PeriodicallySendingMessageContainingSensorValues(configuration)
  
    local SENSOR_REPORTING_INTERVAL = 1 -- 60 secs 
    local AVL_RESPONSE_MIN = 74
    local SENSOR_EXPECTED_VALUE = 0.02
    local DEFAULT_TIMEOUT = 5*60
    local GPS_LAT_PIN = 6;
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins[configuration.source], framework.base64Encode({GPS_SIN, GPS_LAT_PIN}), "data" }
                                             }
                    )
  
    -- set monitored value in position service
    gps.set({  speed = 1, heading = 90, latitude = 1, longitude = 1})
    
    -- waiting for periodical report 1
    local expectedMins = {AVL_RESPONSE_MIN}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, DEFAULT_TIMEOUT+5)
    
    -- set monitored value in position service to expected value
    gps.set({  speed = 1, heading = 90, latitude = SENSOR_EXPECTED_VALUE, longitude = 2})

    local startTime = os.time()
    
    -- waiting for periodical report 2
    receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,60+5)
    
    -- checking if timeout between two reports is ok
    local timeDiff = os.time() - startTime
    assert_equal(timeDiff , 60, 5, "Sensor Reporting Interval test failed - wrong timeout between messages")
    
    -- checking if raported value is monitored properly
    assert_equal(SENSOR_EXPECTED_VALUE * 60000 , tonumber(receivedMessages[AVL_RESPONSE_MIN][configuration.name]), 0, "Sensor Reporting Interval test failed - wrong expected value")

end


--Sending a message when a sensor 1 value has changed by more than set amount
function test_changeSensor1ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor1ChangeThld'
  configuration.min = 77 -- 82, 87, 92
  configuration.source = 'Sensor1Source'
  configuration.sample_interval = 'Sensor1NormalSampleInterval'
  configuration.name = 'Sensor1'
  
  generic_test_changeSensorValueByAmount(configuration)  
end

--Sending a message when a sensor 2 value has changed by more than set amount
function test_changeSensor2ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor2ChangeThld'
  configuration.min = 82
  configuration.source = 'Sensor2Source'
  configuration.sample_interval = 'Sensor2NormalSampleInterval'
  configuration.name = 'Sensor2'
  
  generic_test_changeSensorValueByAmount(configuration)  
end

--Sending a message when a sensor 3 value has changed by more than set amount
function test_changeSensor3ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor3ChangeThld'
  configuration.min = 87
  configuration.source = 'Sensor3Source'
  configuration.sample_interval = 'Sensor3NormalSampleInterval'
  configuration.name = 'Sensor3'
  
  generic_test_changeSensorValueByAmount(configuration)  
end

--Sending a message when a sensor 4 value has changed by more than set amount
function test_changeSensor4ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor4ChangeThld'
  configuration.min = 92
  configuration.source = 'Sensor4Source'
  configuration.sample_interval = 'Sensor4NormalSampleInterval'
  configuration.name = 'Sensor4'
  
  generic_test_changeSensorValueByAmount(configuration)  
end

--Sending a message when a sensor value has changed by more than set amount
function generic_test_changeSensorValueByAmount(configuration)
  
  local AVL_RESPONSE_MIN = configuration.min
  local CHANGE_THLD = 1000
  local DEFAULT_TIMEOUT = 5*60
  local GPS_LAT_PIN = 6;
  local INIT_VALUE = 0.01
  local SENSOR_REPORTING_INTERVAL = 1 -- 60sec
  local MSG_TIMEOUT = SENSOR_REPORTING_INTERVAL * 60 * 2
  local SAMPLE_INTERVAL = 1
  local AVL_REPORT_MIN = 74
  
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins[configuration.change_thld_name], CHANGE_THLD},
                        {avlConstants.pins[configuration.sample_interval], SAMPLE_INTERVAL},
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins[configuration.source], framework.base64Encode({GPS_SIN, GPS_LAT_PIN}), "data" }
                                             }
                    )
  
  -- set first value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE, longitude = 1})
    
  -- waiting for change message or report message
  local expectedMins = {AVL_RESPONSE_MIN,AVL_REPORT_MIN}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT)
  
  -- set second value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE + CHANGE_THLD/60000 , longitude = 1})
   
  -- waiting for change message
  expectedMins = {AVL_RESPONSE_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT)
  -- print(framework.dump(receivedMessages[AVL_RESPONSE_MIN]))
  
  -- checking value (whitch triggered threshold)
  assert_equal( (INIT_VALUE + CHANGE_THLD/60000) * 60000 , tonumber(receivedMessages[AVL_RESPONSE_MIN][configuration.name]), 0, "Problem with triggering change with threshold.")
 
  
end

-- TC for seting single value of gps
function test_SettingSensorValue()
    local GPS_EXPECTED_VALUE = 2
    local GPS_LAT_PIN = 6;
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({GPS_SIN, GPS_LAT_PIN}), "data" }
                                             }
                    )
  
    gps.set({  speed = 1, heading = 90, latitude = GPS_EXPECTED_VALUE, longitude = 2})
    framework.delay(3)
    
    --checking if raported value is set properly
    currentProperties = avlHelperFunctions.propertiesToTable(lsf.getProperties(GPS_SIN, {GPS_LAT_PIN,}))
    sensor1Value = tonumber(currentProperties[GPS_LAT_PIN])
    assert_equal(GPS_EXPECTED_VALUE * 60000 , sensor1Value , 0, "Problem with gps setting (a sensor source)")
end



-------------------------
function test_Sensors_SendMessageWhenValueBelowThreshold()
  
  local SENSOR_MIN = 4
  local SENSOR_INITIAL = 11

  local message = {SIN = SENSOR_SERVICE_SIN, MIN = 1}
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=SENSOR_INITIAL }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  framework.delay(SENSOR_PROCESS_TIME)
  
  -- configure sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    { {avlConstants.pins.Sensor1Source, framework.base64Encode({128, 1}), "data"},
                      {avlConstants.pins.Sensor1ChangeThld, 0},
                      {avlConstants.pins.Sensor1MinThld, 5},
                      {avlConstants.pins.Sensor1MaxThld, 15},
                      {avlConstants.pins.Sensor1MaxReportInterval, 0},
                      {avlConstants.pins.Sensor1NormalSampleInterval, 1},
                    })

	message.Fields = {{Name="TimeChanges", Elements={{Index = 0, Fields = {{Name = "time", Value = 0 }, {Name = "value", Value = SENSOR_INITIAL }}},
                                                   {Index = 1, Fields = {{Name = "time", Value = 3 }, {Name = "value", Value = SENSOR_INITIAL-1 }}},
                                                   {Index = 2, Fields = {{Name = "time", Value = 6 }, {Name = "value", Value = SENSOR_MIN }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1MinStart}, GATEWAY_TIMEOUT)  
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor1MinStart], 'Sensor did not send Min Start message')
  assert_equal(SENSOR_MIN, tonumber(receivedMessages[avlConstants.mins.Sensor1MinStart].Sensor1))
  
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=SENSOR_INITIAL }}},
                                                  }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1MinEnd}, GATEWAY_TIMEOUT)
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor1MinEnd], 'Sensor did not send Min End message')
  assert_equal(SENSOR_MIN, tonumber(receivedMessages[avlConstants.mins.Sensor1MinEnd].SensorMin))
  assert_equal(SENSOR_INITIAL, tonumber(receivedMessages[avlConstants.mins.Sensor1MinEnd].Sensor1))
  
  -- disable Sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {{avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
                    })
  
end

function test_Sensors_SendMessageWhenValueAboveThreshold()
  local SENSOR_MAX = 17
  local SENSOR_INITIAL = 11
  local message = {SIN = SENSOR_SERVICE_SIN, MIN = 1}
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=SENSOR_INITIAL }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  framework.delay(SENSOR_PROCESS_TIME)
  
  -- configure sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    { {avlConstants.pins.Sensor3Source, framework.base64Encode({128, 1}), "data"},
                      {avlConstants.pins.Sensor3ChangeThld, 0},
                      {avlConstants.pins.Sensor3MinThld, 5},
                      {avlConstants.pins.Sensor3MaxThld, 15},
                      {avlConstants.pins.Sensor3MaxReportInterval, 0},
                      {avlConstants.pins.Sensor3NormalSampleInterval, 1},
                    })

	message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=SENSOR_INITIAL }}},
                                                   {Index=1, Fields={{Name="time",Value=3 }, {Name="value",Value=SENSOR_INITIAL-1 }}},
                                                   {Index=2, Fields={{Name="time",Value=6 }, {Name="value",Value=SENSOR_MAX }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor3MaxStart}, GATEWAY_TIMEOUT)  
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor3MaxStart], 'Sensor did not send Max Start message')
  assert_equal(SENSOR_MAX, tonumber(receivedMessages[avlConstants.mins.Sensor3MaxStart].Sensor3))

  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=SENSOR_INITIAL }}},
                                                  }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor3MaxEnd}, GATEWAY_TIMEOUT)
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor3MaxEnd], 'Sensor did not send Max End message')
  assert_equal(SENSOR_MAX, tonumber(receivedMessages[avlConstants.mins.Sensor3MaxEnd].SensorMax))
  assert_equal(SENSOR_INITIAL, tonumber(receivedMessages[avlConstants.mins.Sensor3MaxEnd].Sensor3))

  -- disable Sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {{avlConstants.pins.Sensor3Source, framework.base64Encode(""), "data"},
                    })
  
end