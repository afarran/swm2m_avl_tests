-----------
-- Digital Inputs test module
-- - contains digital input related test cases
-- @module TestDigitalInputsModule

module("TestDigitalInputsModule", package.seeall)

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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.lpmTrigger, 0},
                                                  }
                    )
  framework.delay(2)
  -- checking the state of terminal
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  -- selecting random number of port to be used in TCs
  math.randomseed(os.time())                -- os.time used as randomseed
  math.random(1,4)

  if hardwareVariant == 3 then
  randomPortNumber = math.random(1,3)
  else
  randomPortNumber = math.random(1,4)
  end


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



--- Setup function is run before every TC, it puts terminal into known state so that every TC starts in the same conditions .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set continues property (PIN 15) in Position service (SIN 20) to value GPS_READ_INTERVAL
  -- 2. Put terminal into stationary state
  -- 3. Simulate all 4 port change to low state
  -- 4. Disable 4 digital input lines
  --
  -- Results:
  --
  -- 1. continues property set to GPS_READ_INTERVAL, GPS read periodically
  -- 2. Terminal put into stationary state
  -- 3. All 4 ports in low state
  -- 4. Digital input lines 1-4 disabled
 function setup()

  -- setting the continues mode of position service (SIN 20, PIN 15)
  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}
                                               }
                    )

  -- put terminal into stationary state
  avlHelperFunctions.putTerminalIntoStationaryState()

  -- toggling port 1 (in case terminal is in IgnitionOn state and port is low)
  device.setIO(1, 1)
  framework.delay(2)

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
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.GeneralPurpose}, -- digital input line 13 associated with IgnitionOn and SM0 functions
                                             }
                    )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})
  framework.delay(2)

  ----------------------------------------------------------------------
  -- For IDP 800
  ----------------------------------------------------------------------
  if(hardwareVariant==3) then
     for counter = 1, 3, 1 do
       device.setIO(counter, 0) -- setting all 3 ports to low state
     end

    -- setting the IO properties - disabling all 3 I/O ports
    lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                          }
                      )

  end

  ----------------------------------------------------------------------
  -- For IDP 680
  ----------------------------------------------------------------------
  if(hardwareVariant==1) then
    for counter = 1, 4, 1 do
       device.setIO(counter, 0) -- setting all 4 ports to low state
    end

    -- setting the IO properties - disabling all 4 I/O ports
    lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[4], 0},      -- port disabled
                                          }
                      )
  end

  ----------------------------------------------------------------------
  -- For IDP 780
  ----------------------------------------------------------------------
  if(hardwareVariant==2) then
    -- TODO
  end

  -- disabling line number 1
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], 0},   -- 0 is for line disabled
                                             }
                   )

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end


--    START OF TEST CASES
--   Each test case is a global function whose name begins with "test"





--- TC checks if IgnitionOn message is sent when port associated with IgnitionOn function changes state to high .
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port set as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},   -- line set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gateway.setHighWaterMark()         -- to get the newest messages
  local timeOfEvent = os.time()   -- to get exact timestamp
  device.setIO(randomPortNumber, 1)  -- port  to high level - that should trigger IgnitionOn

  -- IgnitionOn message expected
  local expectedMins = {avlConstants.mins.ignitionON}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.ignitionON], "IgnitionOn message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.ignitionON].Longitude), "IgnitionOn message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.ignitionON].Latitude), "IgnitionOn message has incorrect latitude value")
  assert_equal("IgnitionOn", receivedMessages[avlConstants.mins.ignitionON].Name, "IgnitionOn message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.ignitionON].EventTime), 4, "IgnitionOn message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.ignitionON].Speed), "IgnitionOn message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.ignitionON].Heading), "IgnitionOn message has incorrect heading value")

  -- verification of the state of terminal - IgnitionOn true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                    {avlConstants.pins.digStatesDefBitmap, digStatesDefBitmap}
                                             }
                   )

  gateway.setHighWaterMark()         -- to get the newest messages

  device.setIO(1, 1)                 -- port 1 to high level
  framework.delay(2)
  device.setIO(1, 0)                 -- port 1 to low level - that should trigger IgnitionOn

  -- IgnitionOn message expected
  local expectedMins = {avlConstants.mins.ignitionON}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.ignitionON], "IgnitionOn message not received")

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
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)          -- wait until terminal reads the gps position

  -- gps signal loss is simulated at this moment, no valid fix provided
  gpsSettings["fixType"] = 1

  gps.set(gpsSettings)
  framework.delay(7)          -- wait to make sure gpsFix age is above 5 seconds

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},              -- line number 1 set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gateway.setHighWaterMark()         -- to get the newest messages
  local timeOfEventTC = os.time()   -- to get exact timestamp
  device.setIO(1, 1)                 -- port 1 to high level - that should trigger IgnitionOn

  -- IgnitionOn message expected
  local expectedMins = {avlConstants.mins.ignitionON}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.ignitionON], "IgnitionOn message not received")
  assert_equal(8, tonumber(receivedMessages[avlConstants.mins.ignitionON].GpsFixAge), 3 ,  "IgnitionOn message has incorrect GpsFixAge value")


end


--- TC checks if IgnitionOff message is sent when digital input port changes to low state .
  -- Initial Conditions:lsfConstants.pins.portEdgeDetect
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

  -- *** Setup
  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
                      speed = 0,                      -- terminal in stationary state
                      latitude = 1,                   -- degrees
                      longitude = 1,                  -- degrees
                      fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }
  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port set as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},  -- digital input line set for Ignition function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)    -- applying gps settings
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  device.setIO(randomPortNumber, 1) -- that should trigger IgnitionOn

  -- IgnitionOn message expected
  local expectedMins = {avlConstants.mins.ignitionON}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.ignitionON], "IgnitionOn message not received")

  -- *** Execute
  gateway.setHighWaterMark()         -- to get the newest messages
  local timeOfEvent = os.time()   -- to get exact timestamp
  device.setIO(randomPortNumber, 0)  -- port transition to low state; that should trigger IgnitionOff

  -- IgnitionOff message expected
  local expectedMins = {avlConstants.mins.ignitionOFF}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.ignitionOFF], "IgnitionOff message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].Longitude), "IgnitionOff message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].Latitude), "IgnitionOff message has incorrect latitude value")
  assert_equal("IgnitionOff", receivedMessages[avlConstants.mins.ignitionOFF].Name, "IgnitionOff message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].EventTime), 4, "IgnitionOff message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].Speed), "IgnitionOff message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].Heading), "IgnitionOff message has incorrect heading value")

  -- checking if terminal correctly goes to IgnitionOn = false state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

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
  -- 5. Set fixType to 1 (no valid fix provided)
  -- 6. Simulate port value change back to low state
  -- 7. Receive IgnitionOff message and check terminals state
  -- 8. Verify fields of message against expected values
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. High state of the port set to be the trigger for IgnitionOn line activation
  -- 3. Point#1 is terminals simulated position in stationary state
  -- 4. Terminal goes to IgnitionOn state after setting port state to high level
  -- 5. GPS signal loss is simulated
  -- 6. Port changes value back to low level
  -- 7. IgnitionOff (MIN 5) message received and terminal goes to IgnitionOn=false state
  -- 8. Message fields contain Point#1 GPS and time information and GPS fix age field is included (fix older than 5 seconds)
