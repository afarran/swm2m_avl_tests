-----------
-- GPS test module
-- - contains gps related test cases
-- @module TestGPSModule


local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local avlMessagesMINs       = require("MessagesMINs")           -- the MINs of the messages are taken from the external file
local avlPopertiesPINs      = require("PropertiesPINs")         -- the PINs of the properties are taken from the external file
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
local avlAgentCons          = require("AvlAgentCons")

-- global variables used in the tests
gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds


-- Setup and Teardown


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

  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  -- sending fences.dat file to the terminal with the definitions of geofences used in TCs
  -- for more details please go to Geofences.jpg file in Documentation
  local message = {SIN = 24, MIN = 1}
	message.Fields = {{Name="path",Value="/data/svc/geofence/fences.dat"},{Name="offset",Value=0},{Name="flags",Value="Overwrite"},{Name="data",Value="ABIABQAtxsAAAr8gAACcQAAAAfQEagAOAQEALg0QAAK/IAAATiABnAASAgUALjvwAAQesAAAw1AAAJxABCEAEgMFAC4NEAAEZQAAAFfkAABEXAKX"}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- to make sure file is saved

  -- restaring geofences service, that action is necessary after sending new fences.dat file
  local message = {SIN = 16, MIN = 5}
	message.Fields = {{Name="sin",Value=21}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- wait until geofences service is up again


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
  local geofenceEnabled = false       -- to enable geofence feature

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                             }
                    )
 --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                             }
                   )


  -- gps settings table
  local gpsSettings={
              latitude = 1,
              longitude = 1,
              heading = 90,                 -- degrees
              speed = 0,                    -- to get stationary state
              fixType=3,                    -- valid 3D gps fix
              simulateLinearMotion = false, -- terminal not moving
                     }

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(stationaryDebounceTime+gpsReadInterval+3) -- three seconds are added to make sure the gps is read and processed by agent
  framework.delay(3)                                        -- this delay is for reliability reasons
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end


-------------------------
-- Test Cases
-------------------------

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


  gateway.setHighWaterMark() -- to get the newest messages


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
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThldTerminalNotInMovingState_SpeedingMessageNotSent()

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
function test_Speeding_WhenTerminalStopsWhileSpeedingStateTrue_SpeedingEndMessageSentBeforeMovingEnd()

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


--- TC checks if Turn message is correctly sent when heading difference is above TurnThreshold and is maintained above TurnDebounceTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 1 second
  -- set heading to 90 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 102 (2 degrees above threshold) and wait longer than turnDebounceTime
  -- check if Turn message has been correctly sent and verify field of the report; after that set heading of the terminal back to 90
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Turn message sent and report fields have correct values
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 1         -- in seconds, feature disabled


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.turnThreshold, turnThreshold},
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.heading = 102     -- change in heading above turnThreshold
  gps.set(gpsSettings)          -- applying gps settings

  -- waiting longer than turnDebounceTime
  framework.delay(turnDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- Turn Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.turn))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Turn",
                  currentTime = os.time()
                  }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings.heading = 90     -- terminal put back to initial heading
  gps.set(gpsSettings)         -- applying gps settings


end



--- TC checks if Turn message is not sent when heading difference is above TurnThreshold and is maintained below TurnDebounceTimes
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 10 seconds
  -- set heading to 90 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 110 (20 degrees above threshold) and wait shorter than turnDebounceTime
  -- check if Turn message has not been sent;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Turn message not sent
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsBelowTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 10         -- (feature disabled) in seconds


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.turnThreshold, turnThreshold},
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )


  gateway.setHighWaterMark() -- to get the newest messages
  gpsSettings.heading = 110                             -- change in heading above turnThreshold
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(gpsReadInterval+2)                    -- waiting shorter than turnDebounceTime
  gpsSettings.heading = 90                              -- back to heading before change
  gps.set(gpsSettings)                                  -- applying gps settings

  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

end


--- TC checks if Turn message is not sent when heading difference is below TurnThreshold and is maintained above TurnDebounceTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 2 seconds
  -- set heading to 10 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 15 (1 degree below threshold) and wait longer than turnDebounceTime
  -- check if Turn message has not been sent; after that set heading of the terminal back to 90
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Turn message not sent
function test_Turn_WhenHeadingChangeIsBelowTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 2         -- in seconds


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.turnThreshold, turnThreshold},
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  framework.delay(3) -- to make sure not to receive previous report (generated after movingStart Message)

  gateway.setHighWaterMark()                            -- to get the newest messages
  gpsSettings.heading = 99                              -- change in heading below turnThreshold
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(turnDebounceTime+gpsReadInterval+2)   -- waiting longer than turnDebounceTime


  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings.heading = 90                              -- terminal put back to initial heading
  gps.set(gpsSettings)                                  -- applying gps settings

