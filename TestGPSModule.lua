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
  local expectedMins = {avlConstants.mins.reset}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.reset], "Reset message after reset of AVL not received")


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

  gps.set({fixType = 3}) -- valid fix provided
  avlHelperFunctions.putTerminalIntoStationaryState()


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

  gps.set({speed = 0})   -- terminal does not move

  -- enabling the continues mode of position service (SIN 20, PIN 15)
  lsf.setProperties(lsfConstants.sins.position,{
                                                   {lsfConstants.pins.gpsReadInterval, GPS_READ_INTERVAL}
                                               }
                    )

  -- not to get LongDriving reports
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.maxDrivingTime, 0},
                            }
                   )

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
  -- 4. Wait shorter than movingDebounceTime and change terminals position to Point#3
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
  local MOVING_DEBOUNCE_TIME = 10                            -- seconds
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
  assert_equal("MovingStart", receivedMessages[avlConstants.mins.movingStart].Name, "MovingStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.movingStart].EventTime), 5, "MovingStart message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.movingStart].Speed), "MovingStart message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.movingStart].Heading), "MovingStart message has incorrect heading value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "Terminal not in moving state after sending MovingStart message")

end


--- TC checks if MovingStart message requests new fix when continues reading of GPS position is disabled .
  -- Initial Conditions:
  --
  -- * Terminal not moving
  -- * Air communication not blocked
  -- * GPS is good
  --
  -- Steps:
  --
  -- 1. Set movingDebounceTime (PIN 3) and stationarySpeedThld (PIN 1)
  -- 2. Simulate terminal in Point#1 with speed equal to above stationarySpeedThld
  -- 3. Set continues property (PIN 15) in position service to zero
  -- 4. Change terminals position to Point#2 with speed above stationarySpeedThld (PIN 1)
  -- 6. Wait until movingDebounceTime (PIN 1) passes and receive MovingStart message (MIN 6)
  -- 7. Check the content of the received message
  --
  -- Results:
  --
  -- 1. Properties movingDebounceTime and stationarySpeedThld correctly set
  -- 2. Terminal in stationary state in Point#1
  -- 3. Continues reading of GPS is disabled
  -- 4. Terminal in Point#2 and speed above stationarySpeedThld
  -- 5. MovingStart message sent from terminal after movingDebounceTime (PIN 3)
  -- 6. Report fields contain Point#1 GPS and time information and GpsFixAge is not included
