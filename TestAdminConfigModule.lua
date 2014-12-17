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

function test_GetEventEnable_AllEvents()
  
	local message = {SIN = avlConstants.avlAgentSIN,  MIN = avlConstants.mins.GetEventEnable}
	message.Fields = { {Name="OperationType",Value = OPERATION_TYPE.Sending},
                     {Name="GetAllEvents", Value = 1},
                    }
	gateway.submitForwardMessage(message)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.EventEnableStatus}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[avlConstants.mins.EventEnableStatus]
  
  assert_not_nil(msg, 'EventEnableStatus message not sent')
  
  
  
  
end