function test_Ignition_WhenPortValueChangesToLow_IgnitionOffMessageSentGpsFixAgeReported()

  -- *** Setup
  -- Point#1 gps settings
  local gpsSettings={
                      speed = 0,                      -- terminal in stationary state
                      latitude = 1,                   -- degrees
                      longitude = 1,                  -- degrees
                      fixType = 3,                    -- fix provided
                     }

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]}, -- line number set for IgnitionOn function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  device.setIO(randomPortNumber, 1)         -- that should trigger IgnitionOn

  -- IgnitionOn message expected
  local expectedMins = {avlConstants.mins.ignitionON}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.ignitionON], "IgnitionOn message not received")

  gps.set({fixType = 1})                      -- no valid fix provided, gps signal loss simulated
  framework.delay(6)                          -- to make sure gpsFix age is above 5 seconds
  -- *** Execute
  gateway.setHighWaterMark()         -- to get the newest messages
  device.setIO(randomPortNumber, 0)  -- port transition to low state; that should trigger IgnitionOff

  -- IgnitionOff message expected
  local expectedMins = {avlConstants.mins.ignitionOFF}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.ignitionOFF], "IgnitionOff message not received")
  assert_equal(6, tonumber(receivedMessages[avlConstants.mins.ignitionOFF].GpsFixAge), 3 ,  "IgnitionOff message has incorrect GpsFixAge value")


end


--- TC checks if IdlingStart message is sent when terminal is in stationary state and IgnitionON is true longer than maxIdlingTime .
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
  -- 3. Set maxIdlingTime (PIN 23) to value above zero
  -- 4. Simulate terminals position in stationary state in Point#1
  -- 5. Simulate port value change to high state and wait longer than maxIdlingTime
  -- 6. Receive IdlingStart (MIN 21) message
  -- 7. Verify fields of message against expected values
  -- 8. Read avlStates property and check EngineIdling state
  --
  -- Results:
  --
  -- 1. Port configured as digital input and assiociated with IgnitionOn line
  -- 2. High state of the port set to be the trigger for IgnitionOn line activation
  -- 3. MaxIdlingTime set to value greater than zero
  -- 4. Point#1 is terminals simulated position in stationary state
  -- 5. Terminal goes to IgnitionOn state
  -- 6. IdlingStart (MIN 21) message received
  -- 7. IdlingStart message fields contain Point#1 GPS and time information
  -- 8. EngineIdling state is true
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTime_IdlingStartMessageSent()
  -- *** Setup
  local MAX_IDLING_TIME = 10         -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message
  local STATIONARY_DEBOUNCE_TIME = 1 -- seconds

  -- Point#1 gps settings
  local gpsSettings={
                      speed = 0,                     -- terminal in stationary state
                      latitude = 13,                 -- degrees
                      longitude = 11,                -- degrees
                      fixType = 3,                   -- valid fix provided, good quality of gps signal
                     }


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},      -- line set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, MAX_IDLING_TIME},                                           -- maximum idling time allowed without sending idling report
                                                {avlConstants.pins.stationaryDebounceTime,STATIONARY_DEBOUNCE_TIME}
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME + STATIONARY_DEBOUNCE_TIME)

  -- *** Execute
  gateway.setHighWaterMark()
  timeOfEvent = os.time()
  device.setIO(randomPortNumber, 1)    -- port set to high level - that should trigger IgnitionOn
  framework.delay(MAX_IDLING_TIME)     -- wait longer than maxIdlingTime to trigger the IdlingStart event

  -- IdlingStart message expected
  local expectedMins = {avlConstants.mins.idlingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.idlingStart], "IdlingStart message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.idlingStart].Longitude), "IdlingStart message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.idlingStart].Latitude), "IdlingStart message has incorrect latitude value")
  assert_equal("IdlingStart", receivedMessages[avlConstants.mins.idlingStart].Name, "IdlingStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.idlingStart].EventTime), 4, "IdlingStart message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.idlingStart].Speed), "IdlingStart message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.idlingStart].Heading), "IdlingStart message has incorrect heading value")

  -- checking if terminal has entered EngineIdling state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the EngineIdling state, IdlingStart message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTime_IdlingStartMessageSentGpsFixAgeReported()

  -- *** Setup
  local MAX_IDLING_TIME = 1          -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message
  local STATIONARY_DEBOUNCE_TIME = 1 -- seconds

  -- Point#1 gps settings
  local gpsSettings={
                      speed = 0,                     -- terminal in stationary state
                      latitude = 13,                 -- degrees
                      longitude = 11,                -- degrees
                      fixType = 3,                   -- valid fix provided, good quality of gps signal
                     }


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},      -- line set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, MAX_IDLING_TIME},                                           -- maximum idling time allowed without sending idling report
                                                {avlConstants.pins.stationaryDebounceTime,STATIONARY_DEBOUNCE_TIME}
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME + STATIONARY_DEBOUNCE_TIME)

  gps.set({fixType = 1})  -- GPS signal loss is simulated
  framework.delay(7)      -- to make sure that fix is older than 5 seconds

  -- *** Execute
  gateway.setHighWaterMark()
  timeOfEvent = os.time()
  device.setIO(randomPortNumber, 1)                                -- port set to high level - that should trigger IgnitionOn
  framework.delay(MAX_IDLING_TIME)     -- wait longer than maxIdlingTime to trigger the IdlingStart event, cold fix delay is taken into consideration

  -- IdlingStart message expected
  local expectedMins = {avlConstants.mins.idlingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.idlingStart], "IdlingStart message not received")
  assert_equal(6, tonumber(receivedMessages[avlConstants.mins.idlingStart].GpsFixAge), 3, "IdlingStart message has incorrect GpsFixAge value")


end


