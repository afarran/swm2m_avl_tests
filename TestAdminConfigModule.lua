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

function todo_test_SetProperties_ResponseMessageContainsAllProperties()
  
  -- TODO : separate file with properties values
  -- TODO : random ranges definition and parser for generating test messages fields
	local message = {}
	message.SIN = avlConstants.avlAgentSIN
	message.MIN = avlConstants.mins.setProperties
	message.Fields = {}
	message.Fields[1] = {}
	message.Fields[1].Name = "SaveChanges"
	message.Fields[1].Value = 1
	message.Fields[2] = {}
	message.Fields[2].Name = "StationarySpeedThld"
	message.Fields[2].Value = 5
	message.Fields[3] = {}
	message.Fields[3].Name = "StationaryDebounceTime"
	message.Fields[3].Value = 60
	message.Fields[4] = {}
	message.Fields[4].Name = "MovingDebounceTime"
	message.Fields[4].Value = 10
	message.Fields[5] = {}
	message.Fields[5].Name = "DefaultSpeedLimit"
	message.Fields[5].Value = 120
	message.Fields[6] = {}
	message.Fields[6].Name = "SpeedingTimeOver"
	message.Fields[6].Value = 180
	message.Fields[7] = {}
	message.Fields[7].Name = "SpeedingTimeUnder"
	message.Fields[7].Value = 30
	message.Fields[8] = {}
	message.Fields[8].Name = "LoggingPositionsInterval"
	message.Fields[8].Value = 10
	message.Fields[9] = {}
	message.Fields[9].Name = "StationaryIntervalCell"
	message.Fields[9].Value = 1800
	message.Fields[10] = {}
	message.Fields[10].Name = "MovingIntervalCell"
	message.Fields[10].Value = 60
	message.Fields[11] = {}
	message.Fields[11].Name = "StationaryIntervalSat"
	message.Fields[11].Value = 0
	message.Fields[12] = {}
	message.Fields[12].Name = "MovingIntervalSat"
	message.Fields[12].Value = 900
	message.Fields[13] = {}
	message.Fields[13].Name = "SmReportingHour"
	message.Fields[13].Value = 0
	message.Fields[14] = {}
	message.Fields[14].Name = "OdometerDistanceIncrement"
	message.Fields[14].Value = 100
	message.Fields[15] = {}
	message.Fields[15].Name = "TurnThreshold"
	message.Fields[15].Value = 0
	message.Fields[16] = {}
	message.Fields[16].Name = "TurnDebounceTime"
	message.Fields[16].Value = 7
	message.Fields[17] = {}
	message.Fields[17].Name = "DistanceCellThld"
	message.Fields[17].Value = 0
	message.Fields[18] = {}
	message.Fields[18].Name = "DistanceSatThld"
	message.Fields[18].Value = 0
	message.Fields[19] = {}
	message.Fields[19].Name = "MaxDrivingTime"
	message.Fields[19].Value = 0
	message.Fields[20] = {}
	message.Fields[20].Name = "MinRestTime"
	message.Fields[20].Value = 480
	message.Fields[21] = {}
	message.Fields[21].Name = "AirBlockageTime"
	message.Fields[21].Value = 20
	message.Fields[22] = {}
	message.Fields[22].Name = "MaxIdlingTime"
	message.Fields[22].Value = 600
	message.Fields[23] = {}
	message.Fields[23].Name = "DefaultGeoDwellTime"
	message.Fields[23].Value = 0
	message.Fields[24] = {}
	message.Fields[24].Name = "PositionMsgInterval"
	message.Fields[24].Value = 0
	message.Fields[25] = {}
	message.Fields[25].Name = "OptionalFieldsInMsgs"
	message.Fields[25].Value = 0
	message.Fields[26] = {}
	message.Fields[26].Name = "GpsJamDebounceTime"
	message.Fields[26].Value = 10
	message.Fields[27] = {}
	message.Fields[27].Name = "CellJamDebounceTime"
	message.Fields[27].Value = 10
	message.Fields[28] = {}
	message.Fields[28].Name = "LpmTrigger"
	message.Fields[28].Value = 1
	message.Fields[29] = {}
	message.Fields[29].Name = "LpmEntryDelay"
	message.Fields[29].Value = 0
	message.Fields[30] = {}
	message.Fields[30].Name = "LpmGeoInterval"
	message.Fields[30].Value = 604800
	message.Fields[31] = {}
	message.Fields[31].Name = "LpmModemWakeupInterval"
	message.Fields[31].Value = "60_minutes"
	message.Fields[32] = {}
	message.Fields[32].Name = "TowMotionThld"
	message.Fields[32].Value = 100
	message.Fields[33] = {}
	message.Fields[33].Name = "TowStartCheckInterval"
	message.Fields[33].Value = 20
	message.Fields[34] = {}
	message.Fields[34].Name = "TowStartDebCount"
	message.Fields[34].Value = 3
	message.Fields[35] = {}
	message.Fields[35].Name = "TowStopCheckInterval"
	message.Fields[35].Value = 60
	message.Fields[36] = {}
	message.Fields[36].Name = "TowStopDebCount"
	message.Fields[36].Value = 3
	message.Fields[37] = {}
	message.Fields[37].Name = "TowInterval"
	message.Fields[37].Value = 900
	message.Fields[38] = {}
	message.Fields[38].Name = "SendMsgBitmap"
	message.Fields[38].Value = ""
	message.Fields[39] = {}
	message.Fields[39].Name = "LogMsgBitmap"
	message.Fields[39].Value = ""
	message.Fields[40] = {}
	message.Fields[40].Name = "PersistentMsgBitmap"
	message.Fields[40].Value = ""
	message.Fields[41] = {}
	message.Fields[41].Name = "CellOnlyMsgBitmap"
	message.Fields[41].Value = ""
	message.Fields[42] = {}
	message.Fields[42].Name = "DigStatesDefBitmap"
	message.Fields[42].Value = 1
	message.Fields[43] = {}
	message.Fields[43].Name = "FuncDigInp1"
	message.Fields[43].Value = "Disabled"
	message.Fields[44] = {}
	message.Fields[44].Name = "FuncDigInp2"
	message.Fields[44].Value = "Disabled"
	message.Fields[45] = {}
	message.Fields[45].Name = "FuncDigInp3"
	message.Fields[45].Value = "Disabled"
	message.Fields[46] = {}
	message.Fields[46].Name = "FuncDigInp4"
	message.Fields[46].Value = "Disabled"
	message.Fields[47] = {}
	message.Fields[47].Name = "FuncDigInp5"
	message.Fields[47].Value = "Disabled"
	message.Fields[48] = {}
	message.Fields[48].Name = "FuncDigInp6"
	message.Fields[48].Value = "Disabled"
	message.Fields[49] = {}
	message.Fields[49].Name = "FuncDigInp7"
	message.Fields[49].Value = "Disabled"
	message.Fields[50] = {}
	message.Fields[50].Name = "FuncDigInp8"
	message.Fields[50].Value = "Disabled"
	message.Fields[51] = {}
	message.Fields[51].Name = "FuncDigInp9"
	message.Fields[51].Value = "Disabled"
	message.Fields[52] = {}
	message.Fields[52].Name = "FuncDigInp10"
	message.Fields[52].Value = "Disabled"
	message.Fields[53] = {}
	message.Fields[53].Name = "FuncDigInp11"
	message.Fields[53].Value = "Disabled"
	message.Fields[54] = {}
	message.Fields[54].Name = "FuncDigInp12"
	message.Fields[54].Value = "Disabled"
	message.Fields[55] = {}
	message.Fields[55].Name = "FuncDigInp13"
	message.Fields[55].Value = "GeneralPurpose"
	message.Fields[56] = {}
	message.Fields[56].Name = "SensorReportingInterval"
	message.Fields[56].Value = 0
	message.Fields[57] = {}
	message.Fields[57].Name = "Sensor1Source"
	message.Fields[57].Value = ""
	message.Fields[58] = {}
	message.Fields[58].Name = "Sensor1NormalSampleInterval"
	message.Fields[58].Value = 0
	message.Fields[59] = {}
	message.Fields[59].Name = "Sensor1LpmSampleInterval"
	message.Fields[59].Value = 0
	message.Fields[60] = {}
	message.Fields[60].Name = "Sensor1MaxReportInterval"
	message.Fields[60].Value = 300
	message.Fields[61] = {}
	message.Fields[61].Name = "Sensor1ChangeThld"
	message.Fields[61].Value = 0
	message.Fields[62] = {}
	message.Fields[62].Name = "Sensor1MinThld"
	message.Fields[62].Value = -32768
	message.Fields[63] = {}
	message.Fields[63].Name = "Sensor1MaxThld"
	message.Fields[63].Value = 32767
	message.Fields[64] = {}
	message.Fields[64].Name = "Sensor2Source"
	message.Fields[64].Value = ""
	message.Fields[65] = {}
	message.Fields[65].Name = "Sensor2NormalSampleInterval"
	message.Fields[65].Value = 0
	message.Fields[66] = {}
	message.Fields[66].Name = "Sensor2LpmSampleInterval"
	message.Fields[66].Value = 0
	message.Fields[67] = {}
	message.Fields[67].Name = "Sensor2MaxReportInterval"
	message.Fields[67].Value = 300
	message.Fields[68] = {}
	message.Fields[68].Name = "Sensor2ChangeThld"
	message.Fields[68].Value = 0
	message.Fields[69] = {}
	message.Fields[69].Name = "Sensor2MinThld"
	message.Fields[69].Value = -32768
	message.Fields[70] = {}
	message.Fields[70].Name = "Sensor2MaxThld"
	message.Fields[70].Value = 32767
	message.Fields[71] = {}
	message.Fields[71].Name = "Sensor3Source"
	message.Fields[71].Value = ""
	message.Fields[72] = {}
	message.Fields[72].Name = "Sensor3NormalSampleInterval"
	message.Fields[72].Value = 0
	message.Fields[73] = {}
	message.Fields[73].Name = "Sensor3LpmSampleInterval"
	message.Fields[73].Value = 0
	message.Fields[74] = {}
	message.Fields[74].Name = "Sensor3MaxReportInterval"
	message.Fields[74].Value = 300
	message.Fields[75] = {}
	message.Fields[75].Name = "Sensor3ChangeThld"
	message.Fields[75].Value = 0
	message.Fields[76] = {}
	message.Fields[76].Name = "Sensor3MinThld"
	message.Fields[76].Value = -32768
	message.Fields[77] = {}
	message.Fields[77].Name = "Sensor3MaxThld"
	message.Fields[77].Value = 32767
	message.Fields[78] = {}
	message.Fields[78].Name = "Sensor4Source"
	message.Fields[78].Value = ""
	message.Fields[79] = {}
	message.Fields[79].Name = "Sensor4NormalSampleInterval"
	message.Fields[79].Value = 0
	message.Fields[80] = {}
	message.Fields[80].Name = "Sensor4LpmSampleInterval"
	message.Fields[80].Value = 0
	message.Fields[81] = {}
	message.Fields[81].Name = "Sensor4MaxReportInterval"
	message.Fields[81].Value = 300
	message.Fields[82] = {}
	message.Fields[82].Name = "Sensor4ChangeThld"
	message.Fields[82].Value = 0
	message.Fields[83] = {}
	message.Fields[83].Name = "Sensor4MinThld"
	message.Fields[83].Value = -32768
	message.Fields[84] = {}
	message.Fields[84].Name = "Sensor4MaxThld"
	message.Fields[84].Value = 32767
	message.Fields[85] = {}
	message.Fields[85].Name = "HarshBrakingThld"
	message.Fields[85].Value = 1000
	message.Fields[86] = {}
	message.Fields[86].Name = "MinHarshBrakingTime"
	message.Fields[86].Value = 1000
	message.Fields[87] = {}
	message.Fields[87].Name = "ReArmHarshBrakingTime"
	message.Fields[87].Value = 150
	message.Fields[88] = {}
	message.Fields[88].Name = "HarshAccelThld"
	message.Fields[88].Value = 1000
	message.Fields[89] = {}
	message.Fields[89].Name = "MinHarshAccelTime"
	message.Fields[89].Value = 1000
	message.Fields[90] = {}
	message.Fields[90].Name = "ReArmHarshAccelTime"
	message.Fields[90].Value = 150
	message.Fields[91] = {}
	message.Fields[91].Name = "AccidentThld"
	message.Fields[91].Value = 2000
	message.Fields[92] = {}
	message.Fields[92].Name = "MinAccidentTime"
	message.Fields[92].Value = 1000
	message.Fields[93] = {}
	message.Fields[93].Name = "SeatbeltDebounceTime"
	message.Fields[93].Value = 0
	message.Fields[94] = {}
	message.Fields[94].Name = "DigOutActiveBitmap"
	message.Fields[94].Value = 255
	message.Fields[95] = {}
	message.Fields[95].Name = "FuncDigOut1"
	message.Fields[95].Value = "None"
	message.Fields[96] = {}
	message.Fields[96].Name = "FuncDigOut2"
	message.Fields[96].Value = "None"
	message.Fields[97] = {}
	message.Fields[97].Name = "FuncDigOut3"
	message.Fields[97].Value = "None"
	message.Fields[98] = {}
	message.Fields[98].Name = "FuncDigOut4"
	message.Fields[98].Value = "None"
	message.Fields[99] = {}
	message.Fields[99].Name = "FuncDigOut5"
	message.Fields[99].Value = "None"
	message.Fields[100] = {}
	message.Fields[100].Name = "DriverIdPort"
	message.Fields[100].Value = "rs232aux"
	message.Fields[101] = {}
	message.Fields[101].Name = "DriverIdPollingInterval"
	message.Fields[101].Value = 0
	message.Fields[102] = {}
	message.Fields[102].Name = "DriverIdAutoLogoutDelay"
	message.Fields[102].Value = 0
	message.Fields[103] = {}
	message.Fields[103].Name = "AccidentAccelDataCapture"
	message.Fields[103].Value = 1
	message.Fields[104] = {}
	message.Fields[104].Name = "AccidentGpsDataCapture"
	message.Fields[104].Value = 1
	message.Fields[105] = {}
	message.Fields[105].Name = "ExternalSpeedSource"
	message.Fields[105].Value = ""
	message.Fields[106] = {}
	message.Fields[106].Name = "ExternalOdometerSource"
	message.Fields[106].Value = ""
	gateway.submitForwardMessage(message)
  
  local message2 = {SIN = 126, MIN = 6}
	gateway.submitForwardMessage(message2)

  local receivedMessages = avlHelperFunctions.matchReturnMessages({201}, 10)
  local msg = receivedMessages[201]
  
  assert_equal(tonumber(msg.AccidentAccelDataCapture), 1)
  
end