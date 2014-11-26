-----------
-- GPS test module
-- - contains gps related test cases
-- @module TestGPSModule

module("TestGPSModule", package.seeall)

-- Setup and Teardown


--- Suite setup function ensures that terminal is not in the low power mode .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set lpmTrigger (PIN 31) to 0 (no trigger)
  -- 2. Read avlStatesProperty and check LPM state
  -- 3. Set the continues property (PIN 15) in position service (SIN 20) to value GPS_READ_INTERVAL
  -- 4. Set property geofenceEnabled (PIN 1) in Geofence service (SIN 21) to false
  --
  -- Results:
  --
  -- 1. lpmTrigger set to 0
  -- 2. Terminal not in LPM
  -- 3. Continues property set to GPS_READ_INTERVAL
  -- 4. GeofenceEnabled property set to false
 function suite_setup()


  -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.lpmTrigger, 0},
                                             }
                    )

  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  lsf.setProperties(lsfConstants.sins.position,{
                                                {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                               }
                    )
  framework.delay(2)

  local geofenceEnabled = false        -- to disable geofence feature
  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                               }
                    )
  framework.delay(2)

end

--- Suite teardown function resets AVL agent after running suite.
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Send restartService (MIN 5) message to System (SIN 16) service
  --
  -- Results:
  --
  -- 1. Message sent, AVl agent reset
function suite_teardown()

  -- restarting AVL agent after running module
	local message = {SIN = lsfConstants.sins.system,  MIN = lsfConstants.mins.restartService}
	message.Fields = {{Name="sin",Value=AVL_SIN}}
	gateway.submitForwardMessage(message)

  -- wait until service is up and running again and sends Reset message
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.reset),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "Reset message after reset of AVL not received")


end


--- Setup function put terminal into stationary state .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Run helper function putting terminal into stationary state
  --
  -- Results:
  --
  -- 1. Terminal put in stationary state
function setup()

  avlHelperFunctions.putTerminalIntoStationaryState()


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end

-------------------------
-- Test Cases
-------------------------

--- TC checks if MovingStart message is sent when speed is above stationary threshold for period above moving debounce time .
  -- Initial Conditions:
  --
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set movingDebounceTime (PIN 3) and stationarySpeedThld (PIN 1)
  -- 2. Simulate terminal in Point#1 with speed equal to 0 (stationary)
  -- 3. Change terminals position to Point#2 with speed above stationarySpeedThld (PIN 1)
  -- 4. Wait shorter than stationarySpeedThld (PIN 1) and change terminals position to Point#3
  -- 5. Wait until movingDebounceTime (PIN 1) passes and receive MovingStart message (MIN 6)
  -- 6. Check the content of the received message
  --
  -- Results:
  --
  -- 1. Properties movingDebounceTime and stationarySpeedThld correctly set
  -- 2. Terminal in stationary state in Point#1
  -- 3. Terminal in Point#2 and speed above stationarySpeedThld (PIN 1)
  -- 4. Terminal in Point#3 and speed still above stationarySpeedThld (PIN 1)
  -- 5. MovingStart message sent from terminal after movingDebounceTime (PIN 3)
  -- 6. Report fields contain Point#2 GPS and time information
function test_Moving_WhenSpeedAboveStationarySpeedThldForPeriodAboveMovingDebounceTime_MovingStartMessageSent()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1                            -- seconds
  local STATIONARY_SPEED_THLD = 5                           -- kmh
  local gpsSettings = {}                                    -- table containing gpsSettings used in TC


  -- Point#1 settings
  gpsSettings[1]={
                  speed = 0,                      -- one kmh above threshold
                  heading = 89,                   -- degrees
                  latitude = 0,                   -- degrees
                  longitude = 0                   -- degrees
                 }

  -- Point#2 settings
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                 }

  -- Point#3 settings
  gpsSettings[3]={
                  speed = STATIONARY_SPEED_THLD + 10,  -- 10 kmh above threshold
                  heading = 95,                        -- degrees
                  latitude = 2,                        -- degrees
                  longitude = 2,                       -- degrees
                 }

  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages

  -- terminal in Point#1 - not moving
  gps.set(gpsSettings[1])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local timeOfEvent = os.time()  -- to get the exact timestamp of the moment when the condition was met
  -- terminal in Point#2 - started to move
  gps.set(gpsSettings[2])
  -- wait shorter than movingDebounceTime
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  -- terminal in Point#3 - moved to another position (before MovingStart message was sent)
  gps.set(gpsSettings[3])

  -- wait for period of movingDebounceTime
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.movingStart].Longitude), "MovingStart message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.movingStart].Latitude), "MovingStart message has incorrect latitude value")
  assert_equal("MovingStart", receivedMessages[6].Name, "MovingStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.movingStart].EventTime), 5, "MovingStart message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.movingStart].Speed), "MovingStart message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.movingStart].Heading), "MovingStart message has incorrect heading value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "Terminal not in moving state after sending MovingStart message")

end



--- TC checks if MovingStart message is sent when speed is above stationary threshold for period above moving debounce time and GPS fix age is included .
  -- Initial Conditions:
  --
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS signal is lost
  --
  -- Steps:
  --
  -- 1. Set movingDebounceTime (PIN 3) and stationarySpeedThld (PIN 1)
  -- 2. Simulate terminal in Point#1 with speed equal to 0 (stationary)
  -- 3. Change terminals position to Point#2 with speed above stationarySpeedThld (PIN 1)
  -- 4. Wait shorter than stationarySpeedThld (PIN 1) and change terminals position to Point#3
  -- 5. Simulate GPS signal loss
  -- 6. Wait until movingDebounceTime (PIN 1) passes and receive MovingStart message (MIN 6)
  -- 7. Check the content of the received message
  --
  -- Results:
  --
  -- 1. Properties movingDebounceTime and stationarySpeedThld correctly set
  -- 2. Terminal in stationary state in Point#1
  -- 3. Terminal in Point#2 and speed above stationarySpeedThld (PIN 1)
  -- 4. Terminal in Point#3 and speed still above stationarySpeedThld (PIN 1)
  -- 5. GPS signal is lost
  -- 6. MovingStart message sent from terminal after movingDebounceTime (PIN 3)
  -- 7. Report fields contain Point#2 GPS and time information and GPS fix age is included