--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and IgnitionOn state becomes false
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line, set the high state
  -- of the port to be a trigger for line activation; then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 1 change to low level (IgnitionOff) and check if IdlingEnd message is correctly sent and EngineIdling
  -- state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccurs_IdlingEndMessageSent()

  -- *** Setup
  local MAX_IDLING_TIME = 1          -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message
  local STATIONARY_DEBOUNCE_TIME = 1 -- seconds

  -- Point#1 gps settings
  local gpsSettings={
                      speed = 0,                     -- terminal in stationary state
                      latitude = 13,                 -- degrees
                      longitude = 11,                -- degrees
                      fixType = 3,                   -- valid fix provided, good quality of gps signal
                     }


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},      -- line set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, MAX_IDLING_TIME},                                           -- maximum idling time allowed without sending idling report
                                                {avlConstants.pins.stationaryDebounceTime,STATIONARY_DEBOUNCE_TIME}
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME + STATIONARY_DEBOUNCE_TIME)

  -- *** Execute
  gateway.setHighWaterMark()
  device.setIO(randomPortNumber, 1)    -- port set to high level - that should trigger IgnitionOn
  framework.delay(MAX_IDLING_TIME)     -- wait longer than maxIdlingTime to trigger the IdlingStart event

  -- IdlingStart message expected
  local expectedMins = {avlConstants.mins.idlingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.idlingStart], "IdlingStart message not received")

  timeOfEvent = os.time()
  device.setIO(randomPortNumber, 0)    -- port set to low level - that should trigger IgnitionOff

  -- IdlingEnd message expected
  local expectedMins = {avlConstants.mins.idlingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.idlingEnd], "IdlingEnd message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.idlingEnd].Longitude), "IdlingEnd message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.idlingEnd].Latitude), "IdlingEnd message has incorrect latitude value")
  assert_equal("IdlingEnd", receivedMessages[avlConstants.mins.idlingEnd].Name, "IdlingEnd message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.idlingEnd].EventTime), 4, "IdlingEnd message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.idlingEnd].Speed), "IdlingEnd message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.idlingEnd].Heading), "IdlingEnd message has incorrect heading value")

  -- checking if terminal correctly goes out of EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndIgnitionOffOccurs_IdlingEndMessageSentGpsFixReported()

  -- *** Setup
  local MAX_IDLING_TIME = 1          -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message
  local STATIONARY_DEBOUNCE_TIME = 1 -- seconds

  -- Point#1 gps settings
  local gpsSettings={
                      speed = 0,                     -- terminal in stationary state
                      latitude = 13,                 -- degrees
                      longitude = 11,                -- degrees
                      fixType = 3,                   -- valid fix provided, good quality of gps signal
                     }


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[randomPortNumber], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[randomPortNumber], 3}  -- detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[randomPortNumber], avlConstants.funcDigInp["IgnitionOn"]},      -- line set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, MAX_IDLING_TIME},                                           -- maximum idling time allowed without sending idling report
                                                {avlConstants.pins.stationaryDebounceTime,STATIONARY_DEBOUNCE_TIME}
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME + STATIONARY_DEBOUNCE_TIME)

  -- *** Execute
  gateway.setHighWaterMark()
  device.setIO(randomPortNumber, 1)    -- port set to high level - that should trigger IgnitionOn
  framework.delay(MAX_IDLING_TIME)     -- wait longer than maxIdlingTime to trigger the IdlingStart event

  -- IdlingStart message expected
  local expectedMins = {avlConstants.mins.idlingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.idlingStart], "IdlingStart message not received")

  gps.set({fixType = 1})               -- GPS signal loss is simulated
  framework.delay(7)                   -- to make sure gps fix age is older then 5 seconds
  device.setIO(randomPortNumber, 0)    -- port set to low level - that should trigger IgnitionOff

  -- IdlingEnd message expected
  local expectedMins = {avlConstants.mins.idlingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.idlingEnd], "IdlingEnd message not received")
  assert_equal(7, tonumber(receivedMessages[avlConstants.mins.idlingEnd].GpsFixAge), 3, "IdlingEnd message has incorrect GpsFixAge value")

end

--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and it starts moving (MovingStart sent)
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line, set the high state
  -- of the port to be a trigger for line activation; then simulate port 1 value change to high state and
  -- wait until IgnitionOn is true; then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- after that simulate gps speed above stationarySpeedThld for longer then movingDebounceTime to put the terminal into moving state
  -- check if IdlingEnd message is correctly sent and EngineIdling state becomes false; also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, maxIdlingTime},                          -- maximum idling time allowed without sending idling report
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},              -- stationary speed threshold
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},                -- moving debounce time
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  device.setIO(1, 1)                       -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+3)         -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")

  -- now moving start should be simulated, gps settings are changed
  local gpsSettings={
              speed = stationarySpeedThld+10, -- above stationarySpeedThld
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType=3,                      -- valid fix
              heading = 90                    -- degrees
                     }

  gateway.setHighWaterMark()         -- to get the newest messages from moment when terminal start movement
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+5) -- wait until MovingStart and IdlingEnd messages are genarated

  -- MovingStart and IdlingEnd messages expected
  receivedMessages = gateway.getReturnMessages()            -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.idlingEnd))
  local idlingEndMessage = filteredMessages[1]                            -- that is performed because of the structure of the filteredMessages

  -- TODO: this need to be done in different way
  assert_not_nil(idlingEndMessage, "IdlingEnd message not received")    -- checking if IdlingEnd message was received, if not that is not correct

  if((next(idlingEndMessage))) then                    -- if IdlingEnd message has been received it is verified
  local expectedValues={                               -- expected values of the fields in the report
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = os.time()
                        }
  avlHelperFunctions.reportVerification(idlingEndMessage, expectedValues ) -- verification of the all report fields

  end
  -- checking if terminal correctly goes out of EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if IdlingStart message is not sent when terminal is in stationary state and IgnitionON state is true
  -- for time shorter than maxIdlingTime
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp[1] = 2);
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 3);
  -- then simulate port 1 value change to high state to get the IgnitionOn state is true; then wait shorter
  -- than maxIdlingTime and check if message IdlingStart has not been sent and check if terminal has not entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal does not enter the EngineIdling state, IdlingStart message not sent

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodBelowMaxIdlingTime_IdlingMessageNotSent()

  local maxIdlingTime = 15  -- in seconds, time for which terminal can be in IgnitionOn state without sending IdlingStart message

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlConstants.pins.maxIdlingTime, maxIdlingTime}                          -- maximum idling time allowed without sending idling report
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
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.idlingStart))

  --IdlingStart message not expected
  assert_false(next(filteredMessages), "IdlingStart message not expected")  -- checking if IdlingEnd message was received, if not that is not correct

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

end


--- TC checks if MovingEnd message is sent when terminal is in moving state and IgnitionOff event occurs
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp[1] = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3);set movingDebounceTime to 20 seconds and stationarySpeedThld to 5 kmh
  -- then then simulate port 1 value change to high state to get the IgnitionOn state true;
  -- after that simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if the moving state has been obtained; when terminal is in the moving state simulate
  -- port 1 change to low level to trigger IgnitionOff event and check if MovingEnd message is sent
  -- and terminal is no longer in the moving state after that
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL,
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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.funcDigInp[1], 2},              -- line number 1 set for Ignition function
                                                {avlConstants.pins.digStatesDefBitmap, 3},       -- high state is expected to trigger Ignition on
                                             }
                   )

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                  )

  -- first terminal is put into moving state
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- then terminal is put into IgnitionOn state
  device.setIO(1, 1)                          -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(3)                          -- delay to let the event to be generated

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")


  -- when the terminal is in the moving state IgnitionOff event is genarated
  gateway.setHighWaterMark()                  -- to get the newest messages
  device.setIO(1, 0)                          -- port 1 to low level - that should trigger IgnitionOff
  framework.delay(3)                          -- delay to let the event to be generated

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()

  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingEnd))
  local ignitionOffMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionOFF))

  -- checking if expected messages has been received
  assert_not_nil(next(movingEndMessage), "MovingEnd message not received")              -- if MovingEnd message not received assertion fails
  assert_not_nil(next(ignitionOffMessage), "IgnitionOff message not received")          -- if IgnitionOff message not received assertion fails

  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(tonumber(ignitionOffMessage[1].Payload.EventTime), tonumber(movingEndMessage[1].Payload.EventTime), 1, "Timestamps of IgnitionOff and MovingEnd messages expected to be equal with 1 second tolerance")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of IgnitionOff and MovingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: MovingEnd ReceiveUTC = "2014-09-03 07:56:37" and IgnitionOff MessageUTC = "2014-09-03 07:56:42" - that is correct

  -- checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")
  -- checking the state of terminal, moving state is not ecpected
   assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")


end


