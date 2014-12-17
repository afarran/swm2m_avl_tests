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

function test_SetDriverIds()
  
  local SET_DRIVER_IDS = avlConstants.SetDriverIds
  local GET_DRIVER_IDS = avlConstants.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN 
  
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS}
	message.Fields = {{Name="DeleteAll",Value=false},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=1},{Name="DriverId",Value="AQ=="}}}}},}
	gateway.submitForwardMessage(message)
  
  framework.delay(5)
  
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS}

	gateway.submitForwardMessage(message2)
  
   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)
  
  print(framework.dump(receivedMessages[DEFINED_DRIVER_IDS_MIN]))
  
end

function test_GetDriverIds()
  
end

function testDefinedDriverIds()
  
end