function test_Moving_WhenSpeedAboveThldForPeriodAboveThld_MovingStartMessageSentGpsFixAgeReported()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 7       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh

  gpsSettings = {} -- gps settings table to be sent to simulator

  -- Point#1 settings
  gpsSettings[1]={
                  speed = 0,                      -- one kmh above threshold
                  heading = 90,                   -- degrees
                  latitude = 0,                   -- degrees
                  longitude = 0                   -- degrees
                  }

  -- Point#2 settings
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  }

  -- Point#3 settings
  gpsSettings[3]={
                  speed = STATIONARY_SPEED_THLD + 10,  -- one kmh above threshold
                  heading = 95,                        -- degrees
                  latitude = 2,                        -- degrees
                  longitude = 2,                       -- degrees
                 }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark()

  -- terminal in Point#1 - not moving
  gps.set(gpsSettings[1])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  timeOfEventTc = os.time()  -- to get the exact timestamp of the moment when the condition was met
  -- terminal in Point#2 - started to move
  gps.set(gpsSettings[2])
  -- wait shorter than movingDebounceTime
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gps.set({fixType=1})                        -- simulated no fix (gps signal loss)

  -- terminal in Point#3 - moved to another position (before MovingStart message was sent)
  gps.set(gpsSettings[3])

  -- wait longer than movingDebounceTime,
  framework.delay(lsfConstants.coldFixDelay + MOVING_DEBOUNCE_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  assert_equal(47, tonumber(receivedMessages[avlConstants.mins.movingStart].GpsFixAge), 10, "MovingStart message has GpsFixAge longitude value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

end



--- TC checks if MovingEnd message is sent when speed is below stationary threshold for period above stationary debounce time .
  -- Initial Conditions:
  --
  -- * Terminal moving
  -- * Air communication not blocked
  -- * GPS signal is lost
  --
  -- Steps:
  --
  -- 1. Set stationaryDebounceTime (PIN 2) and stationarySpeedThld (PIN 1)
  -- 2. Simulate terminal in moving state in Point#1
  -- 3. Change terminals position to Point#2 with speed below stationarySpeedThld (PIN 1)
  -- 4. Wait shorter than stationaryDebounceTime (PIN 2) and change terminals position to Point#3
  -- 5. Wait until stationaryDebounceTime (PIN 1) passes and receive MovingEnd message (MIN 7)
  -- 6. Check the content of the received message
  --
  -- Results:
  --
  -- 1. Properties stationaryDebounceTime and stationarySpeedThld correctly set
  -- 2. Terminal in moving state state in Point#1
  -- 3. Terminal in Point#2 and speed below stationarySpeedThld (PIN 1)
  -- 4. Terminal in Point#3 and speed still below stationarySpeedThld (PIN 1)
  -- 5. MovingEnd (MIN 7) message sent from terminal after stationaryDebounceTime (PIN 1)
  -- 6. Report fields contain Point#2 GPS and time information
function test_Moving_WhenSpeedBelowThldForPeriodAboveThld_MovingEndMessageSent()

  -- *** Setup

  -- put terminal into moving state
  avlHelperFunctions.putTerminalIntoMovingState()

  local STATIONARY_DEBOUNCE_TIME = 10  -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local gpsSettings = {}               -- gps settings table to be sent to simulator

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                            }
                   )

  -- Point#1 settings
  gpsSettings[1]={
              speed = STATIONARY_SPEED_THLD + 1, -- kmh, above threshold
              heading = 91,                    -- degrees
              latitude = 1,                    -- degrees
              longitude = 1,                   -- degrees
                     }

  -- Point#2 settings
  gpsSettings[2]={
              speed = STATIONARY_SPEED_THLD - 1,  -- kmh, below threshold
              heading = 92,                     -- degrees
              latitude = 2,                     -- degrees
              longitude = 2,                    -- degrees
                     }

  -- Point#3 settings
  gpsSettings[3]={
              speed = STATIONARY_SPEED_THLD - 3 , -- kmh, below threshold
              heading = 93,                     -- degrees
              latitude = 3,                     -- degrees
              longitude = 3,                    -- degrees
                     }

  -- *** Execute
  gateway.setHighWaterMark()                    -- to get the newest messages

  -- apply Poin#2 settings
  gps.set(gpsSettings[1])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)
  -- apply Point#2 settings and wait shorter than stationaryDebounceTime
  timeOfEvent = os.time()       -- condition for MovingEnd event is met
  gps.set(gpsSettings[2])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  -- apply Point#3 settings and wait shorter longer than stationaryDebounceTime
  gps.set(gpsSettings[3])
  framework.delay(STATIONARY_DEBOUNCE_TIME + GPS_READ_INTERVAL)

  local expectedMins = {avlConstants.mins.movingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingStart message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.movingEnd].Longitude), "MovingEnd message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.movingEnd].Latitude), "MovingEnd message has incorrect latitude value")
  assert_equal("MovingEnd", receivedMessages[avlConstants.mins.movingEnd].Name, "MovingEnd message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.movingEnd].EventTime), 5, "MovingEnd message has incorrect EventTime value")
  assert_equal(0, tonumber(receivedMessages[avlConstants.mins.movingEnd].Speed), "MovingEnd message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.movingEnd].Heading), "MovingEnd message has incorrect heading value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "Terminal incorrectly in the moving state")

end



--- TC checks if MovingStart message is not sent when speed is above stationarySpeedThld for time below movingDebounceTime .
  -- Initial Conditions:
  --
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS signal is good
  --
  -- Steps:
  --
  -- 1. Set movingDebounceTime (PIN 3) and stationarySpeedThld (PIN 1)
  -- 2. Simulate speed above stationarySpeedThld and wait shorted than movingDebounceTime
  -- 3. Receive messages sent by terminal and check if there is any MovingStart (MIN 6) message
  -- 4. Read avlStatesProperty and check if terminal is moving
  --
  -- Results:
  --
  -- 1. Properties movingDebounceTime and stationarySpeedThld correctly set
  -- 2. Speed above stationarySpeedThld for period shorted than movingDebounceTime
  -- 3. There is no MovingStart (MIN 6) message in received messages
  -- 4. Terminal not in moving state
 function test_Moving_WhenSpeedAboveThldForPeriodBelowThld_MovingStartMessageNotSent()

  -- *** Setup

  local MOVING_DEBOUNCE_TIME = 14      -- seconds
  local STATIONARY_SPEED_THLD = 10      -- kmh

  -- setting moving related properties in AVL
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                              {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark()                                    -- to get the newest messages

  gps.set({speed = STATIONARY_SPEED_THLD + 10})                 -- speed set to 10 kmh above threshold
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)         -- waiting for time shorter than MOVING_DEBOUNCE_TIME
  gps.set({speed = STATIONARY_SPEED_THLD - 4})                  -- speed set to 4 kmh below threshold

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)   -- short timeout

  assert_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not expected")

  -- check if terminal is not in moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal unexpectedly in the moving state") -- terminal should not be moving

end



