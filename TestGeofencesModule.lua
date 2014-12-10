-----------
-- Geofences test module
-- - contains gps related test cases
-- @module TestGeofencesModule

module("TestGeofencesModule", package.seeall)

-- Setup and Teardown

--- suite_setup function ensures that terminal is not in the moving state and not in the low power mode
 -- it sends fences.dat file to the terminal
 -- executed before each test suite
 -- * actions performed:
 -- lpmTrigger is set to 0 so that nothing can put terminal into the low power mode
 -- function checks if terminal is not the low power mode (condition necessary for all GPS related test cases)
 -- using filesystem service it sends fences.dat file in overwrite mode
 -- *initial conditions:
 -- running Terminal Simulator with installed AVL Agent, running Modem Simulator with Gateway Web Service and
 -- GPS Web Service switched on
 -- *Expected results:
 -- lpmTrigger set correctly and terminal is not in the Low Power mode
 -- geofences file successfully send to the terminal
function suite_setup()

 -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.lpmTrigger, 0},
                                             }
                    )
  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")

  -- sending fences.dat file to the terminal with the definitions of geofences used in TCs
  -- for more details please go to Geofences.jpg file in Documentation
  local message = {SIN = lsfConstants.sins.filesystem, MIN = lsfConstants.mins.write}
	message.Fields = {{Name="path",Value="/data/svc/geofence/fences.dat"},{Name="offset",Value=0},{Name="flags",Value="Overwrite"},{Name="data",Value="ABIABQAtxsAAAr8gAACcQAAAAfQEagAOAQEALg0QAAK/IAAATiABnAASAgUALjvwAAQesAAAw1AAAJxABCEAEgMFAC4NEAAEZQAAAFfkAABEXAKX"}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- to make sure file is saved

  -- restaring geofences service, that action is necessary after sending new fences.dat file
  message = {SIN = lsfConstants.sins.system, MIN = lsfConstants.mins.restartService}
	message.Fields = {{Name="sin",Value=lsfConstants.sins.geofence}}
	gateway.submitForwardMessage(message)

  framework.delay(5) -- wait until geofences service is up again


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

--- the setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets GPS_READ_INTERVAL (in position service) to the value of GPS_READ_INTERVAL
  -- executed before each unit test
  -- *actions performed:
  -- setting of the GPS_READ_INTERVAL (in the position service) is made using global GPS_READ_INTERVAL variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- by saving deleteData property it deletes Geo-speeding and Geo-dwell limits
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state, Geo-speeding and geo-dwell limits are removed
function setup()

  local GEOFENCE_ENABLED = true        -- to enable geofence feature
  local GEOFENCE_HISTERESIS = 1        -- in seconds
  local STATIONARY_DEBOUNCE_TIME = 1   -- in seconds

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, GEOFENCE_ENABLED, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, GEOFENCE_INTERVAL},         -- global variable
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )

  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                               }
                    )

  -- setting deleteData property to delte geo-speeding limits
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.deleteData, 3},      -- delete Geo-speeding limits
                                             }
                    )
  framework.delay(1)   -- wait until message is processed

  -- setting deleteData property to delte geo-geodwell times
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.deleteData, 2},                                     -- delete Geo-dwell time limits
                                              {avlConstants.pins.stationaryDebounceTime, STATIONARY_DEBOUNCE_TIME},
                                            }
                   )

  -- gps settings table
  local gpsSettings={
                      longitude = 0,                -- degrees, outside any of the defined geofences
                      latitude = 0,                 -- degrees, outside any of the defined geofences
                      heading = 90,                 -- degrees
                      speed = 0,                    -- to get stationary state
                      fixType= 3,                   -- valid 3D gps fix
                      simulateLinearMotion = false, -- terminal not moving
                     }

  -- put terminal outside of any of the defined geozones
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(GEOFENCE_INTERVAL + GEOFENCE_HISTERESIS + STATIONARY_DEBOUNCE_TIME)

end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

-- nothing here for now

end

-------------------------
-- Test Cases
-------------------------

--- TC checks if ZoneEntry message is correctly sent when terminal enters defined zone and stays there for longer than
  -- geofenceHisteresis period
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 second and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 0 (that is outside of
  -- zone 0); change terminals position to inside of geofence 0 and wait fot time longer than geofenceHisteresis plus geofenceInterval and check
  -- if ZoneEntry message has been sent; verify the fields of the report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal enters zone 0 and ZoneEntry message has been sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriod_ZoneEntryMessageSent()

  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local GEOFENCE_INTERVAL = 10         -- seconds
  local GEOFENCE_HISTERESIS = 30       -- seconds
  local gpsSettings = {}               -- gps settings table to be sent to simulator

  -- Point#1 - terminal outside geofence 0
  gpsSettings[1]={
                   speed = STATIONARY_SPEED_THLD + 1,    -- one kmh above threshold
                   heading = 90,                       -- degrees
                   latitude = 50,                      -- degrees
                   longitude = 2,                      -- degrees, that is outside geofence 0
                  }

  -- Point#2 - terminal inside geofence 0
  gpsSettings[2]={
                   speed = STATIONARY_SPEED_THLD + 1,    -- one kmh above threshold
                   heading = 90,                       -- degrees
                   latitude = 50,                      -- degrees
                   longitude = 3,                      -- degrees, that is inside geofence 0
                 }

  -- Point#3 - terminal inside geofence 0
  gpsSettings[3]={
                   speed = STATIONARY_SPEED_THLD + 2,    -- one kmh above threshold
                   heading = 91,                       -- degrees
                   latitude = 50,                      -- degrees
                   longitude = 3,                      -- degrees, that is inside geofence 0
                 }

  -- applying moving related properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )

  ---------------------------------------------------------------------------------------
  --- Terminal moving outside geofence 0
  ---------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  ---------------------------------------------------------------------------------------
  --- Terminal moves in Point#2 inside geofence 0
  ---------------------------------------------------------------------------------------
  gateway.setHighWaterMark()            -- to get the newest messages
  gps.set(gpsSettings[2])
  -- entering geozone should be detected
  framework.delay(GEOFENCE_INTERVAL + GPS_PROCESS_TIME)

  ---------------------------------------------------------------------------------------
  --- Terminal moves in Point#3 inside geofence 0
  ---------------------------------------------------------------------------------------
  gps.set(gpsSettings[3])
  framework.delay(GEOFENCE_HISTERESIS + GPS_PROCESS_TIME) -- waiting for the ZoneEntry message to be generated

  local timeOfEvent = os.time()

  -- ZoneEntry message expected
  local expectedMins = {avlConstants.mins.zoneEntry}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.zoneEntry], "ZoneEntry message not received")
  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.zoneEntry].Longitude), "ZoneEntry message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.zoneEntry].Latitude), "ZoneEntry message has incorrect latitude value")
  assert_equal("ZoneEntry", receivedMessages[avlConstants.mins.zoneEntry].Name, "ZoneEntry message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.zoneEntry].EventTime), 60, "ZoneEntry message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.zoneEntry].Speed), "ZoneEntry message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.zoneEntry].Heading), "ZoneEntry message has incorrect heading value")
  assert_equal(0, tonumber(receivedMessages[avlConstants.mins.zoneEntry].CurrentZoneId), "ZoneEntry message has CurrentZoneId value")


