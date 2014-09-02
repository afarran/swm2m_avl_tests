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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the IgnitionOn state, IgnitionOn message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToHighIgnitionOnMessageSent()

  -- gpsSettings are configured only to check if these are correctly reported in message
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
  print(framework.dump(message))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

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
  -- terminal correctly put in out of the IgnitionOn state, IgnitionOff message sent and report fields
  -- have correct values
function test_Ignition_WhenPortValueChangesToLowIgnitionOffMessageSent()

  -- gpsSettings are configured only to check if these are correctly reported in message
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

  print(framework.dump(message))
  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOff",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- checking if terminal correctly goes out from IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

end


--- TC checks if IdlingStart message is correctly sent when terminal is in stationary state and IgnitionON state is true
  -- for longer than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if message IdlingStart has been correctly sent,
  -- verify reported fields and check if terminal entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the EngineIdling state, IdlingStart message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTimeIdlingMessageSent()

  local idlingTime = 20  --  in seconds - period of time after which IdlingStart event should be genarated

  -- gpsSettings are configured
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
                                              {avlPropertiesPINs.maxIdlingTime, idlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(5)                 -- IgnitionOn report generated

  -- IgnitionOn state expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  gateway.setHighWaterMark()
   framework.delay(idlingTime+2)       -- wait longer than idlingTime to trigger the IdlingStart event

  --IdlingStart message expected
  --receivedMessages = gateway.getReturnMessages()
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
  -- then simulate port 1 change to low level and check if IdlingEnd message is correctly sent and EngineIdling state becomes false;
  -- also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccursIdlingEndMessageSent()

  local idlingTime = 5  --  in seconds - period of time after which IdlingStart event should be genarated

  -- gpsSettings are configured
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
                                              {avlPropertiesPINs.maxIdlingTime, idlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

  device.setIO(1, 1)                       -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(idlingTime+3)            -- wait longer than idlingTime to trigger the IdlingStart event

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

  local idlingTime = 5  --  in seconds - period of time after which IdlingStart event should be genarated
  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh

  -- gpsSettings are configured
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
                                              {avlPropertiesPINs.funcDigInp1, 2},           -- line number 1 set for Ignition function
                                              {avlPropertiesPINs.digStatesDefBitmap, 3},    -- high state is expected to trigger Ignition on
                                              {avlPropertiesPINs.maxIdlingTime, idlingTime}, -- maximum idling time allowed without sending idling report
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},        -- stationary speed threshold
                                              {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},          -- moving debounce time

                                             }
                   )

  device.setIO(1, 1)                       -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(idlingTime+3)            -- wait longer than idlingTime to trigger the IdlingStart event

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
  local idlingEndMessage = filteredMessages[1]              -- that is performed because of the structure of the filteredMessages
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
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state and
  -- wait until IgnitionOn state is true; then wait shorter than maxIdlingTime and check if message IdlingStart has
  -- not been sent and check if terminal has not entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal does not enter the EngineIdling state, IdlingStart message not sent

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodBelowMaxIdlingTimeIdlingMessageNotSent()

  local idlingTime = 20  --  in seconds - period of time after which IdlingStart event should be genarated

  -- gpsSettings are configured
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
                                              {avlPropertiesPINs.maxIdlingTime, idlingTime} -- maximum idling time allowed without sending idling report

                                             }
                   )

  gateway.setHighWaterMark()         -- to get all messages after changing port state from low to high
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(5)                 -- IgnitionOn report generated, terminal in IgnitionOn state only for about 5 seconds (shorter than defined maxIdlingTime)
  -- IgnitionOn state expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  device.setIO(1, 0)                 -- port 1 to low level - that should trigger IgnitionOff


  --IdlingStart message not expected
  receivedMessages = gateway.getReturnMessages()            -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.idlingStart))
  local idlingStartdMessage = filteredMessages[1]              -- that is performed because of the structure of the filteredMessages
  -- TODO: this need to be done in different way
  assert_false((next(idlingStartMessage)), "IdlingStart message not expected")  -- checking if IdlingEnd message was received, if not that is not correct

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end




--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


