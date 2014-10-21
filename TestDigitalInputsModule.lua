-----------
-- Digital Inputs test module
-- - contains digital input related test cases
-- @module TestDigitalInputsModule

local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local avlMessagesMINs       = require("MessagesMINs")           -- the MINs of the messages are taken from the external file
local avlPopertiesPINs      = require("PropertiesPINs")         -- the PINs of the properties are taken from the external file
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
local avlAgentCons          = require("AvlAgentCons")           -- all AVL Agent constants in avlAgentCons
local math = require("math")

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



--- Suite setup function is run before every suite .
  -- Initial Conditions:
  --
  -- * Terminal Simulator running with AVL agent loaded and started
  -- * Gateway Webservice running
  -- * GPS Webservice running
  -- * Device Webservice running
  --
  -- Steps:
  --
  -- 1. Set LpmTrigger (PIN 31) in AVL (SIN 126) to 0
  -- 2. Read AvlStates property to check if terminal is not in LPM
  -- 3. Set randomPortNumber (value from range 1-4) using math.random function
  --
  -- Results:
  --
  -- 1. LpmTrigger (PIN 31) set to 0 (nothing can trigger entering LPM)
  -- 2. Terminal not in the Low Power Mode
  -- 3. Value of randomPortNumber set by using math.random function (different with every run of suite_setup)
 function suite_setup()

 -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.lpmTrigger, 0},
                                             }
                    )
  -- checking the state of terminal
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  -- selecting random number of port to be used in TCs
  math.randomseed(os.time())                -- os.time used as randomseed
  math.random(1,4)
  randomPortNumber = math.random(1,4)


end


-- executed after each test suite
function suite_teardown()

-- nothing here for now

end



--- Setup function is run before every TC, it puts terminal into known state so that every TC starts in the same conditions .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set continues property (PIN 15) in Position service (SIN 20) to value gpsReadInterval
  -- 2. Put terminal into stationary state
  -- 3. Simulate all 4 port change to low state
  -- 4. Disable 4 digital input lines
  --
  -- Results:
  --
  -- 1. continues property set to gpsReadInterval, GPS read periodically
  -- 2. Terminal put into stationary state
  -- 3. All 4 ports in low state
  -- 4. Digital input lines 1-4 disabled
 function setup()

  lsf.setProperties(20,{
                        {15,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                                 -- gps will be read every gpsReadInterval (in seconds)
                      }
                    )
  -- put terminal into stationary state
  avlHelperFunctions.putTerminalIntoStationaryState()

  -- set all 4 ports to low state
  for counter = 1, 4, 1 do
    device.setIO(counter, 0)
  end
  framework.delay(4)

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- setting the EIO properties - disabling all 4 I/O ports
  lsf.setProperties(avlAgentCons.EioSIN,{
                                            {avlPropertiesPINs.port1Config, 0},      -- port disabled
                                            {avlPropertiesPINs.port2Config, 0},      -- port disabled
                                            {avlPropertiesPINs.port3Config, 0},      -- port disabled
                                            {avlPropertiesPINs.port4Config, 0},      -- port disabled
                                        }
                    )

  -- disabling all digital input lines in AVL
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[1], 0},   -- 0 is for line disabled
                                                {avlPropertiesPINs.funcDigInp[2], 0},
                                                {avlPropertiesPINs.funcDigInp[3], 0},
                                                {avlPropertiesPINs.funcDigInp[4], 0},
                                             }
                   )

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



--- TC checks if IgnitionOn message is sent when port associated with IgnitionOn functon changes state to high .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Configure port as a digital input and associate this port with IgnitionOn line
  -- 2. Set the high state of the port to be a trigger for line activation
  -- 3. Simulate terminals position in stationary state in Point#1
  -- 4. Simulate port value change to high state
  -- 5. Receive IgnitionOn message
  -- 6. Verify fields of message against expected values
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. High state of the port set to be the trigger for IgnitionOn line activation
  -- 3. Point#1 is terminals simulated position in stationary state
  -- 4. High state of digital input simulated
  -- 5. IgnitionOn messaage received
  -- 6. Message fields contain Point#1 GPS and time information
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
                                                {avlPropertiesPINs.portConfig[randomPortNumber], 3},     -- port set as digital input
                                                {avlPropertiesPINs.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[randomPortNumber], avlAgentCons.funcDigInp["IgnitionOn"]},   -- line set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(randomPortNumber, 1)  -- port  to high level - that should trigger IgnitionOn

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