end



--- TC checks if ZoneEntry message is not sent when terminal enters defined zone and stays there shorter longer than
  -- geofenceHisteresis period
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 second and
  -- geofenceHisteresis to 1 second; simulate terminals position to latitude = 50, longitude = 3 but for time shorter than geofenceHisteresis
  -- and check if ZoneEntry message has not been sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal stays in zone 0 shorter than geofenceHisteresis and ZoneEntry message is not sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereShorterThanGeofenceHisteresisPeriod_ZoneEntryMessageNotSent()

  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local GEOFENCE_HISTERESIS = 100      -- seconds
  local gpsSettings = {}               -- gps settings table to be sent to simulator

  -- Point#1 - terminal outside geofence 0
  gpsSettings[1]={
                   speed = STATIONARY_SPEED_THLD + 1,    -- one kmh above threshold
                   heading = 90,                       -- degrees
                   latitude = 50,                      -- degrees
                   longitude = 2,                      -- degrees, that is outside geofence 0
                  }

  -- Point#2 - terminal inside geofence 0
  gpsSettings[2]={
                   speed = STATIONARY_SPEED_THLD + 1,    -- one kmh above threshold
                   heading = 90,                       -- degrees
                   latitude = 50,                      -- degrees
                   longitude = 3,                      -- degrees, that is inside geofence 0
                 }

  -- applying moving related properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )

  ---------------------------------------------------------------------------------------
  --- Terminal moving outside geofence 0
  ---------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  ---------------------------------------------------------------------------------------
  --- Terminal moving inside geofence 0
  ---------------------------------------------------------------------------------------
  gateway.setHighWaterMark()            -- to get the newest messages
  gps.set(gpsSettings[2])               -- applying gps settings

  framework.delay(GEOFENCE_INTERVAL + GPS_PROCESS_TIME)

  ---------------------------------------------------------------------------------------
  --- Terminal goes out of geofence 0 before Histeresis time is gone
  ---------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  -- ZoneEntry message not expected
  local expectedMins = {avlConstants.mins.zoneEntry}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)

  assert_nil(receivedMessages[avlConstants.mins.zoneEntry], "ZoneEntry message not expected")

end



--- TC checks if ZoneExit message is correctly sent when terminal exits defined zone and enters undefined zone
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 seconds and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 3 (that is inside of
  -- geofence 0) and speed above stationarySpeedThld (to get moving state true); then change terminals position outside geofence 0
  -- (latitude = 50, longitude = 1) and check if ZoneExit message has been sent and the fields in report have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal exits goefence 0 and ZoneExit message has been sent
