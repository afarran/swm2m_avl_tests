-----------
-- Low Power Mode test module
-- - contains Low Power Mode related test cases
-- @module TestLPMModule

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


--- Suite setup function sets LpmTrigger to 0 and checks if terminal is not in LPM (executed before each test suite  .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set LpmTrigger (PIN 31)
  -- 4. Assert if terminal is not in LPM
  --
  -- Results:
  --
  -- 1. Terminal not in LPM
function suite_setup()

  -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.lpmTrigger, 0},
                                             }
                    )
  framework.delay(2)
 -- checking the terminal state
 local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
 assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

end


--- Teardown function sets LpmTrigger to 0 (executed after each test case)  .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set LpmTrigger (PIN 31) to 0
  --
  -- Results:
  --
  -- 1. LpmTrigger (PIN 31) set to 0
function teardown()

-- terminal should be put out of the low power mode after each test case
lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.lpmTrigger, 0},    -- 0 is for no trigger
                                           }
                    )

end

-- executed after each test suite
function suite_teardown()

-- nothing here for now

end


--- Setup function puts terminal into stationary state, configures gpsReadInterval, sets all ports to low level and checks if terminal is not in LPM and IgnitionOn state .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set gpsReadInterval (PIN 15) in Position service (SIN 20)
  -- 2. Put terminal into stationary state
  -- 3. Set all ports to low level
  -- 4. Assert if terminal not in LPM and IgnitionOn mode
  --
  -- Results:
  --
  -- 1. Terminal not in LPM and IgnitionOn state
 function setup()

  lsf.setProperties(avlAgentCons.positionSIN,{
                                              {avlPropertiesPINs.gpsReadInterval,gpsReadInterval}     -- setting the continues mode interval of position service
                                             }
                    )

  avlHelperFunctions.putTerminalIntoStationaryState()

  -- setting all 4 ports to low stare
  for counter = 1, 4, 1 do
    device.setIO(counter, 0)
  end
  framework.delay(3)

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

 -- checking the the Low power mode - terminal is expected not be in the low power mode
 avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
 assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

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

--[[
    START OF TEST CASES

    Each test case is a global function whose name begins with "test"

--]]



--- TC checks if terminal is put into LPM if the trigger of LPM is set to IgnitionOff and trigger is true longer than lpmEntryDelay .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal in IgnitionOn state
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 1 (IgnitionOff)
  -- 3. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 4. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 1
  -- 3. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 4. Terminal goes to LPM
function test_LPM_WhenLpmTriggerSetToIgnitionOffAndIgnitionOffStateTrueForPeriodAboveLpmEntryDelay_TerminalPutToLowPowerMode()

  local lpmEntryDelay = 0    -- in minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                   -- 1 is for Ignition Off
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
  framework.delay(5)                 -- wait until terminal changes state

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

end



--- TC checks if terminal is not put into LPM if the trigger of LPM is set to IgnitionOff and trigger is true shorter than lpmEntryDelay .
  -- Initial Conditions:
  --
  -- * Terminal not in the LPM
  -- * IgnitonOn is true
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 1 (IgnitionOff)
  -- 3. Simulate low level of port for period shorter than LpmEntryDelay (PIN 32)
  -- 4. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 1
  -- 3. IgnitionOff event generated and terminal in IgnitionOn = false for time shorter than LpmEntryDelay
  -- 4. Terminal does not go  to LPM
function test_LPM_WhenLpmTriggerSetToIgnitionOffAndIgnitionOffStateTrueForPeriodBelowpmEntryDelay_TerminalNotPutToLowPowerMode()

  local lpmEntryDelay = 1    -- minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                    -- 1 is for Ignition Off
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})



  device.setIO(1, 1)  -- port transition to high state; that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(2)                 -- wait for the change of state

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time shorter than lpmEntryDelay, terminal should not go to LPM after this period
  framework.delay(lpmEntryDelay*60-40)
  -- checking the state of terminal - Low Power Mode not expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")

  device.setIO(1, 0)                 -- port transition to high state; that should trigger IgnitionOn
  framework.delay(5)                 -- wait for the change of state


end


