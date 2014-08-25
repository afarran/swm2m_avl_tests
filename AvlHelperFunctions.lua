--[[

	AvlHelperFunctions.lua

--  Revision:     $Revision: 1 $
--  Last Updated By:  $Author: Artur Malyszewicz Sii Poland $
--  Last Updated:   $Date: 2014-04-01 09:19:40 -0400 (Tue, 01 Apr 2014) $

]]

local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()

local avlHelperFunctions = {}



--- Converts decimal value to the table of its binary representation
-- it always returns 32 bits
-- @tparam decimal number num value to be converted
-- @return table of bits of the binary representation of the decimal
-- @usage
-- local x = 4
-- print(avlHelperFunctions.decimalToBinary(x))
-- -- this prints:
-- {
--     1 = 0
--     2 = 0
--     3 = 1
--     .
--     .
--     .
--     32 = 0
-- }
-- @within TestHelpers
function avlHelperFunctions.decimalToBinary(num)

  local tableOfBits={}
  while num>0 do
    rest=math.fmod(num,2)
    tableOfBits[#tableOfBits+1]=rest
    num=(num-rest)/2
  end
  for i=1,32 do -- tableOfBits should always be 32 bits long
    if(tableOfBits[i]== nil) then tableOfBits[i] = 0 end
  end

  return tableOfBits

end


--- Given the AvlStates property (PIN 41) array { PIN = "41, value="x"} this
-- function returns the table of the states with current status
-- @param table containing the AvlStates property to be analysed
-- @return table string with the names of states and current status
-- @usage
-- local avlStatesProperty = lsf.getProperties(avlAgentSIN,avlPropertiesPINs.avlStates)
-- print(avlHelperFunctions.stateDetector(avlStatesProperty))
-- -- this prints for example:
-- {
--   onMainPower = true
--   Geodwelling = false
--   Towing = false
--   CellJammed = false
--   SM1Active = false
--   Reserved = false
--   Tamper = false
--   SM4Active = false
--   SM3Active = false
--   Speeding = false
--   Moving = true
--   SeatbeltViolation = false
--   InLPM = false
--   IgnitionON = false
--   SM2Active = false
--   EngineIdling = false
--   AirCommunicationBlocked = false
--   GPSJammed = false
-- }
-- @within TestHelpers
function avlHelperFunctions.stateDetector(avlStatesArray)

  avlStates = {}
  local avlStatesPropertyBinary =  avlHelperFunctions.decimalToBinary(tonumber(avlStatesArray[1].value))
  for stateIdx = 1, #avlAgentCons.avlStateNames do
  stateNameString = avlAgentCons.avlStateNames[stateIdx]
  avlStates[stateNameString] = (avlStatesPropertyBinary[stateIdx]==1)
  end
  return avlStates
end


--- Given the report message and the expected name of the report
-- this function verifies if the report is complete according to specification
-- and has correct name
-- @param message - from mobile message sent by agent after occurance of event
-- @tparam name string - from mobile message sent by agent after occurance of event
-- @usage
-- Message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
-- avlHelperFunctions.reportVerification(message, "MovingStart")
-- @within TestHelpers
function avlHelperFunctions.reportVerification(message, messageName, speed, heading, longitude, latitude, eventTime)

  colmsg = framework.collapseMessage(message) -- message collapsed for easier usege
  -- print(framework.dump(message))
  -- print(framework.dump(colmsg))
  -- verification of the fields of report message)

  assert_true(colmsg.Payload.Name == messageName, "Message name is wrong")
  assert_true(tonumber(colmsg.Payload.Heading) == heading, "Heading value is wrong in report")
  --assert_true(colmsg.Payload.GpsFixAge, "GpsFixAge value is missing in report") -- TO DO
  assert_true(tonumber((colmsg.Payload.Longitude)/60000) == longitude, "Longitude value is wrong in report")
  assert_true(tonumber((colmsg.Payload.Latitude)/60000) == latitude, "Latitude value is wrong rteport")
  assert_true(tonumber(colmsg.Payload.Speed) == speed, "Speed value is wrong in report")
  --assert_true(colmsg.Payload.EventTime, "EventTime value is missing in report") -- TO DO
end


return function() return avlHelperFunctions end