function test_Geofence_WhenTerminalExitsDefinedGeozoneForTimeLongerThanGeofenceHisteresisPeriod_ZoneExitMessageSent()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local GEOFENCE_HISTERESIS = 1        -- seconds
  local gpsSettings = {}               -- gps settings table to be sent to simulator

    -- Point#1 - terminal moving inside geofence 0
  gpsSettings[1]={
                  speed = 5,                       -- one kmh above threshold
                  heading = 90,                    -- degrees
                  latitude = 50,                   -- degrees
                  longitude = 3,                   -- degrees, that is inside geofence 0
                 }

  -- Point#2 - terminal goes outside geofence 0 and enters undefined geofence (128)
  gpsSettings[2]={
                  speed = 5,                       -- one kmh above threshold
                  heading = 90,                    -- degrees
                  latitude = 50,                   -- degrees
                  longitude = 1,                   -- degrees, that is outside geofence 0
                  }

  -- applying moving related properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )
  -- *** Execute
  ---------------------------------------------------------------------------------------
  --- Terminal moving inside geofence 0
  ---------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])
  framework.delay(GEOFENCE_HISTERESIS + GEOFENCE_INTERVAL + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  --------------------------------------------------------------------------------------
  --- Terminal goes outside geofence 0 to undefined zone (128)
  ---------------------------------------------------------------------------------------
  gateway.setHighWaterMark()
  local timeOfEvent = os.time()
  gps.set(gpsSettings[2])
  framework.delay(GEOFENCE_HISTERESIS + GEOFENCE_INTERVAL + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  -- ZoneExit message expected
  local expectedMins = {avlConstants.mins.zoneExit}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)

  assert_not_nil(receivedMessages[avlConstants.mins.zoneExit], "ZoneExit message not received")
  assert_equal(gpsSettings[2].longitude*60000, tonumber(receivedMessages[avlConstants.mins.zoneExit].Longitude), "ZoneExit message has incorrect longitude value")
  assert_equal(gpsSettings[2].latitude*60000, tonumber(receivedMessages[avlConstants.mins.zoneExit].Latitude), "ZoneExit message has incorrect latitude value")
  assert_equal("ZoneExit", receivedMessages[avlConstants.mins.zoneExit].Name, "ZoneExit message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.zoneExit].EventTime), 60, "ZoneExit message has incorrect EventTime value")
  assert_equal(gpsSettings[2].speed, tonumber(receivedMessages[avlConstants.mins.zoneExit].Speed), "ZoneExit message has incorrect speed value")
  assert_equal(gpsSettings[2].heading, tonumber(receivedMessages[avlConstants.mins.zoneExit].Heading), "ZoneExit message has incorrect heading value")
  assert_equal(128, tonumber(receivedMessages[avlConstants.mins.zoneExit].CurrentZoneId), "ZoneExit message has CurrentZoneId value")
  assert_equal(0, tonumber(receivedMessages[avlConstants.mins.zoneExit].PreviousZoneId), "ZoneExit message has PreviousZoneId value")

end



--- TC checks if SpeedingStart message is correctly sent when terminal moves with the speed above speeding threshold defined in geofence
  -- for time longer than speedingTimeOver
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 1 second, geofence0SpeedLimit to 30 kmh
  -- defaultSpeedLimit to 100 kmh, speedingTimeOver to 1 second and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50, longitude = 2 (that is outside of geofence 0) and speed one kmh above geofence0SpeedLimit;
  -- then change terminals position to inside of the geofence 0 (speed still above geofence0SpeedLimit) and check if speeding message is sent
  -- and reports fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal sends SpeedingStart message in geofence 0 and fields in report have correct values
function test_GeofenceSpeeding_WhenTerminalIsInZoneWithDefinedSpeedLimitAndSpeedIsAboveThldForPeriodAboveThld_SpeedingStartMessageSent()

  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_INTERVAL = 10          -- in seconds
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local GEOFENCE_0_SPEED_LIMIT = 30     -- in kmh
  local GEOFENCE_128_SPEED_LIMIT = 100  -- in kmh
  local SPEEDING_TIME_OVER = 1          -- in seconds
  local gpsSettings = {}                -- gps settings table to be sent to simulator


  -- Point#1 - terminal outside geofence 0 moving with speed above geofence0SpeedLimit threshold but below geofence128SpeedLimit
  gpsSettings[1]={
                  speed = GEOFENCE_0_SPEED_LIMIT + 1,   -- one kmh above threshold
                  heading = 90,                         -- degrees
                  latitude = 50,                        -- degrees
                  longitude = 2,                        -- degrees, outside any of the defined geozones (zone 128)
                 }

  -- Point#2 - terminal inside geofence 0 moving with speed above geofence0SpeedLimit threshold
  gpsSettings[2]={
                    speed = GEOFENCE_128_SPEED_LIMIT + 1 ,  -- kmh, above speeding threshold
                    heading = 90,                           -- degrees
                    latitude = 50,                          -- degrees
                    longitude = 3,                          -- degrees, inside geofence 0
                 }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0 and 128
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=GEOFENCE_0_SPEED_LIMIT}}},
                                                      {Index=1,Fields={{Name="ZoneId",Value=128},{Name="SpeedLimit",Value=GEOFENCE_128_SPEED_LIMIT}}}}},}
	gateway.submitForwardMessage(message)

  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )

  ---------------------------------------------------------------------------------------------------------------
  --- Terminal outside geofence 0 moving with speed above geofence0SpeedLimit but below geofence128SpeedLimit
  ---------------------------------------------------------------------------------------------------------------

  gps.set(gpsSettings[1])
  framework.delay(MOVING_DEBOUNCE_TIME + GEOFENCE_INTERVAL + 15)  -- to get the moving state outside geofence 0

  ---------------------------------------------------------------------------------------------------------------
  --- Terminal enters geofence 0 with speed exceedeing speed limit defined for this zone
  ---------------------------------------------------------------------------------------------------------------

  gateway.setHighWaterMark()                            -- to get the newest messages
  timeOfEventTc = os.time()                             -- to get the correct value in the report
  gps.set(gpsSettings[2])
  framework.delay(SPEEDING_TIME_OVER + GEOFENCE_INTERVAL)    -- waiting until terminal enters the zone and the report is generated

  -- waiting for SpeedingStart message
  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- checking if correct speed limit is reported
  assert_equal(GEOFENCE_128_SPEED_LIMIT, tonumber(receivedMessages[avlConstants.mins.speedingStart].SpeedLimit))


end



--- TC checks if SpeedingEnd message is sent when terminal is in speeding state and moves to geofence with speed limit higher than current speed
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds, geofence0SpeedLimit to 90 kmh
  -- geofence128SpeedLimit to 60 kmh, speedingTimeOver and speedingTimeUnder to 1 second and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50, longitude = 2 (that is outside of geofence 0) and speed above geofence128SpeedLimit - to get speeding
  -- state; then change terminals position to inside of the geofence 0 (speed is below geofence0SpeedLimit) and check if speedingEnd message is sent
  -- and reports fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal sends SpeedingEnd message in geofence 0 and fields in report have correct values