end


--- TC checks if Turn message is not sent when feature is disabled (turnThreshold = 0)
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 0 degrees and turnDebounceTime to 2 seconds
  -- set heading to 90 degrees and speed to one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 120 (30 degrees change) and wait longer than turnDebounceTime
  -- check if Turn message has not been sent; after that set heading of the terminal back to 90
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Turn message not sent
function test_Turn_ForTurnFeatureDisabledWhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 0            -- 0 is for feature disabled, no Turn message should be sent, in degrees
  local turnDebounceTime = 2         -- in seconds


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.turnThreshold, turnThreshold},
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark()                            -- to get the newest messages
  gpsSettings.heading = 120                             -- change in heading of terminal
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(turnDebounceTime+gpsReadInterval+2)   -- waiting longer than turnDebounceTime

  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings.heading = 90                              -- terminal put back to initial heading
  gps.set(gpsSettings)                                  -- applying gps settings

end


--- TC checks if Turn message is correctly sent when heading difference is above TurnThreshold and is maintained above TurnDebounceTime
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 2 seconds
  -- set heading to 90 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 102 (2 degrees above threshold) and wait longer than turnDebounceTime
  -- meanwhile change fixType to 1 (no fix provided) to make the GpsFixAge higher than 5
  -- check if Turn message has been correctly sent and verify field of the report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Turn message sent and report fields have correct values
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageSentGpsFixAgeReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 12        -- in seconds


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.turnThreshold, turnThreshold},
                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  framework.delay(3)           -- this is to receive Turn message
  gateway.setHighWaterMark()   -- to get the newest messages

  gpsSettings.heading = 102     -- change in heading above turnThreshold
  gps.set(gpsSettings)          -- applying gps settings
  framework.delay(gpsReadInterval+1)
  gpsSettings.fixType = 1       -- simulated no fix (gps signal loss)
  gps.set(gpsSettings)          -- applying gps settings

  -- waiting longer than turnDebounceTime
  framework.delay(turnDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- Turn Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.turn))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Turn",
                  currentTime = os.time(),
                  GpsFixAge = 11,
                  }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  turnDebounceTime = 1        -- in seconds

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{

                                                {avlPropertiesPINs.turnDebounceTime, turnDebounceTime},
                                             }
                   )
  gpsSettings.heading = 90                              -- terminal put back to initial heading
  gps.set(gpsSettings)                                  -- applying gps settings

end


--- TC checks if StationaryIntervalSat message is sent periodically when terminal is in stationary state
  -- *actions performed:
  -- check if terminal is in stationary state, set stationaryIntervalSat to 10 seconds, wait for
  -- 20 seconds and collect all the receive messages during that time; count the number of receivedMessages
  -- stationaryIntervalSat reports in collected messages; verify alle the fields of single report
  -- set stationaryIntervalSat to 0 to disable reports (not to cause any troubles in other TCs)ate
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- StationaryIntervalSat reports received periodically, content of the report is correct
function test_Stationary_WhenTerminalStationary_StationaryIntervalSatReportsMessageSentPeriodically()

  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  local stationaryIntervalSat = 10       -- seconds
  local numberOfReports = 2              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gateway.setHighWaterMark()                                -- to get the newest messages
  local timeOfEventTc = os.time()                          -- time of receiving first stationaryIntervalSat report
  framework.delay(stationaryIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))

  gpsSettings.heading = 361 -- for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "StationaryIntervalSat",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received stationaryIntervalSat reports is incorrect")

  -- back to stationaryIntervalSat = 0 to get no more reports
  local stationaryIntervalSat = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )


end



