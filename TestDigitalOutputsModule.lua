-----------
-- Digital Outputs test module
-- - contains digital output related test cases
-- @module TestDigitalOutputsModule

module("TestDigitalOutputsModule", package.seeall)

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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.lpmTrigger, 0},
                                             }
                    )
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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

  local digOutActiveBitmap = 0          -- setting DigOutActiveBitmap 0

  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                               }
                    )

  avlHelperFunctions.putTerminalIntoStationaryState()

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{      {lsfConstants.pins.portConfig[1], 3},      -- port set as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3},  -- detection for both rising and falling edge
                                         }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},    -- digital input line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], 0 },    -- disabled
                                                {avlConstants.pins.funcDigInp[3], 0 },    -- disabled
                                                {avlConstants.pins.funcDigInp[4], 0 },    -- disabled
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)                 -- wait until settings are applied
  device.setIO(1, 0)                 -- that should trigger IgnitionOff
  framework.delay(2)                 -- wait until settings are applied

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  --setting properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.digOutActiveBitmap, digOutActiveBitmap}
                                             }
                    )

  -- setting all 4 ports to low state
  for counter = 1, 4, 1 do
    device.setIO(counter, 0)
  end
  framework.delay(4)

  -- setting the EIO properties - disabling all 4 I/O ports
  lsf.setProperties(lsfConstants.sins.io,{
                                            {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[4], 0},      -- port disabled

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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["IgnitionOn"]},    -- digital output line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["IgnitionOn"]},    -- digital input line number 3 set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  -- asserting state of port 1 - low state is expected
  assert_equal(0, device.getIO(1), "Port1 associated with IgnitionOn is not in low state as expected")

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected
  assert_equal(1, device.getIO(1), "Port1 associated with IgnitionOn is not in high state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOn state change to false
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pinsavlStates)
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["Moving"]},   -- digital output line number 1 set for Moving function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},          -- moving related
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["Speeding"]}, -- digital output line number 1 set for Moving function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},          -- moving related
                                                {avlConstants.pins.stationaryDebounceTime,stationaryDebounceTime},    -- moving related
                                                {avlConstants.pins.speedingTimeOver,speedingTimeOver},                -- speeding related
                                                {avlConstants.pins.defaultSpeedLimit,defaultSpeedLimit},              -- speeding related

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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["IgnitionOn"]},  -- digital input line number 3 set for Ignition function
                                               {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["Idling"]},      -- digital output line number 1 set for Idling function
                                               {avlConstants.pins.maxIdlingTime,maxIdlingTime},                         -- Idling related

                                             }
                   )
   -- setting digital input bitmap describing when special function inputs are active
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["SM1ON"]}, -- digital output line number 1 set for SM1 function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["SM1"]},   -- digital input line number 3 set for Service Meter 1 function

                                              }
                   )
   -- setting digital input bitmap describing when special function inputs are active
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["SM2ON"]}, -- digital output line number 1 set for SM2 function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["SM2"]},   -- digital input line number 3 set for Service Meter 2 function

                                              }
                   )
   -- setting digital input bitmap describing when special function inputs are active
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["SM3ON"]}, -- digital output line number 1 set for SM3 function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["SM3"]},   -- digital input line number 3 set for Service Meter 3 function

                                              }
                   )
   -- setting digital input bitmap describing when special function inputs are active
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["SM4ON"]}, -- digital output line number 1 set for SM4 function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["SM4"]},   -- digital input line number 3 set for Service Meter 4 function

                                              }
                   )
   -- setting digital input bitmap describing when special function inputs are active
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge

                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["Moving"]},   -- digital output line number 1 set for Moving function
                                                {avlConstants.pins.funcDigOut[2], avlConstants.funcDigOut["SM1ON"]},    -- digital output line number 2 set for SM1 function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["SM1"]},      -- digital input line number 3 set for Service Meter 1 function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},            -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},          -- moving related
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[2], 3},      -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3},  -- detection for both rising and falling edge
                                         }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["SeatbeltViol"]},   -- digital output line number 1 set for SeatbeltViolation function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- digital input line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},                  -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},                -- moving related
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime},              -- moving related
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
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
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.avlConstants.mins.setGeoDwellTimes}
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
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                            {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["GeoDwelling"]},   -- digital output line number 1 set for GeoDwelling function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},                 -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},               -- moving related
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
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
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
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                            {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["GeoDwelling"]},   -- digital output line number 1 set for GeoDwelling function
                                                {avlConstants.pins.movingDebounceTime,movingDebounceTime},                 -- moving related
                                                {avlConstants.pins.stationarySpeedThld,stationarySpeedThld},               -- moving related
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["LowPower"]},    -- digital output line number 1 set for LowPower function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["IgnitionOn"]},  -- digital input line number 3 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                        -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)                 -- wait until settings are applied

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (Ignition is on)
  assert_equal(0, device.getIO(1), "Port1 associated with LowPower is not in low state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOff (that is lpmTrigger)
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected - Ignition is off
  assert_equal(1, device.getIO(1), "Port1 associated with LowPower is not in high state as expected")

  -- back to IgnitionOn state
  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.avlConstants.pins.avlStates)
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
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},      -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},  -- detection for both rising and falling edge


                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["IgnitionOn"]},    -- digital output line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["IgnitionOn"]},    -- digital input line number 3 set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)                 -- wait until settings are applied

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected (Ignition is on )
  assert_equal(0, device.getIO(1), "Port 1 associated with IgnitionOn is not in low state as expected")

  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOn state change to false
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected (Ignition is off)
  assert_equal(1, device.getIO(1), "Port 1 associated with IgnitionOn is not in low state as expected")

