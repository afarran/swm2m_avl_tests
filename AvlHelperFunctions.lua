--[[

	AvlHelperFunctions.lua

--  Revision:     $Revision: 1 $
--  Last Updated By:  $Author: Artur Malyszewicz Sii Poland $
--  Last Updated:   $Date: 2014-04-01 09:19:40 -0400 (Tue, 01 Apr 2014) $

]]

local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local bit = require("bit")
local avlConstants =  require("AvlAgentConstants")
local lsfConstants = require("LsfConstants")

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
-- local avlStatesProperty = lsf.getProperties(avlAgentSIN,pins.avlStates)
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
  for stateIdx = 1, #avlConstants.avlStateNames do
  stateNameString = avlConstants.avlStateNames[stateIdx]
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
-- message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingEnd))
-- avlHelperFunctions.reportVerification(message, expectedValues)
-- @within AvlhelperFunctions
function avlHelperFunctions.reportVerification(message, expectedValues)

  colmsg = framework.collapseMessage(message)
  assert_equal(expectedValues.messageName, colmsg.Payload.Name, "Message name is not correct")

  if(expectedValues.gps.latitude) then                                                                                                   -- checking Latitude if that parameter has been passed
    assert_equal(expectedValues.gps.latitude*60000, tonumber(colmsg.Payload.Latitude), "Latitude value is not correct in report")     -- multiplied by 60000 for conversion from miliminutes
  end

  if(expectedValues.gps.longitude) then                                                                                                  -- checking Longitude if that parameter has been passed
    assert_equal(expectedValues.gps.longitude*60000, tonumber(colmsg.Payload.Longitude), "Longitude value is not correct in report")  -- multiplied by 60000 for conversion from miliminutes
  end

  -- normally GpsFixAge is not reported, it should be included only when fix is older than 5 seconds; this condition allows to check it in the report
  if(expectedValues.GpsFixAge) then
    assert_equal(expectedValues.GpsFixAge, tonumber(colmsg.Payload.GpsFixAge), 5, "GpsFixAge value is not correct in report")        -- if GpsFixAge is not passed in expectedValues table
  else                                                                                                                               -- it is expected not to be in the report
    assert_nil(colmsg.Payload.GpsFixAge, "GpsFixAge value not expected in the report")                                               --  otherwise a check of value is performed
  end

  assert_equal(expectedValues.currentTime,tonumber(colmsg.Payload.EventTime),20, "EventTime value is not correct in the report")    -- 20 seconds of tolerance

  if(expectedValues.SpeedLimit) then                                                                                               -- checking speed limit if that parameter has been passed
    assert_equal(expectedValues.speedLimit,tonumber(colmsg.Payload.Speedlimit), "SpeedLimit value is not correct in the report")    -- in the expectedValues table
  end

  if(expectedValues.maximumSpeed) then                                                                                              -- checking maximumSpeed if that parameter has been passed
    assert_equal(expectedValues.maximumSpeed,tonumber(colmsg.Payload.MaxSpeed), "MaximumSpeed value is not correct in the report")   -- in the expectedValues table
  end

  if(expectedValues.CurrentZoneId) then                                                                                                  -- checking CurrentZoneId if that parameter has been passed
    assert_equal(expectedValues.CurrentZoneId,tonumber(colmsg.Payload.CurrentZoneId), "CurrentZoneId value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.PreviousZoneId) then                                                                                                    -- checking PreviousZoneId if that parameter has been passed
    assert_equal(expectedValues.PreviousZoneId,tonumber(colmsg.Payload.PreviousZoneId), "PreviousZoneId value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.DwellTimeLimit) then                                                                                                    -- checking DwellTimeLimit if that parameter has been passed
    assert_equal(expectedValues.DwellTimeLimit,tonumber(colmsg.Payload.DwellTimeLimit), "DwellTimeLimit value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.totalDrivingTime) then                                                                                                    -- checking totalDrivingTime if that parameter has been passed
    assert_equal(expectedValues.totalDrivingTime,tonumber(colmsg.Payload.TotalDrivingTime), "DwellTimeLimit value is not correct in the report") -- in the expectedValues table
  end


  assert_equal(expectedValues.gps.heading, tonumber(colmsg.Payload.Heading), "Heading value is wrong in report")
  assert_equal(expectedValues.gps.speed, tonumber(colmsg.Payload.Speed), "Speed value is wrong in report")


  if(expectedValues.SM0Time) then                                                                                                 -- checking SM0Time if that parameter has been passed
    assert_equal(expectedValues.SM0Time,tonumber(colmsg.Payload.SM0Time), "SM0Time value is not correct in the report")            -- in the expectedValues table
  end

  if(expectedValues.SM0Distance) then                                                                                              -- checking SM0Distance if that parameter has been passed
    assert_equal(expectedValues.SM0Distance,tonumber(colmsg.Payload.SM0Distance), 2, "SM0Distance value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.SM1Time) then                                                                                                  -- checking SM1Time if that parameter has been passed
    assert_equal(expectedValues.SM1Time,tonumber(colmsg.Payload.SM1Time), "SM1Time value is not correct in the report")             -- in the expectedValues table
  end

  if(expectedValues.SM1Distance) then                                                                                              -- checking SM1Distance if that parameter has been passed
    assert_equal(expectedValues.SM1Distance,tonumber(colmsg.Payload.SM1Distance), 2, "SM1Distance value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.SM2Time) then                                                                                                  -- checking SM2Time if that parameter has been passed
    assert_equal(expectedValues.SM2Time,tonumber(colmsg.Payload.SM2Time), "SM2Time value is not correct in the report")             -- in the expectedValues table
  end

  if(expectedValues.SM2Distance) then                                                                                              -- checking SM2Distance if that parameter has been passed
    assert_equal(expectedValues.SM2Distance,tonumber(colmsg.Payload.SM2Distance), 2, "SM2Distance value is not correct in the report") -- in the expectedValues table
  end

  if(expectedValues.SM3Time) then                                                                                                   -- checking SM3Time if that parameter has been passed
    assert_equal(expectedValues.SM3Time,tonumber(colmsg.Payload.SM3Time), "SM3Time value is not correct in the report")              -- in the expectedValues table
  end

  if(expectedValues.SM3Distance) then                                                                                               -- checking SM3Distance if that parameter has been passed
    assert_equal(expectedValues.SM3Distance,tonumber(colmsg.Payload.SM3Distance), 2, "SM3Distance value is not correct in the report")  -- in the expectedValues table
  end

  if(expectedValues.SM4Time) then                                                                                                   -- checking SM4Time if that parameter has been passed
    assert_equal(expectedValues.SM4Time,tonumber(colmsg.Payload.SM4Time), "SM4Time value is not correct in the report")              -- in the expectedValues table
  end

  if(expectedValues.SM4Distance) then                                                                                               -- checking SM4Distance if that parameter has been passed
    assert_equal(expectedValues.SM4Distance,tonumber(colmsg.Payload.SM4Distance), 2, "SM4Distance value is not correct in the report")  -- in the expectedValues table
  end

  if(expectedValues.inputVoltage) then                                                                                                   -- checking inputVoltage if that parameter has been passed
    assert_equal(expectedValues.inputVoltage,tonumber(colmsg.Payload.InputVoltage), 2, "InputVoltage value is not correct in the report")  -- in the expectedValues table
  end


end


--- Given the names of special input functions in the table the function sets DigStatesDefBitmap
-- @tparam functionsToActivate table - table containing names of functions to be activated
-- @usage
-- avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn","SeatbeltOff"})
-- @within AvlhelperFunctions
function avlHelperFunctions.setDigStatesDefBitmap(functionsToActivate)

  local digStatesDefBitmapToSave = 0x00000000   -- value of the property to be set
   for functionsToActivateIndex, functionsToActivateValue in pairs(functionsToActivate) do
    digStatesDefBitmapToSave = bit.bor(digStatesDefBitmapToSave, bit.lshift(1, avlConstants.digStatesDefBitmap[functionsToActivateValue]))
  end

  -- applying AVL agent properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.digStatesDefBitmap, digStatesDefBitmapToSave}
                                              }
                   )


end


--- Given the names of digital output lines in the table the function sets DigOutActiveBitmap
-- @tparam functionsToActivate table - table containing names of digital output functions to be activated
-- @usage
-- avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1","FuncDigOut2"})
-- @within AvlhelperFunctions
function avlHelperFunctions.setDigOutActiveBitmap(functionsToActivate)

  local digOutActiveBitmapToSave = 0x00000000   -- value of the property to be set
   for functionsToActivateIndex, functionsToActivateValue in pairs(functionsToActivate) do
    digOutActiveBitmapToSave = bit.bor(digOutActiveBitmapToSave, bit.lshift(1, avlConstants.digOutActiveBitmap[functionsToActivateValue]))
  end

  -- applying AVL agent properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                   {avlConstants.pins.digOutActiveBitmap, digOutActiveBitmapToSave}
                                              }
                   )