--- TC checks if StationaryIntervalSat message is sent periodically when terminal is in stationary state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- check if terminal is in stationary state, set stationaryIntervalSat to 5 seconds, wait for coldFixDelay plus
  -- 20 seconds and collect all the receive messages during that time; count the number of receivedMessages
  -- stationaryIntervalSat reports in collected messages; verify alle the fields of single report
  -- set stationaryIntervalSat to 0 to disable reports (not to cause eny troubles in other TCs)ate
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- StationaryIntervalSat reports received periodically, content of the report is correct
function test_Stationary_WhenTerminalStationary_StationaryIntervalSatMessageSentPeriodicallyGpxFixReported()

  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
                     }
  gps.set(gpsSettings)

  local stationaryIntervalSat = 5        -- seconds
  local numberOfReports = 5              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

                         --  to get fix older than 5 seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gps.set({fixType = 1})                      -- no fix provided
  framework.delay(avlAgentCons.coldFixDelay)

  gateway.setHighWaterMark()                               -- to get the newest messages

  local timeOfEventTc = os.time()                          -- time of receiving first stationaryIntervalSat report
  framework.delay(stationaryIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports


  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))

  gpsSettings.heading = 361 -- for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "StationaryIntervalSat",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 51,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[2], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received stationaryIntervalSat reports is incorrect")

  -- back to stationaryIntervalSat = 0 to get no more reports
  local stationaryIntervalSat = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

end

--]]

--- TC checks if StationaryIntervalSat message is deffered by ZoneEntry message (for terminal in moving state)
  -- *actions performed:
  -- set stationaryIntervalSat to 30 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime to make terminal moving
  -- then change position of terminal to inside of the defined geofence - ZoneEntry message is generated -
  -- calculate difference in time between ZoneEntry message and MovingIntervalSat message - that should be equal to
  -- movingIntervalSat period if the report has been correctly deffered
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent after full movingIntervalSat period (deffered by ZoneEntry message)
function test_Moving_WhenTerminalInMovingState_MovingIntervalSatMessageSentAfterFullMovingIntervalSatPeriodIfDeffered()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local stationaryIntervalSat = 30   -- seconds
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 3       -- in seconds


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+2)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 50,                  -- degrees
              longitude = 3                   -- degrees
                     }
  gps.set(gpsSettings)
  gateway.setHighWaterMark()                -- to get the newest messages
  framework.delay(stationaryIntervalSat+8)  -- wait longer than stationaryIntervalSat

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingEnd and SpeedingEnd messages
  local stationaryIntervalSatMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))
  local zoneEntryMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))

  -- checking if expected messages has been received
  assert_not_nil(next(stationaryIntervalSatMessage), "stationaryIntervalSat message message not received")   -- if StationaryIntervalSat message not received assertion fails
  assert_not_nil(next(zoneEntryMessage), "ZoneEntry message not received")                                   -- if ZoneEntry message not received assertion fails

  -- difference in time of occurence of ZoneEntry report and StationaryIntervalSat report
  local differenceInTimestamps =  stationaryIntervalSatMessage[1].Payload.EventTime - zoneEntryMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full StationaryIntervalSat period is expected
  assert_equal(stationaryIntervalSat, differenceInTimestamps, 2, "StationaryIntervalSat has not been correctly deffered")

  -- back to stationaryIntervalSat = 0 to get no more reports
  stationaryIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},

                                             }
                   )

end


--- TC checks if MovingIntervalSat message is periodically sent when terminal is in moving state
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime; then check if terminal is
  -- correctly in the moving state then wait for 20 seconds and check if movingIntervalSat messages have been
  -- sent and verify the fields of single report; after verification set movingIntervalSat to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_Moving_WhenTerminalInMovingState_MovingIntervalSatMessageSentPeriodically()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 10       -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


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
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  framework.delay(movingIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingIntervalSat",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received MovingIntervalSat reports is incorrect")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )


end


