-----------
-- Low Power Mode test module
-- - contains Low Power Mode related test cases
-- @module TestLPMModule

module("TestLPMModule", package.seeall)

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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.lpmTrigger, 0},
                                     }
                    )
  framework.delay(2)
 -- checking the terminal state
 local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.lpmTrigger, 0},    -- 0 is for no trigger
                                           }
                    )

end

-- executed after each test suite
function suite_teardown()

  -- restarting AVL agent after running module
	local message = {SIN = lsfConstants.sins.system,  MIN = lsfConstants.mins.restartService}
	message.Fields = {{Name="sin",Value=avlConstants.avlAgentSIN}}
	gateway.submitForwardMessage(message)

  -- wait until service is up and running again and sends Reset message
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.reset),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "Reset message after reset of AVL not received")

end


--- Setup function puts terminal into stationary state, configures GPS_READ_INTERVAL, sets all ports to low level and checks if terminal is not in LPM and IgnitionOn state .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set GPS_READ_INTERVAL (PIN 15) in Position service (SIN 20)
  -- 2. Put terminal into stationary state
  -- 3. Set all ports to low level
  -- 4. Assert if terminal not in LPM and IgnitionOn mode
  --
  -- Results:
  --
  -- 1. Terminal not in LPM and IgnitionOn state
 function setup()

  lsf.setProperties(lsfConstants.sins.position,{
                                                {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}     -- setting the continues mode interval of position service
                                               }
                    )

  avlHelperFunctions.putTerminalIntoStationaryState()


  ----------------------------------------------------------------------
  -- Putting terminal in IgnitionOn = false state
  ----------------------------------------------------------------------
  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                         }
                   )


  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], 0},  -- disabled
                                                {avlConstants.pins.funcDigInp[3], 0},  -- disabled
                                                {avlConstants.pins.funcDigInp[4], 0},  -- disabled
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.GeneralPurpose}, -- digital input line 13 set for GeneralPurpose
                                             }
                    )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)

  -- toggling port 1 (in case terminal is in IgnitionOn state and port is low)
  device.setIO(1, 1)
  framework.delay(2)

  -- setting all 4 ports to low stare
  for counter = 1, 4, 1 do
    device.setIO(counter, 0)
  end
  framework.delay(3)

  -- reading avlStates property
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")
  -- checking the the Low power mode - terminal is expected not be in the low power mode
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  -- disabling line number 1
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], 0},   -- 0 is for line disabled
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
  local lpmTrigger = 1       -- 1 is for IgnitionOff

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                                   -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- wait until terminal changes state

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
  local lpmTrigger = 1       -- 1 is for IgnitionOff


  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})



  device.setIO(1, 1)  -- port transition to high state; that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(2)                 -- wait for the change of state

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time shorter than lpmEntryDelay, terminal should not go to LPM after this period
  framework.delay(lpmEntryDelay*60-40)
  -- checking the state of terminal - Low Power Mode not expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
  local lpmTrigger = 1      -- 1 is for IgnitionOff

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                      -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                            -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(4)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(4)

  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(5)   -- waiting for the state to change

  -- checking state of the terminal, low power mode is not expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")


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
  local lpmTrigger = 1              -- 1 is for Ignition Off

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )

                   -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  avlHelperFunctions.putTerminalIntoMovingState()

  device.setIO(1, 0) -- that should trigger IgnitionOff
  framework.delay(2)

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  -- reading AVLStates property to check moving state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  -- checking if terminal is not in moving state (while being in LPM)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal unexpectedly in moving state while being in LPM")

  device.setIO(1, 1) -- IgnitionOn line becomes active, that should trigger IgnitionOn
  framework.delay(4)

  -- checking state of the terminal, Low Power Mode is not expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")

  -- reading movingDebounceTime property (it is needed as delay value in next step)
  local movingDebounceTime = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.movingDebounceTime)
  framework.delay(2)

  -- waiting until terminal goes into moving state again (speed is above threshold)
  framework.delay(movingDebounceTime[1].value+GPS_READ_INTERVAL+10)

  -- reading AVLStates property to check moving state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
  -- 2. Set Continues  property (PIN 15) in Position service (SIN 20) to value GPS_READ_INTERVAL
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
  -- 15. Read Continues property (PIN 15) and verify if it has been reverted to value GPS_READ_INTERVAL
  -- 16. Read geofence check Interval (PIN 2) and verify if it has been reverted to value A
  -- 17. Read WakeUpInterval property (PIN 11) and verify if it has been set to 5_seconds
  -- 18. Read powerMode property (PIN 10) and verify if it has been reverted to powerModeUserSet
  --
  -- Results:
  --
  -- 1. LedControl set to value ledControlUserSet
  -- 2. Continues set to to value GPS_READ_INTERVAL
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
  -- 15. Value of Continues property (PIN 15, SIN 20) has been reverted to GPS_READ_INTERVAL when leaving LPM
  -- 16. Value of Interval property (PIN 2, SIN 21) has been reverted to value A when leaving LPM
  -- 17. Value of WakeUpInterval property (PIN 11, SIN 27) has been set to 5_seconds when leaving LPM
  -- 18. Value of powerMode (PIN 10, SIN 27) has been reverted to powerModeUserSet