--- TC checks if MovingEnd message is not sent when speed is below stationarySpeedThld for time below stationaryDebounceTime .
  -- Initial Conditions:
  --
  -- * Terminal moving
  -- * Air communication not blocked
  -- * GPS signal is good
  --
  -- Steps:
  --
  -- 1. Set stationaryDebounceTime (PIN 2) and stationarySpeedThld (PIN 1)
  -- 2. Run putTerminalIntoMovingState helper function
  -- 3. Simulate speed below stationarySpeedThld and wait shorted than stationaryDebounceTime
  -- 4. Receive messages sent by terminal and check if there is any MovingEnd (MIN 7) message
  -- 5. Read avlStatesProperty and check if terminal is still moving
  --
  -- Results:
  --
  -- 1. Properties stationaryDebounceTime and stationarySpeedThld correctly set
  -- 2. Terminal put into moving state
  -- 3. Speed above stationarySpeedThld for period shorted than movingDebounceTime
  -- 4. There is no MovingStart (MIN 7) message in received messages
  -- 5. Terminal not in moving state
function test_Moving_ForTerminalInMovingStateWhenSpeedBelowThldForPeriodBelowThld_MovingEndMessageNotSent()

  -- *** Setup
  avlHelperFunctions.putTerminalIntoMovingState()

  local STATIONARY_SPEED_THLD = 5      -- kmh
  local STATIONARY_DEBOUNCE_TIME = 14  -- seconds

  -- applying moving related properties of AVL
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME}
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark()                                -- to get the newest messages

  gps.set({speed = STATIONARY_SPEED_THLD - 2})              -- 2 kmh below STATIONARY_SPEED_THLD
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)     -- time shorter than STATIONARY_DEBOUNCE_TIME
  gps.set({speed = STATIONARY_SPEED_THLD + 2})              -- speed back to value above STATIONARY_SPEED_THLD

  local expectedMins = {avlConstants.mins.movingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)   -- short timeout

  assert_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not expected")

  -- checking if terminal is still in moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the stationary state")

end


--- TC checks if MovingStart message is not sent when speed is above stationarySpeedThld for time below movingDebounceTime .
  -- Initial Conditions:
  --
  -- * Terminal stationary
  -- * Air communication not blocked
  -- * GPS signal is good
  --
  -- Steps:
  --
  -- 1. Set movingDebounceTime (PIN 3) and stationarySpeedThld (PIN 1)
  -- 2. Simulate speed above 0 kmh but below stationarySpeedThld and wait longer than movingDebounceTime
  -- 3. Receive all messages sent by terminal
  -- 4. Look for MovingStart (MIN 6) message
  -- 5. Read avlStates property and verify moving state
  -- Results:
  --
  -- 1. Properties movingDebounceTime and stationarySpeedThld correctly set
  -- 2. Speed simulated above 0 kmh but below stationarySpeedThld
  -- 3. Speed above stationarySpeedThld for period shorted than movingDebounceTime
  -- 4. There is no MovingStart (MIN 7) message in received messages
  -- 5. Terminal not in moving state
  function test_Moving_WhenSpeedBelowStationarySpeedThldForPeriodAboveMovingDebounceTime_MovingStartMessageNotSent()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 10      -- kmh

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME}
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark()                                                   -- to get the newest messages
  gps.set({speed = STATIONARY_SPEED_THLD - 5})                                 -- speed set above 0 but 5 kmh below threshold

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME) -- wait for time longer than MOVING_DEBOUNCE_TIME period

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)

  assert_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not expected")

  -- check the state of the terminal
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state") -- terminal should not be moving

end



--- TC checks if MovingEnd message is not sent when terminal is moving and speed is above stationarySpeedThld for time above stationaryDebounceTime .
  -- Initial Conditions:
  --
  -- * Terminal moving
  -- * Air communication not blocked
  -- * GPS signal is good
  --
  -- Steps:
  --
  -- 1. Set stationaryDebounceTime (PIN 2), stationarySpeedThld (PIN 1) and movingDebounceTime (PIN 3)
  -- 2. Simulate speed above stationarySpeedThld for period longer than movingDebounceTime
  -- 3. Reduce simulated speed to value above stationarySpeedThld and wait longer than stationaryDebounceTime
  -- 4. Receive messages sent by terminal and check if there is any MovingEnd (MIN 7) message
  -- 5. Read avlStatesProperty and check if terminal is still moving
  --
  -- Results:
  --
  -- 1. Properties stationaryDebounceTime, stationarySpeedThld and movingDebounceTime correctly set
  -- 2. Terminal enters moving state
  -- 3. Speed reduced to level above stationarySpeedThld for period longer than stationaryDebounceTime
  -- 4. There is no MovingEnd (MIN 7) message in received messages
  -- 5. Terminal is still in moving state
function test_Moving_WhenSpeedAboveStationarySpeedThldForPeriodAboveStationaryDebounceTime_MovingEndMessageNotSent()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1   -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh

  --applying moving related properties of AVL
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                             {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME}
                            }
                   )


  gateway.setHighWaterMark()
  gps.set({speed = STATIONARY_SPEED_THLD + 10})     -- 10 kmh above threshold, terminal enters moving state

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message received")

  -- *** Execute
  gateway.setHighWaterMark()                                  -- to get the newest messages
  gps.set({speed = STATIONARY_SPEED_THLD + 1})                --  speed reduced to 1 kmh above threshold
  framework.delay(STATIONARY_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)

  assert_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not expected")

  -- checking if terminal is still in moving state
  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the stationary state")

end


--- TC checks if SpeedingStart message is correctly sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to one kmh
  -- above the defaultSpeedLimit for time longer than speedingTimeOver and check if SpeedingStart message is
  -- correctly sent; verify if fields of report have correct values and terminal is put into the speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal correctly put in the speeding state, SpeedingStart message sent and report fields
  -- have correct values
