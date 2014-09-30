-----------
-- IO test module
-- - contains digital input/output related test cases
-- @module TestIOModule

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


--- setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets gpsReadInterval (in position service) to the value of gpsReadInterval, sets all 4 ports to low state
  -- and checks if terminal is not in the IgnitionOn state
  -- executed before each unit test
  -- *actions performed:
  -- setting of the gpsReadInterval (in the position service) is made using global gpsReadInterval variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- set all 4 ports to low state and check if terminal is not in the IgnitionOn state
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state and IgnitionOn false state
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
              fixType=3,
              heading = 90,
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

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")

  -- setting all 4 ports to low stare
  for i = 1, 4, 1 do
  device.setIO(i, 0)
  end
  framework.delay(3)

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")


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



--- TC checks if IgnitionOn message is correctly sent when port 1 changes to high state
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait for IgnitionOn message; check if message has been correctly sent, verify reported fields
  -- and check if terminal entered IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the IgnitionOn state, IgnitionOn message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToHigh_IgnitionOnMessageSent()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)

  framework.delay(10)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},              -- line number 1 set for Ignition function
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn

  --IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionON))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

end


--- TC checks if IgnitionOn message is correctly sent when port 1 changes to high state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 1); then simulate port 1 value change to high state and
  -- wait for IgnitionOn message; check if message has been correctly sent, verify reported fields
  -- and check if terminal entered IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the IgnitionOn state, IgnitionOn message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToHigh_IgnitionOnMessageSentGpsFixAgeReported()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 1,                    -- no valid fix provided, gps signal loss simulated
                     }

  gps.set(gpsSettings)
  framework.delay(7)          -- to make sure gpsFix age is above 5 seconds

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},              -- line number 1 set for Ignition function
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn

  --IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionON))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = os.time(),
                  GpsFixAge = 8
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")


end


--- TC checks if IgnitionOff message is correctly sent when port 1 changes to low state
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 3);
  -- then simulate port 1 value change to high state and check if
  -- terminal enters IgnitionOn state; then simulate port 1 value change to low state and
  -- wait for IgnitionOff message; check if message has been correctly sent, verify reported fields
  -- and check if terminal is no longer in IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put to IgnitionOn false state, IgnitionOff message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToLow_IgnitionOffMessageSent()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},         -- line number 1 set for Ignition function
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- wait for report to be generated

  --IgnitionOff message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionOFF))

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOff",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- checking if terminal correctly goes to IgnitionOn false state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

end


--- TC checks if IgnitionOff message is correctly sent when port 1 changes to low state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation
  -- then simulate port 1 value change to high state and check if
  -- terminal enters IgnitionOn state; then simulate port 1 value change to low state and
  -- wait for IgnitionOff message; check if message has been correctly sent, verify reported fields
  -- and check if terminal is no longer in IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put to IgnitionOn false state, IgnitionOff message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToLow_IgnitionOffMessageSentGpsFixAgeReported()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 1,                    -- no valid fix provided, gps signal loss simulated
                     }

  gps.set(gpsSettings)
  framework.delay(5)          -- to make sure gpsFix age is above 5 seconds

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- wait for report to be generated

  --IgnitionOff message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionOFF))

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOff",
                  currentTime = os.time(),
                  GpsFixAge = 13
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- checking if terminal correctly goes to IgnitionOn false state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

end

--- TC checks if IdlingStart message is correctly sent when terminal is in stationary state and IgnitionON state is true
  -- for longer than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation
  -- then simulate port 1 value change to high state and  wait until IgnitionOn is true;
  -- then wait until maxIdlingTime passes and check if message IdlingStart has been correctly sent,
  -- verify reported fields and check if terminal entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the EngineIdling state, IdlingStart message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTime_IdlingStartMessageSent()

  local maxIdlingTime = 1  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, good quality of gps signal
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )


  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()
  timeOfEventTC = os.time()
  device.setIO(1, 1)                              -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+8)   -- wait longer than maxIdlingTime to trigger the IdlingStart event, coldFixDelay taken into consideration

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- IgnitionOn state expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))

  --IdlingStart message not expected
  assert_true(next(filteredMessages), "IdlingStart message not received")  -- checking if IdlingEnd message was received, if not that is not correct

  idlingStartMessage = filteredMessages[1]

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingStart",
                  currentTime = timeOfEventTC,
                        }
  avlHelperFunctions.reportVerification(idlingStartMessage, expectedValues ) -- verification of the report fields

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")