end



--- Function puts terminal into stationary state
-- @usage
-- avlHelperFunctions.putTerminalIntoStationaryState()
-- @within AvlhelperFunctions
function avlHelperFunctions.putTerminalIntoStationaryState()

  local stationaryDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh


  --setting properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                    {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                    )

  -- gps settings table
  local gpsSettings={
              speed = 0,
              longitude = 0,                   -- degrees
              latitude = 0,                    -- degrees
              fixType = 3,                     -- valid fix provided
                     }

  -- set the speed to zero and wait for stationaryDebounceTime
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(stationaryDebounceTime+gpsReadInterval+6) -- 6 seconds are added to make sure terminal changes state

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)
  framework.delay(2) -- wait until property is read
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in stationary state as expected")


end



--- Function puts terminal into moving state
-- @usage
-- avlHelperFunctions.putTerminalIntoMovingState()
-- @within AvlhelperFunctions
function avlHelperFunctions.putTerminalIntoMovingState()

  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh

  --setting properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                    {avlConstants.pins.movingDebounceTime, movingDebounceTime}
                                             }
                    )

  -- gps settings table
  local gpsSettings={
              speed = stationarySpeedThld+5,   -- kmh
              longitude = 0,                   -- degrees
              latitude = 0,                    -- degrees
              fixType= 3,                      -- valid fix provided
                     }

  -- set the speed above stationarySpeedThld and wait longer than movingDebounceTime
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(movingDebounceTime+gpsReadInterval+3) -- three seconds are added to make sure terminal changes state

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)
   framework.delay(2) -- wait until property is read
  -- assertion gives the negative result if terminal does not change the moving state to true
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in moving state as expected")


