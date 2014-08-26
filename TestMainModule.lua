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
gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds

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

  -- to perform GPS related test cases terminal cannot be in low power mode, checking the AVL states
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "is incorrectly in low power mode")

end


-- executed after each test suite
function suite_teardown()

-- nothing here for now

end


-- executed before each unit test
function setup()
--- the setup function ensures that the terminal is not in the moving state and is not in low power mode
  -- setting values specific for the TC
  local stationaryDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh
  -- gps settings table
  local gpsSettings={
              speed = 0,
                     }

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                    )

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(stationaryDebounceTime+gpsReadInterval+3) -- three seconds are added to make sure the gps is read and processed by agent
  framework.delay(5)                                       -- this delay is for reliability reasons
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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

--]]

function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingStartMessageSent()
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 6 kmh and wait for 2 seconds
  -- check if the state of the AVL agent has changed to moving and correct and
  -- report sent from mobile

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

 -- MovingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingStart",
                  currentTime = os.time()
                  }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

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

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )
    -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- when the terminal is in the moving state the speed is reduced and moving state should change to false after that
  gateway.setHighWaterMark()                            -- to get the newest messages
  gpsSettings.speed = stationarySpeedThld-1             -- one kmh below threshold
  gps.set(gpsSettings)                                  -- gps settings applied
  framework.delay(stationaryDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- MovingEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  -- gps settings table to be sent to simulator
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "MovingEnd",
                    currentTime = os.time()
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

end


function test_Moving_WhenSpeedAboveThldForPeriodBelowThld_MovingStartMessageNotSent()
  -- set movingDebounceTime to 60 seconds and stationarySpeedThld to 5 kmh
  -- simulate terminal speed to 15 kmh and wait for 3 seconds (shorter than movingDebounceTime)
  -- check if the state of the AVL agent has not changed to moving and MovingStart
  -- message has not been sent from mobile

  local movingDebounceTime = 60      -- seconds
  local stationarySpeedThld = 5      -- kmh

  -- gps settings table to be sent to simulator
  local gpsSettings={
                    speed = stationarySpeedThld+10, -- 10 kmh above threshold
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gateway.setHighWaterMark()                -- to get the newest messages
  gps.set(gpsSettings)                      -- applying gps settings
  framework.delay(gpsReadInterval+2)        -- waiting for time shorter than movingDebounceTime

  -- MovingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  assert_false(next(matchingMessages), "MovingSent report not expected")   -- checking if any MovingStart message has been caught

  -- check the state of the terminal
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state") -- terminal should not be moving

end


function test_Moving_WhenSpeedBelowThldForPeriodBelowThld_MovingEndMessageNotSent()
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh and
  -- stationaryDebounceTime to 60 seconds
  -- simulate terminal speed to 15 kmh and wait for 1 second to obtain  the moving state
  -- after that speed is reduced to 4 kmh for 3 seconds (shorter than stationaryDebounceTime)
  -- check if the state of the AVL agent has NOT changed to moving=false and MovingEnd
  -- report has NOT been sent from mobile

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 60  -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10, -- 10 kmh above threshold
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )

  -- first terminal is put into moving state
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings) -- applying gps settings

  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent
  -- checking the state of terminal
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- when the terminal is in the moving state the speed is reduced for short time (seconds)
  gateway.setHighWaterMark()                     -- to get the newest messages
  gpsSettings.speed = stationarySpeedThld-1      -- one kmh below threshold
  gps.set(gpsSettings)                           -- applying gps settings
  framework.delay(gpsReadInterval+2)             -- time much shorter than stationaryDebounceTime

  -- MovingEnd message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  assert_false(next(matchingMessages), "MovingEnd report not expected")   -- checking if any MovingEnd message has been caught

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the stationary state") -- terminal should be in moving state

end


function test_Moving_WhenSpeedBelowThldForPeriodAboveThld_MovingStartMessageNotSent()
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 10 kmh
  -- simulate terminal speed to 5 kmh and wait for 7 seconds
  -- after that check if MovingState report has not been sent and terminal has not get
  -- the moving state

  local movingDebounceTime = 1        -- seconds
  local stationarySpeedThld = 10      -- kmh
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld-5,    -- 5 kmh below threshold
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime}
                                             }
                   )

  gateway.setHighWaterMark()   -- to get the newest messages
  gps.set(gpsSettings)         -- applying gps settings

  framework.delay(movingDebounceTime+gpsReadInterval+5) -- wait for time much longer than movingDebounceTime

  -- MovingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))
  assert_false(next(matchingMessages), "MovingSent report not expected")   -- checking if any MovingStart message has been caught

  -- check the state of the terminal
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state") -- terminal should not be moving

end

function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingEndMessageNotSent()
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh and
  -- stationaryDebounceTime to 60 seconds
  -- simulate terminal speed to 15 kmh and wait for 1 second to obtain  the moving state
  -- after that speed is reduced to 6 kmh (that is above stationarySpeedThld) for 8 seconds
  -- (that is longer than stationaryDebounceTime) after that
  -- check if the state of the AVL agent has NOT changed to moving=false and MovingEnd
  -- report has NOT been sent from mobile

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1  -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10, -- 10 kmh above threshold
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime}
                                             }
                   )

  -- first terminal is put into moving state
  gateway.setHighWaterMark()  -- to get the newest messages
  gps.set(gpsSettings)        -- applying gps settings

  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent
  -- checking the state of terminal
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state") -- moving state expected

  -- when the terminal is in the moving state the speed is reduced to 6 kmh for long time (8 seconds)
  gateway.setHighWaterMark()                                 -- to get the newest messages
  gpsSettings.speed = stationarySpeedThld+1                  -- one kmh above threshold
  gps.set(gpsSettings)                                       -- applying gps settings
  framework.delay(stationaryDebounceTime+gpsReadInterval+6)  -- time much longer than stationaryDebounceTime

  -- MovingEnd message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  assert_false(next(matchingMessages), "MovingEnd report not expected")   -- checking if any MovingEnd message has been caught

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the stationary state") -- terminal should be in moving state

end


--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