end



--- TC checks if digital output line associated with LowPower is changing when lpmTrigger is true for Built-in Battery set as trigger .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure port 1 as a digital output and associate this port with LowPower function
  -- 2. Set the high state of the output be the indicator of active line
  -- 3. Set lpmEntryDelay (PIN 32) to high value (terminal is not supposed to enter low power mode)
  -- 4. Set lpmTrigger (PIN 31) to Built-on battery
  -- 5. Simulate external power source present
  -- 6. Check the state of digital output port
  -- 7. Simulate external power source not present
  -- 8. Ckeck the state of digital output port
  -- 9. Simulate external power source not present
  -- 10. Check the state of digital output port
  --
  -- Results:
  --
  -- 1. Port configured as digital output and assiociated with LowPower function
  -- 2. High state of the output set to be the indicator of active line
  -- 3. LpmEntryDelay (PIN 32) set to high value (i.e. 10 minutes)
  -- 4. LpmTrigger (PIN 31) set to Built-in Battery
  -- 5. External power source  is present
  -- 6. Digital output port is in low state (lpm trigger is false)
  -- 7. External power source not present
  -- 8. Digital output port is in high stare (lpm trigger is true)
  -- 9. External power source present again
  -- 10. Digital output port is in low state (lpm trigger is false again)