end


--- TC checks if IdlingStart message is correctly sent when terminal is in stationary state and IgnitionON state is true
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- for longer than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- set the high state of the port to be a trigger for line activation
  -- then simulate port 1 value change to high state and  wait until IgnitionOn is true;
  -- then wait until maxIdlingTime passes and check if message IdlingStart has been correctly sent,
  -- verify reported fields and check if terminal entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the EngineIdling state, IdlingStart message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTime_IdlingStartMessageSentGpsFixAgeReported()

  local maxIdlingTime = 1  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 1,                    -- no valid fix provided, gps signal loss simulated
                     }

  gps.set(gpsSettings)
  framework.delay(6)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()
  timeOfEventTC = os.time()
  device.setIO(1, 1)                              -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+avlAgentCons.coldFixDelay+2)   -- wait longer than maxIdlingTime to trigger the IdlingStart event, coldFixDelay taken into consideration

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- IgnitionOn state expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))

  --IdlingStart message not expected
  assert_true(next(filteredMessages), "IdlingStart message not received")  -- checking if IdlingEnd message was received, if not that is not correct

  idlingStartMessage = filteredMessages[1]

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingStart",
                  currentTime = timeOfEventTC,
                  GpsFixAge = 6
                        }
  avlHelperFunctions.reportVerification(idlingStartMessage, expectedValues ) -- verification of the report fields

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")


end



