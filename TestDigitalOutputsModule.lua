-----------
-- Digital Outputs test module
-- - contains digital output related test cases
-- @module TestDigitalOutputsModule

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
  local digOutActiveBitmap = 0          -- setting DigOutActiveBitmap 0

  -- gps settings table
  local gpsSettings={
              speed = 0,        -- kmh, terminal not moving
              fixType=3,        -- valid fix provided
              latitude = 1,     -- degrees
              longitude = 1,    -- degrees
              heading = 90,     -- degrees
                     }

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                              {avlPropertiesPINs.digOutActiveBitmap, digOutActiveBitmap}

                                             }
                    )

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(stationaryDebounceTime+gpsReadInterval+3) -- three seconds are added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")

  -- setting all 4 ports to low state
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


--- TC checks if digital output line associated with IgnitionOn state is changing according to IgnitionOn state
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with IgnitionOn function;
  -- configure port 3 as a digital input and associate this port also with IgnitionOn function;
  -- set the high state of the port 3 to be a trigger for line activation; then simulate port 3 value change to
  -- high state and check if terminal goes to IgnitionOn state; check the state of port 1 - high state is expected
  -- simulate port 3 value change to low state - check if terminal goes to IgnitionOn false and port 1 goes back to low state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to IgnitionOn state
function test_DigitalOutput_WhenTerminalInIgnitionOnState_DigitalOutputPortAssociatedWithIgnitionOnInHighState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["IgnitionOn"]},    -- digital output line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["IgnitionOn"]},    -- digital input line number 3 set for Ignition function
                                             }
                   )
  -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected
  assert_equal(0, device.getIO(1), "Port1 associated with IgnitionOn is not in low state as expected")

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected
  assert_equal(1, device.getIO(1), "Port1 associated with IgnitionOn is not in high state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOn state change to false
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected
  assert_equal(0, device.getIO(1), "Port1 associated with IgnitionOn is not in low state as expected")

end



--- TC checks if digital output line associated with Moving state is changing when speed is above Stationary Speed Threshold
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with Moving function; check if state of the line is initially low
  -- simulate speed above Stationary Speed Threshold and check if port 1 changes state to high immediately (before Moving state
  -- is obtained); then simulate speed below Stationary Speed Threshold and check if port 1 changes back to low level
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes state when speed is above Stationary Speed Threshold
function test_DigitalOutput_WhenSpeedAboveStationarySpeedThreshold_DigitalOutputPortAssociatedWithMovingStateInHighState()

  local movingDebounceTime =  60     -- seconds
  local stationarySpeedThld = 5      -- kmh

  -- gpsSettings to be used in TC
  local gpsSettings={
              speed = stationarySpeedThld+10 ,   -- speed above threshold
              latitude = 1,                      -- degrees
              longitude = 1,                     -- degrees
              fixType=3,                         -- valid fix provided
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["Moving"]},   -- digital output line number 1 set for Moving function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},          -- moving related
                                             }
                   )
  -- activating special output function
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as speed is below stationarySpeedThld
  assert_equal(0, device.getIO(1), "Port1 associated with Moving is not in low state as expected")

  -- applying gps settings to simulate speed above stationarySpeedThld
  gps.set(gpsSettings)
  framework.delay(3)  -- wait until settings are applied but not longer than movingDebounceTime

  -- asserting state of port 1 - high state is expected - speed above stationarySpeedThld
  assert_equal(1, device.getIO(1), "Port1 associated with Moving is not in high state as expected")

  -- simulating speed below stationarySpeedThld
  gpsSettings.speed = stationarySpeedThld - 1  -- kmh
  gps.set(gpsSettings)                         -- applying gps settings
  framework.delay(2)                           -- wait until settings are applied

  -- asserting state of port 1 - low state is expected - speed below stationarySpeedThreshold
  assert_equal(0, device.getIO(1), "Port1 associated with Moving is not in low state as expected")

end


--- TC checks if digital output line associated with Speeding state is changing when speed is above defaultSpeedLimit
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with Speeding function; simulate terminal moving and check if state of the port
  -- is low state; then simulate speed above defaultSpeedLimit for time shorter than speedingTimeOver (not to get Speeding state) and check if the
  -- state of port 1 changes to high; then simulate speed below defaultSpeedLimit again and check if port state changes back to low;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes when speed above defaultSpeedLimit
