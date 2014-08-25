--[[

  TestMainModule.lua

  Test main.lua module

--  Module :      $URL: https://ott-svn1.skywavemobile.com/svn/M2M/Agents/Source/J1939/trunk/featureTests/TestMainModule.lua $
--  Revision:     $Revision: 1226 $
--  Last Updated By:  $Author: shawn_l $
--  Last Updated:   $Date: 2014-04-01 09:19:40 -0400 (Tue, 01 Apr 2014) $


]]


local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local bit                   = require "bit"
local avlMessagesMINs       = require("MessagesMINs")           -- the MINs of the messages are taken from the external file
local avlPopertiesPINs      = require("PropertiesPINs")         -- the PINs of the properties are taken from the external file
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
local avlAgentCons          = require("AvlAgentCons")

-- global variables used in the tests
local gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds

-------------------------
-- Setup and Teardown
-------------------------

-- executed before each test suite
function suite_setup()

 lsf.setProperties(20,{
                        {15,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                                 -- gps will be read every gpsReadInterval (in seconds)
                      }
                    )

end


-- executed after each test suite
function suite_teardown()

-- nothing here for now

end


-- executed before each unit test
function setup()
--- the setup function ensures that the terminal is not in the moving state
  -- setting values specific for the TC
  local movingDebounceTime = 1          -- seconds
  local stationaryDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh
  -- gps settings
  gps_heading = 90        -- degrees
  gps_latitude = 1        -- degrees
  gps_longitude = 1       -- degrees

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                            }
                    )

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  local gps_speed = 0
  gps.set{speed = gps_speed, heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude, altitude = gps_altitude}
  framework.delay(stationaryDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  --print(framework.dump(avlStatesProperty)) -- just for debugging for now, will be removed

  --avlHelperFunctions.stateDetector(avlStatesProperty)
 -- print(framework.dump(avlStates)) -- just for debugging for now, will be removed


  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")


end
-----------------------------------------------------------------------------------------------
-- executed after each unit test
function teardown()

-- nothing here for now

end

--[[
    START OF TEST CASES

    Each test case is a global function whose name begins with "test"
    Test cases are run in alphabetical order (e.g. test00 runs before test01)
--]]


function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingStartMessageSent()
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 2 seconds
  -- check if the state of the AVL agent has changed to moving and correct and
  -- report sent from mobile


  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings
  gps_heading = 90        -- degrees
  gps_latitude = 1        -- degrees
  gps_longitude = 1       -- degrees


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local gps_speed = stationarySpeedThld+1 -- one kmh above the threshold
  gps.set{speed = gps_speed, heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude} -- gps settings sent to simulator
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- MovingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  avlHelperFunctions.reportVerification(message, "MovingStart", 0, 361, gps_longitude, gps_latitude) -- verification of the report fields
                                                                                                     -- speed is 0, and heading is 361 for stationary state

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")


end


function test_Moving_WhenSpeedBelowThldForPeriodAboveThld_MovingEndMessageSent()
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 1 second to get the moving state
  -- after that speed is reduced to 4 kmh and the MovingEnd event should appear
  -- check if the state of the AVL agent has changed to moving=false and correct
  -- report sent from mobile


  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings
  gps_heading = 90        -- degrees
  gps_latitude = 1        -- degrees
  gps_longitude = 1       -- degrees


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )

  -- first terminal is put into moving state
  gateway.setHighWaterMark() -- to get the newest messages
  local gps_speed = stationarySpeedThld+1 -- one kmh above threshold
  gps.set{speed = gps_speed, heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude}

  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- MovingStart message expected
  --message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  --avlHelperFunctions.reportVerification(message, "MovingStart", gps_speed, gps_heading, gps_longitude, gps_latitude)

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- when the termoinal is in the moving state the speed is reduced and moving state should change to false after that
  gateway.setHighWaterMark() -- to get the newest messages
  gps_speed = stationarySpeedThld-1 -- one kmh below threshold
  gps.set{speed = gps_speed,  heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude}
  framework.delay(stationaryDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- MovingEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  avlHelperFunctions.reportVerification(message, "MovingEnd", gps_speed, gps_heading, gps_longitude, gps_latitude)  -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

end


function test_Moving_WhenSpeedAboveThldForPeriodBelowThld_MovingStartMessageNotSent()
  -- set movingDebounceTime to 30 seconds and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 3 seconds (shorten than movingDebounceTime)
  -- check if the state of the AVL agent has not changed to moving and MovingStart
  -- message is not sent from mobile


  local movingDebounceTime = 30      -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings
  gps_heading = 90        -- degrees
  gps_latitude = 1        -- degrees
  gps_longitude = 1       -- degrees


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local gps_speed = stationarySpeedThld+1 -- one kmh above the threshold
  gps.set{speed = gps_speed, heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude} -- gps settings sent to simulator
  framework.delay(gpsReadInterval+2) -- time shorter than movingDebounceTime

  -- MovingStart Message is not expected
  local message = gateway.getReturnMessages(5)
  local colmsg = framework.collapseMessage(message)
  if (next(colmsg)) then -- checking if table is empty
  assert_false(colmsg.Payload.MIN == 6 and colmsg.Payload.SIN == 126, "MovingStart message incorrectly sent") -- if not empty
  end                                                                                                         -- checking type of message

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)           -- checking state of terminal
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")

end


function test_Moving_WhenSpeedBelowThldForPeriodBelowThld_MovingEndMessageNotSent()
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 1 second to get the moving state
  -- after that speed is reduced to 4 kmh for 3 seconds (shorter than stationaryDebounceTime)
  -- check if the state of the AVL agent has NOT changed to moving=false and MovingEnd
  -- report has NOT sent from mobile

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 30  -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings
  gps_heading = 90        -- degrees
  gps_latitude = 1        -- degrees
  gps_longitude = 1       -- degrees


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )

  -- first terminal is put into moving state
  gateway.setHighWaterMark() -- to get the newest messages
  local gps_speed = stationarySpeedThld+1 -- one kmh above threshold
  gps.set{speed = gps_speed, heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude}

  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- when the terminal is in the moving state the speed is reduced for short time (seconds)
  gateway.setHighWaterMark() -- to get the newest messages
  gps_speed = stationarySpeedThld-1 -- one kmh below threshold
  gps.set{speed = gps_speed,  heading = gps_heading, latitude = gps_latitude, longitude = gps_longitude}
  framework.delay(gpsReadInterval+2) --


  -- MovingEnd message is not expected
  message = gateway.getReturnMessages(5)
  local colmsg = framework.collapseMessage(message)
  if (next(colmsg)) then -- checking if table is empty
  assert_false(colmsg.Payload.MIN == 7 and colmsg.Payload.SIN == 126, "MovingStart message incorrectly sent") -- if not empty
  end                                                                                                         -- checking type of message



  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly not in the moving state")

end



--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
lunatest.run()
end
framework.printResults()