function test_Speeding_WhenSpeedAboveThldForPeriodAboveThld_SpeedingStartMessageSent()

  -- *** Setup
  local DEFAULT_SPEED_LIMIT = 80       -- kmh
  local SPEEDING_TIME_OVER = 8         -- seconds
  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local gpsSettings = {}

  -- applying moving and speeding related properties of AVl
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                            }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above moving threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  -- Point#2 - terminal starts speeding
  gpsSettings[2]={
                      speed = DEFAULT_SPEED_LIMIT + 1,     -- one kmh above speeding threshold
                      heading = 91,                       -- degrees
                      latitude = 2,                       -- degrees
                      longitude = 2,                      -- degrees
                     }

  -- Point#3 - terminal moving
  gpsSettings[3]={
                      speed = DEFAULT_SPEED_LIMIT + 1,     -- one kmh above speeding threshold
                      heading = 92,                       -- degrees
                      latitude = 3,                       -- degrees
                      longitude = 3,                      -- degrees
                     }


  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[1])
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- *** Execute
  gateway.setHighWaterMark()                             -- to get the newest messages
  timeOfEvent = os.time()                                -- to get e
  gps.set(gpsSettings[2])                                -- terminal exceeds speed limit in Point#2
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- wait until GPS position is read

  gps.set(gpsSettings[3])                                                     -- terminal moving to Point#3 still exceeding speed
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- wait until GPS position is read

  expectedMins = {avlConstants.mins.speedingStart}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.speedingStart].Longitude), "SpeedingStart message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.speedingStart].Latitude), "SpeedingStart message has incorrect latitude value")
  assert_equal("SpeedingStart", receivedMessages[avlConstants.mins.speedingStart].Name, "SpeedingStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.speedingStart].EventTime), 5, "SpeedingStart message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.speedingStart].Speed), "SpeedingStart message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.speedingStart].Heading), "SpeedingStart message has incorrect heading value")
  assert_equal(DEFAULT_SPEED_LIMIT, tonumber(receivedMessages[avlConstants.mins.speedingStart].SpeedLimit), "SpeedingStart message has incorrect speed limit value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

end



--- TC checks if SpeedingEnd message is correctly sent when speed is below defaultSpeedLimit for period above SpeedingTimeUnder
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeUnder to 3 seconds
  -- increase speed above stationarySpeedThld and wait longer than movingDebounceTime and then check if terminal goes into moving state;
  -- then increase speed to 10 kmh above the defaultSpeedLimit for time longer than speedingTimeOver to get the Speeding state;
  -- after that reduce speed one kmh under defaultSpeedLimit for time longer than speedingTimeUnder and check if SpeedingEnd
  -- message has been correctly sent, verify if fields of report have correct values and terminal is put into the non-speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal correctly put out of the speeding state, SpeedingEnd message sent and report fields
  -- have correct values
function test_Speeding_WhenSpeedBelowSpeedingThldForPeriodAboveThld_SpeedingEndMessageSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 3        -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark()                            -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit-1               -- one kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder+GPS_READ_INTERVAL)    -- wait until terminal stops speeding

  -- SpeedingEnd Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingEnd),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "MovingEnd message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingEnd",
                  currentTime = os.time(),
                  maximumSpeed = maxSpeedTC
                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end


--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period below speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 5 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- shorter than speedingTimeOver and check if SpeedingStart message is not sent and terminal does not goes to
  -- speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message sent not
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodBelowThld_SpeedingStartMessageNotSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 15        -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit+10            -- 10 kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(GPS_READ_INTERVAL+3)                  -- wait for 3 seconds + GPS_READ_INTERVAL (that together is shorter than speedingTimeOver)

  gpsSettings.speed = defaultSpeedLimit-10            -- 10 kmh below the speed limit threshold
  gps.set(gpsSettings)

  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end



--- TC checks if SpeedingEnd message is not sent when speed is below defaultSpeedLimit for period below speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if terminal goes to the speeding state;
  -- after that reduce speed below defaultSpeedLimit but for time shorter than speedingTimeUnder and check if SpeedingEnd message has not been
  -- sent and terminal is still in SpeedingState
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal correctly does not loeave the speeding state, SpeedingEnd message not sent
function test_Speeding_WhenSpeedBelowSpeedingThldForPeriodBelowThld_SpeedingEndMessageNotSent()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 10       -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark() -- to get the newest messages
  -- following section simulates speed reduced under the speed limit for short time
  gpsSettings.speed = defaultSpeedLimit-1   -- one kmh below the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder-1)      -- wait shorter than SpeedingTimeUnder
  gpsSettings.speed = defaultSpeedLimit+10  -- back to the speed above the Speeding threshold
  gps.set(gpsSettings)

  -- SpeedingEnd Message not expected
  local receivedMessages = gateway.getReturnMessages()    -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for SpeedingEnd message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingEnd))
  assert_false(next(matchingMessages), "SpeedingEnd report not expected")   -- checking if any SpeedingEnd message has been caught

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly not in the speeding state")


end



--- TC checks if SpeedingStart message is correctly sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 7 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time longer than
  -- speedingTimeOver (meanwhile change fixType to 'no fix') and check if SpeedingStart message is
  -- correctly sent; verify if fields of report have correct values and terminal is put into the speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal correctly put in the speeding state, SpeedingStart message sent and report fields (with GpsFixAge)
  -- have correct values
function test_Speeding_WhenSpeedAboveThldForPeriodAboveThld_SpeedingStartMessageSentGpsFixAgeReported()

  local defaultSpeedLimit = 80       -- kmh
  local speedingTimeOver = 7         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent


  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark() -- to get the newest messages

  gpsSettings.speed = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold
  gps.set(gpsSettings)

  framework.delay(2)                                  -- to make sure gps has been read
  gps.set({fixType=1})                                -- simulated no fix (gps signal loss)

  -- SpeedingStart Message expected
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "SpeedingStart message not received")


  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = os.time()-20,
                  speedLimit = defaultSpeedLimit,
                  GpsFixAge = 6

                        }

  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

end


--- TC checks if SpeedingEnd message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 100 kmh and speedingTimeOver to 3 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 10 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if terminal goes to the speeding state;
  -- after that reduce speed to 1 kmh above defaultSpeedLimit for time longer than speedingTimeUnder and check if SpeedingEnd
  -- message has not been sent and terminal is still in SpeedingState
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal does not leave the speeding state, SpeedingEnd message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThld_SpeedingEndMessageNotSent()

  local defaultSpeedLimit = 100      -- kmh
  local speedingTimeOver = 3         -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeUnder = 2        -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  local maxSpeedTC = defaultSpeedLimit+10  -- 10 kmh above the speed limit threshold, maximum speed of terminal in the test case
  gpsSettings.speed = maxSpeedTC
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gateway.setHighWaterMark() -- to get the newest messages
  -- following section simulates speed reduction but (still above the speed limit) for time longer than SpeedingTimeUnder
  gpsSettings.speed = defaultSpeedLimit+1   -- one kmh above the speed limit threshold
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder+GPS_READ_INTERVAL+1)      -- wait longer than SpeedingTimeUnder

  -- SpeedingEnd Message not expected
  local receivedMessages = gateway.getReturnMessages()    -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for MovingEnd message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingEnd))
  assert_false(next(matchingMessages), "SpeedingEnd report not expected")   -- checking if any SpeedingEnd message has been caught

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly not in the speeding state")

end


--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- for setting DefaultSpeedLimit = 0 (speeding feature disabled)
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 80 kmh and speedingTimeOver to 5 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than movingDebounceTime
  -- and check if terminal gets moving state; then increase speed to 150 kmh above the defaultSpeedLimit for time
  -- longer than speedingTimeOver and check if SpeedingStart message is not sent and terminal does not goes to
  -- speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThldForSpeedingFeatureDisabled_SpeedingStartMessageNotSent()

  local defaultSpeedLimit = 0        -- kmh, for value of 0 the speeding feature should be disabled
  local speedingTimeOver = 2         -- seconds
  local movingDebounceTime = 1        -- seconds
  local stationarySpeedThld = 2      -- kmh

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 3, -- stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                             }
                   )


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+5) -- one second is added to make sure the gps is read and processed by agent


  gateway.setHighWaterMark() -- to get the newest messages


  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end