function test_Moving_WhenMovingStartEventDetected_NewFixRequestedByMovingStartMessage()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 30                           -- seconds
  local STATIONARY_SPEED_THLD = 5                           -- kmh
  local gpsSettings = {}

  -- Point#1 settings
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- kmh, above threshold
                  heading = 89,                       -- degrees
                  latitude = 0,                       -- degrees
                  longitude = 0                       -- degrees
                 }

  -- Point#2 settings
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 10,  -- one kmh above threshold
                  heading = 91,                       -- degrees
                  latitude = 2,                       -- degrees
                  longitude = 2,                      -- degrees
                 }


  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages

  -- terminal starts moving in Point#1
  gps.set(gpsSettings[1])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  lsf.setProperties(lsfConstants.sins.position,{
                                                {lsfConstants.pins.gpsReadInterval, 0}     -- disabling the continues mode of position service (SIN 20, PIN 15)
                                               }
                    )

  -- terminal moves to Point#2, continues reading of GPS is disabled
  gps.set(gpsSettings[2])

  framework.delay(MOVING_DEBOUNCE_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- Point#1 is expected in report (with no fixAge in the report)
  assert_equal(gpsSettings[1].longitude*60000, tonumber(receivedMessages[avlConstants.mins.movingStart].Longitude), "MovingStart message has incorrect longitude value")
  assert_equal(gpsSettings[1].latitude*60000, tonumber(receivedMessages[avlConstants.mins.movingStart].Latitude), "MovingStart message has incorrect latitude value")
  assert_equal(gpsSettings[1].speed, tonumber(receivedMessages[avlConstants.mins.movingStart].Speed), "MovingStart message has incorrect speed value")
  assert_equal(gpsSettings[1].heading, tonumber(receivedMessages[avlConstants.mins.movingStart].Heading), "MovingStart message has incorrect heading value")

  assert_nil(tonumber(receivedMessages[avlConstants.mins.movingStart].GpsFixAge), "New GPS fix has not been requested by MovingStart message")


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

  assert_equal(47, tonumber(receivedMessages[avlConstants.mins.movingStart].GpsFixAge), 10, "MovingStart message has wrong GpsFixAge value")

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

  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not received")

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

  -- *** Setup
  local DEFAULT_SPEED_LIMIT = 80                         -- kmh
  local SPEEDING_TIME_OVER = 1                           -- seconds
  local SPEEDING_TIME_UNDER = 10                         -- seconds
  local MOVING_DEBOUNCE_TIME = 1                         -- seconds
  local STATIONARY_SPEED_THLD = 5                        -- kmh
  local MAX_SPEED_REGISTERED = DEFAULT_SPEED_LIMIT + 10  -- kmh
  local gpsSettings = {}

  -- applying moving and speeding related properties of AVl
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_UNDER},
                            }
                   )

  -- Point#1 - terminal speeding
  gpsSettings[1]={
                      speed = MAX_SPEED_REGISTERED,       -- one kmh above moving threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  -- Point#2 - terminal slows down to speed below speed limit
  gpsSettings[2]={
                      speed = DEFAULT_SPEED_LIMIT - 10,   -- one kmh above speeding threshold
                      heading = 91,                       -- degrees
                      latitude = 2,                       -- degrees
                      longitude = 2,                      -- degrees
                     }

  -- Point#3 - terminal moving with speed below speeding limit
  gpsSettings[3]={
                      speed = DEFAULT_SPEED_LIMIT - 15,   -- one kmh above speeding threshold
                      heading = 92,                       -- degrees
                      latitude = 3,                       -- degrees
                      longitude = 3,                      -- degrees
                     }


  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[1])
  framework.delay(MOVING_DEBOUNCE_TIME + SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- *** Execute
  gateway.setHighWaterMark()                             -- to get the newest messages
  timeOfEvent = os.time()                                -- to get exact timestamp
  gps.set(gpsSettings[2])                                -- terminal slows down under speed limit in Point#2
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- wait until GPS position is read

  gps.set(gpsSettings[3])                                                     -- terminal moving to Point#3 with speed still lower than speed limit
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- wait until GPS position is read

  expectedMins = {avlConstants.mins.speedingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingEnd], "SpeedingEnd message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.speedingEnd].Longitude), "SpeedingEnd message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.speedingEnd].Latitude), "SpeedingEnd message has incorrect latitude value")
  assert_equal("SpeedingEnd", receivedMessages[avlConstants.mins.speedingEnd].Name, "SpeedingEnd message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.speedingEnd].EventTime), 5, "SpeedingEnd message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.speedingEnd].Speed), "SpeedingEnd message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.speedingEnd].Heading), "SpeedingEnd message has incorrect heading value")
  assert_equal(MAX_SPEED_REGISTERED, tonumber(receivedMessages[avlConstants.mins.speedingEnd].MaxSpeed), "SpeedingEnd message has incorrect maximum speed value")

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

  -- *** Setup
  avlHelperFunctions.putTerminalIntoMovingState()

  local DEFAULT_SPEED_LIMIT = 80                         -- kmh
  local SPEEDING_TIME_OVER = 30                          -- seconds

  -- applying speeding related properties of Avl
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                            }
                   )

  -- ** Execute
  gateway.setHighWaterMark()
  -- terminal exceeding speed limit for time shorter than SPEEDING_TIME_OVER
  gps.set({speed = DEFAULT_SPEED_LIMIT + 50})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)
  gps.set({speed = DEFAULT_SPEED_LIMIT - 10})

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not expected")

  -- checking the state of terminal, speeding state is not expected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "Terminal incorrectly in the speeding state")

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

  -- *** Setup
  local DEFAULT_SPEED_LIMIT = 80                         -- kmh
  local SPEEDING_TIME_OVER = 1                           -- seconds
  local SPEEDING_TIME_UNDER = 20                         -- seconds
  local MOVING_DEBOUNCE_TIME = 1                         -- seconds

  -- applying moving and speeding related properties of AVl
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                             {avlConstants.pins.speedingTimeUnder, SPEEDING_TIME_UNDER},
                            }
                   )


  -- *** Setup

  avlHelperFunctions.putTerminalIntoMovingState()
  gateway.setHighWaterMark() -- to get the newest messages

  gps.set({speed = DEFAULT_SPEED_LIMIT + 10})
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- checking if terminal is correctly in the speeding state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  -- *** Execute
  gateway.setHighWaterMark()
  -- terminal slows down to speed below speed limit but for time shorter than SPEEDING_TIME_UNDER
  gps.set({speed = DEFAULT_SPEED_LIMIT - 10})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME + 3)
  gps.set({speed = DEFAULT_SPEED_LIMIT + 10})

  expectedMins = {avlConstants.mins.speedingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.speedingEnd], "SpeedingEnd message not expected")

  avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
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

  -- *** Setup
  avlHelperFunctions.putTerminalIntoMovingState()

  local DEFAULT_SPEED_LIMIT = 80       -- kmh
  local SPEEDING_TIME_OVER = 7         -- seconds

  -- setting speeding related properties of AVL
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                              {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                            }
                   )

  -- ** Execute
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set({speed = DEFAULT_SPEED_LIMIT + 10}) -- 10 kmh above the speed limit threshold
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)   -- to make sure gps has been read
  gps.set({fixType=1})  -- simulated no fix (gps signal loss)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "Terminal incorrectly not in the speeding state")

  assert_equal(6, tonumber(receivedMessages[avlConstants.mins.speedingStart].GpsFixAge), 4 , "SpeedingStart message has incorrect GpsFixAge value")


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

  -- ** SETUP
  avlHelperFunctions.putTerminalIntoMovingState()

  local DEFAULT_SPEED_LIMIT = 100      -- kmh
  local SPEEDING_TIME_OVER = 1         -- seconds
  local SPEEDING_TIME_UNDER = 2        -- seconds

  -- setting speeding related properties of AVL
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                             {avlConstants.pins.speedingTimeUnder, SPEEDING_TIME_UNDER},
                            }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  gps.set({speed = DEFAULT_SPEED_LIMIT + 50})
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- *** Execute

  -- terminal is in speeding state and speed is reduced but still above speeding limit
  gps.set({speed = DEFAULT_SPEED_LIMIT + 1})
  framework.delay(SPEEDING_TIME_UNDER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  expectedMins = {avlConstants.mins.speedingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.speedingEnd], "SpeedingEnd message not expected")

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

  -- ** SETUP
  avlHelperFunctions.putTerminalIntoMovingState()

  local DEFAULT_SPEED_LIMIT = 0        -- kmh
  local SPEEDING_TIME_OVER = 2         -- seconds
  local SPEEDING_TIME_UNDER = 2        -- seconds

  -- setting speeding related properties of AVL
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                             {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages

  gps.set({speed = DEFAULT_SPEED_LIMIT + 50})
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)

  -- back to speed limit greater than zero not to interrupt other TCs
  DEFAULT_SPEED_LIMIT = 100        -- kmh
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                            }
                   )
  assert_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not expected")
  -- check if terminal has not entered Speeding state
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "Terminal incorrectly in the speeding state")





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

  local DEFAULT_SPEED_LIMIT = 50        -- kmh
  local SPEEDING_TIME_OVER = 1          -- seconds
  local MOVING_DEBOUNCE_TIME = 50       -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                                                {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                                             }
                     )

  gateway.setHighWaterMark()
  gps.set({speed = DEFAULT_SPEED_LIMIT + 1})                                   -- that is above stationary and speeding thresholds
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   -- that is longer than speedingTimeOver but shorter than movingDebounceTime

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not expected")

  -- checking the state of terminal, speeding and moving state are notexpected
  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

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

  -- *** Setup
  avlHelperFunctions.putTerminalIntoMovingState()

  local DEFAULT_SPEED_LIMIT = 50       -- kmh
  local SPEEDING_TIME_OVER = 1         -- seconds
  local SPEEDING_TIME_UNDER = 50       -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1   -- seconds

  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                              {avlConstants.pins.defaultSpeedLimit, DEFAULT_SPEED_LIMIT},
                              {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                              {avlConstants.pins.speedingTimeUnder, SPEEDING_TIME_UNDER},
                            }
                   )

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set({speed = DEFAULT_SPEED_LIMIT + 10})                                   -- above speeding limit
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL + GPS_PROCESS_TIME)    -- terminal should enter speeding state after that

  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  gps.set({speed = 0})  -- terminal suddenly stops
  framework.delay(STATIONARY_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- that is shorter than SPEEDING_TIME_UNDER

  -- SpeedingEnd message is expected despite that SPEEDING_TIME_UNDER has not passed
  expectedMins = {avlConstants.mins.speedingEnd, avlConstants.mins.movingEnd }
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingEnd], "SpeedingEnd message not received")

  -- comparison of Timestamps in IgnitionOffMessage and MovingEndMessage - those are expected to be the same
  assert_equal(receivedMessages[avlConstants.mins.speedingEnd].EventTime, receivedMessages[avlConstants.mins.movingEnd].EventTime, 2, "Timestamps of SpeedingEnd and MovingEnd are not equal")

  -- TODO:
  -- in the future this TC should check the exact times of receiving messages of SpeedingEnd and MovingEnd to verify if SpeedingEnd message is sent
  -- before Moving End, in eg.: SpeedingEnd ReceiveUTC = "2014-09-03 07:56:37" and MovingEned MessageUTC = "2014-09-03 07:56:42" - that is correct

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local TURN_THRESHOLD = 10             -- degrees
  local TURN_DEBOUNCE_TIME = 10         -- seconds
  local gpsSettings = {}

  -- Point#1 gps settings
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- kmh
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1                       -- degrees
                 }

  -- Point#2 gps settings
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 10,                     -- kmh
                  heading = gpsSettings[1].heading + TURN_THRESHOLD + 1,  -- degrees, 1 degree above turnThreshold
                  latitude = 2,                                           -- degrees
                  longitude = 2,                                          -- degrees
                 }

  -- Point#3 gps settings
  gpsSettings[3]={
                  speed = STATIONARY_SPEED_THLD + 14,                  -- kmh
                  heading = gpsSettings[2].heading,                    -- degrees
                  latitude = 3,                                        -- degrees
                  longitude = 3,                                       -- degrees
                 }


  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                               {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                               {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                               {avlConstants.pins.turnThreshold, TURN_THRESHOLD},
                               {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                             }
                   )
  -- *** Execute
  gps.set(gpsSettings[1])    -- applying gps settings for Point#1

  -- waiting until turnDebounceTime passes - in case terminal had some different heading before
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL+ GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  timeOfEvent = os.time()    -- to get exact timestamp
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[2])    -- applying gps settings of Point#2

  -- waiting shorter than turnDebounceTime and changing position to another point (terminal is moving)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gps.set(gpsSettings[3])    -- applying gps settings of Point#3

  -- waiting until turnDebounceTime passes
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL)

  expectedMins = {avlConstants.mins.turn}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.turn], "Turn message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.turn].Longitude), "Turn message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.turn].Latitude), "Turn message has incorrect latitude value")
  assert_equal("Turn", receivedMessages[avlConstants.mins.turn].Name, "Turn message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.turn].EventTime), 5, "Turn message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.turn].Speed), "Turn message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.turn].Heading), "Turn message has incorrect heading value")

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local TURN_THRESHOLD = 10             -- degrees
  local TURN_DEBOUNCE_TIME = 1          -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                              {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                              {avlConstants.pins.turnThreshold, TURN_THRESHOLD},
                              {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                            }
                   )

  -- initial position of terminal, speed above stationary speed threshold
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  -- *** Execute
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME) -- terminal should go to moving state after this time

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  turnDebounceTime = 15         -- in seconds, debounce time is increased
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.turnDebounceTime, turnDebounceTime},
                            }
                    )

  gateway.setHighWaterMark()                            -- to get the newest messages
  gps.set({heading = 110})                              -- change in heading above turnThreshold
  framework.delay(GPS_READ_INTERVAL+ GPS_PROCESS_TIME)  -- waiting shorter than turnDebounceTime
  gps.set({heading = 90})                               -- back to initial heading

  expectedMins = {avlConstants.mins.turn}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.turn], "Turn message is not expected")

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local TURN_THRESHOLD = 10             -- degrees
  local TURN_DEBOUNCE_TIME = 2          -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                              {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                              {avlConstants.pins.turnThreshold, TURN_THRESHOLD},
                              {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                            }
                   )

  -- initial position of terminal, speed above stationary speed threshold
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  -- *** Execute
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + 1) -- terminal should go to moving state after this time

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  gateway.setHighWaterMark()                                                   -- to get the newest messages
  gps.set({heading = 99})                                                      -- change in heading below turnThreshold
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   -- waiting longer than turnDebounceTime

  expectedMins = {avlConstants.mins.turn}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.turn], "Turn message is not expected")

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local TURN_THRESHOLD = 0              -- degrees
  local TURN_DEBOUNCE_TIME = 1          -- seconds

  --applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                              {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                              {avlConstants.pins.turnThreshold, TURN_THRESHOLD},
                              {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                            }
                   )

  -- initial position of terminal, speed above stationary speed threshold
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  -- *** Execute
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + 1) -- terminal should go to moving state after this time

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  gateway.setHighWaterMark()                                                   -- to get the newest messages
  gps.set({heading = 150})                                                     -- change in heading
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   -- waiting longer than turnDebounceTime

  expectedMins = {avlConstants.mins.turn}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.turn], "Turn message is not expected")

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local TURN_THRESHOLD = 10             -- degrees
  local TURN_DEBOUNCE_TIME = 1          -- seconds
  local gpsSettings = {}

  -- Point#1 gps settings
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- kmh
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1                       -- degrees
                 }

  -- Point#2 gps settings
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 10,                     -- kmh
                  heading = gpsSettings[1].heading + TURN_THRESHOLD + 1,  -- degrees, 1 degree above turnThreshold
                  latitude = 2,                                           -- degrees
                  longitude = 2,                                          -- degrees
                 }

  -- Point#3 gps settings
  gpsSettings[3]={
                  speed = STATIONARY_SPEED_THLD + 14,                  -- kmh
                  heading = gpsSettings[2].heading,                    -- degrees
                  latitude = 3,                                        -- degrees
                  longitude = 3,                                       -- degrees
                 }


  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                               {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                               {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                               {avlConstants.pins.turnThreshold, TURN_THRESHOLD},
                               {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                             }
                   )

  gps.set(gpsSettings[1])    -- applying gps settings for Point#1


  -- waiting until turnDebounceTime passes - in case terminal had some different heading before
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL+ GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  TURN_DEBOUNCE_TIME = 10          -- seconds
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.turnDebounceTime, TURN_DEBOUNCE_TIME},
                             }
                   )

  timeOfEvent = os.time()    -- to get exact timestamp
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings[2])    -- applying gps settings of Point#2

  -- waiting shorter than turnDebounceTime and changing position to another point (terminal is moving)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gps.set(gpsSettings[3])    -- applying gps settings of Point#3
  framework.delay(GPS_READ_INTERVAL)
  gpsSettings[3].fixType = 1 -- no valid fix provided
  gps.set(gpsSettings[3])    -- applying gps settings of Point#3 with signal loss

  -- waiting until turnDebounceTime passes
  framework.delay(TURN_DEBOUNCE_TIME + GPS_READ_INTERVAL)

  expectedMins = {avlConstants.mins.turn}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.turn], "Turn message not received")

  assert_equal(9, tonumber(receivedMessages[avlConstants.mins.turn].GpsFixAge), 3, "Turn message has incorrect GpsFixAge value")

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

  local MOVING_DEBOUNCE_TIME = 1         -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1     -- seconds
  local STATIONARY_SPEED_THLD = 5        -- kmh
  local MAX_DRIVING_TIME = 1             -- minutes
  local MIN_REST_TIME = 1                -- minutes
  local LONG_DRIVING_CHECK_INTERVAL = 60 -- seconds
  local gpsSettings = {}
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                                                {avlConstants.pins.maxDrivingTime, MAX_DRIVING_TIME},
                                                {avlConstants.pins.minRestTime, MIN_REST_TIME}
                                             }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold, to get moving state
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  heading = 91,                       -- degrees
                 }

  -- Point#2 - terminal moving
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 10,  -- one kmh above threshold, to get moving state
                  heading = 92,                        -- degrees
                  latitude = 2,                        -- degrees
                  longitude = 2,                       -- degrees
                  heading = 92,                        -- degrees
                 }


  -- terminal starts moving in Point#1
  gps.set(gpsSettings[1])                                                           -- gps settings applied
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   -- one second is added to make sure the gps is read and processed by agent
  -- checking if terminal is in the moving state

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- terminal moves to Point#2
  gps.set(gpsSettings[2])

  gateway.setHighWaterMark()
  -- waiting until maxDrivingTime limit passes
  framework.delay(MAX_DRIVING_TIME*60 + LONG_DRIVING_CHECK_INTERVAL)       -- maxDrivingTime multiplied by 60 to get seconds from minutes
  timeOfEvent = os.time()

  -- LongDriving message expected
  expectedMins = {avlConstants.mins.longDriving}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.longDriving], "LongDriving message not received")

  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.longDriving].Longitude), "LongDriving message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.longDriving].Latitude), "LongDriving message has incorrect latitude value")
  assert_equal("LongDriving", receivedMessages[avlConstants.mins.longDriving].Name, "LongDriving message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.longDriving].EventTime), 90, "LongDriving message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.longDriving].Speed), "LongDriving message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.longDriving].Heading), "LongDriving message has incorrect heading value")
  assert_equal(MAX_DRIVING_TIME, tonumber(receivedMessages[avlConstants.mins.longDriving].TotalDrivingTime), 1, "LongDriving message has incorrect TotalDrivingTime value")

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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1         -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1     -- seconds
  local STATIONARY_SPEED_THLD = 5        -- kmh
  local MAX_DRIVING_TIME = 3             -- minutes
  local MIN_REST_TIME = 5                -- minutes
  local LONG_DRIVING_CHECK_INTERVAL = 60 -- seconds
  local gpsSettings = {}
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                                                {avlConstants.pins.maxDrivingTime, MAX_DRIVING_TIME},
                                                {avlConstants.pins.minRestTime, MIN_REST_TIME}
                                             }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold, to get moving state
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  heading = 91,                       -- degrees
                 }

  -- *** Execute
  gateway.setHighWaterMark()

  ----------------------------------------------------------------------------------------------------
  -- terminal is moving
  ----------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])      -- gps settings applied
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)
  framework.delay(MAX_DRIVING_TIME*60 - 100)

  ----------------------------------------------------------------------------------------------------
  -- terminal stops
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = 0})                            -- terminal stops - break in driving
  framework.delay(MIN_REST_TIME*60 - 200)         -- wait shorter than MIN_REST_TIME (multiplied by 60 to get seconds from minutes)

  expectedMins = {avlConstants.mins.movingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not received")

  ----------------------------------------------------------------------------------------------------
  -- terminal is moving again
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = STATIONARY_SPEED_THLD + 1})    -- terminal moves again

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)      -- terminal should go to moving state after this

  expectedMins = {avlConstants.mins.movingStart}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  framework.delay(MAX_DRIVING_TIME*60 - 70 + LONG_DRIVING_CHECK_INTERVAL)

  -- LongDriving message expected
  expectedMins = {avlConstants.mins.longDriving}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.longDriving], "LongDriving message not received")


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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1         -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1     -- seconds
  local STATIONARY_SPEED_THLD = 5        -- kmh
  local MAX_DRIVING_TIME = 5             -- minutes
  local MIN_REST_TIME = 1                -- minutes
  local LONG_DRIVING_CHECK_INTERVAL = 60 -- seconds
  local gpsSettings = {}
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                                                {avlConstants.pins.maxDrivingTime, MAX_DRIVING_TIME},
                                                {avlConstants.pins.minRestTime, MIN_REST_TIME}
                                             }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold, to get moving state
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  heading = 91,                       -- degrees
                 }

  -- *** Execute
  gateway.setHighWaterMark()

  ----------------------------------------------------------------------------------------------------
  -- terminal is moving
  ----------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])      -- gps settings applied
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)
  framework.delay(MAX_DRIVING_TIME*60 - 200)

  ----------------------------------------------------------------------------------------------------
  -- terminal stops
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = 0})                                                    -- terminal stops - break in driving
  -- wait longer than MIN_REST_TIME (multiplied by 60 to get seconds from minutes)
  framework.delay(MIN_REST_TIME*60 + LONG_DRIVING_CHECK_INTERVAL + GPS_READ_INTERVAL)

  expectedMins = {avlConstants.mins.movingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not received")

  ----------------------------------------------------------------------------------------------------
  -- terminal moves again
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = STATIONARY_SPEED_THLD + 1})    -- terminal moves again

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)      -- terminal should go to moving state after this

  expectedMins = {avlConstants.mins.movingStart}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  framework.delay(MAX_DRIVING_TIME*60 - 100 + LONG_DRIVING_CHECK_INTERVAL)

  -- LongDriving message expected
  expectedMins = {avlConstants.mins.longDriving}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.longDriving], "LongDriving message not expected")


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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1         -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1     -- seconds
  local STATIONARY_SPEED_THLD = 5        -- kmh
  local MAX_DRIVING_TIME = 2             -- minutes
  local LONG_DRIVING_CHECK_INTERVAL = 60 -- seconds
  local gpsSettings = {}
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                             {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                             {avlConstants.pins.maxDrivingTime, MAX_DRIVING_TIME},
                            }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold, to get moving state
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  heading = 91,                       -- degrees
                 }

  -- *** Execute
  gateway.setHighWaterMark()

  ----------------------------------------------------------------------------------------------------
  -- terminal is moving
  ----------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])      -- gps settings applied
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- wait longer than maxDrivingTime (multiplied by 60 to get seconds from minutes)
  framework.delay(MAX_DRIVING_TIME*60 + LONG_DRIVING_CHECK_INTERVAL)

  -- LongDriving message expected
  expectedMins = {avlConstants.mins.longDriving}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.longDriving], "First LongDriving message not received")

  assert_equal(MAX_DRIVING_TIME, tonumber(receivedMessages[avlConstants.mins.longDriving].TotalDrivingTime), 1, "First LongDriving message has incorrect TotalDrivingTime value")

  gateway.setHighWaterMark()  -- to get another LongDriving report

  -- wait longer than maxDrivingTime (multiplied by 60 to get seconds from minutes)
  framework.delay(MAX_DRIVING_TIME*60 + LONG_DRIVING_CHECK_INTERVAL)

  -- LongDriving message expected
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_not_nil(receivedMessages[avlConstants.mins.longDriving], "Second LongDriving message not received")
  assert_equal(MAX_DRIVING_TIME, tonumber(receivedMessages[avlConstants.mins.longDriving].TotalDrivingTime), 1, "Second LongDriving message has incorrect TotalDrivingTime value")


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

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1         -- seconds
  local STATIONARY_DEBOUNCE_TIME = 1     -- seconds
  local STATIONARY_SPEED_THLD = 5        -- kmh
  local MAX_DRIVING_TIME = 3             -- minutes
  local MIN_REST_TIME = 3                -- minutes
  local LONG_DRIVING_CHECK_INTERVAL = 60 -- seconds
  local gpsSettings = {}
  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                                                {avlConstants.pins.maxDrivingTime, MAX_DRIVING_TIME},
                                                {avlConstants.pins.minRestTime, MIN_REST_TIME}
                                             }
                   )

  -- Point#1 - terminal moving
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold, to get moving state
                  heading = 90,                       -- degrees
                  latitude = 1,                       -- degrees
                  longitude = 1,                      -- degrees
                  heading = 91,                       -- degrees
                 }

  -- *** Execute
  gateway.setHighWaterMark()

  ----------------------------------------------------------------------------------------------------
  -- terminal is moving
  ----------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])      -- gps settings applied
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  -- wait shorter than maxDrivingTime (multiplied by 60 to get seconds from minutes)
  framework.delay(MAX_DRIVING_TIME*60 - 90 + LONG_DRIVING_CHECK_INTERVAL)

  ----------------------------------------------------------------------------------------------------
  -- terminal stops
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = 0})   -- terminal stops - break in driving
  -- wait longer than MIN_REST_TIME (multiplied by 60 to get seconds from minutes)
  framework.delay(MIN_REST_TIME*60 - 50 + LONG_DRIVING_CHECK_INTERVAL)

  expectedMins = {avlConstants.mins.movingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not received")

  ----------------------------------------------------------------------------------------------------
  -- terminal moves again
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = STATIONARY_SPEED_THLD + 1})    -- terminal moves again

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)      -- terminal should go to moving state after this

  expectedMins = {avlConstants.mins.movingStart}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  framework.delay(MAX_DRIVING_TIME*60 - 80 + LONG_DRIVING_CHECK_INTERVAL)

  ----------------------------------------------------------------------------------------------------
  -- terminal stops - accumulated breakes in driving exceed minRestTime but are not continues
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = 0})   -- terminal stops - break in driving
  -- wait longer than MIN_REST_TIME (multiplied by 60 to get seconds from minutes)
  framework.delay(MIN_REST_TIME*60 - 80 + LONG_DRIVING_CHECK_INTERVAL)

  expectedMins = {avlConstants.mins.movingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingEnd], "MovingEnd message not received")

  ---------------------------------------------------------------------------------------------------
  -- terminal moves again - accumulated driving time exceeds maxDrivingTime limit
  ----------------------------------------------------------------------------------------------------
  gps.set({speed = STATIONARY_SPEED_THLD + 1})    -- terminal moves again

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)      -- terminal should go to moving state after this

  expectedMins = {avlConstants.mins.movingStart}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received")

  framework.delay(MAX_DRIVING_TIME*60 - 90 + LONG_DRIVING_CHECK_INTERVAL)

  -- LongDriving message expected
  expectedMins = {avlConstants.mins.longDriving}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, 10)  -- this timeout is short on purpose (not to pass maxDrivingTime)
  assert_not_nil(receivedMessages[avlConstants.mins.longDriving], "LongDriving message not received")



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

  -- *** Setup
  local EXT_VOLTAGE = 17000     -- milivolts
  local BATT_VOLTAGE = 23000    -- milivolts

  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = 0,                      -- terminal stationary
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)   --- wait until settings are applied

  -- setting terminals power properties for verification

  if (hardwareVariant == 3) then
    device.setPower(3, BATT_VOLTAGE) -- setting battery voltage
     device.setPower(9, EXT_VOLTAGE)  -- setting external power voltage
    -- setting external power source
    device.setPower(8,0)                    -- external power present (terminal plugged to external power source)
    framework.delay(2)
  end

  -- *** Execute
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

  local timeOfEvent = os.time()

  local expectedMins = {avlConstants.mins.diagnosticsInfo}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.diagnosticsInfo], "DiagnosticsInfo message not received")

  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].Longitude), "DiagnosticsInfo message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].Latitude), "DiagnosticsInfo message has incorrect latitude value")
  assert_equal("DiagnosticsInfo", receivedMessages[avlConstants.mins.diagnosticsInfo].Name, "DiagnosticsInfo message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].EventTime), 5, "DiagnosticsInfo message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].Speed), "DiagnosticsInfo message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].Heading), "DiagnosticsInfo message has incorrect heading value")
  assert_equal("Disabled", receivedMessages[avlConstants.mins.diagnosticsInfo].BattChargerState, "DiagnosticsInfo message has incorrect BattChargerState value")
  assert_equal(tonumber(avlStatesProperty[1].value), tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].AvlStates), "DiagnosticsInfo message has incorrect AvlStates value")
  assert_equal(tonumber(digStatesDefBitmapProperty[1].value), tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].DigStatesDefMap), "DiagnosticsInfo message has incorrect DigStatesDefMap value")
  assert_equal(tonumber(temperature[1].value), tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].Temperature), "DiagnosticsInfo message has incorrect Temperature value")
  assert_equal(0, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].SatCnr), "DiagnosticsInfo message has incorrect SatCnr value")
  assert_equal(99, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].CellRssi), "DiagnosticsInfo message has incorrect CellRssi value")

  if (hardwareVariant == 3) then
    assert_equal(BATT_VOLTAGE, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].BattVoltage), "DiagnosticsInfo has incorrect BattVoltage value")
    assert_equal(EXT_VOLTAGE, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].ExtVoltage), "DiagnosticsInfo has incorrect ExtVoltage value")
  else
    assert_equal(0, tonumber(receivedMessages[avlConstants.mins.diagnosticsInfo].BattVoltage), "DiagnosticsInfo has incorrect BattVoltage value")
  end