function test_GeofenceSpeeding_WhenTerminalIsInSpeedingStateAndEntersZoneWithDefinedSpeedLimitAndSpeedIsBelowThldForPeriodAboveThl_SpeedingEndMessageSent()

  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local GEOFENCE_0_SPEED_LIMIT = 90     -- in kmh
  local GEOFENCE_128_SPEED_LIMIT = 60   -- in kmh
  local SPEEDING_TIME_OVER = 1          -- in seconds
  local SPEEDING_TIME_UNDER = 1         -- in seconds
  local gpsSettings = {}                -- gps settings table to be sent to simulator


  -- Point#1: terminal outside any defined geofence moving with speed above geofence128SpeedLimit threshold
  gpsSettings[1]={
                    speed = GEOFENCE_128_SPEED_LIMIT + 10,   -- 10 kmh above speeding threshold
                    heading = 90,                            -- degrees
                    latitude = 50,                           -- degrees
                    longitude = 2,                           -- degrees, outside geofence 0 (inside 128)
                 }

  -- Point#2: terminal inside geofence 0 moving with speed above geofence128SpeedLimit but below geofence0SpeedLimit
  gpsSettings[2]={
                      speed = GEOFENCE_128_SPEED_LIMIT + 10 ,    -- 10 kmh above speeding threshold but below geofence0SpeedLimit
                      heading = 90,                              -- degrees
                      latitude = 50,                             -- degrees
                      longitude = 3,                             -- degrees, iniside geofence 0
                     }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0 and 128
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=GEOFENCE_0_SPEED_LIMIT}}},
                                                      {Index=1,Fields={{Name="ZoneId",Value=128},{Name="SpeedLimit",Value=GEOFENCE_128_SPEED_LIMIT}}}}},}
	gateway.submitForwardMessage(message)

  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                                                {avlConstants.pins.speedingTimeUnder, SPEEDING_TIME_UNDER},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )

  -----------------------------------------------------------------------------------------------------
  -- terminal speeding inside geofence 128
  -----------------------------------------------------------------------------------------------------

  gps.set(gpsSettings[1])
  framework.delay(SPEEDING_TIME_OVER + GPS_READ_INTERVAL)  -- to get the speeding state outside geofence 0 (inside 128)

  -- waiting for SpeedingStart message
  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -----------------------------------------------------------------------------------------------------
  -- terminal is moving with constant speed and enters geofence 0 with higher speed limit
  -----------------------------------------------------------------------------------------------------

  gateway.setHighWaterMark()                             -- to get the newest messages
  timeOfEventTc = os.time()                              -- to get the correct value in the report
  gps.set(gpsSettings[2])

  -- waiting until terminal enters the zone and the SpeedingEnd report is generated
  framework.delay(SPEEDING_TIME_UNDER + GEOFENCE_INTERVAL + GPS_READ_INTERVAL)

  -- waiting for SpeedingStart message
  local expectedMins = {avlConstants.mins.speedingEnd}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingEnd], "SpeedingEnd message not received")

  -- checking if correct maximum speed is reported
  assert_equal(GEOFENCE_128_SPEED_LIMIT + 10 , tonumber(receivedMessages[avlConstants.mins.speedingEnd].MaxSpeed))

end



--- TC checks if ZoneExit message is sent and reported geofence ID is 128 when terminal leaves area with defined geofence and stays
  -- there longer than geofenceHisteresis period
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 seconds and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 3 (that is inside of
  -- zone 0); then change terminals position to latitude = 50, longitude = 1 (this is area with no defined geofence) and check
  -- if in ZoneExit message reported CurrentZoneId is 128;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- ZoneExit message is sent when terminal goes out of the area with defined geofence and reported id of zone is 128
function test_Geofence_WhenTerminalEntersAreaWithNoDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriod_ZoneId128IsReportedInZoneExitMessage()

  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local gpsSettings = {}                -- gps settings table to be sent to simulator

  -- Point#1 gps settings - terminal moving inside geofence 0
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                  heading = 90,                       -- degrees
                  latitude = 50,                      -- degrees
                  longitude = 3,                      -- degrees, that is inside geofence 0
                 }

  -- Point#1 gps settings - terminal moving outisde geofence 0 in area with no defined geofence
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold,
                  heading = 90,                       -- degrees
                  latitude = 50,                      -- degrees
                  longitude = 1,                      -- degrees, that is outside geofence 0, no defined geozone
                 }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )
  ------------------------------------------------------------------------------------------------
  -- terminal moving inside geofence 0
  ------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])                                                    -- applying gps settings of Point#1
  framework.delay(GEOFENCE_INTERVAL + GPS_READ_INTERVAL + GPS_PROCESS_TIME)  -- waiting until terminal gets moving state inside geofence 0

  ------------------------------------------------------------------------------------------------
  -- terminal goes out of geofence 0 to area with no defined geofence
  ------------------------------------------------------------------------------------------------
  gateway.setHighWaterMark()                                    -- to get the newest messages
  gps.set(gpsSettings[2])                                       -- applying gps settings of Point#2
  timeOfEventTc = os.time()                                     -- to get the correct value for verification
  framework.delay(GEOFENCE_INTERVAL + GEOFENCE_HISTERESIS)      -- waiting longer than geofenceHisteresis to get ZoneExit message

  -- waiting for zoneExit message
  local expectedMins = {avlConstants.mins.zoneExit}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.zoneExit], "ZoneExit message not received")

  -- checking if correct zone ids are reported
  assert_equal(128 , tonumber(receivedMessages[avlConstants.mins.zoneExit].CurrentZoneId), "ZoneExit message contains wrong CurrentZoneId value")
  assert_equal(0 , tonumber(receivedMessages[avlConstants.mins.zoneExit].PreviousZoneId), "ZoneExit message contains wrong PreviousZoneId value")


end


--- TC checks if SpeedingStart message is sent when terminal is in area of two overlapping geofences and moves with the speed above speed limit of the geofence with lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds, geofence0SpeedLimit to 60 kmh
  -- geofence1SpeedLimit to 90 kmh, speedingTimeOver and speedingTimeUnder to 1 second and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 3 (that is inside geofence 0 and 1) and speed above geofence0SpeedLimit (SpeedingStart
  -- event should consider this geofence0SpeedLimit)
  -- and reports fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal sends SpeedingStart message and reported speed limit is the limit defined for geofence 0
