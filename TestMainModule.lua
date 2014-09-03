--[[

  GPSModule.lua

description of the GPS module to be added

]]


local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local avlMessagesMINs       = require("MessagesMINs")           -- the MINs of the messages are taken from the external file
local avlPopertiesPINs      = require("PropertiesPINs")         -- the PINs of the properties are taken from the external file
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
local avlAgentCons          = require("AvlAgentCons")

-- global variables used in the tests
gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds

-------------------------
-- Setup and Teardown
-------------------------

--- suite_setup function ensures that terminal is not in the moving state and not in the low power mode
 -- executed before each test suite
 -- * actions performed:
 -- lpmTrigger is set to 0 so that nothing can put terminal into the low power mode
 -- function checks if terminal is not the low power mode (condition necessary for all GPS related test cases)
 -- *initial conditions:
 -- running Terminal Simulator with installed AVL Agent, running Modem Simulator with Gateway Web Service and
 -- GPS Web Service switched on
 -- *Expected results:
 -- lpmTrigger set correctly and terminal is not in the Low Power mode
function suite_setup()

 -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.lpmTrigger, 0},
                                             }
                    )
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

end


-- executed after each test suite
function suite_teardown()

-- nothing here for now

end

--- the setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets gpsReadInterval (in position service) to the value of gpsReadInterval
  -- executed before each unit test
  -- *actions performed:
  -- setting of the gpsReadInterval (in the position service) is made using global gpsReadInterval variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state
