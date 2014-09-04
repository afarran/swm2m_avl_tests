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
-- @treturn table - table of bits of the binary representation of the decimal
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
-- @within AvlhelperFunctions
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
-- @tparam table - table containing the AvlStates property to be analysed
-- @treturn table - table with the names of states and current status
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
-- @within AvlhelperFunctions
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
-- and if all the reported fields have correct values
-- @tparam message array - from mobile message sent by agent after occurance of event
-- @tparam expectedValues table - table containing expectedValues of the fields
-- @usage
-- local gpsSettings={
--                  speed = stationarySpeedThld+1,  -- one kmh above threshold
--                  heading = 90,                   -- degrees
--                  latitude = 1,                   -- degrees
--                  longitude = 1                   -- degrees
--                   }
-- local expectedValues={
--                    gps = gpsSettings,            -- gps settings table
--                    messageName = "MovingEnd",    -- expected message name
--                    currentTime = os.time()       -- current time to check against EventTime field
--                      }
-- message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
-- avlHelperFunctions.reportVerification(message, expectedValues)
-- @within AvlhelperFunctions
function avlHelperFunctions.reportVerification(message, expectedValues)

  colmsg = framework.collapseMessage(message)
  assert_equal(expectedValues.messageName, colmsg.Payload.Name, "Message name is not correct")
  assert_equal(expectedValues.gps.longitude*60000, tonumber(colmsg.Payload.Longitude), "Longitude value is not correct in report")  -- multiplied by 60000 for conversion from miliminutes
  assert_equal(expectedValues.gps.latitude*60000, tonumber(colmsg.Payload.Latitude), "Latitude value is not correct report")        -- multiplied by 60000 for conversion from miliminutes

  -- normally GpsFixAge is not reported, it should be included only when fix is older than 5 seconds; this condition allows to check it in the report
  if(expectedValues.GpsFixAge) then
    assert_equal(expectedValues.GpsFixAge, tonumber(colmsg.Payload.GpsFixAge), 1, "GpsFixAge value is not correct in report")        -- if GpsFixAge is not passed in expectedValues table
  else                                                                                                                               -- it is expected not to be in the report
    assert_nil(colmsg.Payload.GpsFixAge, "GpsFixAge value not expected in the report")                                               --  otherwise a check of value is performed
  end

  assert_equal(expectedValues.currentTime,tonumber(colmsg.Payload.EventTime),20, "EventTime value is not correct in the report")    -- 20 seconds of tolerance

  if(expectedValues.SpeedLimit) then                                                                                               -- checking speed limit if that parameter has been passed
    assert_equal(expectedValues.speedLimit,tonumber(colmsg.Payload.Speedlimit), "SpeedLimit value is not correct in the report")    -- in the expectedValues table
  end

  if(expectedValues.maximumSpeed) then                                                                                              -- checking maximumSpeed if that parameter has been passed
    assert_equal(expectedValues.maximumSpeed,tonumber(colmsg.Payload.MaxSpeed), "MaximumSpeed value is not correct in the report")  -- in the expectedValues table
  end

  assert_equal(expectedValues.gps.heading, tonumber(colmsg.Payload.Heading), "Heading value is wrong in report")
  assert_equal(expectedValues.gps.speed, tonumber(colmsg.Payload.Speed), "Speed value is wrong in report")



end

return function() return avlHelperFunctions end