end


--- TC checks if GpsJammingStart (MIN 25) message is sent when GPS signal jamming is detected for time longer than  GpsJamDebounceTime (PIN 28) .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set gpsJamDebounceTime (PIN 28)
  -- 2. Simulate gps jamming for time longer than gpsJamDebounceTime with known jamming level
  -- 3. Wait longer than gpsJamDebounceTime
  -- 4. Check fields of received message
  -- 5. Read AvlStates property (PIN 51)
  --
  -- Results:
  --
  -- 1. gpsJamDebounceTime set
  -- 2. Gps jamming simulated for time longer than gpsJamDebounceTime with known jamming level
  -- 3. GpsJammingStart message sent by terminal
  -- 4. Message contains simulated jamming level information
  -- 5. Terminal enters GPSJammed state
function test_GpsJamming__WhenGpsJammingDetectedForTimeLongerThanGpsJamDebounceTimePeriod_GpsJammingStartMessageSent()

  -- *** Setup
  local GPS_JAMMING_DEBOUNCE_TIME = 5    -- seconds
  local JAMMING_LEVEL = 10               -- integer

  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.gpsJamDebounceTime, GPS_JAMMING_DEBOUNCE_TIME},
                            }
                    )

  -- gps settings table
  local gpsSettings={
                      speed = 0,                      -- terminal stationary
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1,                  -- degrees
                      jammingDetect = "true",
                      jammingLevel = JAMMING_LEVEL,
                     }

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  local timeOfEvent = os.time()
  framework.delay(GPS_JAMMING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   --- wait until settings are applied

  local expectedMins = {avlConstants.mins.gpsJammingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  gps.set({jammingDetect = "false"}) -- back to jamming off

  assert_not_nil(receivedMessages[avlConstants.mins.gpsJammingStart], "GpsJammingStart message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].Longitude), "GpsJammingStart message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].Latitude), "GpsJammingStart message has incorrect latitude value")
  assert_equal("GpsJammingStart", receivedMessages[avlConstants.mins.gpsJammingStart].Name, "GpsJammingStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].EventTime), 5, "GpsJammingStart message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].Speed), "GpsJammingStart message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].Heading), "GpsJammingStart message has incorrect heading value")
  assert_equal(JAMMING_LEVEL, tonumber(receivedMessages[avlConstants.mins.gpsJammingStart].JammingRaw), "GpsJammingStart message has incorrect heading value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).GPSJammed, "Terminal has not entered GPSJammed state after sending GpsJammingStart message")

end



--- TC checks if GpsJammingStart (MIN 25) message is not sent when GPS signal jamming is detected for time below GpsJamDebounceTime (PIN 28) period .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set gpsJamDebounceTime (PIN 28) to high value
  -- 2. Simulate gps jamming for time shorter than gpsJamDebounceTime
  -- 3. Wait shorter than gpsJamDebounceTime
  -- 4. Read AvlStates property (PIN 51)
  --
  -- Results:
  --
  -- 1. gpsJamDebounceTime set
  -- 2. Gps jamming simulated for time shorter than gpsJamDebounceTime
  -- 3. GpsJammingStart message not sent by terminal
  -- 4. Terminal does not enter GPSJammed state
function test_GpsJamming__WhenGpsJammingDetectedForTimeShorterThanGpsJamDebounceTimePeriod_GpsJammingStartMessageNotSent()

  -- *** Setup
  local GPS_JAMMING_DEBOUNCE_TIME = 100  -- seconds
  local JAMMING_LEVEL = 10               -- integer

  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.gpsJamDebounceTime, GPS_JAMMING_DEBOUNCE_TIME},
                            }
                    )

  -- gps settings table
  local gpsSettings={
                      speed = 0,                      -- terminal stationary
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1,                  -- degrees
                      jammingDetect = "true",
                      jammingLevel = JAMMING_LEVEL,
                     }

  -- *** Execute
  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)    --- wait shorter than GpsJamDebounceTime

  local expectedMins = {avlConstants.mins.gpsJammingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)

  gps.set({jammingDetect = "false"}) -- back to jamming off

  assert_false(receivedMessages[avlConstants.mins.gpsJammingStart], "GpsJammingStart message not received")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).GPSJammed, "Terminal has not entered GPSJammed state after sending GpsJammingStart message")


