-----------
-- Sensors test module
-- - contains AVL driver identification features
-- @module TestDriverIdentModule

module("TestDriverIdentModule", package.seeall)

-- Setup and Teardown
DEVICE_IDS_LIMIT = 100 

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
  --delete all ids
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.SetDriverIds}
  message.Fields = {{Name="DeleteAll",Value=true},}
  gateway.submitForwardMessage(message)
end

-------------------------
-- Test Cases
-------------------------


function test_SetDriverId_WhenSetDriverIdMessageIsSentWithOneDriverId_SingleDriverIdCorrectlyDefined()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  local DRIVER_ID = "AQEBAQEBAQ=="
  local DRIVER_ID_INDEX = 0

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
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[1], "No proper index in message" )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[1].DriverId, "No driver id in message" )

  assert_equal( tonumber(receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[1].Index) , DRIVER_ID_INDEX, 0 , "Wrong index of driver id")

  local driver_id = receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId[1].DriverId
  assert_equal(DRIVER_ID, driver_id, 0 , "Wrong DriverId : " .. driver_id .. " it should be: "..DRIVER_ID )
  
  --TODO:check if there wasn't more than one
end

function test_DeleteAllDriverIds_WhenSetDriverIdMessageIsSentWithDeleteAllFlagSetToTrueAndNoOtherFields_AllExistingDriverIdsAreDeleted()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  local DRIVER_ID = "AQEBAQEBAQ=="
  local DRIVER_ID_INDEX = 0
  
  --adding driver id
  local fillMessage = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  fillMessage.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=DRIVER_ID_INDEX},{Name="DriverId",Value=DRIVER_ID}}}}},}
  gateway.submitForwardMessage(fillMessage)
  framework.delay(5)

  -- delete all driver ids via message
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
 