--- TC checks if MovingEnd and SpeedingEnd messages are sent when terminal is in speeding state and IgnitionOff event occurs
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp[1] = 2), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); set movingDebounceTime to 5 seconds,  stationarySpeedThld to 5 kmh
  -- defaultSpeedLimit to 80  kmh and SpeedingTimeOver to 20 seconds
  -- then simulate port 1 value change to high state to get the IgnitionOn state true;
  -- after that simulate speed above defaultSpeedLimit for time longer than speedingTimeOver
  -- and check if the speeding state has been obtained; when terminal is in the speeding state simulate
  -- port 1 change to low level to trigger IgnitionOff event and check if MovingEnd and SpeedingEnd messages are sent
  -- and terminal is no longer in the speeding state after that
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL,
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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},    -- line number 1 set for Ignition function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},              -- stationary speed threshold
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},                -- moving debounce time
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                  )

  -- first terminal is put into moving state
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- gps settings applied,
  framework.delay(movingDebounceTime+speedingTimeOver+GPS_READ_INTERVAL+6)     -- 5 seconds are added as prior to SpeedingStart there will be movingStart message sent

  --checking if terminal is in the speeding state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the Speeding state")

  -- then terminal is put into IgnitionOn state
  device.setIO(1, 1)                          -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(3)                          -- delay to let the event to be generated

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")


  -- when the terminal is in the speeding state IgnitionOff event is genarated
  gateway.setHighWaterMark()                  -- to get the newest messages
  device.setIO(1, 0)                          -- port 1 to low level - that should trigger IgnitionOff
  framework.delay(5)                          -- delay to let the event to be generated

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()

  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingEnd))
  local ignitionOffMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionOFF))
  local speedingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.speedingEnd))

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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")
  -- checking the state of terminal, moving state is not ecpected
   assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the moving state")

end



--- TC checks if IdlingEnd message is correctly sent when terminal is in EngineIdling state and one of Service Meters lines
  -- goes to active state
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp[1] = 2), set the high state
  -- of the port to be a trigger for line activation (digStatesDefBitmap = 5); configure port 2 as a digital input and associate
  -- this port with SM1 line (funcDigInp[2] = 5);  then simulate port 1 value change to high state and wait until IgnitionOn is true;
  -- then wait until maxIdlingTime passes and check if EngineIdling state has been correctly obtained,
  -- then simulate port 2 change to high level (SM1 = ON) and check if IdlingEnd message is correctly sent and EngineIdling state becomes false;
  -- also verify the fields of the IdlingEnd report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the out of EngineIdling state, IdlingEnd message sent and report fields
  -- have correct values
function test_EngineIdling_WhenTerminalStationaryEngineIdlingStateTrueAndServiceMeterLineBecomesActive_IdlingEndMessageSent()

  local maxIdlingTime = 5 -- in seconds, time in which terminal can be in IgnitionOn state without sending IdlingStart message

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
                     }

  gps.set(gpsSettings)

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},      -- port 1 as digital input
                                                {lsfConstants.pins.portConfig[2], 3},      -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3},  -- detection for both rising and falling edge
                                                {lsfConstants.pins.portEdgeDetect[2], 3},  -- detection for both rising and falling edge

                                        }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SM1"]},          -- line number 2 set for ServiceMeter1 function
                                                {avlConstants.pins.maxIdlingTime, maxIdlingTime},                         -- maximum idling time allowed without sending idling report

                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SM1Active"})

  gateway.setHighWaterMark()                -- to get the newest messages

  device.setIO(1, 1)                        -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+10)         -- wait longer than maxIdlingTime to trigger the IdlingStart event

  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)

  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal not in the EngineIdling state")


  device.setIO(2, 1)                        -- port 2 to high level - that should trigger SM1=ON
  framework.delay(7)

  -- IdlingEnd  message expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.idlingEnd))
  assert_true(next(matchingMessages), "IdlingEnd report not received")   -- checking if IdlingEnd message has been caught

  gpsSettings.heading = 361   -- 361 is reported for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IdlingEnd",
                  currentTime = os.time()
                        }

  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues) -- verification of the report fields
  -- checking if terminal correctly goes out from EngineIdling state
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

  device.setIO(2, 0)                        -- port 2 to high level - that should trigger SM1=OFF

end



--- TC checks if IdlingStart message is not sent when terminal is in stationary state and IgnitionON state is true
  -- for time longer than maxIdlingTime but one Service Meter line (SM1) is active
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOn line (funcDigInp[1] = 2),
  -- set the high state of the port to be a trigger for line activation (digStatesDefBitmap = 5);
  -- configure port 2 as a digital input and associate this port with SM1 line (funcDigInp[2] = 5);
  -- simulate port 1 value change to high (SM1 = ON) and then change port 1 value to high state to get the IgnitionOn state and
  -- wait longer than maxIdlingTime; after that check if message IdlingStart has not been sent and check if terminal has not
  -- entered EngineIdling state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- none of Service Meters lines is high, all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal does not enter the EngineIdling state, IdlingStart message not sent

function test_EngineIdling_WhenTerminalStationaryAndIgnitionOnForPeriodAboveMaxIdlingTimeButServiceMeterLineActive_IdlingMessageNotSent()

  local maxIdlingTime = 1  -- in seconds, time in which terminal can be in IgnitionOn state without sending IdlingStart message

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},      -- port 1 as digital input
                                                {lsfConstants.pins.portConfig[2], 3},      -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3},  -- detection for both rising and falling edge
                                                {lsfConstants.pins.portEdgeDetect[2], 3},  -- detection for both rising and falling edge

                                        }

                   )

   -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},   -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SM1"]},   -- line number 2 set for ServiceMeter1 function
                                                {avlConstants.pins.maxIdlingTime, maxIdlingTime},                         -- maximum idling time allowed without sending idling report

                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn", "SM1Active"})

  device.setIO(2, 0)                        -- that triggers SM = Off (Service Meter line inactive)
  device.setIO(1, 0)                        -- port 1 to low level - that should trigger IgnitionOff

  framework.delay(2)

  gateway.setHighWaterMark()                -- to get the newest messages

  device.setIO(2, 1)                        -- that triggers SM = ON (Service Meter line active)
  framework.delay(5)                        -- to make sure event has been generated before further actions
  device.setIO(1, 1)                        -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(maxIdlingTime+10)         -- wait longer than maxIdlingTime to try to trigger the IdlingStart event

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.idlingStart))

  --IdlingStart message not expected
  assert_false(next(filteredMessages), "IdlingStart message not expected")  -- checking if IdlingEnd message was received, if not that is not correct

  -- checking if terminal has not entered EngineIdling state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).EngineIdling, "terminal incorrectly in the EngineIdling state")

  device.setIO(2, 0)                        -- that triggers SM = Off (Service Meter line not active)

end