--- TC checks if terminal is put out of Low Power Mode if the trigger of LPM is set to IgnitionOff and IgnitionOn state becomes true .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 1 (IgnitionOff)
  -- 3. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 4. Check terminals state
  -- 5. Simulate high level of port
  -- 6. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 1
  -- 3. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 4. Terminal goes to LPM
  -- 5. IgnitionOn event generated
  -- 6. Terminal put out of LPM
function test_LPM_WhenLpmTriggerSetToIgnitionOffTerminalInLpmAndIgnitionOnStateBecomesTrue_TerminalPutOutOfLowPowerMode()

  local lpmEntryDelay = 1   -- minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                   -- 1 is for Ignition Off
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
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(5)   -- waiting for the state to change

  -- checking state of the terminal, low power mode is not expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")


end


--- TC checks if ZoneEntry message is sent after LpmGeoInterval when terminal is in LPM .
  -- Initial Conditions:
  --
  -- * Terminal in LPM
  -- * Defined geofence in fences.dat
  -- * GPS signal is good
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Change position of terminal from outside to inside of defined geofence
  -- 2. Wait longer than LpmGeoInterval (PIN 33)
  --
  -- Results:
  --
  -- 1. Geofence detected after LpmGeoInterval (PIN 33)
  -- 2. ZoneEntry message sent
function test_LPM_WhenTerminalInLowPowerMode_ZoneEntryMessageSentAfterLpmGeoInterval()

  local lpmEntryDelay = 1   -- minutes
  local lpmGeoInterval = 60 -- seconds
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceHisteresis = 1       -- in seconds

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                   -- 1 is for Ignition Off
                                                {avlPropertiesPINs.lpmGeoInterval, lpmGeoInterval}
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- sending fences.dat file to the terminal with the definitions of geofences used in TCs
  -- for more details please go to Geofences.jpg file in Documentation
  local message = {SIN = 24, MIN = 1}
	message.Fields = {{Name="path",Value="/data/svc/geofence/fences.dat"},{Name="offset",Value=0},{Name="flags",Value="Overwrite"},
                    {Name="data",Value="ABIABQAtxsAAAr8gAACcQAAAAfQEagAOAQEALg0QAAK/IAAATiABnAASAgUALjvwAAQesAAAw1AAAJxABCEAEgMFAC4NEAAEZQAAAFfkAABEXAKX"}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- to make sure file is saved

  -- restaring geofences service, that action is necessary after sending new fences.dat file
  message = {SIN = 16, MIN = 5}
	message.Fields = {{Name="sin",Value=21}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- wait until geofences service is up again

  -- gps settings table - terminal outside any of the defined geofences
  local gpsSettings={
              longitude = 1,                -- degrees, outside any of the defined geofences
              latitude = 1,                 -- degrees, outside any of the defined geofences
              heading = 90,                 -- degrees
              speed = 0,                    -- to get stationary state
              fixType=3,                    -- valid 3D gps fix
              simulateLinearMotion = false, -- terminal not moving
                     }

  gps.set(gpsSettings) -- applying settings of gps simulator


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  -- gps settings table - terminal outside any of the defined geofences
  gpsSettings={
              heading = 90,                 -- degrees
              speed = 0,                    -- to get stationary state
              latitude = 50,                -- degrees, inside geofence 1
              longitude = 3,                -- degrees, inside geofence 1
                     }

  gps.set(gpsSettings)               -- applying settings of gps simulator
  timeOfEnteringGeozone= os.time()   -- saved for comparison
  framework.delay(lpmGeoInterval+5)  -- wait for time longer than lpmGeoInterval

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))
  assert_not_nil(next(matchingMessages), "ZoneEntry message not received")  -- checking if any of ZoneEntry messages has been received
  gpsSettings.heading = 361          -- for stationary state
  local expectedValues={
                          gps = gpsSettings,
                          messageName = "ZoneEntry",
                          currentTime = timeOfEnteringGeozone+lpmGeoInterval,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  local geofenceEnabled = false       -- to disable geofence feature
  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

 framework.delay(1)   -- wait until message is processed


end



--- TC checks if terminal goes to stationary state when entering LPM and starts moving (depending on GPS speed) when it leaves LPM .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set LpmTrigger (PIN 31) to 1 to make IgnitionOff the trigger of entering LPM
  -- 2. Put terminal into moving state
  -- 3. Simulate IgnitionOn line in non-active state for time longer than LpmEntryDelay to put terminal in LPM
  -- 4. Read avlStates property and verify moving state
  -- 5. Simulate IgnitionOn line in active state and check terminals state
  -- 6. Read avlStates property and verify moving state when terminal out of LPM
  --
  -- Results:
  --
  -- 1. IgnitionOff set as trigger for LPM
  -- 2. Terminal in moving state
  -- 3. Terminal enters LPM after LpmEntryDelay
  -- 4. Moving state is false (terminal in LPM)
  -- 5. Terminal goes out of LPM
  -- 6. Moving state is true (terminal out of LPM and speed above threshold)
function test_LPM_WhenTerminalEntersAndLeavesLPM_TerminalStopsMovingOnEnterToLpmAndGoesBackToMovingStateAccordingToGpsSpeedWhenLeavingLpm()

  local lpmEntryDelay = 1           -- minutes (1 minute is the minimal value)

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

                   -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                   -- 1 is for Ignition Off
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  avlHelperFunctions.putTerminalIntoMovingState()

  device.setIO(1, 0) -- that should trigger IgnitionOff
  framework.delay(2)

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  -- reading AVLStates property to check moving state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- checking if terminal is not in moving state (while being in LPM)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal unexpectedly in moving state while being in LPM")

  device.setIO(1, 1) -- IgnitionOn line becomes active, that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")

  -- reading movingDebounceTime property (it is needed as delay value in next step)
  local movingDebounceTime = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.movingDebounceTime)
  framework.delay(2)

  -- waiting until terminal goes into moving state again (speed is above threshold)
  framework.delay(movingDebounceTime[1].value+gpsReadInterval+10)

  -- reading AVLStates property to check moving state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- checking if terminal is in moving state after leaving LPM (according to simulated speed it should be moving)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal is not in moving state after leaving LPM as expected ")