end




--- Function reads terminal hardware version
-- @usage
-- avlHelperFunctions.getTerminalHardwareVersion()
-- @treturn string - "600", "700" or "800" indicating version of hardware in use
-- @within AvlhelperFunctions
function avlHelperFunctions.getTerminalHardwareVersion()

  gateway.setHighWaterMark() -- to get the newest messages
  -- sending getTerminalInfo to mobile message (MIN 1) from system service
  local getTerminalInfoMessage = {SIN = 16, MIN = 1}
 	-- local getTerminalInfoMessage = {SIN = lsfConstants.sins.system, MIN = lsfConstans.mins.getTerminalInfo}  -- TODO: change function to use this line
  gateway.submitForwardMessage(getTerminalInfoMessage)
  framework.delay(2)
  -- receiving terminalInfo messge (MIN 1) as the response to the request
  local terminalInfoMessage = gateway.getReturnMessage(framework.checkMessageType(16, 1))
  -- local terminalInfoMessage = gateway.getReturnMessage(framework.checkMessageType(lsfConstants.sins.system, lsfConstans.mins.getTerminalInfo)) -- TODO: change function to use this line
  if(terminalInfoMessage.Payload.Fields[1].Value == "IDP-6XX") then return 600
  elseif(terminalInfoMessage.Payload.Fields[1].Value == "IDP-7XX") then  return 700
  elseif(terminalInfoMessage.Payload.Fields[1].Value == "IDP-8XX") then return 800
  end


end





return function() return avlHelperFunctions end