function test_LPM_WhenTerminalEntersAndLeavesLPM_ValuesOfSomePropertiesAreChangedwhenEnteringLpmAndRevertedWhenLeavingLpm()

  local GPS_READ_INTERVAL = 1                           -- seconds
  local lpmEntryDelay = 0                             -- minutes
  local lpmTrigger = 1                                -- 1 is for IgnitionOff
  local ledControlUserSet = 0                         -- enum type property (0 - Terminal, 1 - User)
  local lpmGeoInterval = 120                          -- seconds
  local geofenceInterval = 50                         -- seconds
  local powerModeUserSet = 4                          -- enum type (0-Mobile Powered, 1 - FixedPowered, 2 - MobileBattery, 3 - FixedBattery, 4 - MobileMinBattery)
  local lpmModemWakeUpInterval = "30_minutes"         -- lpmModemWakeUpInterval value
  local wakeUpInterval = "3_minutes"                  -- wakeUpInterval value
  local wakeUpIntervalOnExitFromLpm = "5_seconds"     -- value of wakeUpInterval which should be set when leaving LPM (this cannot be modified)
  -- helper variables for handling wakeUpInterval
  local lpmModemWakeUpIntervalEnum = lsfConstants.modemWakeUpIntervalValues[lpmModemWakeUpInterval]           -- lpmModemWakeUpInterval enum representation (enum type property)
  local wakeUpIntervalEnum = lsfConstants.modemWakeUpIntervalValues[wakeUpInterval]                           -- wakeUpInterval num representation
  local wakeUpIntervalOnExitFromLpmEnum = lsfConstants.modemWakeUpIntervalValues[wakeUpIntervalOnExitFromLpm] -- wakeUpIntervalOnExitFromLpm enum representation
  -- definition of getProperties message to read properties from 4 services at once
  local getPropertiesMessage = {SIN = 16, MIN = 8}
	getPropertiesMessage.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=lsfConstants.sins.system},{Name="pinList",Value="Bg=="}}},    -- PIN 6
                                                        {Index=1,Fields={{Name="sin",Value=lsfConstants.sins.position},{Name="pinList",Value="Dw=="}}},  -- PIN 15
                                                        {Index=2,Fields={{Name="sin",Value=lsfConstants.sins.geofence},{Name="pinList",Value="Ag=="}}},  -- PIN 2
                                                        {Index=3,Fields={{Name="sin",Value=lsfConstants.sins.idp},{Name="pinList",Value="Cgs="}}}}}}     -- PIN 10 and 11

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn},   -- line set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                      -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                            -- setting lpmTrigger
                                                {avlConstants.pins.lpmGeoInterval, lpmGeoInterval},                    -- setting low power mode geofence check interval
                                                {avlConstants.pins.lpmModemWakeUpInterval, lpmModemWakeUpIntervalEnum},-- setting low power mode modem wake up interval
                                             }
                   )

  -- sending setProperties to set properties in System, Position, Geofence, IDP and EIO services
	local message = {SIN = 16, MIN = 9}
	message.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=lsfConstants.sins.system},  {Name="propList",Elements={{Index=0,Fields={{Name="pin",Value=lsfConstants.pins.ledControl},      {Name="value",Type="enum",Value=ledControlUserSet}}}}}}},
                                           {Index=1,Fields={{Name="sin",Value=lsfConstants.sins.position},{Name="propList",Elements={{Index=0,Fields={{Name="pin",Value=lsfConstants.pins.gpsReadInterval}, {Name="value",Type="unsignedint",Value=GPS_READ_INTERVAL}}}}}}},
                                           {Index=2,Fields={{Name="sin",Value=lsfConstants.sins.geofence},{Name="propList",Elements={{Index=0,Fields={{Name="pin",Value=lsfConstants.pins.geofenceInterval},{Name="value",Type="unsignedint",Value=geofenceInterval}}}}}}},
                                           {Index=3,Fields={{Name="sin",Value=lsfConstants.sins.idp},     {Name="propList",Elements={{Index=0,Fields={{Name="pin",Value=lsfConstants.pins.wakeUpInterval},  {Name="value",Type="enum",Value=wakeUpIntervalEnum}}},
                                                                                                                                    { Index=1,Fields={{Name="pin",Value=lsfConstants.pins.powerMode},       {Name="value",Type="enum",Value=powerModeUserSet}}}}}}},
                                           {Index=4,Fields={{Name="sin",Value=lsfConstants.sins.io},      {Name="propList",Elements={{Index=0,Fields={{Name="pin",Value=lsfConstants.pins.portConfig[1]},     {Name="value",Type="unsignedint",Value=3}}},
                                                                                                                                    { Index=1,Fields={{Name="pin",Value=lsfConstants.pins.portEdgeDetect[1]}, {Name="value",Type="unsignedint",Value=3}}}}}}}}},
                                           {Name="save",Value=true}}

  gateway.submitForwardMessage(message)

  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking state of the terminal, Low Power Mode is not expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)
  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties before entering Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  -- sending getProperties message (SIN 16, MIN 8) to mobile
  gateway.submitForwardMessage(getPropertiesMessage)

  -- propertyValues message expected in response to getProperties
  propertyValuesMessage = gateway.getReturnMessage(framework.checkMessageType(lsfConstants.sins.system, lsfConstants.mins.propertyValues),nil,GATEWAY_TIMEOUT)
  assert_not_nil(propertyValuesMessage, "PropertyValues message not received")

  local ledControlProperty = propertyValuesMessage.Payload.Fields[1].Elements[1].Fields[2].Elements[1].Fields[2].Value
  assert_equal(ledControlUserSet,tonumber(ledControlProperty), "Value of ledControl property has not been correctly set")

  local continuesProperty = propertyValuesMessage.Payload.Fields[1].Elements[2].Fields[2].Elements[1].Fields[2].Value
  assert_equal(GPS_READ_INTERVAL,tonumber(continuesProperty), "Value of Continues property has not been correctly set")

  local geofenceIntervalProperty = propertyValuesMessage.Payload.Fields[1].Elements[3].Fields[2].Elements[1].Fields[2].Value
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty), "Value of Interval property in Geofence service has not been correctly set")

  local wakeUpIntervalProperty =  propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[2].Fields[2].Value
  assert_equal(wakeUpIntervalEnum,tonumber(wakeUpIntervalProperty), "Value of WakeUpInterval property has not been correctly set")

  local powerModeProperty = propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[1].Fields[2].Value
  assert_equal(powerModeUserSet,tonumber(powerModeProperty), "Value of powerMode property has not been correctly set")

  ------------------------------------------------------------------------------------------------------------------
  -- Terminal enters Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  device.setIO(1, 0) -- that should trigger IgnitionOff
  framework.delay(2)

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties after entering Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  -- sending getProperties message (SIN 16, MIN 8) to mobile
  gateway.submitForwardMessage(getPropertiesMessage)
  -- propertyValues message expected in response to getProperties
  propertyValuesMessage = gateway.getReturnMessage(framework.checkMessageType(lsfConstants.sins.system, lsfConstants.mins.propertyValues,nil,GATEWAY_TIMEOUT)  assert_not_nil(propertyValuesMessage, "PropertyValues message not received")

  ledControlProperty = propertyValuesMessage.Payload.Fields[1].Elements[1].Fields[2].Elements[1].Fields[2].Value
  -- checking if  ledControl property (PIN 6)  has been set to 1 - Terminal when entering LPM
  assert_equal(1,tonumber(ledControlProperty), "Value of ledControl property in System service has not been set to 1 when entering LPM")

  continuesProperty = propertyValuesMessage.Payload.Fields[1].Elements[2].Fields[2].Elements[1].Fields[2].Value
  -- checking if  Continues property (PIN 15) has been set to 0 when entering LPM
  assert_equal(0,tonumber(continuesProperty), "Value of Continues property in Position service has not been set to 0 when entering LPM")

  geofenceIntervalProperty = propertyValuesMessage.Payload.Fields[1].Elements[3].Fields[2].Elements[1].Fields[2].Value
  -- checking if geofence Interval has been changed to LpmGeoInterval when entering LPM
  assert_equal(lpmGeoInterval,tonumber(geofenceIntervalProperty), "Value of Interval property in Geofence service has not been changed when entering LPM")

  wakeUpIntervalProperty =  propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[2].Fields[2].Value
  -- checking if  wakeUpInterval property has been set to lpmModemWakeUpInterval when entering LPM
  assert_equal(lpmModemWakeUpIntervalEnum,tonumber(wakeUpIntervalProperty), "Value of WakeUpInterval property in IDP service has not been set to LpmModemWakeUpInterval when entering LPM")

  powerModeProperty = propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[1].Fields[2].Value
  -- checking if powerMode property has been correctly changed
  assert_equal(2,tonumber(powerModeProperty), "Value of powerMode property has not been changed to MobileBattery when entering LPM")

  ------------------------------------------------------------------------------------------------------------------
  -- Terminal leaves Low Power Mode
  ------------------------------------------------------------------------------------------------------------------

  device.setIO(1, 1) -- IgnitionOn line becomes active, that should trigger IgnitionOn
  framework.delay(4)

  -- checking state of the terminal, Low Power Mode is not expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in LPM state")
  framework.delay(2)

  ------------------------------------------------------------------------------------------------------------------
  -- Checking properties after leaving Low Power Mode
  ------------------------------------------------------------------------------------------------------------------
  -- sending getProperties message (SIN 16, MIN 8) to mobile
	gateway.submitForwardMessage(getPropertiesMessage)
  -- propertyValues message expected in response to getProperties
  propertyValuesMessage = gateway.getReturnMessage(framework.checkMessageType(lsfConstants.sins.system, lsfConstants.mins.propertyValues),nil,GATEWAY_TIMEOUT)
  assert_not_nil(propertyValuesMessage, "PropertyValues message not received")

  ledControlProperty = propertyValuesMessage.Payload.Fields[1].Elements[1].Fields[2].Elements[1].Fields[2].Value
  -- checking if ledControl property has been correctly reverted to value ledControlUserSet
  assert_equal(ledControlUserSet,tonumber(ledControlProperty), "Value of ledControl property has not been correctly reverted to user setting when leaving LPM")

  continuesProperty = propertyValuesMessage.Payload.Fields[1].Elements[2].Fields[2].Elements[1].Fields[2].Value
  -- checking if Continues property has been reverted to user-saved value when leaving LPM
  assert_equal(GPS_READ_INTERVAL,tonumber(continuesProperty), "Value of Interval property in Geofence service has not been reverted when leaving LPM")

  geofenceIntervalProperty = propertyValuesMessage.Payload.Fields[1].Elements[3].Fields[2].Elements[1].Fields[2].Value
  -- checking if geofence Interval has been reverted to user-saved value when leaving LPM
  assert_equal(geofenceInterval,tonumber(geofenceIntervalProperty), "Value of Interval property in Geofence service has not been reverted when leaving LPM")

  wakeUpIntervalProperty =  propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[2].Fields[2].Value
  -- checking if  wakeUpInterval property has been set to wakeUpIntervalOnExit when leaving LPM
  assert_equal(wakeUpIntervalOnExitFromLpmEnum,tonumber(wakeUpIntervalProperty), "Value of WakeUpInterval property in IDP service has not been set to WakeUpIntervalOnExit when leaving LPM")

  powerModeProperty = propertyValuesMessage.Payload.Fields[1].Elements[4].Fields[2].Elements[1].Fields[2].Value
  -- checking if powerMode property has been correctly reverted to user saved when leaving LPM
  assert_equal(powerModeUserSet,tonumber(powerModeProperty), "Value of powerMode property property has not been correctly set when leaving LPM")


end



--- TC checks if terminal is put in and out of LPM depening on the external power source presence if the trigger of LPM is set to Built-in battery  .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * Device powered by external power source (in eg. cigarette lighter)
  -- * IDP 800 terminal simulated
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

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0    -- in minutes
  local lpmTrigger = 2       -- 2 is for Built-in battery

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},            -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                  -- setting lpmTrigger
                                             }
                   )

  -- Important: there is bug reported for setPower function
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(3)               -- wait until setting is applied
  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(3)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")


  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)

  framework.delay(2)
  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(3)               -- wait until setting is applied

  assert_equal("False", externalPowerPresentProperty[1].value, "External power source unexpectedly present")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.delay(2)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  device.setPower(8,1)             -- external power present again (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  -- checking if terminal left Low Power Mode after it was plugged back to external power source
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal unexpectedly in the Low Power Mode")



end



--- TC checks if terminal is not put in LPM when external power source is not present for time shorter than lpmEntryDelay for trigger of LPM set to Built-in battery  .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * Device powered by external power source (in eg. cigarette lighter)
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Set LpmEntryDelay (PIN 32) in AVL service to value lpmEntryDelay
  -- 2. Set LpmTrigger (PIN 31) in AVL service to 2 (that is Built-in battery)
  -- 3. Simulate external power not present for time shorter than LpmEntryDelay
  -- 4. Simulate external power present again
  -- 5. Check terminals state
  --
  -- Results:
  --
  -- 1. LpmEntryDelay (PIN 32) set to lpmEntryDelay
  -- 2. LpmTrigger (PIN 31) set to Built-in battery
  -- 3. External Power not present for time shorter than LpmEntryDelay
  -- 4. External power present
  -- 6. Terminal does not enter LPM
function test_LPM_WhenLpmTriggerSetToBuiltInBattery_TerminalNotPutInLpmWhenExternalPowerSourceNotPresentShorterThanLpmEntryDelayPeriod()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 1    -- in minutes
  local lpmTrigger = 2       -- 2 is for Built-in battery

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},            -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                  -- setting lpmTrigger
                                             }
                   )

  -- setting external power source
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(3)               -- wait until setting is applied
  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("False", externalPowerPresentProperty[1].value,  "External power source unexpectedly present")

  -- waiting for time shorter than lpmEntryDelay, terminal should not enter LPM
  framework.delay(lpmEntryDelay*60-30)    -- multiplication by 60 because lpmEntryDelay is in minutes

  device.setPower(8,1)             -- external power present again (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  -- checking if terminal has not entered LPM
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.delay(6)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal unexpectedly in the Low Power Mode")



end



--- TC checks if terminal is put in and out of LPM if the trigger of LPM is set to both Built-in battery and IgnitionOff depening on the external power source presence .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * Device powered by external power source (in eg. cigarette lighter)
  -- * Terminal not in IgnitionOn state
  -- * IDP 800 terminal simulated
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

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0    -- in minutes
  local lpmTrigger = 3       -- 3 is for IgnitionOn and Built-in battery

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},            -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                  -- setting lpmTrigger
                                             }
                   )
  framework.delay(2)

  -- checking if terminal is not in IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.delay(2)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)

  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("False", externalPowerPresentProperty[1].value,  "External power source unexpectedly present")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state as expected")

  device.setPower(8,1)             -- external power present again (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  -- checking if terminal left Low Power Mode after it was plugged back to external power source
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0   -- minutes
  local lpmTrigger = 3      -- 3 is for both IgnitionOff and Built-in Battery

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -----------------------------------------------------------------------------------
  -- External power is present and ignition is on - terminal not in the LPM
  -----------------------------------------------------------------------------------
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  -- checking state of the terminal, Low Power Mode is not expected (LPM trigger is set to Built-in battery)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal in the Low Power Mode state")

  -----------------------------------------------------------------------------------
  -- External power is present but ignition is off - terminal put in the LPM
  -----------------------------------------------------------------------------------
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  -----------------------------------------------------------------------------------
  -- External power is present and ignition is on again - terminal put out of LPM
  -----------------------------------------------------------------------------------
  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(7)   -- waiting for the state to change

  -- checking state of the terminal, low power mode is not expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0   -- minutes
  local lpmTrigger = 2      -- 2 is for Built-in Battery

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})


  ---------------------------------------------------------
  -- Ignition in on and external power is present
  ---------------------------------------------------------

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.delay(2)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- checking state of the terminal, Low Power Mode is not expected (LPM trigger is set to Built-in battery)
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal in the Low Power Mode state")

  ---------------------------------------------------------
  -- Ignition in off and external power is still present
  ---------------------------------------------------------

  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay,
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is not expected (LPM trigger is set to Built-in battery)
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal in the Low Power Mode state")


