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
  -- * Webservices: Device, GPS, Gateway  running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set gpsReadInterval (PIN 15) in Position service (SIN 20)
  -- 2. Put terminal into stationary state
  -- 3. Set all ports to low level
  -- 4. Assert if terminal not in LPM and IgnitionOn mode
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
  -- * Terminal not in the LPM
  -- * IgnitonOn is false
  -- * Port set as digital input and associated with IgnitionOn function
  -- * LpmTrigger (PIN 31) set to IgnitionOff
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Put terminal to IgnitionOn state
  -- 2. Trigger IgnitionOff (MIN 5)
  -- 3. Stay in IgnitionOff longer than LpmEntryDelay (PIN 32)
  -- Results:
  --
  -- 1. Terminal enters LPM after LpmEntryDelay
function test_LPM_WhenLpmTriggerSetTo1AndIgnitionOffStateTrueForPeriodAboveLpmEntryDelay_TerminalPutToLowPowerMode()

  local lpmEntryDelay = 1 -- time of lpmEntryDelay, in minutes

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


--- TC checks if terminal is not put into Low Power Mode if the trigger of LPM is set to IgnitionOff and
  -- the trigger is active for period below the lpmEntryDelay time
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp1 = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); set lpmEntryDelay to one minute and IgnitionOff as the trigger of low power mode;
  -- simulate port 1 value change to high state and check if terminal entered IgnitionOn state
  -- then simulate port 1 value change to low state and check if terminal entered IgnitionOff state
  -- wait for time shorter than lpmEntryDelay and check if  terminal is not put in Low Power Mode
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal not put in the Low Power Mode
function test_LPM_whenLpmTriggerSetTo1AndIgnitionOffStateTrueForPeriodBelowpmEntryDelayTerminalNotPutToLowPowerMode()

  local lpmEntryDelay = 1 -- time of lpmEntryDelay, in minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, 2},                    -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3},             -- high state is expected to trigger Ignition on
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},      -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                     -- 1 is for Ignition Off
                                             }
                   )



  device.setIO(1, 1) -- that should trigger IgnitionOn
  framework.delay(2)
  -- checking if terminal correctly goes to IgnitionOn state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
  framework.delay(5)                 -- wait for the change of state

  -- checking if terminal correctly goes to IgnitionOn false state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- waiting for time shorter than lpmEntryDelay, terminal should not go to LPM after this period
  framework.delay(5)
  -- checking the state of terminal - Low Power Mode not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal incorrectly in the Low Power Mode state")

end


--- TC checks if terminal is put out of Low Power Mode if the trigger of LPM is set to IgnitionOff and
  -- IgnitionOn state becomes true
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp1 = 2)
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 3);
  -- set lpmEntryDelay to one minute and IgnitionOff as the trigger of low power mode;
  -- simulate port 1 value change to high state and check if terminal entered IgnitionOn state
  -- then simulate port 1 value change to low state and check if terminal entered IgnitionOff state
  -- wait for time longer than lpmEntryDelay and check if after this period terminal is not in Low Power Mode
  -- after that simulate IgnitionOn and check if terminal is put out of the Low Power Mode
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the Low Power Mode
function test_LPM_whenLpmTriggerSetTo1TerminalInLpmAndIgnitionOnStateBecomesTrueTerminalPutOutOfLowPowerMode()

  local lpmEntryDelay = 1 -- time of lpmEntryDelay, in minutes

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigInp1, 2},                    -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.digStatesDefBitmap, 3},             -- high state is expected to trigger Ignition on
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},      -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, 1},                     -- 1 is for Ignition Off
                                             }
                   )


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
  framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in seconds
   -- checking state of the terminal, low power mode is expected
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


end



--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