function test_DigitalOutput_WhenSpeedAboveDefaultSpeedLimit_DigitalOutputPortAssociatedWithSpeedingInHighState()

  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh
  local stationaryDebounceTime = 1  -- seconds
  local speedingTimeOver  = 60      -- seconds
  local defaultSpeedLimit = 80      -- kmh


  -- gpsSettings to be used in TC
  local gpsSettings={
              speed = stationarySpeedThld+1 ,    -- speed above stationary threshold, terminal in moving (non-speeding) state
              latitude = 1,                      -- degrees
              longitude = 1,                     -- degrees
              fixType=3,                         -- valid fix provided
                     }
  gps.set(gpsSettings) -- apply gps settings
  framework.delay(movingDebounceTime+gpsReadInterval+2) -- wait until terminal goes to moving state

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["Speeding"]}, -- digital output line number 1 set for Moving function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},          -- moving related
                                                {avlPropertiesPINs.stationaryDebounceTime,stationaryDebounceTime},    -- moving related
                                                {avlPropertiesPINs.speedingTimeOver,speedingTimeOver},                -- speeding related
                                                {avlPropertiesPINs.defaultSpeedLimit,defaultSpeedLimit},              -- speeding related

                                             }
                   )
  -- activating special output function
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(3)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as terminal is not speeding yet
  assert_equal(0, device.getIO(1), "Port1 associated with digital output line 1 is not in low state as expected")

  -- applying gps settings to simulate terminal moving
  gpsSettings.speed = defaultSpeedLimit + 10           -- kmh, 10 kmh above speed limit
  gps.set(gpsSettings)                                 -- speeding time over
  framework.delay(4)                                   -- wait shorter than speedingTimeOver not to put terminal into speeding state

  -- asserting state of port 1 - high state is expected - speed above defau
  assert_equal(1, device.getIO(1), "Port1 associated with digital output line 1 is not in high state as expected")

  -- simulating speed below defaultSpeedLimit again
  gpsSettings.speed = defaultSpeedLimit - 10   -- 10 kmh below threshold
  gps.set(gpsSettings)
  framework.delay(3)

  -- asserting state of port 1 - low state is expected - speed below defaultSpeedLimit
  assert_equal(0, device.getIO(1), "Port1 associated with digital output line 1 is not in low state as expected")

end


--- TC checks if digital output line associated with Idling state is active when terminal is stationary and ignition is switched on
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with Idling function; configure port 3 as a digital input and
  -- associate this port with IgnitionOn function; set the high state of the port 3 to be a trigger for line activation; for terminal in stationary
  -- state check if initial state of port 1 is low; simulate port 3 value change to high state to trigger IgnitionOn; wait for time shorter
  -- than maxIdlingTime and check if port 1 value has changed to high state; then set port 3 to low level - that triggers IgnitionOff and
  -- check if port 1 output is low again; in the end simulate ignition = on (port 3 high) but terminal in moving state - port 1 is expected to be
  -- in low state then (no idling)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 is high when terminal is stationary and ignition is switched on