function test_DeleteSpecificDriverIds_WhenSetDriverIdsMessageIsSentWithTwoSpecificDriverIdsToDelete_SpecificDriverIdsAreDeleted()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  local DRIVER_ID = "AQEBAQEBAQ=="
  local DRIVER_ID_INDEX = 0
  
  --adding a few driver ids
  local fillMessage = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
	fillMessage.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=0},{Name="DriverId",Value="AAEBAQEBAQ=="}}},{Index=1,Fields={{Name="Index",Value=1},{Name="DriverId",Value="AQABAQEBAQ=="}}},{Index=2,Fields={{Name="Index",Value=2},{Name="DriverId",Value="AQEAAQEBAQ=="}}},{Index=3,Fields={{Name="Index",Value=3},{Name="DriverId",Value="AQEBAAEBAQ=="}}}}},}
	gateway.submitForwardMessage(fillMessage)
  framework.delay(5)

  -- delete not all driver ids
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=false},{Name="DeleteIds",Elements={{Index=0,Fields={{Name="Index",Value=1}}},{Index=1,Fields={{Name="Index",Value=2}}}}},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  
  -- get driver ids 
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)

   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check ids
  assert_equal(#receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, 2, "There is different number of driver ids.")

  found = 0
  for i, value in ipairs(receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId) do
    if tonumber(value.Index) == 0 then found = found + 1 end
    if tonumber(value.Index) == 3 then found = found + 1 end
  end
  
  assert_equal(found,2, "Wrong indexes in the result.")

end

function test_SetDriverId_WhenSetDriverIdMessageIsSentWithDuplicatedIndexes_DriverIdsAreCorectlySet()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=0},{Name="DriverId",Value="AAEBAQEBAQ=="}}},{Index=1,Fields={{Name="Index",Value=0},{Name="DriverId",Value="AQABAQEBAQ=="}}},{Index=2,Fields={{Name="Index",Value=2},{Name="DriverId",Value="AQEAAQEBAQ=="}}},{Index=3,Fields={{Name="Index",Value=2},{Name="DriverId",Value="AQEBAAEBAQ=="}}}}},}
  
  gateway.submitForwardMessage(message)
  
  -- get driver ids 
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)
  
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  -- check ids
  assert_equal(#receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, 2, "There is different number of driver ids.")

  found = 0
  for i, value in ipairs(receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId) do
    if tonumber(value.Index) == 0 and value.DriverId == "AQABAQEBAQ==" then found = found + 1 end
    if tonumber(value.Index) == 2 and value.DriverId == "AQEBAAEBAQ==" then found = found + 1 end
  end
  
  assert_equal(found,2, "Wrong ids in the result.")
  
end

function test_DeleteNonExistentDriverId_WhenSetDriverIdsMessageIsSentWithOneNonExistentDriverIdToDelete_ExistingDriverIdsAreNotDeleted()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  
  --adding a few driver ids
  local fillMessage = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
	fillMessage.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=0},{Name="DriverId",Value="AAEBAQEBAQ=="}}},{Index=1,Fields={{Name="Index",Value=1},{Name="DriverId",Value="AQABAQEBAQ=="}}},{Index=2,Fields={{Name="Index",Value=2},{Name="DriverId",Value="AQEAAQEBAQ=="}}},{Index=3,Fields={{Name="Index",Value=3},{Name="DriverId",Value="AQEBAAEBAQ=="}}}}},}
	gateway.submitForwardMessage(fillMessage)
  framework.delay(5)

  -- delete not all driver ids
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=false},{Name="DeleteIds",Elements={{Index=0,Fields={{Name="Index",Value=5}}}}},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  
  -- get driver ids 
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)

   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check ids
  assert_equal(#receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, 4, "There is different number of driver ids.")

end

function test_DeleteDriverIds_WhenSetDriverIdsMessageContainsOptionalEmptyDeleteIdsField_ExistingDriverIdsAreNotDeleted()
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  
  --adding a few driver ids
  local fillMessage = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
	fillMessage.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=0},{Name="DriverId",Value="AAEBAQEBAQ=="}}},{Index=1,Fields={{Name="Index",Value=1},{Name="DriverId",Value="AQABAQEBAQ=="}}},{Index=2,Fields={{Name="Index",Value=2},{Name="DriverId",Value="AQEAAQEBAQ=="}}},{Index=3,Fields={{Name="Index",Value=3},{Name="DriverId",Value="AQEBAAEBAQ=="}}}}},}
	gateway.submitForwardMessage(fillMessage)
  framework.delay(5)

  -- pass DeleteIds field emtpy
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=false},{Name="DeleteIds",Elements={}},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  
  -- get driver ids 
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)

   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check ids
  assert_equal(#receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, 4, "There is different number of driver ids.")

end

function test_setDriverIds_WhenSomeDriverIdsAreAlreadyFindAndMessageWithNewIndexIsSend_NewDriverIdIsDefined()
  
  local DRIVER_ID_INDEX = 4
  local DRIVER_ID = "AQEBAQEBAQ=="
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  local START_LEN = 4
  
  generic_test_BatchSendingAndReceivingDriverId(START_LEN)
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=false},{Name="UpdateDriverIds",Elements={{Index=0,Fields={{Name="Index",Value=DRIVER_ID_INDEX},{Name="DriverId",Value=DRIVER_ID}}}}},}
  gateway.submitForwardMessage(message)
  framework.delay(5)
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)

   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN], "DefinedDriver message is not received." )
  assert_not_nil( receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, "No Driver ids in message" )
  assert_equal(#receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId, START_LEN + 1,0,"New driver id not added")
  
  --TODO: check not only length but value as well
  
end

function test_DriverIds_setDriverIdsMessageSentWithNumberOfDriverIdsEqualToLimit_DriverIdsCorrectlyDefined()
  generic_test_BatchSendingAndReceivingDriverId(DEVICE_IDS_LIMIT)
end

function test_DriverIds_setDriverIdsMessageSentWithNumberOfDriverIdsBelowLimit_DriverIdsCorrectlyDefined()
  generic_test_BatchSendingAndReceivingDriverId(DEVICE_IDS_LIMIT-1)
end


function test_DriverIds_setDriverIdsMessageSentWithNumberOfDriverIdsAboveToLimit_DriverIdsCorrectlyDefinedAndDeviceLimitIsRespected()
  generic_test_BatchSendingAndReceivingDriverId(DEVICE_IDS_LIMIT+1)
end

-- Test sending and receiving driver ids in a batch (generic for more than one tc)
function generic_test_BatchSendingAndReceivingDriverId(limit)
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  local driver_ids = { "AQEBAQEBAQ==" ,"XQEBAQEBAQ==" , "ZQEBAQEBAQ==" }
  local driver_ids_choosen = {}
  local IDS_LIMIT_SET = limit
  
  -- set driver id via message
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=true},{Name="UpdateDriverIds",Elements={}},}

  for i=0,IDS_LIMIT_SET-1,1 do
      driver_ids_choosen[i] = driver_ids[lunatest.random_int(1,#driver_ids)] -- TODO: random
      --print ("Random: i:"..i..driver_ids_choosen[i])
      table.insert(
        message.Fields[2].Elements , 
        { Index = i, Fields = { {Name = "Index", Value = i}, {Name = "DriverId",Value = driver_ids_choosen[i]}} }
      )
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

  local checked_items = 0

  for i, value in ipairs(receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId) do
    assert_not_nil( value, "No proper value in messsage" )
    assert_not_nil( value.DriverId, "No driver id in message" )
    local driver_id = value.DriverId
    local driver_id_to_check = driver_ids_choosen[tonumber(value.Index)] 
    assert_equal(driver_id_to_check, driver_id, 0 , "Wrong DriverId : " .. driver_id .. " it should be: "..driver_id_to_check )
    checked_items = checked_items + 1
  end
  
  assert_lte(limit, checked_items, 0 , "Received driver ids cannot be more than ".. limit)
  
end


function test_DeleteIds_When100DriverIdsAreDefinedAnd99AreDeletedInSetDriverIdsMessage_OnlyDriverIdOneLeft()
  generic_test_BatchDeleting(100,99)
end

function test_DeleteIds_When100DriverIdsAreDefinedAnd100AreDeletedInSetDriverIdsMessage_NoneDriverIdLeft()
  generic_test_BatchDeleting(100,100)
end

-- This raises error : No such file or directory.
--function test_DeleteIds_When100DriverIdsAreDefinedAnd101AreDeletedInSetDriverIdsMessage_NoneDriverIdLeft()
--  generic_test_BatchDeleting(100,101)
--end

function generic_test_BatchDeleting(limit,limit_to_delete)
  
  local SET_DRIVER_IDS_MIN = avlConstants.mins.SetDriverIds
  local GET_DRIVER_IDS_MIN = avlConstants.mins.GetDriverIds
  local DEFINED_DRIVER_IDS_MIN = avlConstants.mins.DefindedDriverIds
  local AVL_SIN = avlConstants.avlAgentSIN
  
  generic_test_BatchSendingAndReceivingDriverId(limit)
  
  local message = {SIN = AVL_SIN, MIN = SET_DRIVER_IDS_MIN}
  message.Fields = {{Name="DeleteAll",Value=false},{Name="DeleteIds",Elements={}},}
  
  for i=0,limit_to_delete-1,1 do
    table.insert(message.Fields[2].Elements,{Index=i,Fields={{Name="Index",Value=i}}})
  end
 
  gateway.submitForwardMessage(message)
  framework.delay(5)
  
  local message2 = {SIN = AVL_SIN, MIN = GET_DRIVER_IDS_MIN}
	gateway.submitForwardMessage(message2)

   -- wait for event
  expectedMins = {DEFINED_DRIVER_IDS_MIN}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  local receivedMessagesCount = 0

  if receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId ~= nil then
    receivedMessagesCount = #receivedMessages[DEFINED_DRIVER_IDS_MIN].DriverId
  end

  assert_equal( receivedMessagesCount, (limit-limit_to_delete), "Wrong batch delete." )
  
end