--- TC checks if IgnitionOn message is sent when digital input port changes to low state .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Configure port as a digital input and associate this port with IgnitionOn line
  -- 2. Set the low state of the port to be a trigger for line activation
  -- 3. Simulate terminals position in stationary state in Point#1
  -- 4. Simulate port value change to high state and than back to low
  -- 5. Receive IgnitionOn message
  -- 6. Verify fields of message against expected values
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. Low state of the port set to be the trigger for IgnitionOn line activation (DigStatesDefBitmap set to 0)
  -- 3. Point#1 is terminals simulated position in stationary state
  -- 4. Change between high and low state is simulated
  -- 5. IgnitionOn message received
  -- 6. Message fields contain Point#1 GPS and time information
 function test_Ignition_WhenPortValueChangesFromHighToLowForDigStatesDefBitmapSetToZero_IgnitionOnMessageSent()

  local digStatesDefBitmap = 0          -- DigStatesDefBitmap set to 0

  -- Point#1 gps settings
  local gpsSettings={
              speed = 0,                  -- terminal in stationary state
              latitude = 1,               -- degrees
              longitude = 1,              -- degrees
              fixType = 3,                -- valid fix provided,
                     }

  gps.set(gpsSettings)             -- applying gps settings
  framework.delay(2)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, digStatesDefBitmap}
                                             }
                   )

  gateway.setHighWaterMark()         -- to get the newest messages

  device.setIO(1, 1)                 -- port 1 to high level
  framework.delay(2)
  device.setIO(1, 0)                 -- port 1 to low level - that should trigger IgnitionOn
  timeOfEventTC = os.time()          -- get the exact time of event occurence
  framework.delay(2)

  --IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionON))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = timeOfEventTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- following code is only not to make problems with setup function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})  -- setting bitmap to make high state the trigger of ignitionON
  framework.delay(2)
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOff
  framework.delay(2)
  device.setIO(1, 0)                 -- port 1 to low level - that should trigger IgnitionOff


end


--- TC checks if IgnitionOn message is sent when port associated with IgnitionOn functon changes state to high and GpsFixAge is reported .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * no GPS signal
  --
  -- Steps:
  --
  -- 1. Configure port as a digital input and associate this port with IgnitionOn line
  -- 2. Set the high state of the port to be a trigger for line activation
  -- 3. Simulate terminals position in stationary state in Point#1 with no valid fix (gps signal loss)
  -- 4. Simulate port value change to high state
  -- 5. Receive IgnitionOn message
  -- 6. Verify fields of message against expected values
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. High state of the port set to be the trigger for IgnitionOn line activation
  -- 3. Point#1 is terminals simulated position in stationary state and there are no new fixes provided
  -- 4. High state of digital input simulated
  -- 5. IgnitionOn messaage received
  -- 6. Message fields contain Point#1 GPS and time information and GpsFixAge is included in report
function test_Ignition_WhenPortValueChangesToHigh_IgnitionOnMessageSentGpsFixAgeReported()

  -- gps signal is good at this point
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided at this point
                     }
  gps.set(gpsSettings)
  framework.delay(gpsReadInterval+2)          -- wait until terminal reads the gps position

  -- gps signal loss is simulated at this moment
  local gpsSettings.fixType = 1              -- no valid fix provided, gps signal loss

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
  -- setting digital input bitmap describing when special function inputs are active
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