function test_DigitalOutput_WhenTerminalStationaryAndIgnitionIsOn_DigitalOutputPortAssociatedWithIdlingInHighState()

  local maxIdlingTime =  30          -- seconds
  local movingDebounceTime =  1      -- seconds
  local stationarySpeedThld = 5      -- kmh

  -- gpsSettings to be used in TC
  local gpsSettings={
              speed = stationarySpeedThld+10 ,   -- speed above threshold
              latitude = 1,                      -- degrees
              longitude = 1,                     -- degrees
              fixType=3,                         -- valid fix provided
                     }


  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                               {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["IgnitionOn"]},  -- digital input line number 3 set for Ignition function
                                               {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["Idling"]},      -- digital output line number 1 set for Idling function
                                               {avlPropertiesPINs.maxIdlingTime,maxIdlingTime},                         -- Idling related

                                             }
                   )
   -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as terminal is not moving but ignition is off
  assert_equal(0, device.getIO(1), "Port1 associated with Idling is not in low state as expected")

  device.setIO(3, 1)                   -- port 3 to high level - that should trigger ignition on
  framework.delay(maxIdlingTime-25)    -- wait shorter than maxIdlingTime, not to get EngineIdling state

  -- asserting state of port 1 - high state is expected - terminal not moving and ignition is on
  assert_equal(1, device.getIO(1), "Port1 associated with Idling is not in high state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger ignition off
  framework.delay(4)     -- wait until IgnitionOff message is processed

  -- asserting state of port 1 - low state is expected - terminal not moving but ignition is off again
  assert_equal(0, device.getIO(1), "Port1 associated with Idling not in low state as expected")

  device.setIO(3, 1)                   -- port 3 to high level - that should trigger ignition on
  framework.delay(maxIdlingTime-25)    -- wait shorter than maxIdlingTime

  -- asserting state of port 1 - high state is expected - terminal not moving and ignition is on
  assert_equal(1, device.getIO(1), "Port1 associated with Idling is not in high state as expected")

  -- now put terminal in moving state and check if Idling output line becomes low
  gps.set(gpsSettings) -- applying settings of gps simulator to make terminal moving
  framework.delay(movingDebounceTime+gpsReadInterval+3) -- wait until terminal becomes moving

  -- asserting state of port 1 - low state is expected - ignition is on but terminal is not moving
  assert_equal(0, device.getIO(1), "Port1 associated with Idling not in low state as expected")


end


--- TC checks if digital output line associated with SM1 state is changing according to SM1 state
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with SM1 function;
  -- configure port 3 as a digital input and associate this port with SM1Active function;
  -- set the high state of the port 3 to be a trigger for line activation; check if initial state of port 1 is low;
  -- simulate port 3 value change to high state to trigger SM1 = ON and check if port 1 value has changed to high state;
  -- then set port 3 to low level - that triggers SM1 = OFF and after that check if port 1 output is low again
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to SM1 state
function test_DigitalOutput_WhenServiceMeter1IsON_DigitalOutputPortAssociatedWithSM1InHighState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["SM1ON"]}, -- digital output line number 1 set for SM1 function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["SM1"]},   -- digital input line number 3 set for Service Meter 1 function

                                              }
                   )
   -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"SM1Active"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as SM1 is not ON yet
  assert_equal(0, device.getIO(1), "Port1 associated SM1 is not in low state as expected")

  device.setIO(3, 1)     -- port 3 to high level - that should trigger SM1 = ON
  framework.delay(4)     -- wait until terminal changes state of Service Meter 1

  -- asserting state of port 1 - high state is expected -  SM1 = ON now
  assert_equal(1, device.getIO(1), "Port1 associated with SM1 is not in high state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger SM1 = OFF
  framework.delay(4)     -- wait until terminal changes state of Service Meter 1

  -- asserting state of port 1 - low state is expected -  SM1 = OFF now
  assert_equal(0, device.getIO(1), "Port1 associated SM1 is not in low state as expected")

end


--- TC checks if digital output line associated with SM2 state is changing according to SM2 state
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with SM2 function;
  -- configure port 3 as a digital input and associate this port with SM2Active function;
  -- set the high state of the port 3 to be a trigger for line activation; check if initial state of port 1 is low;
  -- simulate port 3 value change to high state to trigger SM2 = ON and check if port 1 value has changed to high state;
  -- then set port 3 to low level - that triggers SM2 = OFF and after that check if port 1 output is low again
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to SM2 state
function test_DigitalOutput_WhenServiceMeter2IsON_DigitalOutputPortAssociatedWithSM2InHighState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["SM2ON"]}, -- digital output line number 1 set for SM2 function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["SM2"]},   -- digital input line number 3 set for Service Meter 2 function

                                              }
                   )
   -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"SM2Active"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as SM2 is not ON yet
  assert_equal(0, device.getIO(1), "Port1 associated SM2 is not in low state as expected")


  device.setIO(3, 1)     -- port 3 to high level - that should trigger SM2 = ON
  framework.delay(4)     -- wait until terminal changes state of Service Meter 2

  -- asserting state of port 1 - high state is expected -  SM2 = ON now
  assert_equal(1, device.getIO(1), "Port1 associated with SM2 is not in high state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger SM2 = OFF
  framework.delay(4)     -- wait until terminal changes state of Service Meter 2

  -- asserting state of port 1 - low state is expected -  SM2 = OFF now
  assert_equal(0, device.getIO(1), "Port1 associated with SM2 is not in low state as expected")

end


--- TC checks if digital output line associated with SM3 state is changing according to SM3 state
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with SM3 function;
  -- configure port 3 as a digital input and associate this port with SM3Active function;
  -- set the high state of the port 3 to be a trigger for line activation; check if initial state of port 1 is low;
  -- simulate port 3 value change to high state to trigger SM3 = ON and check if port 1 value has changed to high state;
  -- then set port 3 to low level - that triggers SM3 = OFF and after that check if port 1 output is low again
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to SM3 state
function test_DigitalOutput_WhenServiceMeter3IsON_DigitalOutputPortAssociatedWithSM3InHighState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["SM3ON"]}, -- digital output line number 1 set for SM3 function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["SM3"]},   -- digital input line number 3 set for Service Meter 3 function

                                              }
                   )
   -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"SM3Active"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as SM3 is not ON yet
  assert_equal(0, device.getIO(1), "Port1 associated with SM3 is not in low state as expected")


  device.setIO(3, 1)     -- port 3 to high level - that should trigger SM3 = ON
  framework.delay(4)     -- wait until terminal changes state of Service Meter 3

  -- asserting state of port 1 - high state is expected -  SM3 = ON now
  assert_equal(1, device.getIO(1), "Port1 associated with SM3 is not in high state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger SM3 = OFF
  framework.delay(4)     -- wait until terminal changes state of Service Meter 3

  -- asserting state of port 1 - low state is expected -  SM3 = OFF now
  assert_equal(0, device.getIO(1), "Port1 associated with SM3 is not in low state as expected")

end


--- TC checks if digital output line associated with SM4 state is changing according to SM4 state
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with SM4 function;
  -- configure port 3 as a digital input and associate this port with SM4Active function;
  -- set the high state of the port 3 to be a trigger for line activation; check if initial state of port 1 is low;
  -- simulate port 3 value change to high state to trigger SM4 = ON and check if port 1 value has changed to high state;
  -- then set port 3 to low level - that triggers SM4 = OFF and after that check if port 1 output is low again
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to SM4 state
function test_DigitalOutput_WhenServiceMeter4IsON_AssociatedDigitalOutputPortInHighState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["SM4ON"]}, -- digital output line number 1 set for SM4 function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["SM4"]},   -- digital input line number 3 set for Service Meter 4 function

                                              }
                   )
   -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"SM4Active"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as SM4 is not ON yet
  assert_equal(0, device.getIO(1), "Port1 associated with SM4 is not in low state as expected")


  device.setIO(3, 1)     -- port 3 to high level - that should trigger SM4 = ON
  framework.delay(4)     -- wait until terminal changes state of Service Meter 4

  -- asserting state of port 1 - high state is expected -  SM4 = ON now
  assert_equal(1, device.getIO(1), "Port1 associated with SM4 is not in high state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger SM4 = OFF
  framework.delay(4)     -- wait until terminal changes state of Service Meter 4

  -- asserting state of port 1 - low state is expected -  SM4 = OFF now
  assert_equal(0, device.getIO(1), "Port1 associated with SM4 is not in low state as expected")

end


--- TC checks if 2 digital outputs associated with Moving and SM1 are changing according to speed value and SM1 state
  -- *actions performed:
  -- configure port 3 as a digital input and associate this port with SM4Active function; configure port 1 as a digital output
  -- and associate this port with Moving function; configure port 2 as a digital output and associate this port with SM1 function;
  -- check if states of both lines are initially low (terminal stationary and SM1 is OFF)
  -- simulate terminal speed aboce stationary speed threshold and check if the state of port 1 changes to high; then simulate SM1 = ON and
  -- check if port 2 changes state to high; go back to speed below stationary speed threshold and and SM = OFF and check if both ports
  -- are back to low state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 and port 2 states change according to speed and SM1 state
function test_DigitalOutput_WhenTerminalInMovingStateAndServiceMeter1IsOn_AssociatedDigitalOutputPortsInHighState()

  local movingDebounceTime = 30     -- seconds
  local stationarySpeedThld = 5     -- kmh

  -- gpsSettings to be used in TC
  local gpsSettings={
              speed = stationarySpeedThld+10 ,   -- speed above threshold, terminal in moving state
              latitude = 1,                      -- degrees
              longitude = 1,                     -- degrees
              fixType=3,                         -- valid fix provided
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port2Config, 6},      -- port 2 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["Moving"]},   -- digital output line number 1 set for Moving function
                                                {avlPropertiesPINs.funcDigOut2, avlAgentCons.funcDigOut["SM1ON"]},    -- digital output line number 2 set for SM1 function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["SM1"]},      -- digital input line number 3 set for Service Meter 1 function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},          -- moving related
                                             }
                   )
  -- activating special output function
  avlHelperFunctions.setDigStatesDefBitmap({"SM1Active"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1","FuncDigOut2"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as terminal is not moving yet
  assert_equal(0, device.getIO(1), "Port1 associated with Moving is not in low state as expected")
  -- asserting state of port 2 - low state is expected as SM1 is not ON yet
  assert_equal(0, device.getIO(2), "Port2 associated with SM1 is not in low state as expected")

  -- applying gps settings to simulate speed above stationarySpeedThld
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime-25)  -- wait until shorter than movingDebounceTime

  -- asserting state of port 1 - high state is expected - speed is above stationarySpeedThld
  assert_equal(1, device.getIO(1), "Port1 associated with Moving is not in high state as expected")

  device.setIO(3, 1)     -- port 3 to high level - that should trigger SM1 = ON
  framework.delay(4)     -- wait until terminal changes state of Service Meter 1

  -- asserting state of port 2 - high state is expected - SM1 = ON
  assert_equal(1, device.getIO(2), "Port2 associated with SM1 is not in high state as expected")

  -- simulating speed below stationarySpeedThld
  gpsSettings.speed = stationarySpeedThld - 1   -- kmh, one kmg below stationarySpeedThld
  gps.set(gpsSettings)                          -- apply settings
  framework.delay(gpsReadInterval+3)            -- wait until settings are applied

  -- asserting state of port 1 - low state is expected - speed below stationarySpeedThld
  assert_equal(0, device.getIO(1), "Port1 associated with Moving is not in low state as expected")

  device.setIO(3, 0)     -- port 3 to low level - that should trigger SM1 = OFF
  framework.delay(6)     -- wait until terminal changes state of Service Meter 1

  -- asserting state of port 2 - low state is expected - SM1 = OFF
  assert_equal(0, device.getIO(2), "Port2 associated with SM1 is not in low state as expected")


end


--- TC checks if digital output associated with SeatbeltViolation is changing state when terminal is in Moving state and driver unfastens belt
  -- configure port 1 as a digital output and associate this port with Seatbelt Violation function; configure port 2 as a digital input and
  -- associate this port with SeatbeltOff function; simulate terminal in Moving state and check if port 1 still is in low state; then simulate
  -- port 2 change to high level (driver unfastens seatbelt while moving) and check if port 1 changes state to high level; simulate port 2 change to
  -- low level (driver fastens seatbelt) and check if port 1 changes back to low state; in the end set SeatbeltOff back to high level again but set speed to
  -- 0 (terminal stationary) and check if Seatbelt Violation line is not high in this case
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 associated with SeatbeltViolation function changes state according to SeatbeltOff line and moving state
function test_DigitalOutput_WhenTerminalIsMovingAndDriverUnfastensSeatbelt_DigitalOutputPortAssociatedWithSeatBeltViolationInHighState()

  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh
  local stationaryDebounceTime = 1  -- seconds
  local seatbeltDebounceTime = 30   -- seconds

  -- gpsSettings to be used in TC
  local gpsSettings={
              speed = stationarySpeedThld+10 ,   -- speed above threshold, terminal in moving state
              latitude = 1,                      -- degrees
              longitude = 1,                     -- degrees
              fixType=3,                         -- valid fix provided
                     }

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port2Config, 3},      -- port 2 as digital input
                                                {avlPropertiesPINs.port2EdgeDetect, 3},  -- detection for both rising and falling edge
                                         }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["SeatbeltViol"]},   -- digital output line number 1 set for SeatbeltViolation function
                                                {avlPropertiesPINs.funcDigInp2, avlAgentCons.funcDigInp["SeatbeltOff"]},    -- digital input line number 2 set for SeatbeltOff function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},                  -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},                -- moving related
                                                {avlPropertiesPINs.seatbeltDebounceTime,seatbeltDebounceTime},              -- moving related
                                             }
                   )
  -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"SeatbeltOff"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})

  -- asserting state of port 1 - low state is expected as terminal is not moving yet and seatbelt is fastened
  assert_equal(0, device.getIO(1), "Port1 associated with SeatbeltViol function not in low state as expected")

  -- terminal should be put in the moving state
  local gpsSettings={
              speed = stationarySpeedThld+10, -- speed above stationarySpeedThld
              fixType = 3,                    -- valid fix provided
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+3)

  -- asserting state of port 1 - low state is expected as terminal moving but seatbelt is fastened
  assert_equal(0, device.getIO(1), "Port1 associated with SeatbeltViol function not in low state as expected")

  device.setIO(2, 1)                            --  port 2 to high level - that triggers SeatbeltOff
  framework.delay(seatbeltDebounceTime-20)      --  wait shorter than seatbeltDebounceTime not to get SeatbeltViolation state

  -- asserting state of port 1 - high state is expected as - terminal moving and  seatbelt is unfastened
  assert_equal(1, device.getIO(1), "Port1 associated with seatbeltViolation is not in high state as expected")

  device.setIO(2, 0)     --  port 2 to low level - that triggers SeatbeltOff false
  framework.delay(3)      -- wait until message is processed

  -- asserting state of port 1 - low state is expected as - SeatBelt fastened
  assert_equal(0, device.getIO(1), "Port1 associated with SeatbeltViol function not in low state as expected")

  -- SeatbeltOff high again
  device.setIO(2, 1)                            --  port 2 to high level - that triggers SeatbeltOff
  framework.delay(seatbeltDebounceTime-20)      --  wait shorter than seatbeltDebounceTime not to get SeatbeltViolation state

  -- checking if the Seatbelt Violation line is not active when SeatbeltOff is active but terminal is not moving
  gpsSettings.speed = 0  -- terminal stationary
  gps.set(gpsSettings)   -- applying gps settings
  framework.delay(stationaryDebounceTime+gpsReadInterval+2) -- wait until terminal is stationary


  -- asserting state of port 1 - low state is expected as - SeatBelt fastened
  assert_equal(0, device.getIO(1), "Port1 associated with SeatbeltViol function not in low state as expected")