end



--- TC checks if for terminal in GPSJammed state GpsJammingEnd (MIN 26) message is sent when GPS signal jamming is not detected for time longer than  GpsJamDebounceTime (PIN 28) .
  -- Initial Conditions:
  --
  -- * Running Terminal Simulator
  -- * Webservices: Device, GPS, Gateway running
  -- * Air communication not blocked
  --
  -- Steps:
  --
  -- 1. Set gpsJamDebounceTime (PIN 28)
  -- 2. Simulate gps jamming for time longer than gpsJamDebounceTime with known jamming level
  -- 3. Wait longer than gpsJamDebounceTime
  -- 4. Simulate gps signal not jammed for time longer than gpsJamDebounceTime period
  -- 5. Wait for longer than gpsJamDebounceTime period
  -- 6. Check fields of received message
  -- 7. Read AvlStates property (PIN 51)
  --
  -- Results:
  --
  -- 1. gpsJamDebounceTime set
  -- 2. Gps jamming simulated for time longer than gpsJamDebounceTime with known jamming level
  -- 3. GpsJammingStart message sent by terminal
  -- 4. Gps signal not jammed for time longer than gpsJamDebounceTime
  -- 5. GpsJammingEnd (MIN 26) message sent by terminal
  -- 6. Message contains simulated jamming level information
  -- 7. Terminal enters GPSJammed false state
