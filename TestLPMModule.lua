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
  -- 1. Set LpmTrigger (PIN 31)
  --
  -- Results:
  --
  -- 1. LpmTrigger (PIN 31) set
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
 local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
 assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")


end
-----------------------------------------------------------------------------------------------

--[[
    START OF TEST CASES

    Each test case is a global function whose name begins with "test"

--]]



--- TC checks if terminal is put into LPM if the trigger of LPM is set to IgnitionOff and trigger is true longer than lpmEntryDelay .
  -- Initial Conditions:
  --
  -- * Terminal in LPM and IgnitionOn
  -- * LpmTrigger (PIN 31) set to IgnitionOff
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Trigger IgnitionOff (MIN 5)
  -- 2. Stay in IgnitionOff longer than LpmEntryDelay (PIN 32)
  --
  -- Results:
  --
  -- 1. Terminal enters LPM after LpmEntryDelay
function test_LPM_WhenLpmTriggerSetTo1AndIgnitionOffStateTrueForPeriodAboveLpmEntryDelay_TerminalPutToLowPowerMode()

  local lpmEntryDelay = 1    -- in minutes

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
  framework.delay(5)                 -- wait until terminal changes state

  -- checking if terminal correctly goes to IgnitionOn false state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")


  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

end



--- TC checks if terminal is not put into LPM if the trigger of LPM is set to IgnitionOff and trigger is true shorter than lpmEntryDelay .
  -- Initial Conditions:
  --
  -- * Terminal not in the LPM
  -- * IgnitonOn is false
  -- * LpmTrigger (PIN 31) set to IgnitionOff
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Put terminal to IgnitionOn state
  -- 2. Trigger IgnitionOff (MIN 5)
  -- 3. Stay in IgnitionOff shorter than LpmEntryDelay (PIN 32)
  --
  -- Results:
  --
  -- 1. Terminal does not enter LPM after LpmEntryDelay
function test_LPM_WhenLpmTriggerSetTo1AndIgnitionOffStateTrueForPeriodBelowpmEntryDelay_TerminalNotPutToLowPowerMode()

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
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time shorter than lpmEntryDelay, terminal should not go to LPM after this period
  framework.delay(lpmEntryDelay*60-40)
  -- checking the state of terminal - Low Power Mode not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")

  device.setIO(1, 0)                 -- port transition to high state; that should trigger IgnitionOn
  framework.delay(5)                 -- wait for the change of state


end


--- TC checks if terminal is put out of Low Power Mode if the trigger of LPM is set to IgnitionOff and IgnitionOn state becomes true .
  -- Initial Conditions:
  --
  -- * Terminal in LPM
  -- * LpmTrigger (PIN 31) set to IgnitionOff
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Trigger IgnitionOn message (MIN 4)
  --
  -- Results:
  --
  -- 1. Terminal put out of LPM
function test_LPM_WhenLpmTriggerSetTo1TerminalInLpmAndIgnitionOnStateBecomesTrue_TerminalPutOutOfLowPowerMode()

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
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(5)   -- waiting for the state to change

  -- checking state of the terminal, low power mode is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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
function test_LPM_WhenTerminalInLowPowerMode_GeofenceCheckIntervalSetToLpmGeoInterval()

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
  local message = {SIN = 16, MIN = 5}
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
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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



--- TC checks if geofence interval is changed to LpmGeoInterval when entering LPM and reverted to user-saved value when leaving it .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set Interval (PIN 2) in Geofence service (SIN 21) to value A
  -- 2. Set LpmGeoInterval (PIN 33) in AVL service (SIN 126) to value B
  -- 3. Set LpmTrigger (PIN 31) to 1 to make IgnitionOff the trigger of entering LPM
  -- 4. Simulate IgnitionOn line in non-active state for time longer than LpmEntryDelay and check terminals state
  -- 5. Read Interval (PIN 2) in Geofence (SIN 21) service and verify that is has value B (LpmGeoInterval)
  -- 6. Simulate IgnitionOn line in active state and check terminals state
  -- 7. Read geofence check Interval (PIN 2) and verify if its value has been reverted to A
  --
  -- Results:
  --
  -- 1. Geofence Interval (PIN 2) set to value A
  -- 2. LpmGeoInterval (PIN 33) set to value B
  -- 3. IgnitionOff set as trigger for LPM
  -- 4. Terminal enters LPM after LpmEntryDelay (PIN 32)
  -- 5. Value of Geofence Interval (PIN 2) has been changed to B after entering LPM
  -- 6. Terminal goes out of LPM
  -- 7. Value of geofence check Interval (PIN 2) has been reverted to A when leaving LPM
function test_LPM_WhenEntersAndLeavesLPM_ValueOfGeofenceCheckIntervalIsChangedToLpmGeoIntervalAndRevertedWhenLeaving()

  local lpmEntryDelay = 1           -- minutes
  local lpmGeoInterval = 120        -- seconds
  local geofenceInterval = 50       -- seconds

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                               {avlPropertiesPINs.geofenceInterval, geofenceInterval},  -- setting Interval in geofence service
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

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  -- reading Interval (PIN 2) in Geofence service (SIN 21) when terminal not in LPM
  local geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)
  print(framework.dump(tonumber(geofenceIntervalProperty[1].value)))
  -- checking if geofence Interval has been changed to LpmGeoInterval when entering LPM
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been changed when entering LPM")

  device.setIO(1, 0) -- that should trigger IgnitionOff
  framework.delay(2)

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  -- reading Interval (PIN 2) in Geofence service (SIN 21) when terminal in LPM
  local geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)
  print(framework.dump(tonumber(geofenceIntervalProperty[1].value)))
  -- checking if geofence Interval has been changed to LpmGeoInterval when entering LPM
  assert_equal(lpmGeoInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been changed when entering LPM")


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  -- reading Interval (PIN 2) in Geofence service (SIN 21) when terminal out of LPM
  local geofenceIntervalProperty = lsf.getProperties(avlAgentCons.geofenceSIN,avlPropertiesPINs.geofenceInterval)
  framework.delay(2)
  print(framework.dump(tonumber(geofenceIntervalProperty[1].value)))
  -- checking if geofence Interval has been reverted to user-saved value when leaving LPM
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty[1].value), "Value of Interval property in Geofence service has not been reverted when leaving LPM")


end



--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