--- TC checks if IgnitionOff message is sent when digital input port changes to low state .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Configure port as a digital input and associate this port with IgnitionOn line
  -- 2. Set the high state of the port to be a trigger for line activation
  -- 3. Simulate terminals position in stationary state in Point#1
  -- 4. Simulate port value change to high state and check terminals state
  -- 5. Simulate port value change back to low state
  -- 6. Receive IgnitionOff message and check terminals state
  -- 7. Verify fields of message against expected values
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. High state of the port set to be the trigger for IgnitionOn line activation
  -- 3. Point#1 is terminals simulated position in stationary state
  -- 4. Terminal goes to IgnitionOn state after setting port state to high level
  -- 5. Port changes value back to low level
  -- 5. IgnitionOff message received and terminal goes to IgnitionOn=false state
  -- 6. Message fields contain Point#1 GPS and time information
function test_Ignition_WhenPortValueChangesToLow_IgnitionOffMessageSent()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)    -- applying gps settings

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.portConfig[randomPortNumber], 3},     -- port set as digital input
                                                {avlPropertiesPINs.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[randomPortNumber], avlAgentCons.funcDigInp["IgnitionOn"]},  -- digital input line set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(randomPortNumber, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(randomPortNumber, 0)  -- port transition to low state; that should trigger IgnitionOff
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

  -- checking if terminal correctly goes to IgnitionOn = false state
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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
  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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

  -- setting digital input bitmap describing when special function inputs are active
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



--- TC checks if DigInp4Hi message is sent when port 4 state changes from low to high
  -- *actions performed:
  -- Configure port 4 as a digital input and set General Purpose as function for digital input line number 4
  -- simulate terminal moving and change state of digital port 4 from low to high; check if DigInp4Hi message
  -- has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp4Hi message sent when port changes state from low to high
function test_DigitalInput_WhenTerminalMovingAndPort4StateChangesFromLowToHigh_DigInp4HiMessageSent()

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
                                                {avlPropertiesPINs.port4Config, 3},     -- port 4 as digital input
                                                {avlPropertiesPINs.port4EdgeDetect, 3}, -- port 4 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp4, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 4 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(4, 1)                                       -- set port 4 to high level - that should trigger DigInp4Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp4Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp4Hi))
  assert_true(next(filteredMessages), "DigInp4Hi report not received")   -- checking if digitalInp4Hi message has been caught, if not assertion fails
  digitalInp4HiMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp4Hi",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp4HiMessage, expectedValues) -- verification of the report fields


end



--- TC checks if DigInp4Lo message is sent when port 4 state changes from high to low
  -- *actions performed:
  -- Configure port 4 as a digital input and set General Purpose as function for digital input line number 4
  -- simulate terminal moving and change state of digital port 4 from low to high; then change it  back from high to low
  -- and check if DigInp4Lo message has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp4Lo message sent when port changes state from high to low
function test_DigitalInput_WhenTerminalMovingAndPort4StateChangesFromHighToLow_DigInp4LoMessageSent()

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
                                                {avlPropertiesPINs.port4Config, 3},     -- port 4 as digital input
                                                {avlPropertiesPINs.port4EdgeDetect, 3}, -- port 4 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp4, avlAgentCons.funcDigInp.GeneralPurpose}, -- line number 4 set for General Purpose function
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(4, 1)                                       -- set port 4 to high level - that should trigger DigInp4Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(4, 0)                                       -- set port 4 to low level - that should trigger DigInp4Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp4Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.digitalInp4Lo))
  assert_true(next(filteredMessages), "DigInp4Lo report not received")   -- checking if digitalInp4Lo message has been caught, if not assertion fails
  digitalInp4LoMessage = filteredMessages[1]                             -- that is due to structure of the filteredMessages
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "DigInp4Lo",
                  currentTime = os.time(),
                         }

  avlHelperFunctions.reportVerification(digitalInp4LoMessage, expectedValues) -- verification of the report fields


end