--- TC checks if MovingIntervalSat message is periodically sent when terminal is in moving state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime; then check if terminal is
  -- correctly in the moving state; then change fixType to 1 (no fix) and  wait for coldFixDelay plus 20 seconds
  -- after that check if movingIntervalSat messages have been sent and verify the fields of single report;
  -- after verification set movingIntervalSat to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_Moving_WhenTerminalInMovingState_MovingIntervalSatMessageSentPeriodicallyGpsFixReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 10       -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


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
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )



  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gps.set({fixType = 1})    -- no fix displayed
  framework.delay(avlAgentCons.coldFixDelay)
  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(movingIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingIntervalSat",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 43
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received MovingIntervalSat reports is incorrect")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

end


--- TC checks if MovingIntervalSat message is deffered by ZoneEntry message (for terminal in moving state)
  -- *actions performed:
  -- set movingIntervalSat to 30 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime to make terminal moving
  -- then change position of terminal to inside of the defined geofence - ZoneEntry message is generated -
  -- calculate difference in time between ZoneEntry message and MovingIntervalSat message - that should be equal to
  -- movingIntervalSat period if the report has been correctly deffered
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent after full movingIntervalSat period (deffered by ZoneEntry message)
function test_Moving_WhenTerminalInMovingState_MovingIntervalSatMessageSentAfterFullMovingIntervalSatPeriodIfDeffered()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 30       -- seconds
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 3       -- in seconds


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
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+2)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 50,                  -- degrees
              longitude = 3                   -- degrees
                     }
  gps.set(gpsSettings)
  gateway.setHighWaterMark()            -- to get the newest messages
  framework.delay(movingIntervalSat+5)  -- wait longer than movingIntervalSat

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingEnd and SpeedingEnd messages
  local movingIntervalSatMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))
  local zoneEntryMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))

  -- checking if expected messages has been received
  assert_not_nil(next(movingIntervalSatMessage), "MovingIntervalSat message message not received")       -- if MovingIntervalSat message not received assertion fails
  assert_not_nil(next(zoneEntryMessage), "ZoneEntry message not received")                               -- if ZoneEntry message not received assertion fails

  -- difference in time of occurence of ZoneEntry report and movingIntervalSat report
  local differenceInTimestamps =  movingIntervalSatMessage[1].Payload.EventTime - zoneEntryMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full MovingIntervalSat period is expected
  assert_equal(movingIntervalSat, differenceInTimestamps, 2, "MovingIntervalSat has not been correctly deffered")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},

                                             }
                   )

end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds and wait for 20 seconds; verify
  -- if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_Moving_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodically()

  local positionMsgInterval = 15     -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(positionMsgInterval*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  assert_equal(numberOfReports, table.getn(matchingMessages) , 2, "The number of received Position reports is incorrect")

  gpsSettings.heading = 361                 -- that is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if Position message is sent after full positionMsgInterval when MovingStart event deffers it
  -- *actions performed:
  -- set positionMsgInterval to 20 seconds and movingDebounceTime to 1 second; simulate speed above stationarySpeedThld and wait longer than positionMsgInterval;
  -- check if positionMsgInterval message has been sent after full positionMsgInterval period since MovingStart event
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position messages correctly deffered by MovingStart event
function test_Moving_WhenPositionMsgIntervalIsGreaterThanZeroAndMovingStartEventDeffers_PositionMessageSentAfterFullPositionMsgInterval()

  local positionMsgInterval = 30     -- seconds
  local movingDebounceTime = 1      -- seconds
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
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  gateway.setHighWaterMark()              -- to get the newest messages
  gps.set(gpsSettings)                   -- applying gps settings to generate MovingStart message
  framework.delay(positionMsgInterval+movingDebounceTime+3)

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingEnd and SpeedingEnd messages
  local positionMsgIntervalMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))
  local movingStartMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))

  print(framework.dump(receivedMessages))

  -- checking if expected messages has been received
  assert_not_nil(next(positionMsgIntervalMessage), "PositionMsgInterval message message not received")       -- if PositionMsgInterval message not received assertion fails
  assert_not_nil(next(movingStartMessage), "MovingStart message not received")                               -- if MovingStart message not received assertion fails

  -- difference in time of occurence of ZoneEntry report and movingIntervalSat report
  local differenceInTimestamps =  positionMsgIntervalMessage[1].Payload.EventTime - movingStartMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full positionMsgInterval period is expected
  assert_equal(positionMsgInterval, differenceInTimestamps, 2, "PositionMsgInterval message has not been correctly deffered")


  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds, set fixType to 1 (no fix) and wait for coldFixDelay plus 20 seconds;
  -- verify if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_Moving_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodicallyGpsFixReported()

  local positionMsgInterval = 10     -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )
  gps.set({fixType=1})            -- simulating no fix
  framework.delay(avlAgentCons.coldFixDelay)
  gateway.setHighWaterMark()      -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(positionMsgInterval*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  gpsSettings.heading = 361                 -- that is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 50,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields



  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if LongDriving message is sent when terminal is moving without break for time longer than maxDrivingTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state and after time of maxDrivingTime and check if LongDriving
  -- message is sent and report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit, report fields have correct values
function test_LongDriving_WhenTerminalMovingWithoutBreakForPeriodLongerThanMaxDrivingTime_LongDrivingMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  local maxDrivingTime = 1           -- minutes
  local minRestTime = 1              -- minutes

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                                {avlPropertiesPINs.minRestTime, minRestTime}
                                             }
                   )
    -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark()                 -- to get the newest messages
  -- waiting until maxDrivingTime limit passes
  framework.delay(maxDrivingTime*60+8)       -- maxDrivingTime multiplied by 60 to get seconds from minutes
  eventTimeTc = os.time()                    -- to get the correct value in the report
  -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTime = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end


