-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestGeofencesModule

module("TestAdminConfigModule", package.seeall)

local propertiesMG =  require("PropertiesMessagesGenerator")()

-- Setup and Teardown

--- suite_setup
 -- suite_setup description

function suite_setup()


  -- reset of properties of SIN 126 and 25
	local message = {SIN = 16, MIN = 10}
	message.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=126},}},{Index=1,Fields={{Name="sin",Value=25},}}}}}
	gateway.submitForwardMessage(message)

  -- restarting AVL agent after running module
	local message = {SIN = lsfConstants.sins.system,  MIN = lsfConstants.mins.restartService}
  message.Fields = {{Name="sin",Value=avlConstants.avlAgentSIN}}
  gateway.submitForwardMessage(message)

  -- wait until service is up and running again and sends Reset message
  local expectedMins = {avlConstants.mins.reset}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.reset], "Reset message after reset of AVL not received")

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
  if (RESTORE_EVENTENABLE) then
  
    local events = {}
    local count = 1
    for k,v in pairs(initialEventStatus) do
      events[count] = {Index = count-1, Fields = {{Name="EventId", Value=k}, {Name="Enabled", Value=v} }}
      count = count + 1 
    end
    
    message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.SetEventEnable}
    message.Fields = {{Name="OperationType",Value="Sending"},
                      {Name="EventList",Elements=events},
                      {Name="OtherEvents",Value="NoChange"},{Name="SaveChanges",Value=1}}
    
    gateway.submitForwardMessage(message)
    RESTORE_EVENTENABLE = false
  end
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
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned or duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end

  if msg.DisabledEvents then
    for key, value in pairs(msg.DisabledEvents) do
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned or duplicated Event')
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
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end

  if msg.DisabledEvents then
    for key, value in pairs(msg.DisabledEvents) do
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end

  for key, value in pairs(requestedEvents) do
    assert_true(value, 'Not all requested events were received')
  end

end

function test_GetEventEnable_GetListAndRangeOfEvents_ReturnMessageContainsProperRangeAndListOfEvents()
  local START_RANGE = 12
  local END_RANGE = 32
  local EVENT_LIST = {2, 14, 6, 5, 23, 18}

  local requestedEvents = {}
  for i=START_RANGE,END_RANGE do
    requestedEvents[i] = false
  end
  for key, value in pairs(EVENT_LIST) do
    requestedEvents[value] = false
  end

	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
  message.Fields = { {Name="OperationType",Value=OPERATION_TYPE.Sending},
                     {Name="GetAllEvents",Value=0},
                     {Name="Range", Elements= { {Index=0, Fields= {{Name="From",Value=START_RANGE},
                                                                   {Name="To",Value=END_RANGE}
                                                                  }}}},
                     {Name="List",Value=framework.base64Encode(EVENT_LIST)},}
  gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  assert_not_nil(msg, 'EventEnableStatus message not received')

  if msg.EnabledEvents then
    for key, value in pairs(msg.EnabledEvents) do
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end

  if msg.DisabledEvents then
    for key, value in pairs(msg.DisabledEvents) do
      assert_not_nil(requestedEvents[tonumber(value.EventId)], 'Message returned not expected Event')
      assert_false(requestedEvents[tonumber(value.EventId)], 'Message returned duplicated Event')
      requestedEvents[tonumber(value.EventId)] = true
    end
  end

  for key, value in pairs(requestedEvents) do
    assert_true(value, 'Not all requested events were received')
  end
end