function setup()

  lsf.setProperties(20,{
                        {15,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                                 -- gps will be read every gpsReadInterval (in seconds)
                      }
                    )

  local stationaryDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh
  -- gps settings table
  local gpsSettings={
              speed = 0,
              fixType=3                 -- valid 3D gps fix
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
  --framework.delay(5)                                       -- this delay is for reliability reasons
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end

--[[
    START OF TEST CASES

    Each test case is a global function whose name begins with "test"

--]]

--[[

--- TC checks if MovingStart message is correctly sent when speed is above threshold for time above threshold
  -- *actions performed:
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh; increase speed one kmh above threshold
  -- then wait for time longer than movingDebounceTime; then check if the MovingStart message has been sent and verify
  -- if the fields in the report have correct values and terminal is correctly in the moving state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly put in the moving state, MovingStart message sent and report fields
  -- have correct values
function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingStartMessageSent()

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



--- TC checks if MovingStart message is correctly sent when speed is above threshold for time above threshold
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set gpsReadInterval to value of specialGpsReadInterval (15 seconds)
  -- set movingDebounceTime to 7 seconds and stationarySpeedThld to 5 kmh, increase simulated speed tp 15 kmh
  -- and  wait for time longer than movingDebounceTime; then check if the MovingStart message has been sent and
  -- verify if fields in the report have correct values and terminal is correctly in the moving state
  -- GpsFixAge should be verified in this TC as it should be included in the report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode
  -- *expected results:
  -- terminal correctly put in the moving state, MovingStart message sent and report fields
  -- have correct values
function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingStartMessageSentGpsFixAgeReported()

  local movingDebounceTime = 7       -- seconds
  local stationarySpeedThld = 5      -- kmh
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10,  -- 10 kmh above threshold
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees
              longitude = 1,                   -- degrees
              fixType=3                        -- 3D fix
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )
  gateway.setHighWaterMark()                        -- to receive newest messages
  gps.set(gpsSettings)                              -- applying gps settings
  framework.delay(2)                                -- delay added to make sure gps is read (gpsReadInterval = 1)
  gps.set({fixType=1})                              -- simulated no fix (gps signal loss)
  framework.delay(avlAgentCons.coldFixDelay)        -- delay connected with obtaining cold fix time


  -- MovingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingStart",
                  currentTime = os.time() - 40, -- 40 second are added to reduce discrepancy between event and reports
                  GpsFixAge = 47                --  GpsFixAge is ecpected to be 47 seconds (movingDebounceTime + coldFixDelay)
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

end



--- TC checks if MovingEnd message is correctly sent when speed is below threshold for time above threshold
  -- *actions performed:
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh then wait for time longer than
  -- movingDebounceTime and check if the  moving state has been obtained; after that
  -- reduce speed to one kmh below threshold for time longer than  stationaryDebounceTime and
  -- check if MovingEnd message is sent, report fields have correct values and terminal is put
  -- into the stationary state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly put in the stationary state, MovingEnd message sent and report fields
  -- have correct values
function test_Moving_WhenSpeedBelowThldForPeriodAboveThld_MovingEndMessageSent()

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

--- TC checks if MovingStart message is not sent when speed is above threshold for time below threshold
  -- *actions performed:
  -- set movingDebounceTime to 15 seconds and stationarySpeedThld to 5 kmh then wait for time shorter than
  -- movingDebounceTime and check if the MovingStart message has not been been sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put into moving state, MovingStart message not sent
function test_Moving_WhenSpeedAboveThldForPeriodBelowThld_MovingStartMessageNotSent()

  local movingDebounceTime = 15      -- seconds
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

--- TC checks if MovingEnd message is not sent when terminal is in the moving state and
  -- speed is below threshold for time below threshold
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationaryDebounceTime to 15 and stationarySpeedThld to 5 kmh
  -- then wait for time longer than movingDebounceTime and check if the  moving state has been obtained
  -- after that reduce speed to one kmh below threshold for time shorter than  stationaryDebounceTime and
  -- check if MovingEnd message is not sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the stationary state, MovingEnd message not sent
function test_Moving_WhenSpeedBelowThldForPeriodBelowThld_MovingEndMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 15  -- seconds
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

--- TC checks if MovingStart message is not sent if speed is below threshold for time above threshold
  -- *actions performed:
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 10 kmh
  -- then set speed below stationarySpeedThld and wait for time longer than movingDebounceTime
  -- check if the  moving state has not been obtained and MovingStart message not sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the moving state, MovingStart message not sent
function test_Moving_WhenSpeedBelowThldForPeriodAboveThld_MovingStartMessageNotSent()

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

--- TC checks if MovingEnd message is not sent if speed is above stationarySpeedThld for time above threshold
  -- *actions performed:
  -- set movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh
  -- then set speed above stationarySpeedThld and wait for time longer than movingDebounceTime to get the moving state
  -- then reduce speed to 6 kmh (above stationarySpeedThld) and wait longer than stationaryDebounceTime
  -- check if terminal is still in the moving state and MovingEnd message has not been sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the stationary state, MovingEnd message not sent
function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingEndMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
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


--- TC checks if SpeedingStart message is correctly sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to one kmh
  -- above the defaultSpeedLimit for time longer than speedingTimeOver and check if SpeedingStart message is
  -- correctly sent; verify if fields of report have correct values and terminal is put into the speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly put in the speeding state, SpeedingStart message sent and report fields
  -- have correct values
function test_Speeding_WhenSpeedAboveThldForPeriodAboveThld_SpeedingStartMessageSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 3         -- seconds
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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit+1  -- one kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

 -- SpeedingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = os.time(),
                  speedLimit = defaultSpeedLimit
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

end

--- TC checks if SpeedingEnd message is correctly sent when speed is below defaultSpeedLimit for period above SpeedingTimeUnder
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeUnder to 3 seconds
  -- increase speed above stationarySpeedThld and wait longer than movingDebounceTime and then check if terminal goes into moving state;
  -- then increase speed to 10 kmh above the defaultSpeedLimit for time longer than speedingTimeOver to get the Speeding state;
  -- after that reduce speed one kmh under defaultSpeedLimit for time longer than speedingTimeUnder and check if SpeedingEnd
  -- message has been correctly sent, verify if fields of report have correct values and terminal is put into the non-speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly put out of the speeding state, SpeedingEnd message sent and report fields
  -- have correct values
function test_Speeding_WhenSpeedBelowSpeedingThldForPeriodAboveThld_SpeedingEndMessageSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 3        -- seconds

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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit-1  -- one kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

 -- SpeedingEnd Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingEnd",
                  currentTime = os.time(),
                  maximumSpeed = maxSpeedTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end

--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period below speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 5 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- shorter than speedingTimeOver and check if SpeedingStart message is not sent and terminal does not goes to
  -- speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message sent not
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodBelowThld_SpeedingStartMessageNotSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 15        -- seconds
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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit+10            -- 10 kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(gpsReadInterval+3)                  -- wait for 3 seconds + gpsReadInterval (that together is shorter than speedingTimeOver)

  gpsSettings.speed = defaultSpeedLimit-10            -- 10 kmh below the speed limit threshold
  gps.set(gpsSettings)

  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end

--- TC checks if SpeedingEnd message is not sent when speed is below defaultSpeedLimit for period below speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if terminal goes to the speeding state;
  -- after that reduce speed below defaultSpeedLimit but for time shorter than speedingTimeUnder and check if SpeedingEnd message has not been
  -- sent and terminal is still in SpeedingState
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly does not loeave the speeding state, SpeedingEnd message not sent
function test_Speeding_WhenSpeedBelowSpeedingThldForPeriodBelowThld_SpeedingEndMessageNotSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 10       -- seconds

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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark() -- to get the newest messages
  -- following section simulates speed reduced under the speed limit for short time
  gpsSettings.speed = defaultSpeedLimit-1   -- one kmh below the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder-1)      -- wait shorter than SpeedingTimeUnder
  gpsSettings.speed = defaultSpeedLimit+10  -- back to the speed above the Speeding threshold
  gps.set(gpsSettings)

  -- SpeedingEnd Message not expected
  local receivedMessages = gateway.getReturnMessages()    -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for SpeedingEnd message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))
  assert_false(next(matchingMessages), "SpeedingEnd report not expected")   -- checking if any SpeedingEnd message has been caught

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly not in the speeding state")

