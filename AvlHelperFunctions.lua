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

  -- this is only for LongDriving reports
  if(expectedValues.currentTimeLongDriving) then
    assert_equal(expectedValues.currentTimeLongDriving,tonumber(colmsg.Payload.EventTime), 200, "EventTime in LongDriving report is not correct ")    -- 100 seconds of tolerance
  end


  if(expectedValues.currentTime) then
  assert_equal(expectedValues.currentTime,tonumber(colmsg.Payload.EventTime),25, "EventTime value is not correct in the report")    -- 20 seconds of tolerance
  end


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
    assert_equal(expectedValues.totalDrivingTime,tonumber(colmsg.Payload.TotalDrivingTime),1, "TotalDrivingTime value is not correct in the report") -- in the expectedValues table
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
function avlHelperFunctions.putTerminalIntoStationaryState(tries)

  tries = tries or 10
  local STATIONARY_DEBOUNCE_TIME = 1      -- seconds
  local STATIONARY_SPEED_THLD = 5         -- kmh

  gateway.setHighWaterMark()

  local gpsSettings={
                       speed = 0,
                       longitude = 0,                   -- degrees
                       latitude = 0,                    -- degrees
                       fixType = 3,                     -- valid fix provided
                       simulateLinearMotion = false,   -- terminal not moving
                     }
  gps.set(gpsSettings)

  -- get avlStatesPropety to decide if waiting for MovingEnd message is necessary
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)





  if(avlHelperFunctions.stateDetector(avlStatesProperty).Moving) then

    -- setting properties of the service to put terminal into stationary state
    lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME}
                                               }
                      )
    -- set the speed to zero and wait for stationaryDebounceTime
    framework.delay(STATIONARY_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  end

  -- checking if terminal entered stationary state for sure
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)

  local whilecount = 0
  while(avlHelperFunctions.stateDetector(avlStatesProperty).Moving) do
    avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)
    whilecount = whilecount + 1
    if (whilecount > tries) then
      assert_true(false, "Not possible to put terminal into stationary state after defined number of tries")
      break
    end
  end





end



--- Function puts terminal into moving state
-- @usage
-- avlHelperFunctions.putTerminalIntoMovingState()
-- @within AvlhelperFunctions
function avlHelperFunctions.putTerminalIntoMovingState(tries)

  tries = tries or 10

  local MOVING_DEBOUNCE_TIME = 1      -- seconds
  local STATIONARY_SPEED_THLD = 5     -- kmh

  -- gps settings table
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 5,   -- kmh
                      longitude = 0,                       -- degrees
                      latitude = 0,                        -- degrees
                      fixType= 3,                          -- valid fix provided
                     }
  gps.set(gpsSettings) -- applying settings of gps simulator

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)

  if(avlHelperFunctions.stateDetector(avlStatesProperty).Moving == false) then
    -- setting properties of the service
    lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME}
                                               }
                      )

    framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_READ_INTERVAL)

  end

  -- checking if terminal entered stationary state for sure
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)

  local whilecount = 0
  while(avlHelperFunctions.stateDetector(avlStatesProperty).Moving == false) do
    avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)
    whilecount = whilecount + 1
    if (whilecount > tries) then
      assert_true(false, "Not possible to put terminal into moving state after defined number of tries")
      break
    end
  end


end