--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and IgnitionOn state becomes false
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line, set the high state
  -- of the port to be a trigger for line activation; then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 1 change to low level (IgnitionOff) and check if IdlingEnd message is correctly sent and EngineIdling
  -- state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccurs_IdlingEndMessageSent()

  local maxIdlingTime = 5 -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                  -- valid fix provided, good quality of gps signal
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1)                       -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+3)            -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")


  device.setIO(1, 0)                                      -- port 1 to LOW level - that should trigger IgnitionOff
  framework.delay(3)

  -- IgnitionOff and IdlingEnd messages expected
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingEnd))
  local idlingEndMessage = filteredMessages[1]              -- that is performed because of the structure of the filteredMessages
  assert_true((next(idlingEndMessage)), "IdlingEnd message not received")  -- checking if IdlingEnd message was received, if not that is not correct

  if((next(idlingEndMessage))) then              -- if IdlingEnd message has been received it is verified
  gpsSettings.heading = 361                       -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = os.time()
                        }
  avlHelperFunctions.reportVerification(idlingEndMessage, expectedValues ) -- verification of the all report fields
  end

  -- checking if terminal correctly goes out of EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and IgnitionOn state becomes false
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line, set the high state
  -- of the port to be a trigger for line activation; then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 1 change to low level (IgnitionOff) and check if IdlingEnd message is correctly sent and EngineIdling
  -- state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccurs_IdlingEndMessageSentGpsFixReported()

  local maxIdlingTime = 1 -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- configuration of GPS settings
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 1,                    -- valid fix provided, good quality of gps signal
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1)                                         -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+8) -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")

  --simulating gps signal loss,
  local gpsSettings={
                    speed = 0,                      -- terminal in stationary state
                    latitude = 1,                   -- degrees
                    longitude = 1,                  -- degrees
                    fixType = 1,                    -- no valid fix provided, gps signal loss simulated
                     }

  gps.set(gpsSettings)

  local timeOfEvent = os.time()
  device.setIO(1, 0)                                      -- port 1 to LOW level - that should trigger IgnitionOff
  framework.delay(avlAgentCons.coldFixDelay+3)            -- coldFixDelay taken into consideration

  -- IgnitionOff and IdlingEnd messages expected
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingEnd))
  local idlingEndMessage = filteredMessages[1]              -- that is performed because of the structure of the filteredMessages
  assert_true((next(idlingEndMessage)), "IdlingEnd message not received")  -- checking if IdlingEnd message was received, if not that is not correct

  if((next(idlingEndMessage))) then              -- if IdlingEnd message has been received it is verified
  gpsSettings.heading = 361                       -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = timeOfEvent,
                  GpsFixAge = 13
                        }
  avlHelperFunctions.reportVerification(idlingEndMessage, expectedValues ) -- verification of the all report fields
  end

  -- checking if terminal correctly goes out of EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and it starts moving (MovingStart sent)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line, set the high state
  -- of the port to be a trigger for line activation; then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- after that simulate gps speed above stationarySpeedThld for longer then movingDebounceTime to put the terminal into moving state
  -- check if IdlingEnd message is correctly sent and EngineIdling state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalInEngineIdlingStateAndMovingStateBecomesTrue_IdlingEndMessageSent()

  local maxIdlingTime = 5           -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message
  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh

  -- gpsSettings are configured and used in the TC
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType=3
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime},                          -- maximum idling time allowed without sending idling report
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},              -- stationary speed threshold
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},                -- moving debounce time
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1)                       -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+3)         -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")

  -- now moving start should be simulated, gps settings are changed
  local gpsSettings={
              speed = 10,                     -- above movingDebounceTime
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType=3,                      -- valid fix
              heading = 90                    -- degrees
                     }

  gps.set(gpsSettings)                  -- gps settings are applied
  framework.delay(movingDebounceTime+4) -- wait until MovingStart and IdlingEnd messages are genarated

  -- MovingStart and IdlingEnd messages expected
  receivedMessages = gateway.getReturnMessages()            -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingEnd))
  local idlingEndMessage = filteredMessages[1]                            -- that is performed because of the structure of the filteredMessages
  -- TODO: this need to be done in different way
  assert_true((next(idlingEndMessage)), "IdlingEnd message not received")  -- checking if IdlingEnd message was received, if not that is not correct

  if((next(idlingEndMessage))) then                    -- if IdlingEnd message has been received it is verified
  local expectedValues={                               -- expected values of the fields in the report
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = os.time()
                        }
  avlHelperFunctions.reportVerification(idlingEndMessage, expectedValues ) -- verification of the all report fields

  end
  -- checking if terminal correctly goes out of EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if IdlingStart message is not sent when terminal is in stationary state and IgnitionON state is true
  -- for time shorter than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2);
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 3);
  -- then simulate port 1 value change to high state to get the IgnitionOn state is true; then wait shorter
  -- than maxIdlingTime and check if message IdlingStart has not been sent and check if terminal has not entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal does not enter the EngineIdling state, IdlingStart message not sent

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodBelowMaxIdlingTime_IdlingMessageNotSent()

  local maxIdlingTime = 15  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})


  gateway.setHighWaterMark()         -- to get all messages after changing port state from low to high
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(6)                 -- IgnitionOn report generated, terminal in IgnitionOn state only for about 6 seconds (shorter than defined maxIdlingTime)
  device.setIO(1, 0)                 -- port 1 to low level - that should trigger IgnitionOff

  receivedMessages = gateway.getReturnMessages()            -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))

  --IdlingStart message not expected
  assert_false(next(filteredMessages), "IdlingStart message not expected")  -- checking if IdlingEnd message was received, if not that is not correct

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if MovingEnd message is sent when terminal is in moving state and IgnitionOff event occurs
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3);set movingDebounceTime to 20 seconds and stationarySpeedThld to 5 kmh
  -- then then simulate port 1 value change to high state to get the IgnitionOn state true;
  -- after that simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if the moving state has been obtained; when terminal is in the moving state simulate
  -- port 1 change to low level to trigger IgnitionOff event and check if MovingEnd message is sent
  -- and terminal is no longer in the moving state after that
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval,
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the stationary and IgnitionOFF state, MovingEnd message sent