function test_GeofenceSpeeding_WhenTwoGeofencesAreOverlappingSpeedlimitIsDefinedByGofenceWithLowerIdAnd_SpeedingMessageIsSent()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local GEOFENCE_0_SPEED_LIMIT = 60     -- in kmh
  local GEOFENCE_1_SPEED_LIMIT = 90     -- in kmh
  local SPEEDING_TIME_OVER = 1          -- in seconds
  local SPEEDING_TIME_UNDER = 1         -- in seconds

  -- gps settings: terminal inside ovelapping geofences: 0 and 1, moving with speed above GEOFENCE_0_SPEED_LIMIT threshold
  local gpsSettings = {
                        speed = GEOFENCE_0_SPEED_LIMIT + 10,     -- 10 kmh above speeding threshold
                        heading = 90,                            -- degrees
                        latitude = 50.3,                         -- degrees, this is are of two overlapping geofences (0 and 1)
                        longitude = 3,                           -- degrees, this is are of two overlapping geofences (0 and 1)
                       }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0 and 1
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=GEOFENCE_0_SPEED_LIMIT}}},
                                                      {Index=1,Fields={{Name="ZoneId",Value=1},{Name="SpeedLimit",Value=GEOFENCE_1_SPEED_LIMIT}}}}},}
	gateway.submitForwardMessage(message)

  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.speedingTimeOver, SPEEDING_TIME_OVER},
                                                {avlConstants.pins.speedingTimeUnder, SPEEDING_TIME_UNDER},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )
  -- *** Execute
  gateway.setHighWaterMark()                                 -- to get the newest messages
  timeOfEventTc = os.time()
  gps.set(gpsSettings)                                        -- applying gps settings - speed above GEOFENCE_0_SPEED_LIMIT to get the speeding state
  framework.delay(SPEEDING_TIME_OVER + GEOFENCE_INTERVAL)     -- wait until report is generated

  -- waiting for SpeedingStart message
  local expectedMins = {avlConstants.mins.speedingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.speedingStart], "SpeedingStart message not received")

  -- checking if correct speed limit is reported
  assert_equal(GEOFENCE_0_SPEED_LIMIT, tonumber(receivedMessages[avlConstants.mins.speedingStart].SpeedLimit))

end



--- TC checks if when terminal enters area of two overlapping geofences the ZoneEntry report contains the lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 1 (that is outside geofence 0 and 1) and speed above stationarySpeedThld to get moving state
  -- then simulate terminals position to latitude = 50.3, longitude = 3 (inside geofence 0 and geofence 1) and check if the ZoneEntry report contains CurrentZoneId = 0
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal sends ZoneEntry message and reported CurrentZoneId is correct
function test_Geofence_WhenTerminalEntersAreaOfTwoOverlappingGeofences_LowerGeofenceIdIsReported()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local gpsSettings = {}                -- gps settings table to be sent to simulator


  -- Point#1 - terminal moving outside geofence 0 and 1
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 10,     -- 10 kmh above moving threshold
                  heading = 90,                           -- degrees
                  latitude = 50.3,                        -- degrees, this is outside geofence 0 and 1
                  longitude = 1,                          -- degrees, this is outside geofence 0 and 1
                 }

  -- Point#1 - terminal inside geofence 0 and 1
  gpsSettings[2]={
                  speed = STATIONARY_SPEED_THLD + 10,     -- 10 kmh above moving threshold
                  heading = 90,                           -- degrees
                  latitude = 50.3,                        -- degrees, this is inside of two overlapping geofences (0 and 1)
                  longitude = 3,                          -- degrees, this is inside of two overlapping geofences (0 and 1)
                 }


  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                               }
                   )

  -- *** Execute
  ------------------------------------------------------------------------------------------------
  -- terminal moving outside geofence 0 and 1
  ------------------------------------------------------------------------------------------------

  gps.set(gpsSettings[1])                                       -- applying gps settings of Point#1
  -- wait until terminal goes to moving state outside geofence 0 and 1
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GEOFENCE_INTERVAL + GEOFENCE_HISTERESIS + 15)

  ------------------------------------------------------------------------------------------------
  -- terminal enters two overlapping geofences: 0 and 1
  ------------------------------------------------------------------------------------------------

  timeOfEventTc = os.time()
  gps.set(gpsSettings[2])                                                      -- applying gps settings of Point#2
  framework.delay(GPS_READ_INTERVAL + GEOFENCE_INTERVAL + GEOFENCE_HISTERESIS)  -- wait until report is generated

  -- receiving all messages - usage of getReturnMessages in this case is done on purpose (two reports are expected)
  local receivedMessages = gateway.getReturnMessages()
  -- search for ZoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneEntry))
  assert_not_nil(next(matchingMessages), "ZoneEntry message not received") -- checking if any ZoneEntry message has been received

  assert_equal(0, tonumber(matchingMessages[1].Payload.CurrentZoneId), "Wrong CurrentZoneId in 1st ZoneEntry report")
  assert_equal(0, tonumber(matchingMessages[2].Payload.CurrentZoneId), "Wrong CurrentZoneId in 2nd ZoneEntry report")


end