end


--- TC checks if SpeedingStart message is correctly sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 7 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time longer than
  -- speedingTimeOver (meanwhile change fixType to 'no fix') and check if SpeedingStart message is
  -- correctly sent; verify if fields of report have correct values and terminal is put into the speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal correctly put in the speeding state, SpeedingStart message sent and report fields (with GpsFixAge)
  -- have correct values
function test_Speeding_WhenSpeedAboveThldForPeriodAboveThld_SpeedingStartMessageSentGpsFixAgeReported()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 7         -- seconds
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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent


  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold
  gps.set(gpsSettings)

  framework.delay(2)                                  -- to make sure gps has been read
  gps.set({fixType=1})                                -- simulated no fix (gps signal loss)

 -- SpeedingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))


  framework.dump(message)


  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = os.time()-20,
                  speedLimit = defaultSpeedLimit,
                  GpsFixAge = 6

                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

end


--- TC checks if SpeedingEnd message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 100 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if terminal goes to the speeding state;
  -- after that reduce speed to 1 kmh above defaultSpeedLimit for time longer than speedingTimeUnder and check if SpeedingEnd
  -- message has not been sent and terminal is still in SpeedingState
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal does not leave the speeding state, SpeedingEnd message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThld_SpeedingEndMessageNotSent()

  local defaultSpeedLimit = 100      -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 2        -- seconds

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
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark() -- to get the newest messages
  -- following section simulates speed reduction but (still above the speed limit) for time longer than SpeedingTimeUnder
  gpsSettings.speed = defaultSpeedLimit+1   -- one kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder+gpsReadInterval+1)      -- wait longer than SpeedingTimeUnder

  -- SpeedingEnd Message not expected
  local receivedMessages = gateway.getReturnMessages()    -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for MovingEnd message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))
  assert_false(next(matchingMessages), "SpeedingEnd report not expected")   -- checking if any SpeedingEnd message has been caught

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly not in the speeding state")