function test_Ignition_WhenTerminalInMovingStateAndIgnitionOffEventOccurs_MovingEndMessageSent()

  local movingDebounceTime = 20       -- seconds
  local stationarySpeedThld = 5       -- kmh

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
                                                {avlPropertiesPINs.funcDigInp1, 2},              -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3},       -- high state is expected to trigger Ignition on
                                             }
                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                  )

  -- first terminal is put into moving state
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+gpsReadInterval+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- then terminal is put into IgnitionOn state
  device.setIO(1, 1)                          -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(3)                          -- delay to let the event to be generated

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")


  -- when the terminal is in the moving state IgnitionOff event is genarated
  gateway.setHighWaterMark()                  -- to get the newest messages
  device.setIO(1, 0)                          -- port 1 to low level - that should trigger IgnitionOff
  framework.delay(3)                          -- delay to let the event to be generated

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()

  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  local ignitionOffMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionOFF))

  -- checking if expected messages has been received
  assert_not_nil(next(movingEndMessage), "MovingEnd message not received")              -- if MovingEnd message not received assertion fails
  assert_not_nil(next(ignitionOffMessage), "IgnitionOff message not received")          -- if IgnitionOff message not received assertion fails

  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(tonumber(ignitionOffMessage[1].Payload.EventTime), tonumber(movingEndMessage[1].Payload.EventTime), 1, "Timestamps of IgnitionOff and MovingEnd messages expected to be equal with 1 second tolerance")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of IgnitionOff and MovingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: MovingEnd ReceiveUTC = "2014-09-03 07:56:37" and IgnitionOff MessageUTC = "2014-09-03 07:56:42" - that is correct

  -- checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")
  -- checking the state of terminal, moving state is not ecpected
   assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")


end


--- TC checks if MovingEnd and SpeedingEnd messages are sent when terminal is in speeding state and IgnitionOff event occurs
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); set movingDebounceTime to 5 seconds,  stationarySpeedThld to 5 kmh
  -- defaultSpeedLimit to 80  kmh and SpeedingTimeOver to 20 seconds
  -- then simulate port 1 value change to high state to get the IgnitionOn state true;
  -- after that simulate speed above defaultSpeedLimit for time longer than speedingTimeOver
  -- and check if the speeding state has been obtained; when terminal is in the speeding state simulate
  -- port 1 change to low level to trigger IgnitionOff event and check if MovingEnd and SpeedingEnd messages are sent
  -- and terminal is no longer in the speeding state after that
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval,
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the stationary and IgnitionOFF state, SpedingEnd and MovingEnd messages sent

function test_Ignition_WhenTerminalInSpeedingStateAndIgnitionOffEventOccurs_MovingEndAndSpeedingEndMessagesSent()

  local movingDebounceTime = 20       -- seconds
  local stationarySpeedThld = 5       -- kmh
  local defaultSpeedLimit = 80        -- kmh
  local speedingTimeOver = 1         -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = defaultSpeedLimit+10,   -- 10 kmh above threshold of speeding
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},              -- stationary speed threshold
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},                -- moving debounce time
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                  )

  -- first terminal is put into moving state
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- gps settings applied,
  framework.delay(movingDebounceTime+speedingTimeOver+gpsReadInterval+6)     -- 5 seconds are added as prior to SpeedingStart there will be movingStart message sent

  --checking if terminal is in the speeding state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the Speeding state")

  -- then terminal is put into IgnitionOn state
  device.setIO(1, 1)                          -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(3)                          -- delay to let the event to be generated

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")


  -- when the terminal is in the speeding state IgnitionOff event is genarated
  gateway.setHighWaterMark()                  -- to get the newest messages
  device.setIO(1, 0)                          -- port 1 to low level - that should trigger IgnitionOff
  framework.delay(5)                          -- delay to let the event to be generated

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()

  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingEnd))
  local ignitionOffMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionOFF))
  local speedingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))

  -- checking if expected messages has been received
  assert_not_nil(next(movingEndMessage), "MovingEnd message not received")              -- if MovingEnd message not received assertion fails
  assert_not_nil(next(ignitionOffMessage), "IgnitionOff message not received")          -- if IgnitionOff message not received assertion fails
  assert_not_nil(next(speedingEndMessage), "SpeedingEnd message not received")          -- if SpeedingEnd message not received assertion fails


  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(tonumber(ignitionOffMessage[1].Payload.EventTime), tonumber(speedingEndMessage[1].Payload.EventTime), 1, "Timestamps of IgnitionOff and SpeedingEnd messages expected to be equal with 1 second tolerance")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of IgnitionOff and SpeedingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: SpeedingEnd ReceiveUTC = "2014-09-03 07:56:37" and IgnitionOff MessageUTC = "2014-09-03 07:56:42" - that is correct

  -- checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")
  -- checking the state of terminal, moving state is not ecpected
   assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the moving state")

end