--- TC checks if when terminal exits area of two overlapping geofences the ZoneExit report contains the lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 3 (that is inside geofence 0 and 1) and speed above stationarySpeedThld to get moving state
  -- then simulate terminals position to latitude = 50.3, longitude = 1 (outside geofence 0 and geofence 1) and check if the ZoneExit report contains PreviousZoneId = 0
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- terminal sends ZoneExit message and reported PreviousZoneId is correct
function test_Geofence_WhenTerminalExitsAreaOfTwoOverlappingGeofences_TwoGeofenceIdsAreReported()

  -- *** Setup
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh
  local GEOFENCE_HISTERESIS = 1         -- in seconds
  local gpsSettings = {}                -- gps settings table to be sent to simulator


  -- Point#1 - terminal moving inside two overlapping geofences: 0 and 1
  gpsSettings[1]={
                  speed = STATIONARY_SPEED_THLD + 10,     -- 10 kmh above moving threshold
                  heading = 90,                           -- degrees
                  latitude = 50.3,                        -- degrees, this is inside geofence 0 and 1
                  longitude = 3,                          -- degrees, this is inside geofence 0 and 1
                 }

  -- Point#2 - terminal moving in area outside geofence 0 and 1
  gpsSettings[2]={
                    speed = STATIONARY_SPEED_THLD +10,     -- 10 kmh above moving threshold
                    heading = 90,                          -- degrees
                    latitude = 50.3,                       -- degrees, this is outside of two overlapping geofences (0 and 1)
                    longitude = 1,                         -- degrees, this is outside of two overlapping geofences (0 and 1)
                  }
  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                               }
                   )

  ----------------------------------------------------------------------------------------
  -- Terminal moving inside two overlapping geofences (geofence 0 and geofence 1)
  ----------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])                 -- applying gps settings
  framework.delay(GEOFENCE_INTERVAL + 25)  -- wait until terminal is in moving state inside two overlapping geofences

  ----------------------------------------------------------------------------------------
  -- Terminal moves outside two overlapping geofences
  ----------------------------------------------------------------------------------------

  timeOfEventTc = os.time()
  gateway.setHighWaterMark()                                    -- to get the newest messages
  gps.set(gpsSettings[2])                                       -- applying gps settings
  framework.delay(GEOFENCE_INTERVAL + GEOFENCE_HISTERESIS + 20) -- wait until report is generated

  -- receiving all messages - usage of getReturnMessages in this case is done on purpose (two reports are expected)
  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneExit messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneExit))
  assert_not_nil(next(matchingMessages), "No ZoneExit message received") -- checking if any ZoneExit message has been received

  ----------------------------------------------------------------------------------------
  -- Verification of two received ZoneExit messages
  ----------------------------------------------------------------------------------------
  assert_equal(0, tonumber(matchingMessages[1].Payload.PreviousZoneId), "Wrong PreviousZoneId in 1st ZoneEntry report")
  assert_equal(1, tonumber(matchingMessages[2].Payload.PreviousZoneId), "Wrong PreviousZoneId in 2nd ZoneEntry report")

end


--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone with defined DwellTimelimit and stays there for longer than
  -- this limit
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 240 minutes; then simulate terminals  position to latitude = 50.5, longitude = 4.5
  -- (that is inside zone 2); wait longer than geofence2DwellTime (1 minute) and check if GeoDwellStart message is sent, reports fields
  -- have correct values and Geodwelling is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerrThanDwellTimeLimitPeriod_GeoDwellStartMessageSent()

  -- *** Setup
  local GEOFENCE_HISTERESIS = 1       -- in seconds
  local GEOFENCE_2_DWELL_TIME = 1       -- in minutes
  local GEOFENCE_3_DWELL_TIME = 15      -- in minutes
  local ALL_ZONES_DWELL_TIME = 240      -- in minutes
  local MOVING_DEBOUNCE_TIME = 1        -- seconds
  local STATIONARY_SPEED_THLD = 5       -- kmh

  -- applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )


  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=GEOFENCE_2_DWELL_TIME}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=GEOFENCE_3_DWELL_TIME}}}}},
                                                    {Name="AllZonesTime",Value=ALL_ZONES_DWELL_TIME}}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 5,   -- kmh
                      heading = 90,                        -- degrees
                      latitude = 50.5,                     -- degrees, that is inside geofence 2
                      longitude = 4.5,                     -- degrees, that is inside geofence 2
                     }

  -- applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceHisteresis, GEOFENCE_HISTERESIS},
                                              }
                   )
  -- *** Execute
  gateway.setHighWaterMark()                      -- to get the newest messages
  local timeOfEvent = os.time()                  -- to get correct value in the report
  gps.set(gpsSettings)                            -- applying gps settings
  framework.delay(GEOFENCE_2_DWELL_TIME*60)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  -- waiting for GeoDwellStart message
  local expectedMins = {avlConstants.mins.geoDwellStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.geoDwellStart], "GeoDwellStart message not received")

  -- verification of report contents
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.geoDwellStart].Longitude), "GeoDwellStart message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.geoDwellStart].Latitude), "GeoDwellStart message has incorrect latitude value")
  assert_equal("GeoDwellStart", receivedMessages[avlConstants.mins.geoDwellStart].Name, "GeoDwellStart message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.geoDwellStart].EventTime), 60, "GeoDwellStart message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.geoDwellStart].Speed), "GeoDwellStart message has incorrect speed value")
  assert_equal(gpsSettings.heading, tonumber(receivedMessages[avlConstants.mins.geoDwellStart].Heading), "GeoDwellStart message has incorrect heading value")
  assert_equal(GEOFENCE_2_DWELL_TIME , tonumber(receivedMessages[avlConstants.mins.geoDwellStart].DwellTimeLimit), "GeoDwellStart message has incorrect DwellTimeLimit value")

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end


--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone with defined DwellTimelimit and stays there for longer than
  -- limit and GpsFixAge is reported for fixes older than 5 seconds
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 240 minutes; then simulate terminals  position to latitude = 50.5, longitude = 4.5
  -- (that is inside zone 2); change fixType to 1 (no valid fix provided) and wait longer than geofence2DwellTime (1 minute) and check if GeoDwellStart message is sent,
  -- eports fields have correct values and Geodwelling is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanDwellTimeLimitPeriod_GeoDwellStartMessageSentGpsFixAgeReported()
 local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 1       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 240      -- in minutes
  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+ 5,  -- kmh
              heading = 90,                    -- degrees
              latitude = 50.5,                 -- degrees, that is inside geofence 2
              longitude = 4.5,                 -- degrees, that is inside geofence 2
                     }

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )
  gateway.setHighWaterMark()                             -- to get the newest messages
  local timeOfEventTc = os.time()                       -- to get correct value in the report
  gps.set(gpsSettings)                                   -- applying gps settings
  framework.delay(movingDebounceTime+GPS_READ_INTERVAL+10)  -- wait until position of terminal is read
  gpsSettings.fixType = 1                                -- no valid fix provided
  gps.set(gpsSettings)                                   -- applying gps settings
  framework.delay(geofence2DwellTime*60)                -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellStart message not received") -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                          gps = gpsSettings,
                          messageName = "GeoDwellStart",
                          currentTime = timeOfEventTc,
                          DwellTimeLimit = geofence2DwellTime,     -- in minutes, DwellTimeLimit defined in geofence2
                          GpsFixAge = 95,
                        }
  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end