--- TC checks if SpeedingStart message is not sent when speed is above defaultSpeedLimit for period above speedingTimeOver
  -- for terminal which is not in the moving stare (SpeedingStart cannot be sent before MovingStart)
  -- *actions performed:
  -- set movingDebounceTime to 20 seconds,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 5 kmh and speedingTimeOver to 1 seconds
  -- set gps speed above stationarySpeedThld wait for time longer than speedingTimeOver but shorter than movingDebounceTime
  -- and check if terminal gets speeding state;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal not put in the speeding state, SpeedingStart message not sent
function test_Speeding_WhenSpeedAboveSpeedingThldForPeriodAboveThldTerminalNotInMovingState_SpeedingMessageNotSent()

  local defaultSpeedLimit = 5        -- kmh, for value of 0 the speeding feature should be disabled
  local speedingTimeOver = 1         -- seconds
  local movingDebounceTime = 20      -- seconds
  local stationarySpeedThld = 5      -- kmh


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = defaultSpeedLimit+1,    -- that is above stationary and speeding thresholds
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+GPS_READ_INTERVAL) -- that is longer than speedingTimeOver but shorter than movingDebounceTime

  -- checking if terminal is not in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")


  -- SpeedingStart Message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingStart message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingStart))
  assert_false(next(matchingMessages), "SpeedingStart report not expected")   -- checking if any SpeedingStart message has been caught

  --checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end


--- TC checks if SpeedingEnd message is sent when terminal goes to stationary state (speed = 0)
  -- even if speedingTimeUnder has not passed
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, defaultSpeedLimit to 50 kmh and speedingTimeOver to 1 second
  -- set gps speed above defaultSpeedLimit and wait for time longer than speedingTimeOver to get the speeding state;
  -- then simulate terminal stop (speed = 0) and check if MovingEnd and SpeedingEnd is sent before speedingTimeUnder passes
  -- and verify if terminal is no longer in moving and speeding state
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal put in the speeding state false, SpeedingEnd message sent
function test_Speeding_WhenTerminalStopsWhileSpeedingStateTrue_SpeedingEndMessageSentBeforeMovingEnd()

  local defaultSpeedLimit = 50       -- kmh
  local stationarySpeedThld = 5      -- kmh
  local speedingTimeOver = 1         -- seconds
  local speedingTimeUnder = 20       -- seconds
  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = defaultSpeedLimit+1,    -- that is above stationary and speeding thresholds
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},

                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+GPS_READ_INTERVAL+2) -- that is longer than speedingTimeOver and longer than movingDebounceTime


  --checking the state of terminal, speeding state is  ecpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  gpsSettings.speed = 0   -- terminal suddenly stops
  gps.set(gpsSettings)
  framework.delay(stationaryDebounceTime+GPS_READ_INTERVAL+5)


  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for MovingEnd and SpeedingEnd messages
  local movingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.movingEnd))
  local speedingEndMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.speedingEnd))

  -- checking if expected messages has been received
  assert_not_nil(next(movingEndMessage), "MovingEnd message not received")              -- if MovingEnd message not received assertion fails
  assert_not_nil(next(speedingEndMessage), "SpeedingEnd message not received")          -- if SpeedingEnd message not received assertion fails

  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(speedingEndMessage[1].Payload.EventTime, movingEndMessage[1].Payload.EventTime, 0, "Timestamps of SpeedingEnd and MovingEnd messages expected to be equal")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of SpeedingEnd and MovingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: SpeedingEnd ReceiveUTC = "2014-09-03 07:56:37" and MovingEned MessageUTC = "2014-09-03 07:56:42" - that is correct

  -- checking the state of terminal, speeding state is not ecpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")
  -- checking the state of terminal, moving state is not ecpected
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

end



--- TC checks if Turn message is sent when heading difference is above TurnThreshold and is maintained above TurnDebounceTime .
  -- Initial Conditions:
  --
  -- * Terminal moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set TurnThreshold (PIN 16) to value above 0 to enable sending Turn messages and TurnDebounceTime (PIN 17) to value in range 1 to 63
  -- 2. Put terminal in moving state in Point#1
  -- 3. Change position to Point#2 and ensure change in heading is above TurnThreshold (PIN 16)
  -- 4. Wait shorter than TurnDebounceTime (PIN 17) and change terminals position to Point#3
  -- 5. Wait until TurnDebounceTime (PIN 17) passes and receive Turn message (MIN 14)
  -- 6. Check the content of the received message
  --
  -- Results:
  --
  -- 1. TurnThreshold set above 0 and TurnDebounceTime set in range 1 to 63
  -- 2. Terminal in moving state in Point#1 with initial heading
  -- 3. Terminal in Point#2 and heading changed above TurnThreshold (PIN 16)
  -- 4. Terminal in Point#3 and heading changed still above TurnThreshold (PIN 16)
  -- 5. Turn message sent from terminal after TurnDebounceTime (PIN 17)
  -- 6. Report fields contain Point#2 GPS and time information
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- degrees
  local turnDebounceTime = 10         -- seconds
  local gpsSettings = {}

  -- Point#1 gps settings
  gpsSettings[1]={
                  speed = stationarySpeedThld+1,  -- kmh
                  heading = 90,                   -- degrees
                  latitude = 1,                   -- degrees
                  longitude = 1                   -- degrees
                 }

  -- Point#2 gps settings
  gpsSettings[2]={
                  speed = stationarySpeedThld+10,                         -- kmh
                  heading = gpsSettings[1].heading + turnThreshold + 1,   -- degrees, 1 degree above turnThreshold
                  latitude = 2,                                           -- degrees
                  longitude = 2,                                          -- degrees
                 }

  -- Point#3 gps settings
  gpsSettings[3]={
                  speed = stationarySpeedThld+14,                  -- kmh
                  heading = gpsSettings[2].heading,                -- degrees
                  latitude = 3,                                    -- degrees
                  longitude = 3,                                   -- degrees
                 }


  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.turnThreshold, turnThreshold},
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},
                                             }
                   )

  gps.set(gpsSettings[1])                               -- applying gps settings for Point#1
  -- waiting until turnDebounceTime passes - that is terminal had some different heading before
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL+5)

  -- checking if terminal is in moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  timeOfEventTc = os.time()  -- to get exact timestamp
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[2])    -- applying gps settings of Point#2

  -- waiting shorter than turnDebounceTime and changing position to another point (terminal is moving)
  framework.delay(GPS_READ_INTERVAL+2)

  gps.set(gpsSettings[3])    -- applying gps settings of Point#3

  -- waiting until turnDebounceTime passes
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL)

  -- Turn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.turn),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "Turn message not received")

  -- content of the report should contain Point#2 gps and time information
  local expectedValues={
                  gps = gpsSettings[2],
                  messageName = "Turn",
                  currentTime = timeOfEventTc
                  }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings[1].heading = 90     -- terminal put back to initial heading
  gps.set(gpsSettings[1])         -- applying gps settings