function test_SetEventEnable_EventList_GetEventMessageReturnsCorrectConfigurationOfEventEnable()
  RESTORE_EVENTENABLE = true
  local EVENT_LIST = {2, 14, 6, 5, 23, 18}

	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},}
                   
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  assert_not_nil(msg, 'EventEnableStatus Sending message not sent')
  
  initialEventStatus = {} -- used in teardown
  local expectedEventStatus = {}
  -- 0 for disabled, 1 for enabled
  
  for k, v in pairs(msg.EnabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 1
    expectedEventStatus[tonumber(v.EventId)] = 1
  end
  for k, v in pairs(msg.DisabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 0
    expectedEventStatus[tonumber(v.EventId)] = 0
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.SetEventEnable}
	message.Fields = {{Name="OperationType",Value="Sending"},
                    {Name="EventList",Elements= createEventlist(EVENT_LIST, 0)},
                    {Name="OtherEvents",Value="NoChange"},{Name="SaveChanges",Value=1}}
	
  gateway.submitForwardMessage(message)
  
  for k,v in pairs(EVENT_LIST) do 
    expectedEventStatus[v] = 0
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  for k, v in pairs(msg.EnabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 1, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be disabled')
  end
  for k, v in pairs(msg.DisabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 0, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be enabled')
  end
  
end

-- Helper needed for SetEventEnable
local function createEventlist(ids, value)
  result = {}
  for i=1, #ids do
    result[i] = {Index = i-1, Fields = {{Name="EventId", Value=ids[i]}, {Name="Enabled", Value=value} }}
  end
  return result
end

function test_SetEventEnable_EventListDisableOthers_GetEventMessageReturnsCorrectConfigurationOfEventEnable()
  RESTORE_EVENTENABLE = true
  local EVENT_LIST = {2, 14, 6, 5, 23, 18}

	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},}
                   
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  assert_not_nil(msg, 'EventEnableStatus Sending message not sent')
  
  initialEventStatus = {} -- used in teardown
  local expectedEventStatus = {}
  -- 0 for disabled, 1 for enabled
  
  for k, v in pairs(msg.EnabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 1
    expectedEventStatus[tonumber(v.EventId)] = 1
  end
  for k, v in pairs(msg.DisabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 0
    expectedEventStatus[tonumber(v.EventId)] = 0
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.SetEventEnable}
	message.Fields = {{Name="OperationType",Value="Sending"},
                    {Name="EventList",Elements= createEventlist(EVENT_LIST, 1)},
                    {Name="OtherEvents",Value="DisableAllOthers"},{Name="SaveChanges",Value=1}}
	
  gateway.submitForwardMessage(message)
  for i=1, #expectedEventStatus do
    expectedEventStatus[i] = 0
  end
  for k,v in pairs(EVENT_LIST) do 
    expectedEventStatus[v] = 1
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  for k, v in pairs(msg.EnabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 1, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be disabled')
  end
  for k, v in pairs(msg.DisabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 0, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be enabled')
  end
  
end

function test_SetEventEnable_EventListEnableOthers_GetEventMessageReturnsCorrectConfigurationOfEventEnable()
  RESTORE_EVENTENABLE = true
  local EVENT_LIST = {2, 14, 6, 5, 23, 18, 15} -- Event 15 is always disabled

	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},}
                   
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  assert_not_nil(msg, 'EventEnableStatus Sending message not sent')
  
  initialEventStatus = {} -- used in teardown
  local expectedEventStatus = {}
  -- 0 for disabled, 1 for enabled
  
  for k, v in pairs(msg.EnabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 1
    expectedEventStatus[tonumber(v.EventId)] = 1
  end
  for k, v in pairs(msg.DisabledEvents) do
    initialEventStatus[tonumber(v.EventId)] = 0
    expectedEventStatus[tonumber(v.EventId)] = 0
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.SetEventEnable}
	message.Fields = {{Name="OperationType",Value="Sending"},
                    {Name="EventList",Elements= createEventlist(EVENT_LIST, 0)},
                    {Name="OtherEvents",Value="EnableAllOthers"},{Name="SaveChanges",Value=1}}
	
  gateway.submitForwardMessage(message)
  for i=1, #expectedEventStatus do
    expectedEventStatus[i] = 1
  end
  for k,v in pairs(EVENT_LIST) do 
    expectedEventStatus[v] = 0
  end
  
  message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  for k, v in pairs(msg.EnabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 1, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be disabled')
  end
  for k, v in pairs(msg.DisabledEvents) do
    assert_equal(expectedEventStatus[tonumber(v.EventId)], 0, 0, 'Event ' .. tonumber(v.EventId) .. ' expected to be enabled')
  end
  
end

function test_SetProperties_WhenSetPropertiesMessageSent_PropertiesCorrectlySetAndResponseMessageContainsAllProperties()
  local properties = propertiesMG:getMessageWithDefaultValues()
  generic_SetProperties_WhenSetPropertiesMessageSent_PropertiesCorrectlySetAndResponseMessageContainsAllProperties(properties)
end

function test_SetProperties_WhenSetRandomPropertiesMessageSent_PropertiesCorrectlySetAndResponseMessageContainsAllProperties()
  local properties = propertiesMG:getMessageWithRandomValues()
  generic_SetProperties_WhenSetPropertiesMessageSent_PropertiesCorrectlySetAndResponseMessageContainsAllProperties(properties)
end

function generic_SetProperties_WhenSetPropertiesMessageSent_PropertiesCorrectlySetAndResponseMessageContainsAllProperties(properties)

  local message = {}
  -- preparing setProperties message
	message.SIN = avlConstants.avlAgentSIN
	message.MIN = avlConstants.mins.setProperties
  -- fields of serviceProperties message are taken from getMessageWithDefaultValues helper function
  message.Fields = properties
  message.Fields[1].Value = 0 -- not to save all properties
  gateway.setHighWaterMark()  -- to get the newest messages

  -- sending setProperties message
  gateway.submitForwardMessage(message)

  framework.delay(2)  -- wait until properties are saved
  -- requesting serviceProperties message by sending getProperties
  local message2 = {SIN = avlConstants.avlAgentSIN , MIN = avlConstants.mins.getProperties}
	gateway.submitForwardMessage(message2)

  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.serviceProperties})
  local msg = receivedMessages[avlConstants.mins.serviceProperties]
  assert_not_nil(msg, "serviceProperties message not received after getProperties request")

  -- checking values of the properties in the message sent in response
  for i = 1, #message.Fields do
    local name = message.Fields[i].Name
    local value = message.Fields[i].Value
    if msg[name] and value then
      assert_equal(tonumber(msg[name]), tonumber(value), "Property" .. name .. "has not been correctly set")
    end
  end

  -- reset of properties of SIN 126 and 25
	local message2 = {SIN = 16, MIN = 10}
	message2.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=126},}},{Index=1,Fields={{Name="sin",Value=25},}}}}}
	gateway.submitForwardMessage(message2)

end


