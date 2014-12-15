-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestGeofencesModule

module("TestSensorsModule", package.seeall)

local SENSOR_SERVICE_SIN = 128

-- Setup and Teardown

--- suite_setup
 -- suite_setup description
 
function suite_setup()
  
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
    local SENSOR_SIMULATOR_SIN  = 128
    local SENSOR_SIMULATOR_PIN  = 1
    local SENSOR_SIMULATOR_DATA_MSG = 1
    local AVL_RESPONSE_MIN = 74
    local SENSOR_1_EXPECTED_VALUE = 120
    local DEFAULT_TIMEOUT = 5*60
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({SENSOR_SIMULATOR_SIN, SENSOR_SIMULATOR_PIN}), "data" }
                                             }
                    )
  
    -- sending data to Simulator with expected value after 10th second
    local message = {SIN = SENSOR_SIMULATOR_SIN, MIN = SENSOR_SIMULATOR_DATA_MSG }
    message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                  {Index=1, Fields={{Name="time",Value=5 }, {Name="value",Value=10 }}},
                                                  {Index=2, Fields={{Name="time",Value=10 }, {Name="value",Value=SENSOR_1_EXPECTED_VALUE }}},
                                                  }},}
                                          
    gateway.submitForwardMessage(message)
    gateway.setHighWaterMark()         -- to get the newest messages
    
    -- waiting for periodical report 1
    local expectedMins = {AVL_RESPONSE_MIN}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, DEFAULT_TIMEOUT+5)
    
    local startTime = os.time()
    
    -- waiting for periodical report 2
    receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,60+5)
    
    -- checking if timeout between two reports is ok
    local timeDiff = os.time() - startTime
    assert_equal(timeDiff , 60, 5, "Sensor Reporting Interval test failed - wrong timeout between messages")
    
    -- checking if raported value is set properly
    assert_equal(SENSOR_1_EXPECTED_VALUE , tonumber(receivedMessages[AVL_RESPONSE_MIN].Sensor1), 0, "Sensor Reporting Interval test failed - wrong expected value")

end

-- TC for seting single value of sensor 1
function test_SettingSensorValue()
    local SENSOR_SIMULATOR_SIN  = 128
    local SENSOR_SIMULATOR_PIN  = 1
    local SENSOR_SIMULATOR_DATA_MSG = 1
    local SENSOR_1_EXPECTED_VALUE = 120
    
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({SENSOR_SIMULATOR_SIN, SENSOR_SIMULATOR_PIN}), "data" }
                                             }
                    )
  
    -- sending data to Simulator with expected value after 10th second
    local message = {SIN = SENSOR_SIMULATOR_SIN, MIN = SENSOR_SIMULATOR_DATA_MSG }
    message.Fields = {{Name="TimeChanges", Elements={
                                                  {Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                  {Index=1, Fields={{Name="time",Value=1 }, {Name="value",Value=10 }}},
                                                  {Index=2, Fields={{Name="time",Value=3 }, {Name="value",Value=SENSOR_1_EXPECTED_VALUE }}},
                                                  }},}
   
    gateway.submitForwardMessage(message)
    gateway.setHighWaterMark()         -- to get the newest messages
    
    framework.delay(4)
    
    --verify properties
    currentProperties = avlHelperFunctions.propertiesToTable(lsf.getProperties(SENSOR_SIMULATOR_SIN, {SENSOR_SIMULATOR_PIN,}))
    
    --print(framework.dump(currentProperties))
    
    sensor1Value = tonumber(currentProperties[1])+
    
    --checking if raported value is set properly
    assert_equal(SENSOR_1_EXPECTED_VALUE , sensor1Value , 0, "Sensor Value set - wrong expected value")
end



-------------------------
function test_Sensors_SendMessageWhenValueBelowThreshold()
  
  local message = {SIN = SENSOR_SERVICE_SIN, MIN = 1}
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
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

	message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                   {Index=1, Fields={{Name="time",Value=3 }, {Name="value",Value=10 }}},
                                                   {Index=2, Fields={{Name="time",Value=6 }, {Name="value",Value=4 }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1MinStart}, GATEWAY_TIMEOUT)  
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor1MinStart], 'Sensor did not send Min Start message')
  
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                  }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1MinEnd}, GATEWAY_TIMEOUT)
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor1MinEnd], 'Sensor did not send Min End message')
  
  -- disable Sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {{avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
                    })
  
end

function test_Sensors_SendMessageWhenValueAboveThreshold()
  
  local message = {SIN = SENSOR_SERVICE_SIN, MIN = 1}
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
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

	message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                   {Index=1, Fields={{Name="time",Value=3 }, {Name="value",Value=10 }}},
                                                   {Index=2, Fields={{Name="time",Value=6 }, {Name="value",Value=17 }}},
                                                   }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor3MaxStart}, GATEWAY_TIMEOUT)  
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor3MaxStart], 'Sensor did not send Max Start message')
  
  message.Fields = {{Name="TimeChanges", Elements={{Index=0, Fields={{Name="time",Value=0 }, {Name="value",Value=11 }}},
                                                  }},}
	gateway.submitForwardMessage(message)
  
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor3MaxEnd}, GATEWAY_TIMEOUT)
  assert_not_nil(receivedMessages[avlConstants.mins.Sensor3MaxEnd], 'Sensor did not send Max End message')
  
  -- disable Sensor
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {{avlConstants.pins.Sensor3Source, framework.base64Encode(""), "data"},
                    })
  
end