end



--- TC checks if Turn message is not sent when heading difference is above TurnThreshold and is maintained below TurnDebounceTimes
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 10 seconds
  -- set heading to 90 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 110 (20 degrees above threshold) and wait shorter than turnDebounceTime
  -- check if Turn message has not been sent;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- Turn message not sent
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsBelowTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 10         -- (feature disabled) in seconds


  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.turnThreshold, turnThreshold},
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},
                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},

                                             }
                   )


  gateway.setHighWaterMark() -- to get the newest messages
  gpsSettings.heading = 110                             -- change in heading above turnThreshold
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(GPS_READ_INTERVAL+2)                    -- waiting shorter than turnDebounceTime
  gpsSettings.heading = 90                              -- back to heading before change
  gps.set(gpsSettings)                                  -- applying gps settings

  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

end


--- TC checks if Turn message is not sent when heading difference is below TurnThreshold and is maintained above TurnDebounceTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 2 seconds
  -- set heading to 10 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 15 (1 degree below threshold) and wait longer than turnDebounceTime
  -- check if Turn message has not been sent; after that set heading of the terminal back to 90
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- Turn message not sent
function test_Turn_WhenHeadingChangeIsBelowTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- in degrees
  local turnDebounceTime = 2         -- in seconds


  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.turnThreshold, turnThreshold},
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  framework.delay(3) -- to make sure not to receive previous report (generated after movingStart Message)

  gateway.setHighWaterMark()                            -- to get the newest messages
  gpsSettings.heading = 99                              -- change in heading below turnThreshold
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL+2)   -- waiting longer than turnDebounceTime


  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings.heading = 90                              -- terminal put back to initial heading
  gps.set(gpsSettings)                                  -- applying gps settings

end


--- TC checks if Turn message is not sent when feature is disabled (turnThreshold = 0)
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 0 degrees and turnDebounceTime to 2 seconds
  -- set heading to 90 degrees and speed to one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 120 (30 degrees change) and wait longer than turnDebounceTime
  -- check if Turn message has not been sent; after that set heading of the terminal back to 90
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- Turn message not sent
function test_Turn_ForTurnFeatureDisabledWhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 0            -- 0 is for feature disabled, no Turn message should be sent, in degrees
  local turnDebounceTime = 2         -- in seconds


  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.turnThreshold, turnThreshold},
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},

                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }


  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1) -- one second is added to make sure the gps is read and processed by agent

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark()                            -- to get the newest messages
  gpsSettings.heading = 120                             -- change in heading of terminal
  gps.set(gpsSettings)                                  -- applying gps settings
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL+2)   -- waiting longer than turnDebounceTime

  -- Turn message is not expected
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- look for Turn message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.turn))
  assert_false(next(matchingMessages), "Turn report not expected")    -- assertion fails if any Turn message has been received

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings.heading = 90                              -- terminal put back to initial heading
  gps.set(gpsSettings)                                  -- applying gps settings

end


--- TC checks if Turn message is correctly sent when heading difference is above TurnThreshold and is maintained above TurnDebounceTime
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh, turnThreshold to 10 degrees and turnDebounceTime to 2 seconds
  -- set heading to 90 degrees and speed one kmh above threshold and wait for time longer than movingDebounceTime;
  -- check if terminal is the moving state; then change heading to 102 (2 degrees above threshold) and wait longer than turnDebounceTime
  -- meanwhile change fixType to 1 (no fix provided) to make the GpsFixAge higher than 5
  -- check if Turn message has been correctly sent and verify field of the report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- Turn message sent and report fields have correct values
function test_Turn_WhenHeadingChangeIsAboveTurnThldAndLastsAboveTurnDebounceTimePeriod_TurnMessageSentGpsFixAgeReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local turnThreshold = 10           -- degrees
  local turnDebounceTime = 10         -- seconds
  local gpsSettings = {}

  -- Point#1 gps settings
  gpsSettings[1]={
                  speed = stationarySpeedThld+1,  -- kmh
                  heading = 90,                   -- degrees
                  latitude = 1,                   -- degrees
                  longitude = 1                   -- degrees
                 }

  -- Point#2 gps settings
  gpsSettings[2]={
                  speed = stationarySpeedThld+10,                         -- kmh
                  heading = gpsSettings[1].heading + turnThreshold + 1,   -- degrees, 1 degree above turnThreshold
                  latitude = 2,                                           -- degrees
                  longitude = 2,                                          -- degrees
                 }

  -- Point#3 gps settings
  gpsSettings[3]={
                  speed = stationarySpeedThld+14,                  -- kmh
                  heading = gpsSettings[2].heading,                -- degrees
                  latitude = 3,                                    -- degrees
                  longitude = 3,                                   -- degrees
                  fixType = 3,                                     -- valid fix
                 }


  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.turnThreshold, turnThreshold},
                                                {avlConstants.pins.turnDebounceTime, turnDebounceTime},
                                             }
                   )

  gps.set(gpsSettings[1])                               -- applying gps settings for Point#1
  -- waiting until turnDebounceTime passes - that is terminal had some different heading before
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL+5)

  -- checking if terminal is in moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  timeOfEventTc = os.time()  -- to get exact timestamp
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[2])    -- applying gps settings of Point#2

  -- waiting shorter than turnDebounceTime and changing position to another point (terminal is moving)
  framework.delay(GPS_READ_INTERVAL+2)

  gps.set(gpsSettings[3])    -- applying gps settings of Point#3
  framework.delay(GPS_READ_INTERVAL)
  gpsSettings[3].fixType = 1 -- no valid fix provided
  gps.set(gpsSettings[3])    -- applying gps settings of Point#3 with signal loss

  -- waiting until turnDebounceTime passes
  framework.delay(turnDebounceTime+GPS_READ_INTERVAL)

  -- Turn message expected
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.turn),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "Turn message not received")

  -- content of the report should contain Point#2 gps and time information
  local expectedValues={
                  gps = gpsSettings[2],
                  messageName = "Turn",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 9,
                  }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- in the end of the TC heading should be set back to 90 not to interrupt other TCs
  gpsSettings[1].heading = 90     -- terminal put back to initial heading
  gps.set(gpsSettings[1])         -- applying gps settings


end



--- TC checks if LongDriving message is sent when terminal is moving without break for time longer than maxDrivingTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state and after time of maxDrivingTime and check if LongDriving
  -- message is sent and report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit, report fields have correct values