--- TC checks if PowerMain message is sent when virtual line number 13 changes state to 1 (external power source becomes present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Simulate terminals position in stationary state in Point#1
  -- 2. Simulate external power source not present (PIN 8 in Power service)
  -- 3. Set External Input Voltage to value A
  -- 4. Simulate external power source present
  -- 5. Receive PowerMain message (MIN 2)
  -- 6. Verify messages fields against expected values
  -- 7. Check terminals state
  --
  -- Results:
  --
  -- 1. Point#1 is terminals simulated position in stationary state
  -- 2. External power source not present (PIN 8 in Power service is 1)
  -- 3. Value of External Input Voltage set to value A
  -- 4. External power source not present (PIN 8 in Power service is 0)
  -- 5. PowerMain message received (MIN 2)
  -- 6. Message fields contain Point#1 GPS and time information and reported InputVoltage is value A
  -- 7. PowerMain is true
  --
 function test_PowerMain_WhenVirtualLine13ChangesStateTo1_PowerMainMessageSentAndPowerMainStateBecomesTrue()

  local inputVoltageTC = 240      -- tenths of volts, external power voltage value

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)               -- applying gps settings
  framework.delay(3)
  gateway.setHighWaterMark()         -- to get the newest messages

  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged from external power source)
  framework.delay(2)

  device.setPower(9,inputVoltageTC*100)  -- setting external power source input voltage to known value, multiplied by 100 as this is saved in milivolts
  framework.delay(2)

  -- setting external power source
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  timeOfEventTC = os.time()
  framework.delay(2)               -- wait until setting is applied

  -- PowerMain message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.powerMain))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "PowerMain",
                  currentTime = timeOfEventTC,
                  inputVoltage = inputVoltageTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - onMainPower true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "terminal not in onMainPower state")

end




--- TC checks if PowerBackup message is sent when virtual line number 13 changes state to 0 (external power source becomes not present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Simulate terminals position in stationary state in Point#1
  -- 2. Simulate external power source present (PIN 8 in Power service)
  -- 3. Set Battery Voltage to value A
  -- 4. Simulate external power source not present
  -- 5. Receive PowerBackup message (MIN 3)
  -- 6. Verify messages fields against expected values
  -- 7. Check terminals state
  --
  -- Results:
  --
  -- 1. Point#1 is terminals simulated position in stationary state
  -- 2. External power source present (PIN 8 in Power service is 1)
  -- 3. Value of External Input Voltage set to value A
  -- 4. External power source present (PIN 8 in Power service is 0)
  -- 5. PowerBackup message received (MIN 3)
  -- 6. Message fields contain Point#1 GPS and time information and InputVoltage is value A (Battery Voltage)
  -- 7. PowerMain is true
  --
 function test_PowerBackup_WhenVirtualLine13ChangesStateTo0_PowerBackupMessageSentAndPowerMainStateBecomesFalse()

  local inputVoltageTC = 240      -- tenths of volts, external power voltage value

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)               -- applying gps settings
  framework.delay(3)
  gateway.setHighWaterMark()         -- to get the newest messages
  -- setting external power source
  device.setPower(8,1)                    -- external power present (terminal plugged to external power source
  framework.delay(2)

  device.setPower(3,inputVoltageTC*100)  -- setting external power source input voltage to known value, multiplied by 100 as this is saved in milivolts
  framework.delay(2)

  -- setting external power source
  device.setPower(8,0)            -- external power not present (terminal unplugged from external power source)
  timeOfEventTC = os.time()
  framework.delay(2)               -- wait until setting is applied

  -- PowerMain message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.powerBackup))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "PowerBackup",
                  currentTime = timeOfEventTC,
                  inputVoltage = inputVoltageTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - onMainPower false expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "onMainPower state is incorrectly true")

end



