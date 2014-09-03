--[[

  TestIOModule.lua


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
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait for IgnitionOn message; check if message has been correctly sent, verify reported fields
  -- and check if terminal entered IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the IgnitionOn state, IgnitionOn message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToHighIgnitionOnMessageSent()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
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
                                                {avlPropertiesPINs.funcDigInp1, 2},        -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3}  -- high state is expected to trigger Ignition on
                                             }
                   )

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


--- TC checks if IgnitionOff message is correctly sent when port 1 changes to low state
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and check if
  -- terminal enters IgnitionOn state; then simulate port 1 value change to low state and
  -- wait for IgnitionOff message; check if message has been correctly sent, verify reported fields
  -- and check if terminal is no longer in IgnitionOn state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put to IgnitionOn false state, IgnitionOff message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToLowIgnitionOffMessageSent()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
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
                                                {avlPropertiesPINs.funcDigInp1, 2},        -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3}  -- high state is expected to trigger Ignition on
                                             }
                   )

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


--- TC checks if IdlingStart message is correctly sent when terminal is in stationary state and IgnitionON state is true
  -- for longer than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and  wait until IgnitionOn is true;
  -- then wait until maxIdlingTime passes and check if message IdlingStart has been correctly sent,
  -- verify reported fields and check if terminal entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the EngineIdling state, IdlingStart message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTimeIdlingMessageSent()

  local maxIdlingTime = 20  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
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
                                              {avlPropertiesPINs.funcDigInp1, 2},              -- line number 1 set for Ignition function
                                              {avlPropertiesPINs.digStatesDefBitmap, 3},       -- high state is expected to trigger Ignition on
                                              {avlPropertiesPINs.maxIdlingTime, maxIdlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(5)                 -- waiting for IgnitionOn report generated

  -- IgnitionOn state expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  gateway.setHighWaterMark()
   framework.delay(maxIdlingTime+2)       -- wait longer than maxIdlingTime to trigger the IdlingStart event

  --IdlingStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingStart",
                  currentTime = os.time()
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- checking if terminal correctly goes to EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")

end

--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and IgnitionOn state becomes false
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2), set the high state
  -- of the port to be a trigger for line activation (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 1 change to low level (IgnitionOff) and check if IdlingEnd message is correctly sent and EngineIdling
  -- state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccursIdlingEndMessageSent()

  local maxIdlingTime = 5 -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
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
                                              {avlPropertiesPINs.funcDigInp1, 2},           -- line number 1 set for Ignition function
                                              {avlPropertiesPINs.digStatesDefBitmap, 3},    -- high state is expected to trigger Ignition on
                                              {avlPropertiesPINs.maxIdlingTime, maxIdlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

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


--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and it starts moving (MovingStart sent)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2), set the high state
  -- of the port to be a trigger for line activation (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- after that simulate gps speed above stationarySpeedThld for longer then movingDebounceTime to put the terminal into moving state
  -- check if IdlingEnd message is correctly sent and EngineIdling state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalInEngineIdlingStateAndMovingStateBecomesTrueIdlingEndMessageSent()

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
                                              {avlPropertiesPINs.funcDigInp1, 2},               -- line number 1 set for Ignition function
                                              {avlPropertiesPINs.digStatesDefBitmap, 3},        -- high state is expected to trigger Ignition on
                                              {avlPropertiesPINs.maxIdlingTime, maxIdlingTime}, -- maximum idling time allowed without sending idling report
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},      -- stationary speed threshold
                                              {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},        -- moving debounce time

                                             }
                   )

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

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodBelowMaxIdlingTimeIdlingMessageNotSent()

  local maxIdlingTime = 15  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.funcDigInp1, 2},              -- line number 1 set for Ignition function
                                              {avlPropertiesPINs.digStatesDefBitmap, 3},       -- high state is expected to trigger Ignition on
                                              {avlPropertiesPINs.maxIdlingTime, maxIdlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

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

function test_Ignition_WhenTerminalInMovingStateAndIgnitionOffEventOccursMovingEndMessageSent()

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
  assert_equal(ignitionOffMessage[1].Payload.EventTime, movingEndMessage[1].Payload.EventTime, 0, "Timestamps of IgnitionOff and MovingEnd messages expected to be equal")

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

function test_Ignition_WhenTerminalInSpeedingStateAndIgnitionOffEventOccursMovingEndAndSpeedingEndMessagesSent()

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

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.funcDigInp1, 2},                -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3},         -- high state is expected to trigger Ignition on
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},

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
  assert_equal(ignitionOffMessage[1].Payload.EventTime, speedingEndMessage[1].Payload.EventTime, 0, "Timestamps of IgnitionOff and SpeedingEnd messages expected to be equal")

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
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndServiceMeterLineBecomesActiveIdlingEndMessageSent()

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
                                                {avlPropertiesPINs.funcDigInp1, 2},        -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, 5},        -- line number 2 set for ServiceMeter1 function
                                                {avlPropertiesPINs.digStatesDefBitmap, 5},  -- high state is expected to trigger IgnitionOn and SM1
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime},
                                             }
                   )


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

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTimeButServiceMeterLineActiveIdlingMessageNotSent()

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
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, 2},         -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp2, 5},         -- line number 2 set for ServiceMeter1 function
                                                {avlPropertiesPINs.digStatesDefBitmap, 5},  -- high state is expected to trigger IgnitionOn and SM1
                                                {avlPropertiesPINs.maxIdlingTime, maxIdlingTime},
                                             }
                   )


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



--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


