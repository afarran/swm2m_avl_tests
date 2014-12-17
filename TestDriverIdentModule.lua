-----------
-- Sensors test module
-- - contains AVL driver identification features
-- @module TestDriverIdentModule

module("TestDriverIdentModule", package.seeall)

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
function test_SendingAndReceivingDriverIds()
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
function test_DeleteAllDriverIds()
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