end




--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- for setting DefaultSpeedLimit = 0 (speeding feature disabled)
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 5 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 150 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if SpeedingStart message is not sent and terminal does not goes to
  -- speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThldForSpeedingFeatureDisabled_SpeedingStartMessageNotSent()

  local defaultSpeedLimit = 0        -- kmh, for value of 0 the speeding feature should be disabled
  local speedingTimeOver = 2         -- seconds
  local movingDebounceTime = 1        -- seconds
  local stationarySpeedThld = 2      -- kmh

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 3, -- stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+5) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
 -- local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  --assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

 -- gpsSettings.speed = defaultSpeedLimit+150            -- 150 kmh above the speed limit threshold
  --gps.set(gpsSettings)
 -- framework.delay(speedingTimeOver+gpsReadInterval+1)  -- wait for time longer than speedingTimeOver


  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end


--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- for terminal which is not in the moving stare (SpeedingStart cannot be sent before MovingStart)
  -- *actions performed:
  -- set movingDebounceTime to 20 seconds,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 5 kmh and speedingTimeOver to 1 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than speedingTimeOver but shorter than movingDebounceTime
  -- and check if terminal gets speeding state;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThldTerminalNotInMovingStateSpeedingMessageNotSent()

  local defaultSpeedLimit = 5        -- kmh, for value of 0 the speeding feature should be disabled
  local speedingTimeOver = 1         -- seconds
  local movingDebounceTime = 20      -- seconds
  local stationarySpeedThld = 5      -- kmh


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = defaultSpeedLimit+1,    -- that is above stationary and speeding thresholds
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval) -- that is longer than speedingTimeOver but shorter than movingDebounceTime

  -- checking if terminal is not in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")


  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end

--]]
--- TC checks if SpeedingEnd message is sent when terminal goes to stationary state (speed = 0)
  -- even if speedingTimeUnder has not passed
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 50 kmh and speedingTimeOver to 1 second
  -- set gps speed above defaultSpeedLimit and wait for time longer than speedingTimeOver to get the speeding state;
  -- then simulate terminal stop (speed = 0) and check if MovingEnd and SpeedingEnd is sent before speedingTimeUnder passes
  -- and verify if terminal is no longer in moving and speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal put in the speeding state false, SpeedingEnd message sent
function test_Speeding_WhenTerminalStopsWhileSpeedingStateTrueSpeedingEndMessageSentBeforeMovingEnd()

  local defaultSpeedLimit = 50       -- kmh
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeOver = 1         -- seconds
  local speedingTimeUnder = 20       -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = defaultSpeedLimit+1,    -- that is above stationary and speeding thresholds
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},

                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+2) -- that is longer than speedingTimeOver and longer than movingDebounceTime


  --checking the state of terminal, speeding state is  ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gpsSettings.speed = 0   -- terminal suddenly stops
  gps.set(gpsSettings)
  framework.delay(stationaryDebounceTime+gpsReadInterval+5)


  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  local speedingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))

  -- checking if expected messages has been received
  assert_not_nil(next(movingEndMessage), "MovingEnd message not received")              -- if MovingEnd message not received assertion fails
  assert_not_nil(next(speedingEndMessage), "SpeedingEnd message not received")          -- if SpeedingEnd message not received assertion fails

  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(speedingEndMessage[1].Payload.EventTime, movingEndMessage[1].Payload.EventTime, 0, "Timestamps of SpeedingEnd and MovingEnd messages expected to be equal")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of SpeedingEnd and MovingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: SpeedingEnd ReceiveUTC = "2014-09-03 07:56:37" and MovingEned MessageUTC = "2014-09-03 07:56:42" - that is correct

  -- checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")
  -- checking the state of terminal, moving state is not ecpected
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")



end





--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