end


--- TC checks if some specific properties are changing values when terminal enters LPM and are correctly reverted when terminal leaves it .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set ledControl  property (PIN 6) in System service (SIN 16) to value ledControlUserSet
  -- 2. Set Continues  property (PIN 15) in Position service (SIN 20) to value gpsReadInterval
  -- 3. Set Interval property (PIN 2) in Geofence service (SIN 21) to value A and LpmGeoInterval (PIN 33) in AVL service (SIN 126) to value B
  -- 4. Set WakeUpInterval property (PIN 11) in IDP service  (SIN 27) to value C and LpmModemWakeUpInterval property (PIN 34) in AVL service (SIN 126) to value D
  -- 5. Set powerMode property (PIN 11) in IDP service  (SIN 27) to value powerModeUserSet
  -- 6. Save all properties of System, Position, IDP and Geofence service
  -- 7. Set LpmTrigger (PIN 31) to 1 to make IgnitionOff the trigger of entering LPM
  -- 8. Simulate IgnitionOn line in non-active state for time longer than LpmEntryDelay and check terminals state
  -- 9. Read ledControl  property (PIN 6) in System service (SIN 16) and verify that is has value 1 (User)
  -- 10. Read Continues property (PIN 15) in Position service (SIN 20) and verify that is has value 0 (feature disabled)
  -- 11. Read Interval (PIN 2) in Geofence (SIN 21) service and verify that is has value B (LpmGeoInterval)
  -- 12. Read WakeUpInterval property (PIN 11) in IDP service (SIN 27) and verify that is has value D (LpmModemWakeUpInterval)
  -- 13. Simulate IgnitionOn line in active state and check terminals state
  -- 14. Read ledControl property (PIN 6) in System service (SIN 16) and verify that is has been reverted to user saved (ledControlUserSet)
  -- 15. Read Continues property (PIN 15) and verify if it has been reverted to value gpsReadInterval
  -- 16. Read geofence check Interval (PIN 2) and verify if it has been reverted to value A
  -- 17. Read WakeUpInterval property (PIN 11) and verify if it has been set to 5_seconds
  -- 18. Read powerMode property (PIN 10) and verify if it has been reverted to powerModeUserSet
  --
  -- Results:
  --
  -- 1. LedControl set to value ledControlUserSet
  -- 2. Continues set to to value gpsReadInterval
  -- 3. Interval set to value A and LpmGeoInterval set to value B
  -- 4. WakeUpInterval set to value C and LpmModemWakeUpInterval set to value D
  -- 5. PowerMode property set to powerModeUserSet
  -- 5. All properties of System, Position and Geofence services saved
  -- 6. IgnitionOff set as trigger for LPM
  -- 7. Terminal enters LPM after LpmEntryDelay
  -- 8. LedControl property has been changed to 1 (User) after entering LPM
  -- 9. Continues property set to 0
  -- 10. Geofence Interval set to value B (LpmGeoInterval)
  -- 11. WakeUpInterval set to value D (LpmModemWakeUpInterval)
  -- 12. powerMode property set to 2 - MobileBattery
  -- 13. Terminal goes out of LPM
  -- 14. Value of ledControl property (PIN 6, SIN 16) has been reverted to ledControlUserSet (user-saved) when leaving LPM
  -- 15. Value of Continues property (PIN 15, SIN 20) has been reverted to gpsReadInterval when leaving LPM
  -- 16. Value of Interval property (PIN 2, SIN 21) has been reverted to value A when leaving LPM
  -- 17. Value of WakeUpInterval property (PIN 11, SIN 27) has been set to 5_seconds when leaving LPM
  -- 18. Value of powerMode (PIN 10, SIN 27) has been reverted to powerModeUserSet
