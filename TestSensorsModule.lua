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