--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and one of Service Meters lines
  -- goes to active state
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2), set the high state
  -- of the port to be a trigger for line activation (digStatesDefBitmap = 5); configure port 2 as a digital input and associate
  -- this port with SM1 line (funcDigInp2 = 5);  then simulate port 1 value change to high state and wait until IgnitionOn is true;
  -- then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 2 change to high level (SM1 = ON) and check if IdlingEnd message is correctly sent and EngineIdling state becomes false;
  -- also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndServiceMeterLineBecomesActive_IdlingEndMessageSent()

  local maxIdlingTime = 1 -- in seconds, time in which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
                     }

  gps.set(gpsSettings)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},      -- port 1 as digital input
                                                {avlPropertiesPINs.port2Config, 3},      -- port 2 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3},  -- detection for both rising and falling edge
                                                {avlPropertiesPINs.port2EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SM1"]},          -- line number 2 set for ServiceMeter1 function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime},                         -- maximum idling time allowed without sending idling report

                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SM1Active"})

  gateway.setHighWaterMark()                -- to get the newest messages

  device.setIO(1, 1)                        -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+10)         -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)

  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")


  device.setIO(2, 1)                        -- port 2 to high level - that should trigger SM1=ON
  framework.delay(4)


  --IdlingEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingEnd))

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- checking if terminal correctly goes out from EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if IdlingStart message is not sent when terminal is in stationary state and IgnitionON state is true
  -- for time longer than maxIdlingTime but one Service Meter line (SM1) is active
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2),
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 5);
  -- configure port 2 as a digital input and associate this port with SM1 line (funcDigInp2 = 5);
  -- simulate port 1 value change to high (SM1 = ON) and then change port 1 value to high state to get the IgnitionOn state and
  -- wait longer than maxIdlingTime; after that check if message IdlingStart has not been sent and check if terminal has not
  -- entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal does not enter the EngineIdling state, IdlingStart message not sent

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTimeButServiceMeterLineActive_IdlingMessageNotSent()

  local maxIdlingTime = 1  -- in seconds, time in which terminal can be in IgnitionOn state without sending IdlingStart message

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},      -- port 1 as digital input
                                                {avlPropertiesPINs.port2Config, 3},      -- port 2 as digital input
                                                {avlPropertiesPINs.port1EdgeSampleCount,0},
                                                {avlPropertiesPINs.port1EdgeDetect, 3},  -- detection for both rising and falling edge
                                                {avlPropertiesPINs.port2EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }

                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},      -- port 1 as digital input
                                                {avlPropertiesPINs.port2Config, 3},      -- port 2 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3},  -- detection for both rising and falling edge
                                                {avlPropertiesPINs.port2EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SM1"]},   -- line number 2 set for ServiceMeter1 function
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime},                         -- maximum idling time allowed without sending idling report

                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SM1Active"})

  gateway.setHighWaterMark()                -- to get the newest messages

  device.setIO(2, 1)                        -- that triggers SM = ON (Service Meter line active)
  framework.delay(5)                        -- to make sure event has been generated before further actions
  device.setIO(1, 1)                        -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+10)         -- wait longer than maxIdlingTime to try to trigger the IdlingStart event

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))

  --IdlingStart message not expected
  assert_false(next(filteredMessages), "IdlingStart message not expected")  -- checking if IdlingEnd message was received, if not that is not correct

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end