function test_LPM_WhenTerminalEntersAndLeavesLPM_ValuesOfSomePropertiesAreChangedwhenEnteringLpmAndRevertedWhenLeavingLpm()

  local lpmEntryDelay = 1                             -- minutes
  local ledControlUserSet = 0                         -- enum type property (0 - Terminal, 1 - User)
  local lpmGeoInterval = 120                          -- seconds
  local geofenceInterval = 50                         -- seconds
  local powerModeUserSet = 4                          -- enum type (0-Mobile Powered, 1 - FixedPowered, 2 - MobileBattery, 3 - FixedBattery, 4 - MobileMinBattery)
  local lpmModemWakeUpInterval = "30_minutes"         -- lpmModemWakeUpInterval value
  local wakeUpInterval = "3_minutes"                  -- wakeUpInterval value
  local wakeUpIntervalOnExitFromLpm = "5_seconds"     -- value of wakeUpInterval which should be set when leaving LPM (this cannot be modified)
  -- helper variables for handling wakeUpInterval
  local lpmModemWakeUpIntervalEnum = avlAgentCons.lpmModemWakeUpIntervalValues[lpmModemWakeUpInterval]        -- lpmModemWakeUpInterval enum representation (enum type property)
  local wakeUpIntervalEnum = avlAgentCons.modemWakeUpIntervalValues[wakeUpInterval]                           -- wakeUpInterval num representation
  local wakeUpIntervalOnExitFromLpmEnum = avlAgentCons.modemWakeUpIntervalValues[wakeUpIntervalOnExitFromLpm] -- wakeUpIntervalOnExitFromLpm enum representation

  -- setting properties of System service
  lsf.setProperties(avlAgentCons.systemSIN,{
                                               {avlPropertiesPINs.ledControl,ledControlUserSet}        -- setting ledControl property in System service (SIN 16, PIN 6)
                                           }
                    )

  -- setting properties of Position service
  lsf.setProperties(avlAgentCons.positionSIN,{
                                               {avlPropertiesPINs.gpsReadInterval,gpsReadInterval}      -- setting the continues mode of Position service (SIN 20, PIN 15)
                                             }
                    )

  -- setting properties of Geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                               {avlPropertiesPINs.geofenceInterval, geofenceInterval},   -- setting geofence check Interval in Geofence service (SIN 21, PIN 2)
                                             }
                   )

  -- setting properties of IDP Service
  lsf.setProperties(avlAgentCons.idpSIN,{
                                               {avlPropertiesPINs.wakeUpInterval,wakeUpIntervalEnum},     -- saving wakeUpIntervalEnum  to wakeUpInterval property
                                               {avlPropertiesPINs.powerMode,powerModeUserSet},            -- saving powerModeUserSet  to powerMode property
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn},   -- line set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                      -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                                     -- 1 is for Ignition Off
                                                {avlPropertiesPINs.lpmGeoInterval, lpmGeoInterval},                    -- setting low power mode geofence check interval
                                                {avlPropertiesPINs.lpmModemWakeUpInterval, lpmModemWakeUpIntervalEnum},-- setting low power mode modem wake up interval
                                             }
                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port set as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- saving properties of System, Geofence and Position service (by sending saveProperties message from System service)
  local savePropertiesMessage = {SIN = avlAgentCons.systemSIN, MIN = avlMessagesMINs.saveProperties}
	savePropertiesMessage.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=avlAgentCons.systemSIN},}},
                                                         {Index=1,Fields={{Name="sin",Value=avlAgentCons.geofenceSIN},}},
                                                         {Index=2,Fields={{Name="sin",Value=avlAgentCons.positionSIN},}},
                                                         {Index=3,Fields={{Name="sin",Value=avlAgentCons.idpSIN},}}}}}
  gateway.submitForwardMessage(savePropertiesMessage)

  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)
  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties before entering Low Power Mode
  ------------------------------------------------------------------------------------------------------------------

  -- reading ledControl property (PIN 6) in System service (SIN 16) when terminal not in LPM
  local ledControlProperty = lsf.getProperties(avlAgentCons.systemSIN,avlPropertiesPINs.ledControl)
  framework.delay(2)
  -- checking if ledControl property has been correctly set to value of ledControlUserSet
  assert_equal(ledControlUserSet,tonumber(ledControlProperty[1].value), "Value of ledControl property has not been correctly set")

  -- reading Continues property (PIN 15) in Position service (SIN 20) when terminal not in LPM
  local continuesProperty = lsf.getProperties(avlAgentCons.positionSIN,avlPropertiesPINs.gpsReadInterval)
  framework.delay(2)
  -- checking if Continues property has been correctly set
  assert_equal(gpsReadInterval,tonumber(continuesProperty[1].value), "Value of Continues property has not been correctly set")

  -- reading Interval property (PIN 2) in Geofence service (SIN 21) when terminal not in LPM
  local geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)
  -- checking if geofence Interval has been correctly set
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been correctly set")

  -- reading wakeUpInterval property (PIN 11) in IDP service (SIN 27) when terminal not in LPM
  local wakeUpIntervalProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.wakeUpInterval)
  framework.delay(2)
  -- checking if wakeUpInterval property has been correctly set
  assert_equal(wakeUpIntervalEnum,tonumber(wakeUpIntervalProperty[1].value), "Value of WakeUpInterval property has not been correctly set")

  -- reading powerMode property (PIN 10) in IDP service (SIN 27) when terminal not in LPM
  local powerModeProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.powerMode)
  framework.delay(2)
  -- checking if powerMode property has been correctly set
  assert_equal(powerModeUserSet,tonumber(powerModeProperty[1].value), "Value of powerMode property has not been correctly set")

  ------------------------------------------------------------------------------------------------------------------
  -- Terminal enters Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  device.setIO(1, 0) -- that should trigger IgnitionOff
  framework.delay(2)

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties after entering Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  -- reading ledControl property (PIN 6) in System service (SIN 16) when terminal in LPM
  ledControlProperty = lsf.getProperties(avlAgentCons.systemSIN,avlPropertiesPINs.ledControl)
  framework.delay(2)
  -- checking if  ledControl property (PIN 6)  has been set to 1 - Terminal when entering LPM
  assert_equal(1,tonumber(ledControlProperty[1].value), "Value of ledControl property in System service has not been set to 1 when entering LPM")

  -- reading Continues property (PIN 15) in Position service (SIN 20) when terminal in LPM
  continuesProperty = lsf.getProperties(avlAgentCons.positionSIN,avlPropertiesPINs.gpsReadInterval)
  framework.delay(2)
  -- checking if  Continues property (PIN 15) has been set to 0 when entering LPM
  assert_equal(0,tonumber(continuesProperty[1].value), "Value of Continues property in Position service has not been set to 0 when entering LPM")

  -- reading Interval (PIN 2) in Geofence service (SIN 21) when terminal in LPM
  geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)
  -- checking if geofence Interval has been changed to LpmGeoInterval when entering LPM
  assert_equal(lpmGeoInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been changed when entering LPM")

  -- reading wakeUpInterval property property (PIN 11) in IDP service (SIN 27) when terminal in LPM
  wakeUpIntervalProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.wakeUpInterval)
  framework.delay(2)
  -- checking if  wakeUpInterval property has been set to lpmModemWakeUpInterval when entering LPM
  assert_equal(lpmModemWakeUpIntervalEnum,tonumber(wakeUpIntervalProperty[1].value), "Value of WakeUpInterval property in IDP service has not been set to LpmModemWakeUpInterval when entering LPM")

  -- reading powerMode property (PIN 10) in IDP service (SIN 27) when terminal in LPM
  powerModeProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.powerMode)
  framework.delay(2)
  -- checking if powerMode property has been correctly changed
  assert_equal(2,tonumber(powerModeProperty[1].value), "Value of powerMode property has not been changed to MobileBattery when entering LPM")

  ------------------------------------------------------------------------------------------------------------------
  -- Terminal leaves Low Power Mode
  ------------------------------------------------------------------------------------------------------------------

  device.setIO(1, 1) -- IgnitionOn line becomes active, that should trigger IgnitionOn
  framework.delay(20)

  -- checking state of the terminal, Low Power Mode is not expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties after leaving Low Power Mode
  ------------------------------------------------------------------------------------------------------------------

  -- reading ledControl property (PIN 6) in System service (SIN 16)
  ledControlProperty = lsf.getProperties(avlAgentCons.systemSIN,avlPropertiesPINs.ledControl)
  framework.delay(2)

  -- reading Continues property (PIN 15) in Position service (SIN 20)
  continuesProperty = lsf.getProperties(avlAgentCons.positionSIN,avlPropertiesPINs.gpsReadInterval)
  framework.delay(2)

  -- reading Interval (PIN 2) in Geofence service (SIN 21)
  geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)

  -- reading wakeUpInterval property property (PIN 11) in IDP service (SIN 27)
  wakeUpIntervalProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.wakeUpInterval)
  framework.delay(2)

  -- reading powerMode property (PIN 10) in IDP service (SIN 27) when terminal not in LPM
  powerModeProperty = lsf.getProperties(avlAgentCons.idpSIN,avlPropertiesPINs.powerMode)
  framework.delay(2)

  -- checking if ledControl property has been correctly reverted to value ledControlUserSet
  assert_equal(ledControlUserSet,tonumber(ledControlProperty[1].value), "Value of ledControl property has not been correctly reverted to user setting when leaving LPM")
  -- checking if Continues property has been reverted to user-saved value when leaving LPM
  assert_equal(gpsReadInterval,tonumber(continuesProperty[1].value), "Value of Interval property in Geofence service has not been reverted when leaving LPM")
  -- checking if geofence Interval has been reverted to user-saved value when leaving LPM
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been reverted when leaving LPM")
  -- checking if  wakeUpInterval property has been set to wakeUpIntervalOnExit when leaving LPM
  assert_equal(wakeUpIntervalOnExitFromLpmEnum,tonumber(wakeUpIntervalProperty[1].value), "Value of WakeUpInterval property in IDP service has not been set to WakeUpIntervalOnExit when leaving LPM")
  -- checking if powerMode property has been correctly reverted to user saved when leaving LPM
  assert_equal(powerModeUserSet,tonumber(powerModeProperty[1].value), "Value of powerMode property property has not been correctly set")



