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
                                                   {Index=1, Fields={{Name="time",Value=5 }, {Name="value",Value=10 }}},
                                                   {Index=2, Fields={{Name="time",Value=10 }, {Name="value",Value=4 }}},
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