end


--- TC checks if terminal is not put in Low Power Mode by IgnitionOff or external power source not present when LPM trigger is set to 0 (no trigger) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 0
  -- 3. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 4. Check terminals state
  -- 5. Simulate external power source change to 0 (terminal unplugged from external power source)
  -- 6. Check terminal state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 0
  -- 3. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 4. Terminal does not enter LPM
  -- 5. Terminal unplugged from external power source
  -- 6. Terminal doesn not enter LPM
 function test_LPM_WhenLpmTriggerSetToZero_TerminalIsNotPutIntoLpmByIgnitionOffEventOrUnpluggingExternalPowerSource()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0   -- minutes
  local lpmTrigger = 0      -- 0 is for no trigger

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(3)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.delay(2)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time longer than lpmEntryDelay,
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is not expected (LPM trigger is set to 0)
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal in the Low Power Mode state")

  -- setting external power source
  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal("False", externalPowerPresentProperty[1].value,  "External power source unexpectedly present")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal has not entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")


end


--- TC checks if terminal is not put in Low Power Mode when terminal is unplugged from external power source for LPM trigger set to IgnitionOff .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Set LpmTrigger (PIN 31) to 1 (IgnitionOff)
  -- 2. Simulate external power source not present for time longer than LpmEntryDelay
  -- 3. Check terminals state
  --
  -- Results:
  --
  -- 1. LpmTrigger (PIN 31) set to 1 (IgnitionOff)
  -- 2. External Power not present for LpmEntryDelay
  -- 3. Terminal does not enter LPM
 function test_LPM_WhenLpmTriggerSetToIgnitionOff_TerminalIsNotPutIntoLpmWhenExternalPowerSourceIsNotPresent()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0   -- minutes
  local lpmTrigger = 1      -- 1 is for IgnitionOff

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )

  -- setting external power source
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(3)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(2)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present")

  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal("False", externalPowerPresentProperty[1].value,  "External power source unexpectedly present")

  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

  -- checking if terminal has not entered Low Power Mode after it was powered by built-in battery for time longer than LpmEntryDelay
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")