end



--- TC checks if terminal is put in and out of LPM if the trigger of LPM is set to Built-in battery .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * Device powered by external power source (in eg. cigarette lighter)
  --
  -- Steps:
  --
  -- 1. Set LpmEntryDelay (PIN 32) in AVL service to value lpmEntryDelay
  -- 2. Set LpmTrigger (PIN 31) in AVL service to 2 (that is Built-in battery)
  -- 3. Simulate external power not present for time longer than LpmEntryDelay
  -- 4. Check terminals state
  -- 5. Simulate external power present
  -- 6. Check terminals state
  --
  -- Results:
  --
  -- 1. LpmEntryDelay (PIN 32) set to lpmEntryDelay
  -- 2. LpmTrigger (PIN 31) set to Built-in battery
  -- 3. External Power not present for LpmEntryDelay
  -- 4. Terminal enters LPM
  -- 5. External power present
  -- 6. Terminal leaves LPM
function test_LPM_WhenLpmTriggerSetToBuiltInBattery_TerminalPutInLpmWhenExternalPowerSourceNotPresentAndOutOfLpmWhenExternalPowerSourcePresent()

  local lpmEntryDelay = 0    -- in minutes

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},            -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 2},                           -- 1 is for Built-in battery
                                             }
                   )

  -- Important: there is bug reported for setPower function
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")
  print(framework.dump(externalPowerPresentProperty[1].value))

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  device.setPower(8,1)             -- external power present again (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- checking if terminal left Low Power Mode after it was plugged back to external power source
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal unexpectedly in the Low Power Mode")



end



--- TC checks if terminal is put in and out of LPM if the trigger of LPM is set to both Built-in battery and IgnitionOff depening on the external power source presence .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * Device powered by external power source (in eg. cigarette lighter)
  -- * Terminal not in IgnitionOn state
  --
  -- Steps:
  --
  -- 1. Read avlStates property and check IgnitionOn state
  -- 2. Set LpmEntryDelay (PIN 32) in AVL service to value lpmEntryDelay
  -- 3. Set LpmTrigger (PIN 31) in AVL service to 3 (that is both IgnitionOn and Built-in battery)
  -- 4. Simulate external power not present for time longer than LpmEntryDelay
  -- 5. Check terminals state
  -- 6. Simulate external power present
  -- 7. Check terminals state
  --
  -- Results:
  --
  -- 1. Terminal not in IgnitionOn
  -- 2. LpmEntryDelay (PIN 32) set to lpmEntryDelay
  -- 3. LpmTrigger (PIN 31) set to IgnitionOn and Built-in battery
  -- 4. External Power not present for LpmEntryDelay
  -- 5. Terminal enters LPM
  -- 6. External power present
  -- 7. Terminal leaves LPM
function test_LPM_WhenLpmTriggerSetToIgnitionOffAndBuiltInBattery_TerminalPutInLpmWhenExternalPowerSourceNotPresentAndOutOfLpmWhenExternalPowerSourcePresent()

  local lpmEntryDelay = 0    -- in minutes

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},            -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 3},                           -- 3 is for IgnitionOn and Built-in battery
                                             }
                   )

  -- checking if terminal is not in IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- Important: there is bug reported for setPower function
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")
  print(framework.dump(externalPowerPresentProperty[1].value))

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  device.setPower(8,1)             -- external power present again (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(avlAgentCons.powerSIN,avlPropertiesPINs.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- checking if terminal left Low Power Mode after it was plugged back to external power source
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal unexpectedly in the Low Power Mode")



end



--- TC checks if terminal is put in and out of Low Power Mode according to IgnitionOn and IgnitionOff events if the trigger of LPM is set to both IgnitionOff and Built-in Battery .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 3 (IgnitionOff and Built-in Battery)
  -- 2. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 3. Check terminals state
  -- 4. Simulate high level of port
  -- 5. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 3
  -- 2. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 3. Terminal goes to LPM
  -- 4. IgnitionOn event generated
  -- 5. Terminal put out of LPM
function test_LPM_WhenLpmTriggerSetToBothIgnitionOffAndBuiltInBattery_TerminalPutInLpmAfterIgnitionOffAndPutOutOfLpmAfterIgnitionOn()

  local lpmEntryDelay = 0   -- minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 3},                                   -- 3 is for both IgnitionOff and Built-in Battery
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(5)   -- waiting for the state to change

  -- checking state of the terminal, low power mode is not expected
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")


end



--- TC checks if terminal is not put in Low Power Mode by IgnitionOff event when LPM trigger is set to Built-in Battery .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 2 (Built-in Battery)
  -- 2. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 3. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 2
  -- 2. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 3. Terminal does not go to to LPM
 function test_LPM_WhenLpmTriggerSetToBuiltInBattery_TerminalIsNotPutIntoLpmByIgnitionOffEvent()

  local lpmEntryDelay = 0   -- minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 3},                                   -- 3 is for both IgnitionOff and Built-in Battery
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay,
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is not expected (LPM trigger is set to Built-in battery)
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal in the Low Power Mode state")


end






--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