--- TC checks if SeatbeltViolationStart message is correctly sent when terminal is moving and SeatbeltOFF line
  -- becomes active and stays active for time longer than seatbeltDebounceTime (driver unfastens belt during the ride)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 10       -- seconds

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90                    -- deegres
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+3)

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  gateway.setHighWaterMark()                -- to get the newest messages
  device.setIO(2, 1)                        -- port 2 to high level - that triggers SeatbeltOff true
  framework.delay(seatbeltDebounceTime+3)   -- to make sure seatbeltDebounceTime passes

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is correctly sent when terminal starts moving and SeatbeltOFF line
  -- is active for time longer than seatbeltDebounceTime (driver starts ride and does not fasten seatbelt)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalStartsMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 10       -- seconds

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})


  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90                    -- deegres
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+3)

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  gateway.setHighWaterMark()         -- to get the newest messages
  framework.delay(seatbeltDebounceTime) -- to make sure seatbeltDebounceTime passes

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is correctly sent when terminal is moving and SeatbeltOFF line is active for time
  -- longer than seatbeltDebounceTime and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSentGpsFixAgeReported()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 15       -- seconds


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})


  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90                    -- deegres
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+3)

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  local timeOfEvent = os.time()
  gpsSettings.fixType = 1                    -- no valid fix provided from now
  gps.set(gpsSettings)                       -- applying gps setttings
  framework.delay(7)                         -- to make sure gps fix is older than 5 seconds related to EventTime
  gateway.setHighWaterMark()                 -- to get the newest messages
  framework.delay(seatbeltDebounceTime)      -- to make sure seatbeltDebounceTime passes

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationStart))


  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEvent,
                  GpsFixAge = 8
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is not sent when terminal is moving and SeatbeltOFF line
  -- is active for time shorter than seatbeltDebounceTime
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that simulate port 2 value change to high state to make SeatbeltOff
  -- line active but for time shorter than seatbeltDebounceTime;
  -- check if SeatbeltViolationStart message is not sent and terminal does not go to SeatbeltViolation state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal not put in the SeatbeltViolation state, SeatbeltViolationStart message not sent
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- moving state related properties
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 15        -- seconds



  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})


  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10,      -- speed above stationarySpeedThld
              latitude = 1,                        -- degrees
              longitude = 1,                       -- degrees
              fixType = 3,                         -- valid fix provided, no GpsFixAge expected in the report
              heading = 90                         -- deegres
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+4)

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")

  gateway.setHighWaterMark()               -- to get the newest messages

  device.setIO(2, 1)                       -- port 2 to high level - that triggers SeatbeltOff true
  framework.delay(seatbeltDebounceTime-5)  -- time shorter than seatbeltDebounceTime
  device.setIO(2, 0)                       -- port 2 to low level - that triggers SeatbeltOff false

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationStart))

  --SeatbeltViolationStart message not expected
  assert_false(next(filteredMessages), "SeatbeltViolationStart message not expected")  -- checking if SeatbeltViolationStart message was received, if not that is not correct

  -- checking if terminal has not entered SeatbeltViolation state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolationf state")

end


--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and SeatbeltOff line becomes inactive (driver fastened belt)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state;  then simulate port 2 value change to low
  -- (SeatbeltOff line becomes inactive) and check if terminal goes out of SeatbeltViolation state,
  -- SeatbeltViolationEnd message is sent and reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndSeatbeltOffLineBecomesInactive_SeatbeltltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 1       -- seconds


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})


  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90                    -- deegres
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+5)

  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")

  gateway.setHighWaterMark()           -- to get the newest messages
  device.setIO(2, 0)                   -- port 2 to low level - that triggers SeatbeltOff false, belt fastened
   framework.delay(3)                  -- wait for the message to be processed

  -- SeatbeltViolationEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationEnd))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolationStart state")


end