--- TC checks if SeatbeltViolationStart message is correctly sent when terminal is moving and SeatbeltOFF line
  -- becomes active and stays active for time longer than seatbeltDebounceTime (driver unfastens belt during the ride)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 10       -- seconds

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  gateway.setHighWaterMark()                -- to get the newest messages
  local timeOfEventTC = os.time()           -- to get exact timestamp
  device.setIO(2, 1)                        -- port 2 to high level - that triggers SeatbeltOff true
  framework.delay(seatbeltDebounceTime)     -- wait for seatbeltDebounceTime

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationStart message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is correctly sent when terminal starts moving and SeatbeltOFF line
  -- is active for time longer than seatbeltDebounceTime (driver starts ride and does not fasten seatbelt)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalStartsMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 10       -- seconds

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  gateway.setHighWaterMark()            -- to get the newest messages
  local timeOfEventTC = os.time()      -- to get exact timestamp
  framework.delay(seatbeltDebounceTime) -- to make sure seatbeltDebounceTime passes

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationStart message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is correctly sent when terminal is moving and SeatbeltOFF line is active for time
  -- longer than seatbeltDebounceTime and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that wait for longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state, SeatbeltViolationStart message is sent and
  -- reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put in the SeatbeltViolation state, SeatbeltViolationStart message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSentGpsFixAgeReported()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 15       -- seconds


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")
  local timeOfEventTC = os.time()
  gpsSettings.fixType = 1                    -- no valid fix provided from now
  gps.set(gpsSettings)                       -- applying gps setttings
  framework.delay(7)                         -- to make sure gps fix is older than 5 seconds related to EventTime
  gateway.setHighWaterMark()                 -- to get the newest messages
  framework.delay(seatbeltDebounceTime)      -- to make sure seatbeltDebounceTime passes

  -- SeatbeltViolationStart message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationStart message not received")


  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEventTC,
                  GpsFixAge = 8
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  -- verification of the state of terminal - SeatbeltViolation true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationStart message is not sent when terminal is moving and SeatbeltOFF line
  -- is active for time shorter than seatbeltDebounceTime
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); simulate speed above stationarySpeedThld for time longer than movingDebounceTime
  -- and check if terminal goes to moving state; after that simulate port 2 value change to high state to make SeatbeltOff
  -- line active but for time shorter than seatbeltDebounceTime;
  -- check if SeatbeltViolationStart message is not sent and terminal does not go to SeatbeltViolation state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal not put in the SeatbeltViolation state, SeatbeltViolationStart message not sent
function test_SeatbeltViolation_WhenTerminalMovingAndSeatbeltOffLineIsActiveForPeriodAboveThld_SeatbeltViolationStartMessageSent()

  -- moving state related properties
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 15        -- seconds



  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the Moving state")

  gateway.setHighWaterMark()               -- to get the newest messages

  device.setIO(2, 1)                       -- port 2 to high level - that triggers SeatbeltOff true
  framework.delay(seatbeltDebounceTime-5)  -- time shorter than seatbeltDebounceTime
  device.setIO(2, 0)                       -- port 2 to low level - that triggers SeatbeltOff false

  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationStart))

  --SeatbeltViolationStart message not expected
  assert_false(next(filteredMessages), "SeatbeltViolationStart message not expected")  -- checking if SeatbeltViolationStart message was received, if not that is not correct

  -- checking if terminal has not entered SeatbeltViolation state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolationf state")

end



--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and SeatbeltOff line becomes inactive (driver fastened belt)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime
  -- and check if terminal goes to SeatbeltViolation state;  then simulate port 2 value change to low
  -- (SeatbeltOff line becomes inactive) and check if terminal goes out of SeatbeltViolation state,
  -- SeatbeltViolationEnd message is sent and reported fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndSeatbeltOffLineBecomesInactive_SeatbeltltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 1       -- seconds


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolation state")

  gateway.setHighWaterMark()           -- to get the newest messages
  timeOfEventTC = os.time()
  device.setIO(2, 0)                   -- port 2 to low level - that triggers SeatbeltOff false, belt fastened

  -- SeatbeltViolationEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationEnd),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationEnd message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionOn true expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolationStart state")


end




--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and it stops moving (movingEng message sent)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3), set the high state of the port to be a trigger for line activation
  -- (digStatesDefBitmap = 3); then simulate port 2 value change to high state to make SeatbeltOff line
  -- active; then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate speed = 0 (terminal stops) and check if
  -- terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported fields have
  -- correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndMovingStateBecomesFalse_SeatbeltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local seatbeltDebounceTime = 1        -- seconds


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")

  gateway.setHighWaterMark()           -- to get the newest messages

  gpsSettings.speed = 0                -- terminal stops
  gps.set(gpsSettings)
  framework.delay(6)                                      -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- filtering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationEnd))
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationEnd message is correctly sent when terminal is in SeatbeltViolation state
  -- and it IgnitionOff event occurs
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3); configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp[1] = 2), set the high state of the port to be a trigger for these two lines activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state to make terminal IgnitionON = true
  -- and simulate port 2 value change to high state to make SeatbeltOff line active;
  -- then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate port 1 value change to low to generate IgnitionOff event
  -- and  and check if terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported
  -- fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndIgnitionOnStateBecomesFalse_SeatbeltViolationEndMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 15          -- seconds
  local stationarySpeedThld = 5          -- kmh
  local seatbeltDebounceTime = 15        -- seconds


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")

  gateway.setHighWaterMark()                              -- to get the newest messages

  device.setIO(1, 0)                                      -- port 1 to low level - that should trigger IgnitionOff
  local timeOfEvent = os.time()
  framework.delay(10)                                     -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- flitering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationEnd))
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")


end


--- TC checks if SeatbeltViolationEnd message is correctly sent (for terminal is in SeatbeltViolation state) when
  -- IgnitionOff event occurs and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- configure port 2 as a digital input and associate this port with SeatbeltOFF line
  -- (funcDigInp[2] = 3); configure port 1 as a digital input and associate this port with IgnitionOn line
  -- (funcDigInp[1] = 2), set the high state of the port to be a trigger for these two lines activation
  -- (digStatesDefBitmap = 3); then simulate port 1 value change to high state to make terminal IgnitionON = true
  -- and simulate port 2 value change to high state to make SeatbeltOff line active;
  -- then simulate speed above stationarySpeedThld for time longer than seatbeltDebounceTime and check if
  -- terminal goes to SeatbeltViolation state; then simulate port 1 value change to low to generate IgnitionOff event
  -- and  and check if terminal goes out of SeatbeltViolation state, SeatbeltViolationEnd message is sent and reported
  -- fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- terminal correctly put out of the SeatbeltViolation state, SeatbeltViolationEnd message sent and reported fields
  -- have correct values
function test_SeatbeltViolation_WhenTerminalMovingSeatbeltViolationStateTrueAndIgnitionOnStateBecomesFalse_SeatbeltViolationEndMessageSentGpsFixAgeReported()

  -- properties values to be used in TC
  local movingDebounceTime = 15          -- seconds
  local stationarySpeedThld = 5          -- kmh
  local seatbeltDebounceTime = 15        -- seconds


  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}  -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp["IgnitionOn"]},     -- line number 1 set for Ignition function
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp["SeatbeltOff"]},    -- line number 2 set for SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime,seatbeltDebounceTime}, -- seatbeltDebounceTime set
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},  -- stationarySpeedThld - moving related
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},    -- movingDebounceTime - moving related
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
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal not in the seatbeltViolationStart state")
  gpsSettings.fixType = 1                                 -- no valid fix provided from now
  gps.set(gpsSettings)                                    -- applying gps settings
  framework.delay(6)                                      -- to make sure gps fix is older than 5 seconds related to EventTime
  gateway.setHighWaterMark()                              -- to get the newest messages

  device.setIO(1, 0)                                      -- port 1 to low level - that should trigger IgnitionOff
  local timeOfEvent = os.time()
  framework.delay(10)                                     -- wait for the messages to be processed
  receivedMessages = gateway.getReturnMessages()          -- receiving all the messages

  -- filtering received messages to find IdlingEnd message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationEnd))
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
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "terminal incorrectly in the seatbeltViolation state")