end


--- TC checks if digital output associated with GeoDwelling changes state when terminal moves from geofence with defined DwellTime = 0
  -- to geofence with defined DwellTime different than zero
  -- Initial Conditions:
  --
  -- * Geofence feature enabled and geozones defined in fences.dat file
  -- * DwellTime different than 0 one geofence and DwellTime = 0 for global geofence (#128)
  -- * Port 1 configured as digital output and Geodwelling function associated to it
  -- * GPS signal is good
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Terminal moving outside any of the defined geofences
  -- 2. Terminal enters defined geofence with DwellTime different than 0
  -- 3. Terminal goes back to outside any of the defined geofences
  --
  -- Results:
  --
  -- 1. Port 1 in low state
  -- 2. Port 1 changes its state to high (GeoDwelling function line activated)
  -- 3. Port 1 changes state back to low state
function test_DigitalOutput_WhenTerminalMovingInsideGeofenceWithDwellTimeSetToDifferentThanZero_DigitalOutputPortAssociatedWithGeoDwellingInHighState()

  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh
  local geofenceEnabled = true     -- to enable geofence feature
  local geofenceInterval = 10       -- in seconds
  local geofenceHisteresis = 1      -- in seconds
  local geofence2DwellTime = 100    -- in minutes
  local geofence128DwellTime = 0    -- in minutes, 0  is for feature disabled

  -- setting ZoneDwellTimes for geofence 2
  local message = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.setGeoDwellTimes}
  message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                    {Index=1,Fields={{Name="ZoneId",Value=128},{Name="DwellTime",Value=geofence128DwellTime}}}}},}

	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10,  -- kmh, 10 kmh above stationary threshold
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees, that is outside of any of the defined geofences
              longitude = 1,                   -- degrees, that is outside of any of the defined geofences
              simulateLinearMotion = false,
                     }

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                            {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["GeoDwelling"]},   -- digital output line number 1 set for GeoDwelling function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},                 -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},               -- moving related
                                             }
                   )
  -- activating special output function
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2) -- wait until settings are applied

  gps.set(gpsSettings)         -- applying gps settings, terminal moving outside any of the defined geofences (DwellTime = 0)
  framework.delay(gpsReadInterval+geofenceInterval+10)  -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as terminal is not inside geofence with defined DwellTime
  assert_equal(0, device.getIO(1), "Port1 associated with GeoDwelling is not in low state as expected")

  -- changing gps settings - terminal outside any of the defined geofences (DwellTime = 0)
  gpsSettings={
               latitude = 50.5,     -- degrees, that is inside geofence 2
               longitude = 4.5,     -- degrees, that is inside geofence 2
              }
  gps.set(gpsSettings)         -- applying gps settings, terminal moving inside geofence 2
  framework.delay(gpsReadInterval+geofenceInterval+10)  -- wait until settings are applied

  -- asserting state of port 1 - high state is expected as terminal is inside geofence 2 (with defined DwellTime)
  assert_equal(1, device.getIO(1), "Port1 associated with GeoDwelling is not in high state as expected")

  -- changing gps settings - terminal back to area outside any of the defined geofences (DwellTime = 0)
  gpsSettings={
               latitude = 1,      -- degrees, that is outside any of the geofences
               longitude = 1,     -- degrees, that is outside any of the geofences
              }

  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(gpsReadInterval+geofenceInterval+10)  -- wait until settings are applied

  -- asserting state of port 1 - low state is expected as terminal is not inside geofence with defined DwellTime
  assert_equal(0, device.getIO(1), "Port1 associated with GeoDwelling is not in low state as expected")


