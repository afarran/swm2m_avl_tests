-----------
-- Sensors test module
-- - contains AVL driver identification features
-- @module TestDriverIdentModule

module("TestDriverIdentModule", package.seeall)

DEVICE_IDS_LIMIT = 99 -- device limit of saved ids

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

-- Test of aplying new driver id.
-- Message SetDriverIds is sent.
-- Message GetDriverIds is sent.
-- Message DefinedDriversIds is received and driver id is checked and joined with correct id
function test_DriverIds_SendingOnlyOneSingleDriverId_DriverIdsCorrectlyDefined()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN 
  local DRIVER_ID = "AQEBAQEBAQ==" 
  local DRIVER_ID_INDEX = 1
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=DRIVER_ID_INDEX},{Name="DriverId",Value=DRIVER_ID}}}}},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)
  
   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN], "DefinedDriver message is not received." )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, "No Driver ids in message" )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[DRIVER_ID_INDEX], "No proper index in messsage" )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[DRIVER_ID_INDEX].DriverId, "No driver id in message" )
  
  local driver_id = receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[DRIVER_ID_INDEX].DriverId
  assert_equal(DRIVER_ID, driver_id, 0 , "Wrong DriverId : " .. driver_id .. " it should be: "..DRIVER_ID )
end

-- Test of deleting all driver ids
-- Message SetDriverIds is sent.
-- Message GetDriverIds is sent.
-- Message DefinedDriversIds is received and driver id is assumed empty
function test_DriverIds_DeleteAllDriverIds_DriverIdsAreCorrectlySetToZero()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN 
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=true},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)
  
   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  assert_nil(receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, "DriverIds collection should be empty")

end

-- Test of aplying new driver ids.
-- Message SetDriverIds is sent (many ids , limit respected)
-- Message GetDriverIds is sent.
-- Message DefinedDriversIds is received and all driver ids are checked
function test_DriverIds_setDriverIdsMessageSentWithNumberOfDriverIdsEqualToLimit_DriverIdsCorrectlyDefined()
  generic_test_BatchSendingAndReceivingDriverId(DEVICE_IDS_LIMIT-1,DEVICE_IDS_LIMIT-1)
end

-- Test of aplying new driver ids.
-- Message SetDriverIds is sent (many ids , limit is exceeded).
-- Message GetDriverIds is sent.
-- Message DefinedDriversIds is received and driver ids are checked (limit respected)
function test_DriverIds_setDriverIdsMessageSentWithNumberOfDriverIdsAboveToLimit_DriverIdsCorrectlyDefinedAndDeviceLimitIsRespected()
  generic_test_BatchSendingAndReceivingDriverId(2*(DEVICE_IDS_LIMIT-1),DEVICE_IDS_LIMIT-1)
end

-- Test sending and receiving driver ids in a batch (generic for more than one tc)
function generic_test_BatchSendingAndReceivingDriverId(limit,limit_to_check)
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN 
  local DRIVER_ID_1 = "AQEBAQEBAQ=="
  local DRIVER_ID_2 = "XQEBAQEBAQ=="
  local DRIVER_ID_3 = "ZQEBAQEBAQ=="
  local IDS_LIMIT_SET = limit
  local IDS_LIMIT_CHECK = limit_to_check
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={}},}
  
  for i=0,IDS_LIMIT_SET,1 do
    if i == 0 then
      message.Fields[2].Elements[i+1]= { Index = i, Fields = { {Name = "Index", Value = i+1}, {Name = "DriverId",Value = DRIVER_ID_1}} } 
    elseif i == IDS_LIMIT_SET  then
      message.Fields[2].Elements[i+1]= { Index = i, Fields = { {Name = "Index", Value = i+1}, {Name = "DriverId",Value = DRIVER_ID_2}} } 
    else
      message.Fields[2].Elements[i+1]= { Index = i, Fields = { {Name = "Index", Value = i+1}, {Name = "DriverId",Value = DRIVER_ID_3}} } 
    end
  
  end

	gateway.submitForwardMessage(message)
  framework.delay(5)
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)
  
   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN], "DefinedDriver message is not received." )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, "No Driver ids in message" )
  
  for i=0,IDS_LIMIT_CHECK,1 do
    local driver_id_to_check
    if i == 0 then
      driver_id_to_check = DRIVER_ID_1
    elseif i == IDS_LIMIT_SET  then
      driver_id_to_check = DRIVER_ID_2
    else
      driver_id_to_check = DRIVER_ID_3
    end
    
    assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[i+1], "No proper index in messsage" )
    assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[i+1].DriverId, "No driver id in message" )
    local driver_id = receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[i+1].DriverId
    assert_equal(driver_id_to_check, driver_id, 0 , "Wrong DriverId : " .. driver_id .. " it should be: "..driver_id_to_check )
  end
  
end