--- TC checks if GeoDwellStart message is not sent when terminal enters zone with defined DwellTimeLimit and stays there shorter than
  -- this limit
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 240 minutes; then simulate terminals  position to latitude = 50.5, longitude = 4.5
  -- (that is inside zone 2); wait shorter than geofence2DwellTime (1 minute) and check if GeoDwellStart message is not sent and terminal does not
  -- change Geodwelling state to true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is not sent, Geodwelling state false
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereShorterThanDwellTimeLimitPeriod_GeoDwellStartMessageNotSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 1       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 240      -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 50.5,                 -- degrees, that is inside geofence 2
              longitude = 4.5,                 -- degrees, that is inside geofence 2
                    }
 --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )


  gateway.setHighWaterMark()                      -- to get the newest messages
  local timeOfEventTc = os.time()                -- to get correct value in the report
  gps.set(gpsSettings)                            -- applying gps settings
  framework.delay(geofence2DwellTime*60-15)       -- waiting shorter than geofence2DwellTime (multiplied by 60 to convert minutes to seconds)

  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees, outside geofence 2
              longitude = 1,                   -- degrees, outside geofence 2
                    }

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_false(next(matchingMessages), "GeoDwellStart message not expected")  -- checking if any of GeoDwellStart messages has been received

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal incorrectly in the Geodwelling state")

end


--- TC checks if GeoDwellEnd message is correctly sent when terminal exits zone in which it was in GeoDwellTime state true
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 240 minutes; then simulate terminals  position to latitude = 50.5, longitude = 4.5
  -- (that is inside zone 2); wait longer than geofence2DwellTime (1 minute) and check if Geodwelling state is true; then simulate terminals positon
  -- outside the geofence 2 and check if GeoDwellEnd message has been sent, reported fields have correct values and Geodwelling becomes false
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellEnd message is sent after leaving the geofence in which terminal was dwelling, Geodwelling changed to false
function test_Geodwell_WhenTerminalInGeodwellingStateTrueExitsDefinedGeozone_GeoDwellEndMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 1       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 240      -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 50.5,                 -- degrees, that is inside geofence 2
              longitude = 4.5,                 -- degrees, that is inside geofence 2
                     }

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                                             -- applying gps settings
  framework.delay(geofence2DwellTime*60+geofenceInterval+10)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees, that is outside geofence 2
              longitude = 1,                   -- degrees, that is outside geofence 2
                     }

  gateway.setHighWaterMark()                      -- to get the newest messages
  local timeOfEventTc = os.time()                -- to get correct value in the report
  gps.set(gpsSettings)                            -- applying gps settings

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellEnd),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellEnd message not received") -- checking if any of GeoDwellEnd messages has been received

  local expectedValues={
                        gps = gpsSettings,
                        messageName = "GeoDwellEnd",
                        currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(message, expectedValues)    -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal unexpectedly in GeoDwell tate")

end



--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone and and stays there longer than DefaultGeoDwellTime
  -- but there are no defined DwellTimelimits
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second and DefaultGeoDwellTime to 1 minute;
  -- then simulate terminals  position to latitude = 50.3, longitude = 3.1 (that is inside zone 1); wait longer than geofence2DwellTime (1 minute)
  -- and check if GeoDwellStart message is sent, reports fields have correct values and Geodwelling is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching DefaultGeoDwellTime and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanDefaultGeoDwellTimePeriod_GeoDwellStartMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local defaultGeoDwellTime = 1      -- in minutes

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 50.3,                 -- degrees, that is inside geofence 1
              longitude = 3.1,                 -- degrees, that is inside geofence 1
                     }

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                             }

                   )
  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.defaultGeoDwellTime, defaultGeoDwellTime},
                                              }

                   )
  gateway.setHighWaterMark()                      -- to get the newest messages
  local timeOfEventTc = os.time()                 -- to get correct value in the report
  gps.set(gpsSettings)                            -- applying gps settings
  framework.delay(defaultGeoDwellTime*60)         -- waiting until defaultGeoDwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellStart message not received") -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = defaultGeoDwellTime     -- in minutes, defaultGeoDwellTime
                        }
  avlHelperFunctions.reportVerification(message, expectedValues) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end


--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone with dwell limit defined in AllZonesTime
  -- and stays there longer than limit
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 1 minute; then simulate terminals  position to latitude = 50.3, longitude = 3.1
  -- (that is inside zone 1); wait longer than AllZonesTime (1 minute) and check if GeoDwellStart message is sent, reports fields
  -- have correct values and Geodwelling state is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanDwellTimeLimitDefinedForAllZones_GeoDwellStartMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 5       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 1        -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}
	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 50.3,                 -- degrees, that is inside geofence 1, it has allZonesDwellTime limit
              longitude = 3.1,                 -- degrees, that is inside geofence 1, it has allZonesDwellTime limit
                     }

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )
  gateway.setHighWaterMark()                     -- to get the newest messages
  local timeOfEventTc = os.time()               -- to get correct value in the report
  gps.set(gpsSettings)                           -- applying gps settings
  framework.delay(allZonesDwellTime*60)          -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellStart message not received") -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = AllZonesTime     -- in minutes, AllZonesTime defined in geofence 1
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end