end



--- TC checks if digital output associated with GeoDwelling does not change state when terminal moves between geofences with DwellTime set to 0
  -- Initial Conditions:
  --
  -- * Geofence feature enabled and geozones defined in fences.dat file
  -- * DwellTime = 0 for one specific geofence and  global geofence (#128)
  -- * Port 1 configured as digital output and Geodwelling function associated to it
  -- * GPS signal is good
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Terminal moving outside any of the defined geofences
  -- 2. Terminal enters defined geofence with DwellTime = 0
  --
  -- Results:
  --
  -- 1. Port 1 state low
  -- 2. Port 1 does not change its state (GeoDwelling function line not activated)
  function test_DigitalOutput_WhenTerminalMovingBetweenGeofencesWithDwellTimesSetToZero_DigitalOutputPortAssociatedWithGeoDwellingInLowState()

  local movingDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5     -- kmh
  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10       -- in seconds
  local geofenceHisteresis = 1      -- in seconds
  local geofence2DwellTime = 0      -- in minutes
  local geofence128DwellTime = 0    -- in minutes, for 0 GeoDwelling feature is disabled

  -- setting ZoneDwellTimes for geofence 2
  local message = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                     {Index=1,Fields={{Name="ZoneId",Value=128},{Name="DwellTime",Value=geofence128DwellTime}}}}},}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10,  -- kmh, 10 kmh above stationary threshold
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees, that is outside any of the defined geofences
              longitude = 1,                   -- degrees, that is outside any of the defined geofences
              simulateLinearMotion = false,
                     }

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                            {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["GeoDwelling"]},   -- digital output line number 1 set for GeoDwelling function
                                                {avlPropertiesPINs.movingDebounceTime,movingDebounceTime},                 -- moving related
                                                {avlPropertiesPINs.stationarySpeedThld,stationarySpeedThld},               -- moving related
                                             }
                   )
  -- activating special output function
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2) -- wait until settings are applied

  gps.set(gpsSettings)         -- applying gps settings, terminal moving in geofence 128 (DwellTime = 0)

  -- asserting state of port 1 - low state is expected as terminal moving in geofence 128 (DwellTime = 0)
  assert_equal(0, device.getIO(1), "Port1 associated with GeoDwelling is not in low state as expected")

  gpsSettings={
                latitude = 50.5,                -- degrees, that is inside geofence 2
                longitude = 4.5,                -- degrees, that is inside geofence 2
              }


  gps.set(gpsSettings)     -- applying gps settings, terminal moving inside geofence 2
  framework.delay(gpsReadInterval+geofenceInterval+10)  -- wait until settings are applied

  -- asserting state of port 1 - low state is expected - now terminal moving in geofence 2 (DwellTime = 0)
  assert_equal(0, device.getIO(1), "Port1 associated with GeoDwelling is not in low state as expected")