--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and it stops moving (movingEng message sent)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate speed = 0 (terminal stops) and check if
  -- terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported fields have
  -- correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndMovingStateBecomesFalse_SeatbeltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 1        -- seconds


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})

  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+5)

  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")

  gateway.setHighWaterMark()           -- to get the newest messages

  gpsSettings.speed = 0                -- terminal stops
  gps.set(gpsSettings)
  framework.delay(6)                                      -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationEnd))
  assert_true(next(filteredMessages), "SeatbeltViolationEnd report not received")   -- checking if SeatbeltViolationEnd message has been caught

  seatbeltViolationEndMessage = filteredMessages[1]   -- that is due to structure of the filteredMessages
  gpsSettings.heading = 361                            -- 361 is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(seatbeltViolationEndMessage, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and it IgnitionOff event occurs
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3); configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for these two lines activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state to make terminal IgnitionON = true
  -- and simulate port 2 value change to high state to make SeatbeltOff line active;
  -- then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate port 1 value change to low to generate IgnitionOff event
  -- and  and check if terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported
  -- fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndIgnitionOnStateBecomesFalse_SeatbeltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 15          -- seconds
  local stationarySpeedThld = 5          -- kmh
  local seatbeltDebounceTime = 15        -- seconds


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})

  device.setIO(1, 1)                         -- port 1 to high level - that should trigger IgnitionOn
  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+17)     -- movingDebounceTime plus time for messages to be processed

  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")

  gateway.setHighWaterMark()                              -- to get the newest messages

  device.setIO(1, 0)                                      -- port 1 to low level - that should trigger IgnitionOff
  local timeOfEvent = os.time()
  framework.delay(10)                                     -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationEnd))
  assert_true(next(filteredMessages), "SeatbeltViolationEnd report not received")   -- checking if SeatbeltViolationEnd message has been caught

  seatbeltViolationEndMessage = filteredMessages[1]   -- that is due to structure of the filteredMessages

  gpsSettings.heading = 361                           -- 361 is for stationary state
  gpsSettings.speed = 0                               -- after IgnitionOff stationary state is expected
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = timeOfEvent
                        }

  avlHelperFunctions.reportVerification(seatbeltViolationEndMessage, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationEnd message is correctly sent (for terminal is in SeatbeltViolation state) when
  -- IgnitionOff event occurs and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp2 = 3); configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for these two lines activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state to make terminal IgnitionON = true
  -- and simulate port 2 value change to high state to make SeatbeltOff line active;
  -- then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate port 1 value change to low to generate IgnitionOff event
  -- and  and check if terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported
  -- fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndIgnitionOnStateBecomesFalse_SeatbeltViolationEndMessageSentGpsFixAgeReported()

  -- properties values to be used in TC
  local movingDebounceTime = 15          -- seconds
  local stationarySpeedThld = 5          -- kmh
  local seatbeltDebounceTime = 15        -- seconds


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
                                             }
                   )

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SeatbeltOff"})


  device.setIO(1, 1)                         -- port 1 to high level - that should trigger IgnitionOn
  device.setIO(2, 1)                         -- port 2 to high level - that triggers SeatbeltOff true

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
              heading = 90
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+17)     -- movingDebounceTime plus time for messages to be processed

  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")
  gpsSettings.fixType = 1                                 -- no valid fix provided from now
  gps.set(gpsSettings)                                    -- applying gps settings
  framework.delay(6)                                      -- to make sure gps fix is older than 5 seconds related to EventTime
  gateway.setHighWaterMark()                              -- to get the newest messages

  device.setIO(1, 0)                                      -- port 1 to low level - that should trigger IgnitionOff
  local timeOfEvent = os.time()
  framework.delay(10)                                     -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationEnd))
  assert_true(next(filteredMessages), "SeatbeltViolationEnd report not received")   -- checking if SeatbeltViolationEnd message has been caught

  seatbeltViolationEndMessage = filteredMessages[1]   -- that is due to structure of the filteredMessages

  gpsSettings.heading = 361                           -- 361 is for stationary state
  gpsSettings.speed = 0                               -- after IgnitionOff stationary state is expected
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = timeOfEvent,
                  GpsFixAge = 6                       -- GpsFixAge is expected in the report
                        }

  avlHelperFunctions.reportVerification(seatbeltViolationEndMessage, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")

end




--- TC checks if DigInp1Hi message is sent when port 1 state changes from low to high
  -- *actions performed:
  -- Configure port 1 as a digital input and set General Purpose as function for digital input line number 1
  -- simulate terminal moving and change state of digital port 1 from low to high; check if DigInp1Hi message
  -- has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp1Hi message sent when port changes state from low to high
function test_DigitalInput_WhenTerminalMovingAndPort1StateChangesFromLowToHigh_DigInp1HiMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 1 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(1, 1)                                       -- set port 1 to high level - that should trigger DigInp1Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp1Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp1Hi))
  assert_true(next(filteredMessages), "DigInp1Hi report not received")   -- checking if digitalInp1Hi message has been caught, if not assertion fails
  digitalInp1HiMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp1Hi",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp1HiMessage, expectedValues) -- verification of the report fields


end


--- TC checks if DigInp1Lo message is sent when port 1 state changes from high to low
  -- *actions performed:
  -- Configure port 1 as a digital input and set General Purpose as function for digital input line number 1
  -- simulate terminal moving and change state of digital port 1 from low to high; then change it  back from high to low
  -- and check if DigInp1Lo message has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp1Lo message sent when port changes state from high to low