function test_DigitalOutput_WhenLpmTriggerIsSetToBuiltInBatteryAndExternalPowerSourceIsNotPresent_DigitalOutputPortAssociatedWithLowPowerInHighState()

  -- Dual power source feature is specific to IDP 800
  if(terminalInUse~=800) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 10   -- time of lpmEntryDelay, in minutes
  local lpmTrigger = 2       -- 2 is for Built-in battery

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["LowPower"]},    -- digital output line number 1 set for LowPower function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                  -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},
                                             }
                   )
  -- setting digital input bitmap describing when special function outputs are active
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(2)               -- wait until settings are applied

  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (external power is present)
  assert_equal(0, device.getIO(1), "Digital output port associated with LowPower trigger is not in low state as expected")

  device.setPower(8,0)             -- external not power present (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")

  -- asserting state of port 1 - high state is expected - terminal is on Backup power source
  assert_equal(1, device.getIO(1), "Port1 associated with LowPower is not in high state as expected")

  -- back to external power present again
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (external power is present)
  assert_equal(0, device.getIO(1), "Digital output port associated with LowPower trigger is not in low state as expected")

end



--- TC checks if digital output line associated with LowPower is changing according to any of the triggers when lpmTrigger is set to IgnitionOn and Built-in Battery .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure port 1 as a digital output and associate this port with LowPower function
  -- 2. Set the high state of the output be the indicator of active line
  -- 3. Configure port 3 as a digital input and associate this port with IgnitionOn function
  -- 4. Set the high level of port 3 to be the trigger for IgnitionOn line activation
  -- 5. Set lpmEntryDelay (PIN 32) to high value (terminal is not supposed to enter low power mode)
  -- 6. Set lpmTrigger (PIN 31) to Built-on battery and IgnitionOff
  -- 7. Simulate external power source present and Ignition switched on
  -- 8. Check the state of digital output port
  -- 9. Simulate external power source not present (Ignition still switched on)
  -- 10. Ckeck the state of digital output port
  -- 11. Simulate Ignition swtiched off end external power source present
  -- 12. Check the state of digital output port
  --
  -- Results:
  --
  -- 1. Port 1 configured as digital output and assiociated with LowPower function
  -- 2. High state of the output set to be the indicator of active line
  -- 3. Port 3 configured as digital input ans associated with IgnitionOn function
  -- 4. High state of the port is the trigger for line activation
  -- 5. LpmEntryDelay (PIN 32) set to high value (i.e. 10 minutes)
  -- 6. LpmTrigger (PIN 31) set to Built-in Battery and IgnitionOff
  -- 7. External power source  is present and Ignition is on
  -- 8. Digital output port is in low state (none of the lpm triggers is active)
  -- 9. External power source not present and Ignition still switched on
  -- 10. Digital output port is in high state (one lpm trigger is true)
  -- 11. External power source present again but Ignition is off
  -- 12. Digital output port is in high state (one lpm trigger is active)
function test_DigitalOutput_WhenLpmTriggerIsSetToBothBuiltInBatteryAndIgnitionOff_DigitalOutputPortAssociatedWithLowPowerInHighStateIfAnyOfTheTriggersIsActive()

  -- Dual power source feature is specific to IDP 800
  if(terminalInUse~=800) then skip("TC related only to IDP 800s") end

  local lpmEntryDelay = 10   -- time of lpmEntryDelay, in minutes
  local lpmTrigger = 3       -- 3 is for both IgnitionOn and Built-in battery

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                                {lsfConstants.pins.portConfig[3], 3},        -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3},    -- detection for both rising and falling edge
                                }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["LowPower"]},      -- digital output line number 1 set for LowPower function
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp["IgnitionOn"]},    -- digital input line number 3 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},
                                             }
                   )
  -- setting digital input bitmap describing when special function outputs are active
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)               -- wait until settings are applied

  -------------------------------------------------------------------------------------------------------------
  -- None of the triggers is active, output line expected to be in low level
  -------------------------------------------------------------------------------------------------------------
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected - both low power mode triggers are false
  assert_equal(0, device.getIO(1), "Digital output port associated with LowPower trigger is not in low state as expected")

  -----------------------------------------------------------------------------------------------------------------
  -- Built-in battery trigger is active, IgnitionOff trigger is inactive, output line expected to be in high level
  -----------------------------------------------------------------------------------------------------------------
  device.setPower(8,0)             -- external not power present (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")

  -- asserting state of port 1 - high state is expected - terminal is on Backup power source
  assert_equal(1, device.getIO(1), "Port1 associated with LowPower is not in high state as expected")

  -- back to external power present again
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- asserting state of port 1 - low state is expected - low power mode trigger is false again (external power is present)
  assert_equal(0, device.getIO(1), "Digital output port associated with LowPower trigger is not in low state as expected")

  ---------------------------------------------------------------------------------------------------------------
  -- IgnitionOff trigger is active, Built-in battery trigger is inactive, output line expected to be in high level
  -----------------------------------------------------------------------------------------------------------------
  device.setIO(3, 0)                 -- port 3 to low level - that should trigger IgnitionOn state change to false
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn false state

  -- verification of the state of terminal - IgnitionOn false expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- asserting state of port 1 - high state is expected (Ignition is off)
  assert_equal(1, device.getIO(1), "Port 1 associated with IgnitionOn is not in low state as expected")

  device.setIO(3, 1)                 -- port 3 to high level - that should trigger IgnitionOn
  framework.delay(2)                 -- wait until terminal goes into IgnitionOn state

  -- verification of the state of terminal - IgnitionOn true expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

  -- asserting state of port 1 - low state is expected - lpmTrigger is false (external power is present)
  assert_equal(0, device.getIO(1), "Digital output port associated with LowPower trigger is not in low state as expected")


end


--- TC checks if digital output line associated with MainPower is changing according to onMainPower state of terminal .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure port as a digital output and associate this port with MainPower function
  -- 2. Set the high state of the output be the indicator of active line
  -- 3. Simulate external power source not present
  -- 4. Read the avlStates (PIN 41) and check onMainPower state
  -- 5. Check the state of digital output port
  -- 6. Simulate external power source  present
  -- 7. Read the avlStates (PIN 41) and check onMainPower state
  -- 8. Check the state of digital output port
  -- 9. Simulate external power source present again
  -- 10. Read the avlStates (PIN 41) and check onMainPower state
  -- 11. Check the state of digital output port
  --
  -- Results:
  --
  -- 1. Port configured as digital output and assiociated with MainPower function
  -- 2. High state of the output set to be the indicator of active line
  -- 3. External power source  is not present
  -- 4. OnMainPower state is false
  -- 5. Digital output port is in low state
  -- 6. External power source is present
  -- 7. OnMainPower state is true
  -- 8. Digital output port is in high state
  -- 9. External power source present
  -- 10. OnMainPower state is false
  -- 11. Digital output port is in low state
function test_DigitalOutput_WhenDigitalOutputLineIsAssociatedWithMainPowerFunction_DigitalOutputPortChangesAccordingToOnMainPowerState()

  -- Dual power source feature is specific to IDP 800
  if(terminalInUse~=800) then skip("TC related only to IDP 600") end

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigOut[1], avlConstants.funcDigOut["MainPower"]},    -- digital output line number 1 set for LowPower function
                                      }
                   )
  -- setting digital input bitmap describing when special function outputs are active
  avlHelperFunctions.setDigOutActiveBitmap({"FuncDigOut1"})
  framework.delay(10002)               -- wait until settings are applied

  ---------------------------------------------------------------------------------------------------------------
  -- External power source not present - terminal not in the onMainPower state
  ---------------------------------------------------------------------------------------------------------------
  device.setPower(8,0)             -- external not power present (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")

  -- verification of the state of terminal - onMainPower false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "terminal not incorrectly in the onMainPower state")

  -- asserting state of port 1 - low state is expected - onMainPower is false
  assert_equal(0, device.getIO(1), "Digital output port associated with MainPower trigger is not in low state as expected")

  ---------------------------------------------------------------------------------------------------------------
  -- External power source present - terminal in the onMainPower state
  ---------------------------------------------------------------------------------------------------------------
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  local externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 1, "External power source not present as expected")

  -- verification of the state of terminal - onMainPower true expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "terminal not in the onMainPower state")

  -- asserting state of port 1 - high state is expected - terminal is in onMainPower state
  assert_equal(1, device.getIO(1), "Port1 associated with MainPower is not in high state as expected")

  ---------------------------------------------------------------------------------------------------------------
  -- External power source not present - terminal not in the onMainPower state
  ---------------------------------------------------------------------------------------------------------------
  device.setPower(8,0)             -- external not power present (terminal unplugged from external power source)
  framework.delay(2)               -- wait until setting is applied

  -- check external power property
  externalPowerPresentProperty = lsf.getProperties(lsfConstants.sins.power,lsfConstants.pins.extPowerPresent)
  assert_equal(externalPowerPresentProperty[1].value, 0, "External power source unexpectedly present")

  -- verification of the state of terminal - onMainPower false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "terminal not incorrectly in the onMainPower state")

  -- asserting state of port 1 - low state is expected - onMainPower is false
  assert_equal(0, device.getIO(1), "Digital output port associated with MainPower function is not in low state as expected")