end


--- TC checks if digital output line associated with LowPower is changing when lpmTrigger is true
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with LowPower function; configure port 3 as
  -- a digital input and associate this port with IgnitionOn function; set the high state of the port 3 to
  -- be a trigger for line activation; set lpmEntryDelay to 10 minutes and IgnitionOff as the trigger of low power mode;
  -- simulate port 3 value change to high state and check if port 1 state is low (lpmTrigger is not active); change port 3
  -- value to low state to trigger IgnitionOff and check if port 1 state immediately becomes high (lpmTrigger is active);
  -- then change port 3 back to high state to trigger IgnitionOn and check if port 1 goes back to low state (lpmTrigger is not active);
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- port 1 state changes according to lpmTrigger state
function test_DigitalOutput_WhenLpmTriggerIsSetToIgnitionOffAndTerminalInIgnitionOnFalseState_DigitalOutputPortAssociatedWithLowPowerInHighState()

  local lpmEntryDelay = 10   -- time of lpmEntryDelay, in minutes
  local lpmTrigger = 1       -- 1 is for IgnitionOff

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["LowPower"]},    -- digital output line number 1 set for LowPower function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["IgnitionOn"]},  -- digital input line number 3 set for Ignition function
                                                {avlPropertiesPINs.lpmEntryDelay, lpmEntryDelay},                        -- time of lpmEntryDelay, in minutes
                                                {avlPropertiesPINs.lpmTrigger, lpmTrigger},
                                             }
                   )
  -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (Ignition is on)
  assert_equal(0, device.getIO(1), "Port1 associated with LowPower is not in low state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOff (that is lpmTrigger)
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected - Ignition is off
  assert_equal(1, device.getIO(1), "Port1 associated with LowPower is not in high state as expected")

  -- back to IgnitionOn state
  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (Ignition is on)
  assert_equal(0, device.getIO(1), "Port1 associated with LowPower is not in low state as expected")


end


--- TC checks if digital output line associated with IgnitionOn state is changing according to IgnitionOn state
  -- when for for active line digital output is low (digOutActiveBitmap set to 0)
  -- *actions performed:
  -- configure port 1 as a digital output and associate this port with IgnitionOn function; do not write any value to
  -- digOutActiveBitmap; configure port 3 as a digital input and associate this port also with IgnitionOn function;
  -- set the high state of the port 3 to be a trigger for line activation; then simulate port 3 value change to
  -- high state and check if terminal goes to IgnitionOn state; check the state of port 1 - low state is expected
  -- simulate port 3 value change to low state - check if terminal goes to IgnitionOn false and port 1 goes to high state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- gpsReadInterval; all 4 ports in LOW state, terminal not in the IgnitionOn state, digOutActiveBitmap set to 0
  -- *expected results:
  -- port 1 state changes according to IgnitionOn state (low state is for active line)
function test_DigitalOutput_WhenTerminalInIgnitionOnStateAndDigOutActiveBitmapIsSetToZero_DigitalOutputPortAssociatedWithIgnitionOnInLowState()

  -- setting the EIO properties
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 6},      -- port 1 as digital output
                                                {avlPropertiesPINs.port3Config, 3},      -- port 3 as digital input
                                                {avlPropertiesPINs.port3EdgeDetect, 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.funcDigOut1, avlAgentCons.funcDigOut["IgnitionOn"]},    -- digital output line number 1 set for Ignition function
                                                {avlPropertiesPINs.funcDigInp3, avlAgentCons.funcDigInp["IgnitionOn"]},    -- digital input line number 3 set for Ignition function
                                             }
                   )
  -- activating special input and output functions
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)                 -- wait until settings are applied

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected (Ignition is on )
  assert_equal(0, device.getIO(1), "Port 1 associated with IgnitionOn is not in low state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOn state change to false
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected (Ignition is off)
  assert_equal(1, device.getIO(1), "Port 1 associated with IgnitionOn is not in low state as expected")

end






--[[

TODO:
TCs for digital outputs associated with following functions:

- LowPower -- onBattery as the LpmTrigger
- MainPower
- Towing"
- GpsJammed
- CellJammed
- Tamper
- AirBlocked
- LoggedIn
- AntCut
--]]


--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()