--- TC checks if IgnitionOn message is sent when virtual line number 13 changes state to 1 (external power source becomes present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set funcDigInp13 (PIN 59) to associate digital input line 13 with IgnitionOn function
  -- 2. Simulate terminals position in stationary state in Point#1
  -- 3. Simulate external power source not present
  -- 4. Simulate external power source present
  -- 5. Receive IgnitionOn message (MIN 4)
  -- 6. Verify messages fields against expected values
  -- 7. Check terminals state
  --
  -- Results:
  --
  -- 1. Line number 13 associated with IgnitionOn function
  -- 2. Point#1 is terminals simulated position in stationary state
  -- 3. External power source not present (line 13 in low state)
  -- 4. Line 13 changes state to 1
  -- 5. IgnitionOn message received (MIN 4)
  -- 6. Message fields contain Point#1 GPS and time information
  -- 7. IgnitionOn is true
 function test_Line13_WhenVirtualLine13ChangesStateTo1_IgnitionOnMessageSent()


  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[13], avlAgentCons.funcDigInp.IgnitionOn}, -- digital input line 13 associated with IgnitionOn function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)                    -- applying gps settings
  framework.delay(3)

  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  framework.delay(2)
  gateway.setHighWaterMark()              -- to get the newest messages

  local timeOfEventTC = os.time()        -- to get correct timestamp
  -- setting external power source
  device.setPower(8,1)                    -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionON))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is not true")

end



--- TC checks if IgnitionOff message is sent when virtual line number 13 changes state to 0 (external power source becomes not present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set funcDigInp13 (PIN 59) to associate digital input line 13 with IgnitionOn function
  -- 2. Simulate terminals position in stationary state in Point#1
  -- 3. Simulate external power source present
  -- 4. Simulate external power source not present
  -- 5. Receive IgnitionOff message (MIN 5)
  -- 6. Verify messages fields against expected values
  -- 7. Check terminals state
  --
  -- Results:
  --
  -- 1. Line number 13 associated with IgnitionOn function
  -- 2. Point#1 is terminals simulated position in stationary state
  -- 3. External power source present (line 13 in high state)
  -- 4. Line 13 changes state to 0
  -- 5. IgnitionOn message received (MIN 5)
  -- 6. Message fields contain Point#1 GPS and time information
  -- 7. IgnitionOn is false
 function test_Line13_WhenVirtualLine13ChangesStateTo0_IgnitionOffMessageSent()


  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[13], avlAgentCons.funcDigInp.IgnitionOn}, -- digital input line 13 associated with IgnitionOn function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)                    -- applying gps settings
  framework.delay(3)

  -- setting external power source
  device.setPower(8,1)                    -- external power present (terminal plugged to external power source)
  framework.delay(2)
  gateway.setHighWaterMark()              -- to get the newest messages

  local timeOfEventTC = os.time()        -- to get correct timestamp
  -- setting external power source
  device.setPower(8,0)                    -- external power becomes not present (line 13 changes state to 0)
  framework.delay(2)

  -- IgnitionOff message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.ignitionOFF))
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOff",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is incorrectly true")

end