end




--[[
TODO:
TCs for digital outputs associated with following functions:

- Towing
- GpsJammed
- CellJammed
- Tamper
- AirBlocked
- LoggedIn
- AntCut
 add FuncDigOut5 - outputSink18 for 780
--]]


--- TC checks if setDigitalOutputs message sets digital output ports for IDP 600 series terminal  .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 600 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 4 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 4 ports to high level
  -- 3. Read states of the ports
  -- 4. Send setDigitalOutputs to-mobile message setting all 4 ports to low level
  -- 5. Read states of the ports
  -- 6. Send setDigitalOutputs to-mobile message setting all 4 ports back to high level
  -- 7. Read states of the ports
  --
  -- Results:
  --
  -- 1. All 4 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 4 digital outputs in high state
  -- 4. SetDigitalOutputs message sent
  -- 5. 4 digital outputs in low state
  -- 6. SetDigitalOutputs message sent
  -- 7. 4 digital outputs in high state
function test_DigitalOutputIDP600_WhenSetDigitalOutputsMessageSent_DigitalOutputsChangeStatesAccordingToMessage()

  -- This TC only applies to IDP 600 series terminal
  if(terminalInUse~=600) then skip("TC related only to IDP 600s") end

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                  {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                  {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                  {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                  {lsfConstants.pins.portConfig[4], 6},      -- port 4 as digital output
                                }
                   )

  -- Sending setDigitalOutputs message setting all 4 port to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP6xxLine4"},    {Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 4 port to low state
  message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP6xxLine4"},    {Name="LineState",Value=0},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to low level
  for counter = 1, 4, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 4 port back to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP6xxLine4"},    {Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end



end

--- TC checks if setDigitalOutputs message sets digital output ports for IDP 800 series terminal  .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 3 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 3 ports to high level
  -- 3. Read states of the ports
  -- 4. Send setDigitalOutputs to-mobile message setting all 3 ports to low level
  -- 5. Read states of the ports
  -- 6. Send setDigitalOutputs to-mobile message setting all 3 ports back to high level
  -- 7. Read states of the ports
  --
  -- Results:
  --
  -- 1. All 3 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 3 digital outputs in high state
  -- 4. SetDigitalOutputs message sent
  -- 5. 3 digital outputs in low state
  -- 6. SetDigitalOutputs message sent
  -- 7. 3 digital outputs in high state
function test_DigitalOutputIDP800_WhenSetDigitalOutputsMessageSent_DigitalOutputsChangeStatesAccordingToMessage()

  -- This TC only applies to IDP 800 series terminal
  if(terminalInUse~=800) then skip("TC related only to IDP 800s") end

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                  {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                  {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                  {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                }
                   )

  -- Sending setDigitalOutputs message setting all 3 port to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 3 ports has been correctly set to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 3 port to low state
  message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 3 ports has been correctly set to low level
  for counter = 1, 3, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 3 port back to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 3 ports has been correctly set to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end



end


--- TC checks if setDigitalOutputs message sets digital output ports for IDP 700 series terminal  .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 700 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 3 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 5 ports to high level
  -- 3. Read states of the ports
  -- 4. Send setDigitalOutputs to-mobile message setting all 5 ports to low level
  -- 5. Read states of the ports
  -- 6. Send setDigitalOutputs to-mobile message setting all 5 ports back to high level
  -- 7. Read states of the ports
  --
  -- Results:
  --
  -- 1. All 5 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 5 digital outputs in high state
  -- 4. SetDigitalOutputs message sent
  -- 5. 5 digital outputs in low state
  -- 6. SetDigitalOutputs message sent
  -- 7. 5 digital outputs in high state
function test_DigitalOutputIDP700_WhenSetDigitalOutputsMessageSent_DigitalOutputsChangeStatesAccordingToMessage()

  -- This TC only applies to IDP 800 series terminal
  if(terminalInUse~=700) then skip("TC related only to IDP 700s") end

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                  {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                  {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                  {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                }
                   )

  -- Sending setDigitalOutputs message setting all 5 ports to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
  message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP7xxLine14"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP7xxLine15"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP7xxLine16"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP7xxLine17"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=4,Fields={{Name="LineNum",Value="IDP7xxLine18"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- TODO: modify following section to work on 700's IDP
  -- checking if all 3 ports has been correctly set to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 5 ports to low state
  message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
  message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP7xxLine14"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP7xxLine15"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP7xxLine16"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP7xxLine17"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}},
                                                 {Index=4,Fields={{Name="LineNum",Value="IDP7xxLine18"},{Name="LineState",Value=0},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- TODO: modify following section to work on 700's IDP
  -- checking if all 3 ports has been correctly set to low level
  for counter = 1, 3, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  -- Sending setDigitalOutputs message setting all 5 ports back to high state
  message = {SIN = avlConstants.avlAgentSIN, MIN = mins.setDigitalOutputs}
  message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP7xxLine14"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP7xxLine15"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP7xxLine16"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP7xxLine17"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}},
                                                 {Index=4,Fields={{Name="LineNum",Value="IDP7xxLine18"},{Name="LineState",Value=1},{Name="InvertTime",Value=0}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- TODO: modify following section to work on 700's IDP
  -- checking if all 3 ports has been correctly set to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

end




--- TC checks if setDigitalOutputs message sets digital output ports for IDP 600 series terminal and inverts it after set time .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 600 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 4 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 4 ports to high level and invertTime different than zero
  -- 3. Read states of the ports
  -- 4. wait longer than set invertTime and read states of the ports
  -- 5. Send setDigitalOutputs to-mobile message setting all 4 ports back to low level and invertTime different than zero
  -- 6. Read states of the ports
  -- 7. wait longer than set invertTime and read states of the ports
  --
  -- Results:
  --
  -- 1. All 4 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 4 digital outputs in high state
  -- 4. 4 digital outputs inverted automatically to low state
  -- 5. SetDigitalOutputs message sent
  -- 6. 4 digital outputs in high state
  -- 7. 4 digital outputs inverted automatically to low state
function test_DigitalOutputIDP600_WhenSetDigitalOutputsMessageSentAndInvertTimeGreaterThanZero_DigitalOutputsChangeStatesAccordingToMessageAndInvertsAutomaticallyAfterInvertTime()

  -- This TC only applies to IDP 600 series terminal
  if(terminalInUse~=600) then skip("TC related only to IDP 600s") end

  local invertTime = 1   -- in minutes, time in minutes, after which the set digital output state is automatically inverted

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                          {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                          {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                          {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                          {lsfConstants.pins.portConfig[4], 6},      -- port 4 as digital output
                                         }
                   )

  -- Sending setDigitalOutputs message setting all 4 port to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP6xxLine4"},    {Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 4 ports has been correctly automatically inverted to low level
  for counter = 1, 4, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been automatically inverted to low level after invertTime period")
  end

  -- Sending setDigitalOutputs message setting all 4 port to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP6xxLine4"},    {Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to low level
  for counter = 1, 4, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 4 ports has been correctly automatically inverted to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been automatically inverted to high level after invertTime period")
  end



end



--- TC checks if setDigitalOutputs message sets digital output ports for IDP 700 series terminal and inverts it after set time .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 700 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 5 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 5 ports to high level and invertTime different than zero
  -- 3. Read states of the ports
  -- 4. wait longer than set invertTime and read states of the ports
  -- 5. Send setDigitalOutputs to-mobile message setting all 5 ports back to low level and invertTime different than zero
  -- 6. Read states of the ports
  -- 7. wait longer than set invertTime and read states of the ports
  --
  -- Results:
  --
  -- 1. All 5 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 5 digital outputs in high state
  -- 4. 5 digital outputs inverted automatically to low state
  -- 5. SetDigitalOutputs message sent
  -- 6. 5 digital outputs in high state
  -- 7. 5 digital outputs inverted automatically to low state
function test_DigitalOutputIDP700_WhenSetDigitalOutputsMessageSentAndInvertTimeGreaterThanZero_DigitalOutputsChangeStatesAccordingToMessageAndInvertsAutomaticallyAfterInvertTime()

  -- This TC only applies to IDP 700 series terminal
  if(terminalInUse~=700) then skip("TC related only to IDP 700s") end

  local invertTime = 1   -- in minutes, time in minutes, after which the set digital output state is automatically inverted

  -- TODO: change this TC to work in 700's terminals

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                          {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                          {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                          {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                          {lsfConstants.pins.portConfig[4], 6},      -- port 2 as digital output
                                         }
                   )

  -- Sending setDigitalOutputs message setting all 5 ports to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP7xxLine14"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP7xxLine15"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP7xxLine16"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP7xxLine17"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=4,Fields={{Name="LineNum",Value="IDP7xxLine18"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 5 ports has been correctly set to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 5 ports has been correctly automatically inverted to low level
  for counter = 1, 4, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been automatically inverted to low level after invertTime period")
  end

  -- Sending setDigitalOutputs message setting all 5 ports to low state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP7xxLine14"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP7xxLine15"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP7xxLine16"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=3,Fields={{Name="LineNum",Value="IDP7xxLine17"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=4,Fields={{Name="LineNum",Value="IDP7xxLine18"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 4 ports has been correctly set to low level
  for counter = 1, 4, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 4 ports has been correctly automatically inverted to high level
  for counter = 1, 4, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been automatically inverted to high level after invertTime period")
  end



end



--- TC checks if setDigitalOutputs message sets digital output ports for IDP 800 series terminal and inverts it after set time .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 terminal simulated
  --
  -- Steps:
  --
  -- 1. Configure all 3 ports as digital outputs
  -- 2. Send setDigitalOutputs to-mobile message setting all 3 ports to high level and invertTime different than zero
  -- 3. Read states of the ports
  -- 4. wait longer than set invertTime and read states of the ports
  -- 5. Send setDigitalOutputs to-mobile message setting all 3 ports back to low level and invertTime different than zero
  -- 6. Read states of the ports
  -- 7. wait longer than set invertTime and read states of the ports
  --
  -- Results:
  --
  -- 1. All 3 ports set as digital outputs
  -- 2. SetDigitalOutputs message sent
  -- 3. 3 digital outputs in high state
  -- 4. 3 digital outputs inverted automatically to low state
  -- 5. SetDigitalOutputs message sent
  -- 6. 3 digital outputs in high state
  -- 7. 3 digital outputs inverted automatically to low state
function test_DigitalOutputIDP800_WhenSetDigitalOutputsMessageSentAndInvertTimeGreaterThanZero_DigitalOutputsChangeStatesAccordingToMessageAndInvertsAutomaticallyAfterInvertTime()

  -- This TC only applies to IDP 600 series terminal
  if(terminalInUse~=800) then skip("TC related only to IDP 800s") end

  local invertTime = 1   -- in minutes, time in minutes, after which the set digital output state is automatically inverted

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                          {lsfConstants.pins.portConfig[1], 6},      -- port 1 as digital output
                                          {lsfConstants.pins.portConfig[2], 6},      -- port 2 as digital output
                                          {lsfConstants.pins.portConfig[3], 6},      -- port 3 as digital output
                                         }
                   )

  -- Sending setDigitalOutputs message setting all 3 ports to high state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=1},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 3 ports has been correctly set to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been correctly set to high level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 3 ports has been correctly automatically inverted to low level
  for counter = 1, 3, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been automatically inverted to low level after invertTime period")
  end

  -- Sending setDigitalOutputs message setting all 3 ports to low state
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setDigitalOutputs}
	message.Fields = {{Name="OutputList",Elements={{Index=0,Fields={{Name="LineNum",Value="IDP6xx,8xxLine1"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=1,Fields={{Name="LineNum",Value="IDP6xx,8xxLine2"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}},
                                                 {Index=2,Fields={{Name="LineNum",Value="IDP6xx,8xxLine3"},{Name="LineState",Value=0},{Name="InvertTime",Value=invertTime}}}}}}

  gateway.submitForwardMessage(message)
  framework.delay(2)

  -- checking if all 3 ports has been correctly set to low level
  for counter = 1, 3, 1 do
  assert_equal(0, device.getIO(counter), "Digital output port has not been correctly set to low level by setDigitalOutputs message")
  end

  framework.delay(invertTime*60+2) -- wait longer than invertTime to let the outputs change its states

  -- checking if all 3 ports has been correctly automatically inverted to high level
  for counter = 1, 3, 1 do
  assert_equal(1, device.getIO(counter), "Digital output port has not been automatically inverted to high level after invertTime period")
  end



end