end



--- TC checks if terminal is put in and out of Low Power Mode when both Ignition is on and external power is present for the LPM trigger set to both IgnitionOff and Built-in Battery .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set port as digital input and associate it with IgnitionOn line
  -- 2. Set LpmTrigger (PIN 31) to 3 (IgnitionOff and Built-in Battery)
  -- 3. Simulate external power source present (set to 1)
  -- 4. Simulate high level of input port and check IgnitionOn state
  -- 5. Simulate low level of port for period longer than LpmEntryDelay (PIN 32)
  -- 6. Check terminals state
  -- 7. Simulate external power source change to 0 (terminal unplugged from external power source)
  -- 8. Simulate high level of port
  -- 9. Check terminals state
  -- 10. Simulate external power source change to 1 (terminal plugged to external power source)
  -- 11. Check terminals state
  --
  -- Results:
  --
  -- 1. Port set as digital input and associated with IgnitionOn line
  -- 2. LpmTrigger (PIN 31) set to 3
  -- 3. Terminal powered by external power source
  -- 4. Ignition is on
  -- 5. IgnitionOff event generated and terminal in IgnitionOn = false for time longer than LpmEntryDelay
  -- 6. Terminal enters LPM
  -- 7. External power source not present
  -- 8. IgnitionOn event generated
  -- 9. Terminal not put out of LPM (terminal still powered by Built-in battery)
  -- 10. External power present
  -- 11. Terminal leaves LPM