function test_DigitalInput_WhenTerminalMovingAndPort1StateChangesFromHighToLow_DigInp1LoMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}, -- port 1 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 1 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(1, 1)                                       -- set port 1 to high level - that should trigger DigInp1Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(1, 0)                                       -- set port 1 to low level - that should trigger DigInp1Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp1Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp1Lo))
  assert_true(next(filteredMessages), "DigInp1Lo report not received")   -- checking if digitalInp1Lo message has been caught, if not assertion fails
  digitalInp1LoMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp1Lo",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp1LoMessage, expectedValues) -- verification of the report fields


end




--- TC checks if DigInp2Hi message is sent when port 2 state changes from low to high
  -- *actions performed:
  -- Configure port 2 as a digital input and set General Purpose as function for digital input line number 2
  -- simulate terminal moving and change state of digital port 2 from low to high; check if DigInp2Hi message
  -- has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp2Hi message sent when port changes state from low to high
function test_DigitalInput_WhenTerminalMovingAndPort2StateChangesFromLowToHigh_DigInp2HiMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}, -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 2 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(2, 1)                                       -- set port 2 to high level - that should trigger DigInp2Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp2Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp2Hi))
  assert_true(next(filteredMessages), "DigInp2Hi report not received")   -- checking if digitalInp2Hi message has been caught, if not assertion fails
  digitalInp2HiMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp2Hi",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp2HiMessage, expectedValues) -- verification of the report fields


end



--- TC checks if DigInp2Lo message is sent when port 2 state changes from high to low
  -- *actions performed:
  -- Configure port 2 as a digital input and set General Purpose as function for digital input line number 2
  -- simulate terminal moving and change state of digital port 2 from low to high; then change it  back from high to low
  -- and check if DigInp2Lo message has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp2Lo message sent when port changes state from high to low
function test_DigitalInput_WhenTerminalMovingAndPort2StateChangesFromHighToLow_DigInp2LoMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port2Config, 3},     -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3}, -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 2 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(2, 1)                                       -- set port 2 to high level - that should trigger DigInp2Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(2, 0)                                       -- set port 2 to low level - that should trigger DigInp2Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp2Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp2Lo))
  assert_true(next(filteredMessages), "DigInp2Lo report not received")   -- checking if digitalInp2Lo message has been caught, if not assertion fails
  digitalInp2LoMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp2Lo",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp2LoMessage, expectedValues) -- verification of the report fields


end



--- TC checks if DigInp3Hi message is sent when port 3 state changes from low to high
  -- *actions performed:
  -- Configure port 3 as a digital input and set General Purpose as function for digital input line number 3
  -- simulate terminal moving and change state of digital port 3 from low to high; check if DigInp3Hi message
  -- has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp2Hi message sent when port changes state from low to high
function test_DigitalInput_WhenTerminalMovingAndPort3StateChangesFromLowToHigh_DigInp3HiMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port3Config, 3},    -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3}, -- port 3 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 3 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(3, 1)                                       -- set port 3 to high level - that should trigger DigInp3Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp3Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp3Hi))
  assert_true(next(filteredMessages), "DigInp3Hi report not received")   -- checking if digitalInp3Hi message has been caught, if not assertion fails
  digitalInp3HiMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp3Hi",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp3HiMessage, expectedValues) -- verification of the report fields


end



--- TC checks if DigInp3Lo message is sent when port 3 state changes from high to low
  -- *actions performed:
  -- Configure port 3 as a digital input and set General Purpose as function for digital input line number 3
  -- simulate terminal moving and change state of digital port 3 from low to high; then change it  back from high to low
  -- and check if DigInp3Lo message has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp3Lo message sent when port changes state from high to low
function test_DigitalInput_WhenTerminalMovingAndPort3StateChangesFromHighToLow_DigInp3LoMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld + 10, -- to simulate terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided
              heading = 90                      -- heading in degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port3Config, 3},     -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3}, -- port 3 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 3 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(3, 1)                                       -- set port 3 to high level - that should trigger DigInp3Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(3, 0)                                       -- set port 3 to low level - that should trigger DigInp3Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp3Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp3Lo))
  assert_true(next(filteredMessages), "DigInp3Lo report not received")   -- checking if digitalInp3Lo message has been caught, if not assertion fails
  digitalInp3LoMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp3Lo",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp3LoMessage, expectedValues) -- verification of the report fields


end






--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