function test_GpsJamming__ForTerminalInGPSJammedStateWhenGpsJammingNotDetectedForTimeLongerThanGpsJamDebounceTimePeriod_GpsJammingEndMessageSent()

  -- *** Setup
  local GPS_JAMMING_DEBOUNCE_TIME = 5    -- seconds
  local JAMMING_LEVEL = 10               -- integer

  -- applying properties of the service
  lsf.setProperties(AVL_SIN,{
                              {avlConstants.pins.gpsJamDebounceTime, GPS_JAMMING_DEBOUNCE_TIME},
                            }
                    )

  -- gps settings table
  local gpsSettings={
                      speed = 0,                      -- terminal stationary
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1,                  -- degrees
                      jammingDetect = "true",
                      jammingLevel = JAMMING_LEVEL,
                     }


  gateway.setHighWaterMark() -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(GPS_JAMMING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   --- wait until terminal goes to GPSJammed = true state
  local expectedMins = {avlConstants.mins.gpsJammingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.gpsJammingStart], "GpsJammingStart message not received")

  -- *** Execute
  gps.set({jammingDetect = "false"}) -- back to jamming off
  local timeOfEvent = os.time()
  framework.delay(GPS_JAMMING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)   --- wait until GpsJammingEnd is sent

  expectedMins = {avlConstants.mins.gpsJammingEnd}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.gpsJammingEnd], "GpsJammingEnd message not received")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].Longitude), "GpsJammingEnd message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].Latitude), "GpsJammingEnd message has incorrect latitude value")
  assert_equal("GpsJammingEnd", receivedMessages[avlConstants.mins.gpsJammingEnd].Name, "GpsJammingEnd message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].EventTime), 5, "GpsJammingEnd message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].Speed), "GpsJammingEnd message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].Heading), "GpsJammingEnd message has incorrect heading value")
  assert_equal(JAMMING_LEVEL, tonumber(receivedMessages[avlConstants.mins.gpsJammingEnd].JammingRaw), "GpsJammingEnd message has incorrect heading value")

  local avlStatesProperty = lsf.getProperties(AVL_SIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).GPSJammed, "Terminal has not left GPSJammed state after sending GpsJammingEnd message")

end