end



--- TC checks if DigInp1Hi message is sent when port 1 state changes from low to high
  -- *actions performed:
  -- Configure port 1 as a digital input and set General Purpose as function for digital input line number 1
  -- simulate terminal moving and change state of digital port 1 from low to high; check if DigInp1Hi message
  -- has been sent from terminal and report contains correct values of fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.GeneralPurpose}, -- line number 1 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(1, 1)                                       -- set port 1 to high level - that should trigger DigInp1Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp1Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp1Hi))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- port 1 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.GeneralPurpose}, -- line number 1 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(1, 1)                                       -- set port 1 to high level - that should trigger DigInp1Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(1, 0)                                       -- set port 1 to low level - that should trigger DigInp1Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp1Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp1Lo))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}, -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                    {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp.GeneralPurpose}, -- line number 2 set for General Purpose function
                                                    {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                    {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(2, 1)                                       -- set port 2 to high level - that should trigger DigInp2Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp2Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp2Hi))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}, -- port 2 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp.GeneralPurpose}, -- line number 2 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(2, 1)                                       -- set port 2 to high level - that should trigger DigInp2Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(2, 0)                                       -- set port 2 to low level - that should trigger DigInp2Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp2Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp2Lo))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[3], 3},    -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3}, -- port 3 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp.GeneralPurpose}, -- line number 3 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(3, 1)                                       -- set port 3 to high level - that should trigger DigInp3Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp3Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp3Hi))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[3], 3},     -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3}, -- port 3 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp.GeneralPurpose}, -- line number 3 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(3, 1)                                       -- set port 3 to high level - that should trigger DigInp3Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(3, 0)                                       -- set port 3 to low level - that should trigger DigInp3Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp3Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp3Lo))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp4Hi message sent when port changes state from low to high
function test_DigitalInput_WhenTerminalMovingAndPort4StateChangesFromLowToHigh_DigInp4HiMessageSent()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant==3) then skip("TC related only to IDP 600 and 700s") end

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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[4], 3},     -- port 4 as digital input
                                                {lsfConstants.pins.portEdgeDetect[4], 3}, -- port 4 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[4], avlConstants.funcDigInp.GeneralPurpose}, -- line number 4 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(4, 1)                                       -- set port 4 to high level - that should trigger DigInp4Hi
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp4Hi message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp4Hi))
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
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- DigInp4Lo message sent when port changes state from high to low
function test_DigitalInput_WhenTerminalMovingAndPort4StateChangesFromHighToLow_DigInp4LoMessageSent()

  -- Dual power source feature is specific to IDP 800
  if(hardwareVariant==3) then skip("TC related only to IDP 600s and 700s") end
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

  -- setting the IO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[4], 3},     -- port 4 as digital input
                                                {lsfConstants.pins.portEdgeDetect[4], 3}, -- port 4 detection for both rising and falling edge
                                        }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[4], avlConstants.funcDigInp.GeneralPurpose}, -- line number 4 set for General Purpose function
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},              -- stationarySpeedThld
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},                -- movingDebounceTime

                                             }
                   )
  gps.set(gpsSettings)                                     -- applying gps settings to make terminal moving
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- wait terminal gets moving state and MovingStart message is processed
  gateway.setHighWaterMark()                               -- to get the newest messages
  device.setIO(4, 1)                                       -- set port 4 to high level - that should trigger DigInp4Hi
  framework.delay(3)                                       -- wait until message is processed

  device.setIO(4, 0)                                       -- set port 4 to low level - that should trigger DigInp4Lo
  framework.delay(3)                                       -- wait until message is processed

  receivedMessages = gateway.getReturnMessages()           -- receiving all the messages
  -- flitering received messages to find DigInp4Lo message
  local filteredMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.digitalInp4Lo))
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
  -- * IDP 800 simulated
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local inputVoltageTC = 240      -- tenths of volts, external power voltage value

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  local gpsSettings={
              speed = 0,                      -- terminal in stationary state
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided, no GpsFixAge expected in the report
                     }

  gps.set(gpsSettings)               -- applying gps settings
  framework.delay(2)

  device.setPower(8,0)                   -- external power not present (terminal unplugged from external power source)
  framework.delay(3)

  gateway.setHighWaterMark()         -- to get the newest messages
  -- setting external power source
  device.setPower(9,inputVoltageTC*100)  -- setting external power source input voltage to known value, multiplied by 100 as this is saved in milivolts
  framework.delay(2)
  device.setPower(8,1)             -- external power present (terminal plugged to external power source)
  timeOfEventTC = os.time()

  -- PowerMain message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.powerMain),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "PowerMain message not received")
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "PowerMain",
                  currentTime = timeOfEventTC,
                  inputVoltage = inputVoltageTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - onMainPower true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "terminal not in onMainPower state")

end




--- TC checks if PowerBackup message is sent when virtual line number 13 changes state to 0 (external power source becomes not present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 simulated
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local inputVoltageTC = 180      -- tenths of volts, external power voltage value

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

  -- PowerMain message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.powerBackup),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "PowerBackup message not received")
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "PowerBackup",
                  currentTime = timeOfEventTC,
                  inputVoltage = inputVoltageTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - onMainPower false expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).onMainPower, "onMainPower state is incorrectly true")

end


--- TC checks if IgnitionOn message is sent when virtual line number 13 changes state to 1 (external power source becomes present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with IgnitionOn function
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.IgnitionOn}, -- digital input line 13 associated with IgnitionOn function
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

  -- IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionON),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "IgnitionOn message not received")
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is not true")

end



--- TC checks if IgnitionOff message is sent when virtual line number 13 changes state to 0 (external power source becomes not present) .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with IgnitionOn function
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.IgnitionOn}, -- digital input line 13 associated with IgnitionOn function
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

  -- IgnitionOff message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionOFF),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "IgnitionOff message not received")
  gpsSettings.heading = 361   -- 361 is reported for stationary state

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOff",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is incorrectly true")

end