function test_LongDriving_WhenTerminalMovingWithoutBreakForPeriodLongerThanMaxDrivingTime_LongDrivingMessageSent()

  local movingDebounceTime = 1        -- seconds
  local stationaryDebounceTime = 1    -- seconds
  local stationarySpeedThld = 5       -- kmh
  local maxDrivingTime = 1            -- minutes
  local minRestTime = 1               -- minutes
  local longDrivingCheckInterval = 60 -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                                {avlConstants.pins.minRestTime, minRestTime}
                                             }
                   )
    -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
                                       -- to get the correct value in the report

  gateway.setHighWaterMark()                 -- to get the newest messages
  -- waiting until maxDrivingTime limit passes
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval)       -- maxDrivingTime multiplied by 60 to get seconds from minutes
  eventTimeTc = os.time() - 30

  -- LongDriving message expected
  message = gateway.getReturnMessage(framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "LongDriving message not received")


  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTimeLongDriving = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(message,expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end


--- TC checks if LongDriving message is sent when terminal is moving longer than maxDrivingTime and breakes together are shorter than
  -- minRestTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving and wait until LongDriving message is sent; check if report fields
  -- have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with break shorter than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithBreakesShorterThanMinRestTime_LongDrivingMessageSent()

  local movingDebounceTime = 1        -- seconds
  local stationaryDebounceTime = 1    -- seconds
  local stationarySpeedThld = 5       -- kmh
  local maxDrivingTime = 3            -- minutes
  local minRestTime = 5               -- minutes
  local longDrivingCheckInterval = 60 -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                                {avlConstants.pins.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving
  framework.delay(maxDrivingTime*60-100)   -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60-200)           -- wait shorter than minRestTime

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- terminal moving again
  gateway.setHighWaterMark()                  -- to get the newest messages
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60 - 70 + longDrivingCheckInterval)      -- wait for 110 seconds + longDrivingCheckInterval

  eventTimeTc = os.time() - 30                 -- to get the correct value in the report

  -- LongDriving Message is expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving))
  assert_true(next(matchingMessages), "LongDriving report not received")   -- checking if LongDriving message has been caught

  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTimeLongDriving = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1],expectedValues)  -- verification of the report fields

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end


--- TC checks if LongDriving message is not sent when terminal is moving longer than maxDrivingTime but breakes together are longer than
  -- minRestTime
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving and wait until LongDriving message is sent; check if report fields
  -- have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with break shorter than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithBreakLongerThanMinRestTime_LongDrivingMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationaryDebounceTime = 1   -- seconds
  local stationarySpeedThld = 3      -- kmh
  local maxDrivingTime = 5           -- minutes
  local minRestTime = 1              -- minutes


  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                                {avlConstants.pins.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving
  framework.delay(maxDrivingTime*60-200)       -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- gps settings table to be sent to simulator to make terminal stationary
  local gpsSettings={
              speed = 0,                      -- break in driving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  gps.set(gpsSettings)                                        -- gps settings applied
  framework.delay(stationaryDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60+15)                          -- wait longer than minRestTime (multiplied by 60 to get minutes from seconds)

  -- terminal moving again
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- terminal moving again
  gateway.setHighWaterMark()                  -- to get the newest messages
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60-200)   -- maxDrivingTime multiplied by 60 to get seconds from minutes

  -- LongDriving Message is not expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving))
  assert_false(next(matchingMessages), "LongDriving report not expected")   -- checking if any LongDriving message has been caught

  local maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end



--- TC checks if LongDriving message is sent when terminal is moving without break for time longer than maxDrivingTime and maxDrivingTime timer
  -- is reseted after report is generated
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 1 minute and minRestTime to 1 minute
  -- then wait for time longer than movingDebounceTime to get the moving state and after time of maxDrivingTime and check if LongDriving
  -- message is sent and report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit, report fields have correct values
function test_LongDriving_WhenTerminalMovingWithoutBreakForPeriodLongerThanMaxDrivingTime_LongDrivingMessageSentMaxDrivingTimeReset()

  local movingDebounceTime = 1        -- seconds
  local stationaryDebounceTime = 1    -- seconds
  local stationarySpeedThld = 5       -- kmh
  local maxDrivingTime = 1            -- minutes
  local minRestTime = 1               -- minutes
  local longDrivingCheckInterval = 60 -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                                {avlConstants.pins.minRestTime, minRestTime}
                                             }
                   )
    -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- first terminal is put into moving state
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gateway.setHighWaterMark()                 -- to get the newest messages
  -- waiting until maxDrivingTime limit passes
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval+10)       -- maxDrivingTime multiplied by 60 to get seconds from minutes
  local eventTimeTc = os.time()              -- to get the correct value in the report

  -- LongDriving Message is expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving))
  assert_true(next(matchingMessages), "First LongDriving report not received")   -- checking if LongDriving message has been caught

  gateway.setHighWaterMark()                                         -- to get the newest messages
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval+8)      -- to generate second LongDriving event, (maxDrivingTime multiplied by 60 to get seconds from minutes)
  local eventTimeTc = os.time()                                      -- to get the correct value in the report

  -- LongDriving Message is expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving))
  assert_true(next(matchingMessages), "Second LongDriving report not received")   -- checking if LongDriving message has been caught

  local expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTimeLongDriving = eventTimeTc,
                    totalDrivingTime = maxDrivingTime                        -- in minutes, totalDrivingTime is expected to be maxDrivingTime again (timer reseted)
                        }

  avlHelperFunctions.reportVerification(matchingMessages[1],expectedValues)  -- verification of the report fields

  maxDrivingTime = 0                                       -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end



--- TC checks if LongDriving message is sent when terminal is moving longer than maxDrivingTime and breakes together are longer than
  -- minRestTime but are not continues
  -- *actions performed:
  -- set movingDebounceTime to 1 second,  stationarySpeedThld to 5 kmh, maxDrivingTime to 3 minutes and minRestTime to 3 minutes
  -- then wait for time longer than movingDebounceTime to get the moving state; wait shorter than maxDrivingTime and put terminal to stationary state
  -- for time shorter than minRestTime; then again simulate terminal moving for time shorter than maxDrivingTime and stop for time shorter than minRestTime
  -- finally simulate driving for time shorter maxDrivingTime (together driving time is longer than maxDrivingTime) and wait until LongDriving message is sent;
  -- check if report fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LongDriving message sent after exceeeding maxDrivingTime limit with discontinous breakes longer than minRestTime, report fields have correct values