--- TC checks if LongDriving message is sent when terminal is moving longer than maxDrivingTime and breakes together are shorter than
  -- minRestTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving and wait until LongDriving message is sent; check if report fields
  -- have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with break shorter than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithBreakesShorterThanMinRestTime_LongDrivingMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  local maxDrivingTime = 1           -- minutes
  local minRestTime = 5              -- minutes

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                                {avlPropertiesPINs.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving
  framework.delay(maxDrivingTime*60-20)       -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(30)                          -- wait shorter than minRestTime

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- terminal moving again
  gateway.setHighWaterMark()                  -- to get the newest messages
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60-20)       -- maxDrivingTime multiplied by 60 to get seconds from minutes

  eventTimeTc = os.time()                     -- to get the correct value in the report
    -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTime = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end


--- TC checks if LongDriving message is not sent when terminal is moving longer than maxDrivingTime but breakes together are longer than
  -- minRestTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving and wait until LongDriving message is sent; check if report fields
  -- have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with break shorter than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithBreakesLongerThanMinRestTime_LongDrivingMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  local maxDrivingTime = 1           -- minutes
  local minRestTime = 1              -- minutes

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                                {avlPropertiesPINs.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving
  framework.delay(maxDrivingTime*60-20)       -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60+15)                          -- wait longer than minRestTime (multiplied by 60 to get minutes from seconds)

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- terminal moving again
  gateway.setHighWaterMark()                  -- to get the newest messages
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60-20)       -- maxDrivingTime multiplied by 60 to get seconds from minutes


  -- LongDriving Message is not expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  assert_false(next(matchingMessages), "LongDriving report not expected")   -- checking if any LongDriving message has been caught

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end



--- TC checks if LongDriving message is sent when terminal is moving without break for time longer than maxDrivingTime and maxDrivingTime timer
  -- is reseted after report is generated
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state and after time of maxDrivingTime and check if LongDriving
  -- message is sent and report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit, report fields have correct values
function test_LongDriving_WhenTerminalMovingWithoutBreakForPeriodLongerThanMaxDrivingTime_LongDrivingMessageSentMaxDrivingTimeReset()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  local maxDrivingTime = 1           -- minutes
  local minRestTime = 1              -- minutes

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                                {avlPropertiesPINs.minRestTime, minRestTime}
                                             }
                   )
    -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark()                 -- to get the newest messages
  -- waiting until maxDrivingTime limit passes
  framework.delay(maxDrivingTime*60+8)       -- maxDrivingTime multiplied by 60 to get seconds from minutes
  local eventTimeTc = os.time()                    -- to get the correct value in the report
  -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTime = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, totalDrivingTime is expected to be maxDrivingTime
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  gateway.setHighWaterMark()                 -- to get the newest messages
  framework.delay(maxDrivingTime*60+8)       -- to generate second LongDriving event, (maxDrivingTime multiplied by 60 to get seconds from minutes)
  local eventTimeTc = os.time()             -- to get the correct value in the report
  -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTime = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, totalDrivingTime is expected to be maxDrivingTime again (timer reseted)
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end


--- TC checks if LongDriving message is sent when terminal is moving longer than maxDrivingTime and breakes together are longer than
  -- minRestTime but are not continues
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 3 minutes and minRestTime to 3 minutes
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving for time shorter than maxDrivingTime and stop for time shorter than minRestTime
  -- finally simulate driving for time shorter maxDrivingTime (together driving time is longer than maxDrivingTime) and wait until LongDriving message is sent;
  -- check if report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with discontinous breakes longer than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithDiscontinuousBreakesLongerThanMinRestTime_LongDrivingMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 5      -- kmh
  local maxDrivingTime = 3           -- minutes
  local minRestTime = 3              -- minutes

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                                {avlPropertiesPINs.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving
  framework.delay(maxDrivingTime*60-40)       -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60-10)                          -- wait shorter than minRestTime

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60-40)       -- maxDrivingTime multiplied by 60 to get seconds from minutes

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60-10)                          -- wait shorter than minRestTime

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- terminal moving again
  gateway.setHighWaterMark()                  -- to get the newest messages
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60-10)       -- maxDrivingTime multiplied by 60 to get seconds from minutes

  eventTimeTc = os.time()                     -- to get the correct value in the report
    -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.longDriving))
  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTime = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end




--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