--- TC checks if terminal enters and leaves SeatbeltViolation state when line number 13 is controls SeatbeltOff function .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set funcDigInp13 (PIN 59) to associate digital input line 13 with SeatbeltOff function
  -- 2. Set SeatbeltDebounceTime (PIN 115) to value above zero to enable seatbelt violation feature
  -- 3. Set DigStatesDefBitmap (PIN 46) to make high state of the line be a trigger for SeatbeltOff
  -- 4. Simulate terminals position in moving state in Point#1
  -- 5. Simulate external power source not present
  -- 6. Simulate external power source present and wait longer than SeatbeltDebounceTime
  -- 7. Receive SeatbeltViolationStart message (MIN 19)
  -- 8. Verify if message contains Point#1 GPS and time information
  -- 9. Simulate terminals position in moving state in Point#2
  -- 10. Simulate external power source not present
  -- 11. Receive SeatbeltViolationEnd message (MIN 20)
  -- 12. Verify if message contains Point#2 GPS and time information
  --
  -- Results:
  --
  -- 1. Line number 13 associated with SeatbeltOff function
  -- 2. SeatbeltDebounceTime property set to value greater than zero
  -- 3. DigStatesDefBitmap set
  -- 4. Point#1 is terminals simulated position in moving state
  -- 5. External power source not present (line 13 in low state)
  -- 6. Line 13 becomes high and stays high longer than SeatbeltDebounceTime
  -- 7. SeatbeltViolationStart message received (MIN 19)
  -- 8. Message fields contain Point#1 GPS and time information
  -- 9. Point#1 is terminals simulated position in moving state
  -- 10. External power source not present (line 13 in low state again)
  -- 11. SeatbeltViolationEnd message received (MIN 20)
  -- 12. Message fields contain Point#2 GPS and time information
  function test_Line13_WhenVirtualLine13IsAssociatedWithSeatbeltOffFunction_SeatbeltViolationStartAndSeatbeltViolationEndMessageSentAccordingToStateOfLine13()

  local seatbeltDebounceTime = 10       -- seconds

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[13], avlAgentCons.funcDigInp.SeatbeltOff}, -- digital input line 13 associated with SeatbeltOff function
                                                {avlPropertiesPINs.seatbeltDebounceTime, seatbeltDebounceTime},          -- setting seatbeltDebounceTime
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SeatbeltOff"})

  avlHelperFunctions.putTerminalIntoMovingState()

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  -- Point#1 GPS Settings
  local gpsSettings={
              speed = 50,                     -- terminal moving
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided
                     }

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(3)

  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  framework.delay(2)
  gateway.setHighWaterMark()              -- to get the newest messages

  -- setting external power source
  device.setPower(8,1)                     -- external power present (terminal plugged to external power source - line 13 changes state to high)
  local timeOfEventTC = os.time()         -- to get exact timestamp
  framework.delay(seatbeltDebounceTime+2)  -- wait longer than seatbeltDebounceTime to get seatbeltViolationStart message

  -- seatbeltViolationStart message expected
  local message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationStart))
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEventTC,
                        }
  -- verification of the report fields
  avlHelperFunctions.reportVerification(message, expectedValues)

  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "SeatbeltViolation state is not true")

  -- Point#2 GPS Settings
  gpsSettings={
              speed = 51,                     -- terminal moving
              latitude = 2,                   -- degrees
              longitude = 2,                  -- degrees
                     }

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(3)

  gateway.setHighWaterMark()              -- to get the newest messages
  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  timeOfEventTC = os.time()               -- to get exact timestamp
  framework.delay(2)

  -- seatbeltViolationEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.seatbeltViolationEnd))
  expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = timeOfEventTC,
                        }
  -- verification of the report fields
  avlHelperFunctions.reportVerification(message, expectedValues)

  -- verification of the state of terminal - SeatbeltViolation false expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "SeatbeltViolation state is incorrectly true")


end



--- TC checks if Service Meter 1 is activated and deactivated when virtual line number 13 controls SM1 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set funcDigInp13 (PIN 59) to associate digital input line 13 with SM1 function
  -- 2. Set DigStatesDefBitmap (PIN 46) to make high state of the line be a trigger for SM1Active
  -- 3. Simulate external power source not present
  -- 4. Read avlStates property (PIN 41) and verify if SM1Active bit is not true
  -- 5. Simulate external power source present
  -- 6. Read avlStates property (PIN 41) and verify if SM1Active bit is true
  -- 7. Simulate external power source not present
  -- 8. Read avlStates property (PIN 41) and verify if SM1Active bit is not true
  --
  -- Results:
  --
  -- 1. Line number 13 associated with SM1 function
  -- 2. High state of the line is set to be a trigger for SM1Active
  -- 3. External power source not present - line 13 in low state
  -- 4. SM1Active bit in avlStates property is not true
  -- 5. External power source present - line 13 changes state to high
  -- 6. SM1Active bit in avlStates property is true
  -- 7. External power source not present - line 13 in low state
  -- 8. SM1Active bit in avlStates property is not true
 function test_Line13_WhenVirtualLine13IsAssociatedWithSM1_ServiceMeter1BecomesActiveAndInactiveAccordingToStateOfLine13()

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp[13], avlAgentCons.funcDigInp.SM1}, -- digital input line 13 associated with SM1 function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SM1Active"})

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active false is expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly true")

  -- setting external power source
  device.setPower(8,1)                -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active true is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly not true")

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active false is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly true")


end




--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