function test_LongDriving_WhenTerminalMovingLongerThanMaxDrivingTimeWithDiscontinuousBreakesLongerThanMinRestTime_LongDrivingMessageSent()

  local movingDebounceTime = 1        -- seconds
  local stationaryDebounceTime = 1    -- seconds
  local stationarySpeedThld = 5       -- kmh
  local maxDrivingTime = 3            -- minutes
  local minRestTime = 2               -- minutes
  local longDrivingCheckInterval = 60 -- seconds



  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryDebounceTime, stationaryDebounceTime},
                                                {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                                {avlConstants.pins.minRestTime, minRestTime}
                                             }
                   )
  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold, to get moving state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- terminal starts driving
  gps.set(gpsSettings)                                    -- gps settings applied
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent

  --checking if terminal is in the moving state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")
  -- terminal moving - LongDriving counter starts
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval-120)  -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)

  -- terminal stops
  gps.set({speed=0})                                          -- gps settings applied
  framework.delay(stationaryDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving) for short time
  framework.delay(minRestTime*60+longDrivingCheckInterval-100)  -- wait shorter than minRestTime

  -- terminal drives
  gps.set({speed=stationarySpeedThld+1})
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  -- checking if terminal is in the moving state
  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval-100)       -- maxDrivingTime multiplied by 60 to get seconds from minutes

  -- terminal stops
  gps.set({speed=0})
  framework.delay(stationaryDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is not the moving state
  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the stationary state")
  -- terminal stationary (break in driving)
  framework.delay(minRestTime*60+longDrivingCheckInterval-100)                          -- wait shorter than minRestTime

  -- terminal moving again
  gps.set({speed=stationarySpeedThld+1})
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+1)   -- one second is added to make sure the gps is read and processed by agent
  --checking if terminal is in the moving state
  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  eventTimeTc = os.time()                 -- to get the correct value in the report
  -- terminal moving again
  gateway.setHighWaterMark()
  -- waiting shorter than maxDrivingTime
  framework.delay(maxDrivingTime*60+longDrivingCheckInterval-30)       -- maxDrivingTime multiplied by 60 to get seconds from minutes

  -- LongDriving Message is expected
  local receivedMessages = gateway.getReturnMessages()   -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for LongDriving message
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.longDriving))
  assert_true(next(matchingMessages), "LongDriving report not received")   -- checking if LongDriving message has been caught

  expectedValues={
                    gps = gpsSettings,
                    messageName = "LongDriving",
                    currentTimeLongDriving = eventTimeTc,
                    totalDrivingTime = maxDrivingTime            -- in minutes, maxDrivingTime is expected
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1],expectedValues)  -- verification of the report fields

  maxDrivingTime = 0                                      -- in minutes, 0 not to get more LongDriving reports

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                              {avlConstants.pins.maxDrivingTime, maxDrivingTime},
                                             }
                   )


end



--- TC checks if DiagnosticsInfo message is sent when requested and fields of the report have correct values
  -- *actions performed:
  -- for terminal in stationary state set send getDiagnosticsInfo message and check if DiagnosticsInfo message is sent after that
  -- verify all the fields of report
  -- *initial conditions:
  -- IMPORTANT: IDP 800 series terminal should be used in this TC (checking battery voltage value in the report)
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  DiagnosticsInfo message sent after request and fields of the reports have correct values
function test_DiagnosticsInfo_WhenTerminalInStationaryStateAndGetDiagnosticsInfoRequestSent_DiagnosticsInfoMessageSent()

  local extVoltage = 15000     -- milivolts
  local battVoltage = 24000    -- milivolts

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- terminal stationary
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(3)   --- wait until settings are applied


  -- setting terminals power properties for verification
  device.setPower(3, battVoltage) -- setting battery voltage
  device.setPower(9, extVoltage)  -- setting external power voltage

  -- setting external power source
  device.setPower(8,0)                    -- external power present (terminal plugged to external power source)
  framework.delay(2)

  gateway.setHighWaterMark() -- to get the newest messages

  -- getting AvlStates and DigPorts properties for analysis
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  -- getting digPortsProperty and DigPorts properties for analysis
  local digStatesDefBitmapProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.digStatesDefBitmap)
  -- getting current temperature value
  local temperature = lsf.getProperties(lsfConstants.sins.io,lsfConstants.pins.temperatureValue)

  -- sending getDiagnostics message
  local getDiagnosticsMessage = {SIN = AVL_SIN, MIN = avlConstants.mins.getDiagnostics}    -- to trigger DiagnosticsInfo message
	gateway.submitForwardMessage(getDiagnosticsMessage)

  local timeOfEventTc = os.time()
  framework.delay(2)    -- wait until message is processed

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for diagnosticsInfo messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(AVL_SIN, avlConstants.mins.diagnosticsInfo))

  gpsSettings.heading = 361   -- for stationary state
  --- verification of the received report fields
  colmsg = framework.collapseMessage(matchingMessages[1])   -- collapsing message for easier analysys
  assert_equal("DiagnosticsInfo", colmsg.Payload.Name, "Message name is not correct")
  assert_equal(gpsSettings.latitude*60000, tonumber(colmsg.Payload.Latitude), "Latitude value is not correct in report")     -- multiplied by 60000 for conversion from miliminutes
  assert_equal(gpsSettings.longitude*60000, tonumber(colmsg.Payload.Longitude), "Longitude value is not correct in report")  -- multiplied by 60000 for conversion from miliminutes
  assert_equal(timeOfEventTc,tonumber(colmsg.Payload.EventTime),10, "EventTime value is not correct in the report")          -- 10 seconds of tolerance
  assert_equal(gpsSettings.heading, tonumber(colmsg.Payload.Heading), "Heading value is wrong in report")
  assert_equal(gpsSettings.speed, tonumber(colmsg.Payload.Speed), "Speed value is wrong in report")
  assert_equal("Disabled", colmsg.Payload.BattChargerState, "BattChargerState value is wrong in report")
  assert_equal(tonumber(avlStatesProperty[1].value), tonumber(colmsg.Payload.AvlStates), "AvlStates value is wrong in report")
  assert_equal(tonumber(digStatesDefBitmapProperty[1].value), tonumber(colmsg.Payload.DigStatesDefMap), "DigStatesDefMap value is wrong in report")
  assert_equal(tonumber(temperature[1].value), tonumber(colmsg.Payload.Temperature),1, "Temperature value is wrong in report")
  assert_equal(0, tonumber(colmsg.Payload.SatCnr), "SatCnr value is wrong in report")                                         --TODO: this value will be simulated in the future
  assert_equal(99, tonumber(colmsg.Payload.CellRssi), "CellRssi value is wrong in report")
  if (hardwareVariant==3) then
    assert_equal(extVoltage, tonumber(colmsg.Payload.ExtVoltage), "ExtVoltage value is wrong in report")
    assert_equal(battVoltage, tonumber(colmsg.Payload.BattVoltage), "BattVoltage value is wrong in report")
  else
    assert_equal(0, tonumber(colmsg.Payload.ExtVoltage), "ExtVoltage value is wrong in report")
    assert_equal(0, tonumber(colmsg.Payload.BattVoltage), "BattVoltage value is wrong in report")

  end

end



