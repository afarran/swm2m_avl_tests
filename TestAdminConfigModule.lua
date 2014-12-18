-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestGeofencesModule

module("TestAdminConfigModule", package.seeall)

   
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

end

------------------------- 
-- Test Cases
-------------------------

local OPERATION_TYPE = {Sending = 0, Logging = 1, Persistency = 2, CellOnly = 3}

function test_GetEventEnable_AllEvents_ResponseMessageContainsAllEvents()
  -- print("Testing if GetEventEnable triggers EventEnableStatus(MIN 200), check if All Event status is reported for different OperationType (sending, logging, persistance, cellonly)")
  local NUMBEROFEVENTS = 199
  -- check sending
	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus Sending message not sent')
  local allEventsCount = 0
  if msg.EnabledEvents then allEventsCount = allEventsCount + #msg.EnabledEvents end
  if msg.DisabledEvents then allEventsCount = allEventsCount + #msg.DisabledEvents end
  assert_equal(NUMBEROFEVENTS, allEventsCount, 'Sending - Number of reported Events does not match ' .. NUMBEROFEVENTS)
  
  -- check Logging
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Logging},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus Logging message not sent')
  allEventsCount = 0
  if msg.EnabledEvents then allEventsCount = allEventsCount + #msg.EnabledEvents end
  if msg.DisabledEvents then allEventsCount = allEventsCount + #msg.DisabledEvents end
  assert_equal(NUMBEROFEVENTS, allEventsCount, 'Logging - Number of reported Events does not match ' .. NUMBEROFEVENTS)
  
  -- check Persistency
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Persistency},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus Persistency message not sent')
  allEventsCount = 0
  if msg.EnabledEvents then allEventsCount = allEventsCount + #msg.EnabledEvents end
  if msg.DisabledEvents then allEventsCount = allEventsCount + #msg.DisabledEvents end
  assert_equal(NUMBEROFEVENTS, allEventsCount, 'Persistency - Number of reported Events does not match ' .. NUMBEROFEVENTS)
  
    -- check CellOnly
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.CellOnly},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus CellOnly message not sent')
  allEventsCount = 0
  if msg.EnabledEvents then allEventsCount = allEventsCount + #msg.EnabledEvents end
  if msg.DisabledEvents then allEventsCount = allEventsCount + #msg.DisabledEvents end
  assert_equal(NUMBEROFEVENTS, allEventsCount, 'CellOnly - Number of reported Events does not match ' .. NUMBEROFEVENTS)
 
end

function test_GetEventEnable_GetRangeOfEvents_ReturnMessageContainsProperRangeOfEvents()
  local START_RANGE = 12
  local END_RANGE = 32
	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
  message.Fields = { {Name="OperationType",Value=OPERATION_TYPE.Sending},
                     {Name="GetAllEvents",Value=0},
                     {Name="Range", Elements= { {Index=0, Fields= {{Name="From",Value=START_RANGE},
                                                                   {Name="To",Value=END_RANGE}
                                                                  }}}},}
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus Sending message not sent')
  
  local requestedEvents = {}
  for i=START_RANGE,END_RANGE do
    requestedEvents[i] = false
  end
  
  if msg.EnabledEvents then
    for key, value in pairs(msg.EnabledEvents) do
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned non requested or duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end
  
  if msg.DisabledEvents then
    for key, value in pairs(msg.DisabledEvents) do
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned non requested or duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end
  
  for key, value in pairs(requestedEvents) do
    assert_true(value, 'Not all requested events were received')
  end
end

function test_GetEventEnable_GetListOfEvents_ReturnMessageContainsProperListOfEvents()
  local EVENT_LIST = {2, 14, 6, 5, 23, 18}
	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
  message.Fields = {{Name="OperationType",Value=OPERATION_TYPE.Sending},
                    {Name="GetAllEvents",Value=0},
                    {Name="List",Value=framework.base64Encode(EVENT_LIST)},}
	
  gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  assert_not_nil(msg, 'EventEnableStatus message not received')
  
  requestedEvents = {}
  for key, value in pairs(EVENT_LIST) do
    requestedEvents[value] = false
  end
  
  if msg.EnabledEvents then
    for key, value in pairs(msg.EnabledEvents) do
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned non requested or duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end
  
  if msg.DisabledEvents then
    for key, value in pairs(msg.DisabledEvents) do
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned non requested or duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end
  
  for key, value in pairs(requestedEvents) do
    assert_true(value, 'Not all requested events were received')
  end
  
  
end