--- TC checks if terminal enters and leaves SeatbeltViolation state when line number 13 is controls SeatbeltOff function .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with SeatbeltOff function
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end
  local seatbeltDebounceTime = 10       -- seconds

  local movingDebounceTime = 1   -- seconds
  local stationarySpeedThld = 10 -- kmh

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.SeatbeltOff}, -- digital input line 13 associated with SeatbeltOff function
                                                {avlConstants.pins.seatbeltDebounceTime, seatbeltDebounceTime},          -- setting seatbeltDebounceTime
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},              -- moving related
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},            -- moving related
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SeatbeltOff"})

  -- in this TC gpsSettings are configured only to check if these are correctly reported in message
  -- Point#1 GPS Settings
  local gpsSettings={
              speed = 50,                     -- terminal moving
              latitude = 0,                   -- degrees
              longitude = 0,                  -- degrees
              fixType = 3,                    -- valid fix provided
              heading = 90,
                     }

  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(GPS_READ_INTERVAL+movingDebounceTime+3) -- wait until terminal goes to moving state

  -- verification of the state of terminal - Moving state true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "Terminal is not moving as expected")

  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  framework.delay(2)
  gateway.setHighWaterMark()              -- to get the newest messages

  -- setting external power source
  device.setPower(8,1)                     -- external power present (terminal plugged to external power source - line 13 changes state to high)
  local timeOfEventTC = os.time()         -- to get exact timestamp
  framework.delay(seatbeltDebounceTime)    -- wait for period seatbeltDebounceTime to get seatbeltViolationStart message

  -- seatbeltViolationStart message expected
  local message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationStart message not received")
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationStart",
                  currentTime = timeOfEventTC,
                        }

  -- verification of the report fields
  avlHelperFunctions.reportVerification(message, expectedValues)

  -- verification of the state of terminal - SeatbeltViolation true expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "SeatbeltViolation state is not true")

  -- Point#2 GPS Settings
  gpsSettings={
                speed = 51,                     -- terminal moving
                latitude = 2,                   -- degrees
                longitude = 2,                  -- degrees
                fixType = 3,                    -- valid fix provided
                heading = 90,
              }

  gps.set(gpsSettings)                        -- applying gps settings
  framework.delay(3)

  gateway.setHighWaterMark()              -- to get the newest messages
  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  timeOfEventTC = os.time()               -- to get exact timestamp

  -- seatbeltViolationEnd message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.seatbeltViolationEnd),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SeatbeltViolationEnd message not received")
  expectedValues={
                  gps = gpsSettings,
                  messageName = "SeatbeltViolationEnd",
                  currentTime = timeOfEventTC,
                        }
  -- verification of the report fields
  avlHelperFunctions.reportVerification(message, expectedValues)

  -- verification of the state of terminal - SeatbeltViolation false expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SeatbeltViolation, "SeatbeltViolation state is incorrectly true")


end




--- TC checks if IgnitionOn message is sent and Service Meter 0 becomes active according to state of line number 13 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * GPS is good
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with IgnitionOn and SM0 functions
  -- 2. Simulate terminals position in stationary state in Point#1
  -- 3. Simulate external power source not present
  -- 4. Send setServiceMeter (MIN 11) message to set SM0Time and SM0Distance to 0
  -- 5. Simulate external power source present
  -- 6. Receive IgnitionOn message (MIN 4)
  -- 7. Verify messages fields against expected values
  -- 8. Read avlStates (PIN 41) property and check terminals state
  -- 9. Simulate terminals position in Point#2 1 degree (111,12 km) away from Point#1
  -- 10. Send getServiceMeterMessage
  -- 11. Verify content of received ServiceMeter message
  -- 12. Simulate external power source not present
  -- 13. Receive IgnitionOff message (MIN 5)
  -- 14. Verify messages fields against expected values
  -- 15. Read avlStates (PIN 41) property and check terminals state
  -- 16. Simulate terminals position in Point#3 111,12 km away from Point#2
  -- 17. Send getServiceMeterMessage
  -- 18. Verify content of received ServiceMeter message
  --
  -- Results:
  --
  -- 1. Line number 13 associated with IgnitionOn and SM0 functions
  -- 2. Point#1 is terminals simulated position in stationary state
  -- 3. External power source not present (line 13 in low state)
  -- 4. SM0Time and SM0Distance set to 0
  -- 5. Line 13 changes state to 1
  -- 6. IgnitionOn message received (MIN 4)
  -- 7. Message fields contain Point#1 GPS and time information
  -- 8. IgnitionOn is true
  -- 9. Terminal is in Point#2 111,12 km away from Point#1
  -- 10. ServiceMeter message sent from terminal after GetServiceMeter request
  -- 11. SM0Distance is 111 km and SM0Time is 0
  -- 12. External power source not present (line 13 in low state)
  -- 13. IgnitionOff message (MIN 5) received
  -- 14. Message fields contain Point#2 GPS and time information
  -- 15. IgnitionOn is false
  -- 16. Terminal is in Point#3 111,12 km away from Point#2
  -- 17. ServiceMeter message sent from terminal after GetServiceMeter request
  -- 18. SM0Distance is 111 km and SM0Time is 0 (SM0 has been deactivated after reaching Point#2)
 function test_Line13_WhenVirtualLine13IsAssociatedWithIgnitionAndSM0_IgnitionAndSM0AreActivatedAndDeactivatedAccordingToStateOfLine13()

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  local odometerDistanceIncrement = 10  -- meters
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- detection for both rising and falling edge
                                         }
                   )

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.IgnitionAndSM0}, -- digital input line 13 associated with IgnitionOn and SM0 functions
                                                {avlConstants.pins.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  -- Point#1
  local gpsSettings={
              speed = stationarySpeedThld+10,   -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 90,
                     }

  gps.set(gpsSettings)                                     -- applying gps settings
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- waiting until terminal gets moving state in Point#1

  -- setting external power source
  device.setPower(8,0)                    -- external power not present (terminal unplugged to external power source)
  framework.delay(2)

  -- setting SM0Time and SM0Distance to 0
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setServiceMeter}
	message.Fields = {{Name="SM0Time",Value=0},{Name="SM0Distance",Value=0},}
	gateway.submitForwardMessage(message)
  framework.delay(2)


  ------------------------------------------------------------------------------------
  -- external power present - Igniton is on ans SM0 is active
  ------------------------------------------------------------------------------------
  gateway.setHighWaterMark()              -- to get the newest messages
  local timeOfEventTC = os.time()        -- to get correct timestamp
  -- setting external power source
  device.setPower(8,1)                    -- external power present (terminal plugged to external power source and line 13 changes state to 1)

  -- IgnitionOn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionON),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "IgnitionOn message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "IgnitionOn",
                  currentTime = timeOfEventTC,
                        }

  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields
  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is not true")

  -- Point#2 -- 111,12 kilometres away from Point#1
  gpsSettings.heading = 90
  gpsSettings.latitude = 2
  gps.set(gpsSettings)                    -- applying gps settings
  framework.delay(3)

  -- sending getServiceMeter message
  local getServiceMeterMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getServiceMeter}    -- to trigger ServiceMeter event
  gateway.submitForwardMessage(getServiceMeterMessage)

  -- ServiceMeter message is expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.serviceMeter),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "ServiceMeter message not received")
  expectedValues={
                  gps = gpsSettings,
                  messageName = "ServiceMeter",
                  currentTime = os.time(),
                  SM0Time = 0,                             -- zero hours of IgnitionOn is expected (this value has been set to 0 a moment ago)
                  SM0Distance = 111.12                     -- 1 degree of travel is 111.12 kilometers and number iteration
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  ------------------------------------------------------------------------------------
  -- external power not present - Igniton is off ans SM0 is not active
  ------------------------------------------------------------------------------------

  gateway.setHighWaterMark()              -- to get the newest messages
  -- setting external power source
  device.setPower(8,0)             -- external power not present (terminal unplugged to external power source)
  timeOfEventTC = os.time()        -- to get correct timestamp

  -- IgnitionOff message expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.ignitionOFF),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "IgnitionOff message not received")

  -- verification of the state of terminal - IgnitionON true expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "IgnitionOn state is not false as expected")

  -- Terminal moving in Point#3 -- 111,12 kilometres away from Point#2
  local gpsSettings={
              speed = stationarySpeedThld+10,   -- terminal in stationary state
              latitude = 3,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 90,
                     }

  gps.set(gpsSettings)                                     -- applying gps settings
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+3)    -- waiting until terminal gets moving state in Point#3

  gateway.setHighWaterMark()              -- to get the newest messages
  -- sending getServiceMeter message
  local getServiceMeterMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getServiceMeter}    -- to trigger ServiceMeter event
  gateway.submitForwardMessage(getServiceMeterMessage)

  -- ServiceMeter message is expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.serviceMeter),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "ServiceMeter message not received")
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ServiceMeter",
                  currentTime = os.time(),
                  SM0Time = 0,                             -- zero hours of IgnitionOn is expected (this value has been set to 0 a moment ago)
                  SM0Distance = 111.12                     -- no increase in SM0Distance is expected is it has been disabled after travelling to Point#2
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields



end


--- TC checks if Service Meter 1 is activated and deactivated when virtual line number 13 controls SM1 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with SM1 function
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

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.SM1}, -- digital input line 13 associated with SM1 function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SM1Active"})

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active false is expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly true")

  -- setting external power source
  device.setPower(8,1)                -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active true is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly not true")

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM1Active false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM1Active, "SM1Active state is incorrectly true")


end


--- TC checks if Service Meter 2 is activated and deactivated when virtual line number 13 controls SM2 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13]3 (PIN 59) to associate digital input line 13 with SM2 function
  -- 2. Set DigStatesDefBitmap (PIN 46) to make high state of the line be a trigger for SM2Active
  -- 3. Simulate external power source not present
  -- 4. Read avlStates property (PIN 41) and verify if SM2Active bit is not true
  -- 5. Simulate external power source present
  -- 6. Read avlStates property (PIN 41) and verify if SM2Active bit is true
  -- 7. Simulate external power source not present
  -- 8. Read avlStates property (PIN 41) and verify if SM2Active bit is not true
  --
  -- Results:
  --
  -- 1. Line number 13 associated with SM2 function
  -- 2. High state of the line is set to be a trigger for SM2Active
  -- 3. External power source not present - line 13 in low state
  -- 4. SM2Active bit in avlStates property is not true
  -- 5. External power source present - line 13 changes state to high
  -- 6. SM2Active bit in avlStates property is true
  -- 7. External power source not present - line 13 in low state
  -- 8. SM2Active bit in avlStates property is not true
 function test_Line13_WhenVirtualLine13IsAssociatedWithSM2_ServiceMeter2BecomesActiveAndInactiveAccordingToStateOfLine13()

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.SM2}, -- digital input line 13 associated with SM2 function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SM2Active"})

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM2Active false is expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM2Active, "SM2Active state is incorrectly true")

  -- setting external power source
  device.setPower(8,1)                -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- verification of the state of terminal - SM2Active true is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SM2Active, "SM2Active state is incorrectly not true")

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM2Active false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM2Active, "SM2Active state is incorrectly true")


end


--- TC checks if Service Meter 3 is activated and deactivated when virtual line number 13 controls SM3 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with SM3 function
  -- 2. Set DigStatesDefBitmap (PIN 46) to make high state of the line be a trigger for SM3Active
  -- 3. Simulate external power source not present
  -- 4. Read avlStates property (PIN 41) and verify if SM3Active bit is not true
  -- 5. Simulate external power source present
  -- 6. Read avlStates property (PIN 41) and verify if SM3Active bit is true
  -- 7. Simulate external power source not present
  -- 8. Read avlStates property (PIN 41) and verify if SM3Active bit is not true
  --
  -- Results:
  --
  -- 1. Line number 13 associated with SM3 function
  -- 2. High state of the line is set to be a trigger for SM3Active
  -- 3. External power source not present - line 13 in low state
  -- 4. SM3Active bit in avlStates property is not true
  -- 5. External power source present - line 13 changes state to high
  -- 6. SM3Active bit in avlStates property is true
  -- 7. External power source not present - line 13 in low state
  -- 8. SM3Active bit in avlStates property is not true
 function test_Line13_WhenVirtualLine13IsAssociatedWithSM3_ServiceMeter3BecomesActiveAndInactiveAccordingToStateOfLine13()

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.SM3}, -- digital input line 13 associated with SM3 function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SM3Active"})

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM3Active false is expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM3Active, "SM3Active state is incorrectly true")

  -- setting external power source
  device.setPower(8,1)                -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- verification of the state of terminal - SM3Active true is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SM3Active, "SM3Active state is incorrectly not true")

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM3Active false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM3Active, "SM3Active state is incorrectly true")


end


--- TC checks if Service Meter 4 is activated and deactivated when virtual line number 13 controls SM4 .
  -- Initial Conditions:
  --
  -- * Terminal not in LPM
  -- * Air communication not blocked
  -- * IDP 800 simulated
  --
  -- Steps:
  --
  -- 1. Set funcDigInp[13] (PIN 59) to associate digital input line 13 with SM4 function
  -- 2. Set DigStatesDefBitmap (PIN 46) to make high state of the line be a trigger for SM4Active
  -- 3. Simulate external power source not present
  -- 4. Read avlStates property (PIN 41) and verify if SM4Active bit is not true
  -- 5. Simulate external power source present
  -- 6. Read avlStates property (PIN 41) and verify if SM4Active bit is true
  -- 7. Simulate external power source not present
  -- 8. Read avlStates property (PIN 41) and verify if SM4Active bit is not true
  --
  -- Results:
  --
  -- 1. Line number 13 associated with SM4 function
  -- 2. High state of the line is set to be a trigger for SM4Active
  -- 3. External power source not present - line 13 in low state
  -- 4. SM4Active bit in avlStates property is not true
  -- 5. External power source present - line 13 changes state to high
  -- 6. SM4Active bit in avlStates property is true
  -- 7. External power source not present - line 13 in low state
  -- 8. SM4Active bit in avlStates property is not true
 function test_Line13_WhenVirtualLine13IsAssociatedWithSM4_ServiceMeter4BecomesActiveAndInactiveAccordingToStateOfLine13()

  -- line 13 is specific only in IDP 800s
  if(hardwareVariant~=3) then skip("TC related only to IDP 800s") end

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[13], avlConstants.funcDigInp.SM4}, -- digital input line 13 associated with SM4 function
                                             }
                   )
  -- setting digital input bitmap describing when special function inputs are active
  avlHelperFunctions.setDigStatesDefBitmap({"SM4Active"})

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM4Active false is expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM4Active, "SM4Active state is incorrectly true")

  -- setting external power source
  device.setPower(8,1)                -- external power present (terminal plugged to external power source and line 13 changes state to 1)
  framework.delay(2)

  -- verification of the state of terminal - SM4Active true is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).SM4Active, "SM4Active state is incorrectly not true")

  -- setting external power source
  device.setPower(8,0)                 -- external power not present (terminal unplugged to external power source, line 13 in low state)
  framework.delay(2)

  -- verification of the state of terminal - SM4Active false is expected
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).SM4Active, "SM4Active state is incorrectly true")


end