function test_LPM_WhenLpmTriggerSetToBothIgnitionOffAndBuiltInBattery_TerminalPutOutOfLpmWhenBothIgnitionIsOnAndExternalPowerIsPresent()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 0   -- minutes
  local lpmTrigger = 3      -- 3 is for both IgnitionOff and Built-in Battery


  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                          -- setting lpmTrigger
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- setting external power source
  device.setPower(8,1)             -- external power present (terminal plugged back to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  framework.delay(4)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")


  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- waiting for the state to change

  -- checking if terminal correctly goes to IgnitionOn false state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- setting external power source
  device.setPower(8,0)             -- external power not present from now (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- checking ExtPowerPresent property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal("False", externalPowerPresentProperty[1].value,  "External power source unexpectedly present")


  -- waiting for time longer than lpmEntryDelay, terminal should go to LPM after this period
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes
  -- checking state of the terminal, Low Power Mode is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)

  -- checking if terminal correctly goes to IgnitionOn state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")
  framework.delay(5)   -- waiting for the state to change

  -- checking state of the terminal, Low Power Mode is expected (terminal still powered by Built-in Battery - trigger is true)
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")

  device.setPower(8,1)             -- external power present (terminal plugged back to external power source)
  framework.delay(2)               -- wait until setting is applied
  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal("True", externalPowerPresentProperty[1].value, "External power source not present as expected")

  -- checking state of the terminal, low power mode is not expected from now (both triggers are not true)
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  framework.dump(2)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")


end