--- TC checks if GeoDwellStart message is correctly sent when terminal dwells in area with no defined geofence and DwellTimes for zone 128 is defined
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 128 to 1 minute and defaultGeoDwellTime to 2 minutes; then simulate terminals position inside any of the defined geofences latitude = 50.5,
  -- longitude = 4.5 (that is inside zone 2); then change terminals position to inside zone 128 (longitude 1, latitude = 1) and wait longer than geofence128DwellTime
  -- (1 minute) and check if GeoDwellStart message is sent, reports fields have correct values and Geodwelling state is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersAreaWithNoDefinedGeozoneAndDwellsThereForPeriodAboveThldDefinedForZone128_GeoDwellStartMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence128DwellTime = 1     -- in minutes
  local defaultGeoDwellTime = 2      -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=128},{Name="DwellTime",Value=geofence128DwellTime}}},
                                                    }}}


	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                      -- kmh
              heading = 90,                   -- degrees
              latitude = 50.5,                -- degrees, that is outside geofence 128
              longitude = 4.5,                -- degrees, that is outside geofence 128
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.defaultGeoDwellTime, defaultGeoDwellTime},
                                              }

                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                           -- applying gps settings
  framework.delay(10)                             -- wait until terminal is for sure outside the geofence 128

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                      -- kmh
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees, that is inside geofence 128
              longitude = 1,                  -- degrees, that is inside geofence 128
                     }
  gps.set(gpsSettings)                           -- applying gps settings

  gateway.setHighWaterMark()                     -- to get the newest messages
  local timeOfEventTc = os.time()               -- to get correct value in the report
  framework.delay(geofence128DwellTime*60)       -- waiting until geofence128DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellStart message not received") -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence128DwellTime     -- in minutes, geofence128DwellTime defined in geofence 128
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")


end

--- TC checks if GeoDwellStart message is correctly sent and DwellTime limit correctly recognized if terminal dwells in area of two overlapping geozones with different
  -- dwell limits (lower geofence ID should be recognized as the current geofence)
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for geofence 2 to 1 minute, geofence 3 to 15 minutes
  -- and defaultGeoDwellTime to 2 minutes; then simulate terminals position to latitude = 50.5, longitude = 4.8 (that is inside zone 2 and zone 3); wait longer than geofence2DwellTime
  -- (1 minute) but shorter than geofence3DwellTime (15 minutes) and check if GeoDwellStart message is sent, reports fields have correct values and Geodwelling state is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalStaysInAreaOfTwoOverlappingGeozonesForPeriodLongerThanDwellLimitDefinedForZoneWithLowerId_GeoDwellStartMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 1       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 10       -- in minutes
  local defaultGeoDwellTime = 2      -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}


	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                      -- kmh
              heading = 90,                   -- degrees
              latitude = 50.3,                -- degrees, that is inside geofence 2 and 3
              longitude = 4.8,                -- degrees, that is inside geofence 2 and 3
                      }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.defaultGeoDwellTime, defaultGeoDwellTime},
                                              }

                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                          -- applying gps settings

  gateway.setHighWaterMark()                                     -- to get the newest messages
  local timeOfEventTc = os.time()                                -- to get correct value in the report
  framework.delay(geofence2DwellTime*60+geofenceInterval)        -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "GeoDwellStart message not received") -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence2DwellTime     -- in minutes, geofence2DwellTime defined in geofence 2
                        }
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end

--- TC checks if GeoDwellStart message is correctly sent and DwellTime limit correctly recognized if terminal dwells in area of two overlapping geozones with different
  -- dwell limits (lower geofence ID should be recognized as the current geofence)
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for geofence 2 to 15 minutes, geofence 3 to 1 minute
  -- and defaultGeoDwellTime to 2 minutes; then simulate terminals position to latitude = 50.5, longitude = 4.8 (that is inside zone 2 and zone 3); wait longer than geofence3DwellTime
  -- (1 minute) but shorter than geofence2DwellTime (15 minutes) and check if GeoDwellStart message is not sent, Geodwelling state is false
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is not sent after reaching dwell limit for geofence with higher ID
function test_Geodwell_WhenTerminalStaysInAreaOfTwoOverlappingGeozonesForPeriodShorterThanDwellLimitDefinedForZoneWithLowerId_GeoDwellStartMessageNotSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10       -- in seconds
  local geofenceHisteresis = 1      -- in seconds
  local geofence2DwellTime = 15     -- in minutes
  local geofence3DwellTime = 1      -- in minutes
  local allZonesDwellTime = 10      -- in minutes
  local defaultGeoDwellTime = 2     -- in minutes

  -- setting ZoneDwellTimes for geofences
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoDwellTimes}
	message.Fields = {{Name="ZoneDwellTimes",Elements={{Index=0,Fields={{Name="ZoneId",Value=2},{Name="DwellTime",Value=geofence2DwellTime}}},
                                                    {Index=1,Fields={{Name="ZoneId",Value=3},{Name="DwellTime",Value=geofence3DwellTime}}}}},
                                                    {Name="AllZonesTime",Value=allZonesDwellTime}}


	gateway.submitForwardMessage(message)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                      -- kmh
              heading = 90,                   -- degrees
              latitude = 50.3,                -- degrees, that is inside geofence 2 and 3
              longitude = 4.8,                -- degrees, that is inside geofence 2 and 3
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.defaultGeoDwellTime, defaultGeoDwellTime},
                                              }

                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                          -- applying gps settings

  gateway.setHighWaterMark()                    -- to get the newest messages
  local timeOfEventTc = os.time()              -- to get correct value in the report
  framework.delay(geofence3DwellTime*60+10)     -- waiting until geofence3DwellTime time passes (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_false(next(matchingMessages), "GeoDwellStart message not expected")  -- checking if any of GeoDwellStart messages has been received

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal incorrectly in the Geodwelling state")


end




