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
                        {15,gpsReadInterval}    -- setting the continues mode of position service (SIN 20, PIN 15)
                                                 -- gps will be read every second with this setting
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

  local movingDebounceTime = 1
  local stationaryDebounceTime = 1 -- to make sure AVL will quickly go to non moving state
  local stationarySpeedThld = 5

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                            }
                    )

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  gps.set{speed=0}
  framework.delay(stationaryDebounceTime+gpsReadInterval)

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

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set{speed=stationarySpeedThld+1}
  framework.delay(movingDebounceTime+gpsReadInterval)

  -- MovingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  avlHelperFunctions.reportVerification(message, "MovingStart") -- verification of the report fields


  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")


end

function test_Moving_WhenBelowThldForPeriodAboveThld_MovingEndMessageSent()
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 1 second to get the moving state
  -- after that speed is reduced to 4 kmh and the MovingEnd event should appear
  -- check if the state of the AVL agent has changed to moving=false and correct
  -- report sent from mobile


  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )

  -- first terminal is put into moving state
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set{speed=stationarySpeedThld+1}
  framework.delay(movingDebounceTime+gpsReadInterval)

  -- MovingStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  avlHelperFunctions.reportVerification(message, "MovingStart") -- verification of the report fields


  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- when the termoinal is in the moving state the speed is reduced and moving state should change to false after that
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set{speed=stationarySpeedThld-1}
  framework.delay(stationaryDebounceTime+gpsReadInterval)


  -- MovingEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  avlHelperFunctions.reportVerification(message, "MovingEnd") -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")
  --debugging
  --print(framework.dump(avlStatesProperty))


end


--[[Start the tests]]
for i=1, 3, 1 do     -- to check the reliability, will be removed
lunatest.run()
end
framework.printResults()