--- Function puts terminal into speeding state
-- @usage
-- avlHelperFunctions.putTerminalIntoSpeedingState()
-- @within AvlhelperFunctions
function avlHelperFunctions.putTerminalIntoSpeedingState()

  local MOVING_DEBOUNCE_TIME = 1      -- seconds
  local STATIONARY_SPEED_THLD = 5     -- kmh
  local DEFAULT_SPEED_LIMIT = 80      -- kmh
  local SPEEDING_TIME_OVER = 1        -- seconds

  -- setting speeding and moving related properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                              {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                              {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                                              {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                                             }
                    )

  -- gps settings table
  local gpsSettings={
              speed = DEFAULT_SPEED_LIMIT + 5,   -- kmh
              longitude = 0,                     -- degrees
              latitude = 0,                      -- degrees
              fixType= 3,                        -- valid fix provided
                     }

  -- set the speed above DEFAULT_SPEED_LIMIT and wait longer than SPEEDING_TIME_OVER
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + SPEEDING_TIME_OVER + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- checking if terminal is in speeding state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN, avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in moving state as expected")


end




--- Function reads terminal hardware version
-- @usage
-- avlHelperFunctions.getTerminalHardwareVersion()
-- @treturn string - "1", "2" or 3" indicating version of hardware in use
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
  if(terminalInfoMessage.Payload.Fields[1].Value == "IDP-6XX") then return 1
  elseif(terminalInfoMessage.Payload.Fields[1].Value == "IDP-7XX") then  return 2
  elseif(terminalInfoMessage.Payload.Fields[1].Value == "IDP-8XX") then return 3
  end


end


---
-- @tparam table expectedMins array of expected MINs
-- @tparam ?number timeout in seconds
-- @treturn table array of messages that match expected MINs of the service under test
function avlHelperFunctions.matchReturnMessages(expectedMins, timeout)
  assert_table(expectedMins, "invalid minList")
  timeout = tonumber(timeout) or GATEWAY_TIMEOUT

  local msgList = {count = 0}

  local function UpdateMsgMatchingList(msg)
    if msg then   --TODO: why would this function be called with no msg?
      for idx, min in pairs(expectedMins) do
        if msg.Payload and min == msg.Payload.MIN and msg.SIN == avlConstants.avlAgentSIN and msgList[min] == nil then
          msgList[min] = framework.collapseMessage(msg).Payload
          msgList.count = msgList.count + 1
          break
        end
      end
    end
    return #expectedMins == msgList.count
  end
  gateway.getReturnMessage(UpdateMsgMatchingList, nil, timeout)
  return msgList
end

--- Function waits for specific timeout until given old properties are different than current properties
-- @tparam oldProperties - list of properties received from getProperties method ({{pin, value}, {pin, value}})
-- @tparam timeout - timeout in seconds determining how long to wait for property change
-- @tparam delay - delay in seconds between requesting new parameter list
-- @treturn table of properties {pin, value}

function avlHelperFunctions.getChangedProperties(oldProperties, timeout, delay)
  delay = delay or 0.33
  timeout = timeout or 10
  local startTime = os.time()
  local propList = {}
  local newProperties
  local result
  for i=1, #oldProperties do
    propList[i] = oldProperties[i].pin
  end

  while (os.time() - startTime < timeout) do
    framework.delay(delay)
    newProperties = lsf.getProperties(avlConstants.avlAgentSIN, propList)

    for i=1,#newProperties do
      if newProperties[i].value ~= oldProperties[i].value then
        result = newProperties
        break
      end
    end
    if result then break end
  end
  return result
end

--- Function converts property list to table
-- e.g. propList = {{pin = pin1, value = val1}, {pin = pin2, value = val2}}
-- is converted into result = {pin1 = val1, pin2 = val2}
-- @tparam propertyList - list of properties received from getProperties method ({{pin, value}, {pin, value}})
-- @treturn - table of properties where pin determines index and value determines pin value
function avlHelperFunctions.propertiesToTable(propertyList)
  result = {}
  for index, property in ipairs(propertyList) do
    result[tonumber(property.pin)] = property.value
  end
  return result
end

function avlHelperFunctions.bytesToInt(str,endian,signed) -- use length of string to determine 8,16,32,64 bits
    local t={str:byte(1,-1)}
    if endian=="big" then --reverse bytes
        local tt={}
        for k=1,#t do
            tt[#t-k+1]=t[k]
        end
        t=tt
    end
    local n=0
    for k=1,#t do
        n=n+t[k]*2^((k-1)*8)
    end
    if signed then
        n = (n > 2^(#t*8-1) -1) and (n - 2^(#t*8)) or n -- if last bit set, negative.
    end
    return n
end

-- This uses the ‘haversine’ formula to calculate 
-- the great-circle distance between two points – that is, 
-- the shortest distance over the earth’s surface – 
-- giving an ‘as-the-crow-flies’ distance between the points (ignoring any hills they fly over, of course!).
-- Haversine
-- formula: 	a = sin²(Δφ/2) + cos φ1 ⋅ cos φ2 ⋅ sin²(Δλ/2)
-- c = 2 ⋅ atan2( √a, √(1−a) )
-- d = R ⋅ c
-- where 	φ is latitude, λ is longitude, R is earth’s radius (mean radius = 6,371km);
-- note that angles need to be in radians to pass to trig functions!
--
-- This solution has accuracy about 3m per 1km
-- Solution of better accuracy (1mm per 1km) is here: http://www.movable-type.co.uk/scripts/latlong-vincenty.html
-- Python implementation: https://github.com/geopy/geopy/blob/master/geopy/distance.py
-- usage: geoDistance(30.19, 71.51, 31.33, 74.21)
function avlHelperFunctions.geoDistance(lat1, lon1, lat2, lon2)
  if lat1 == nil or lon1 == nil or lat2 == nil or lon2 == nil then
    return nil
  end
  local dlat = math.rad(lat2-lat1)
  local dlon = math.rad(lon2-lon1)
  local sin_dlat = math.sin(dlat/2)
  local sin_dlon = math.sin(dlon/2)
  local a = sin_dlat * sin_dlat + math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) * sin_dlon * sin_dlon
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
  -- To get miles, use 3963 as the constant (equator again)
  local d = 6378 * c
  return d
end


return function() return avlHelperFunctions end
