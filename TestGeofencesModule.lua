-----------
-- GPS test module
-- - contains gps related test cases
-- @module TestGPSModule


local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file

-- global variables used in the tests
gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds
terminalInUse = avlHelperFunctions.getTerminalHardwareVersion()   -- 600, 700 and 800 available

local avlConstants =  require("AvlAgentConstants")
local lsfConstants = require("LsfConstants")

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
  local message = {SIN = 24, MIN = 1}
	message.Fields = {{Name="path",Value="/data/svc/geofence/fences.dat"},{Name="offset",Value=0},{Name="flags",Value="Overwrite"},{Name="data",Value="ABIABQAtxsAAAr8gAACcQAAAAfQEagAOAQEALg0QAAK/IAAATiABnAASAgUALjvwAAQesAAAw1AAAJxABCEAEgMFAC4NEAAEZQAAAFfkAABEXAKX"}}
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

--- the setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets gpsReadInterval (in position service) to the value of gpsReadInterval
  -- executed before each unit test
  -- *actions performed:
  -- setting of the gpsReadInterval (in the position service) is made using global gpsReadInterval variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- by saving deleteData property it deletes Geo-speeding and Geo-dwell limits
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state, Geo-speeding and geo-dwell limits are removed
function setup()


  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                               }
                    )

  -- setting properties of the AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.deleteData, 3},      -- delete Geo-speeding limits
                                             }

                    )
 framework.delay(1)   -- wait until message is processed

 -- setting properties of the AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.deleteData, 2},      -- delete Geo-dwell time limits
                                            }
                   )

  avlHelperFunctions.putTerminalIntoStationaryState()

  -- gps settings table
  local gpsSettings={
              longitude = 0,                -- degrees, outside any of the defined geofences
              latitude = 0,                 -- degrees, outside any of the defined geofences
              heading = 90,                 -- degrees
              speed = 0,                    -- to get stationary state
              fixType= 3,                    -- valid 3D gps fix
              simulateLinearMotion = false, -- terminal not moving
                     }

  -- put terminal outside of any of the defined geozones
  gps.set(gpsSettings) -- applying settings of gps simulator



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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal enters zone 0 and ZoneEntry message has been sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriod_ZoneEntryMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10         -- in seconds
  local geofenceHisteresis = 1       -- in seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 2,                   -- degrees, that is outside geofence 0
              simulateLinearMotion = false,
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)     -- applying gps settings
  framework.delay(movingDebounceTime+gpsReadInterval+2)       -- waiting until terminal gets Moving state true

  -- changing gps settings
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  gps.set(gpsSettings)     -- applying gps settings
  framework.delay(geofenceHisteresis+geofenceInterval)       -- waiting for the ZoneEntry message to be generated

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneEntry))
  assert_not_nil(next(matchingMessages), "ZoneEntry message not received")  -- checking if any of ZoneEntry messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneEntry",
                  currentTime = os.time(),
                  CurrentZoneId = 0     -- the number of the zone defined in this area
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

end


--- TC checks if ZoneEntry message is not sent when terminal enters defined zone and stays there shorter longer than
  -- geofenceHisteresis period
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 second and
  -- geofenceHisteresis to 1 second; simulate terminals position to latitude = 50, longitude = 3 but for time shorter than geofenceHisteresis
  -- and check if ZoneEntry message has not been sent
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal stays in zone 0 shorter than geofenceHisteresis and ZoneEntry message is not sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereShorterThanGeofenceHisteresisPeriod_ZoneEntryMessageNotSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 50      -- in seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 2,                   -- degrees, that is outside geofence 0
              simulateLinearMotion = false,
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)     -- applying gps settings
  framework.delay(4)       -- waiting until terminal gets Moving state true

  -- changing gps settings - inside the geofence 0
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  gps.set(gpsSettings)                  -- applying gps settings
  gateway.setHighWaterMark()            -- to get the newest messages
  framework.delay(geofenceInterval+5)   -- waiting shorter than geofenceHisteresis

  -- changing gps settings - outside the geofence 0
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 2,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneEntry))
  assert_false(next(matchingMessages), "ZoneEntry report not expected")   -- checking if any ZoneEntry message has been caught

end


--- TC checks if ZoneExit message is correctly sent when terminal exits defined zone and enters undefined zone
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 seconds and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 3 (that is inside of
  -- geofence 0) and speed above stationarySpeedThld (to get moving state true); then change terminals position outside geofence 0
  -- (latitude = 50, longitude = 1) and check if ZoneExit message has been sent and the fields in report have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal exits goefence 0 and ZoneExit message has been sent
function test_Geofence_WhenTerminalExitsDefinedGeozoneForTimeLongerThanGeofenceHisteresisPeriod_ZoneExitMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10         -- in seconds
  local geofenceHisteresis = 1       -- in seconds

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  -- gps settings - terminal inside geofence 0
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  gps.set(gpsSettings)                                       -- applying gps settings
  framework.delay(geofenceHisteresis+geofenceInterval+10)    -- terminal enters geofence 0 and moving state true

  -- changing gps settings - terminal goes outside geofence 0  to undefined geofence (128)
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 1,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  local timeOfEventTc = os.time()
  gateway.setHighWaterMark()                              -- to get the newest messages
  gps.set(gpsSettings)                                    -- applying gps settings
  framework.delay(geofenceHisteresis+geofenceInterval+10) -- terminal enters geofence 128

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneExit messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneExit))
  assert_not_nil(next(matchingMessages), "ZoneExit message not received") -- checking if any ZoneExit message has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneExit",
                  currentTime = timeOfEventTc,
                  CurrentZoneId = 128,     -- terminal goes out from geofence 0 to undefined geofence
                  PreviousZoneId = 0
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal sends SpeedingStart message in geofence 0 and fields in report have correct values
function test_GeofenceSpeeding_WhenTerminalIsInZoneWithDefinedSpeedLimitAndSpeedIsAboveThldForPeriodAboveThld_SpeedingStartMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true          -- to enable geofence feature
  local geofenceInterval = 10         -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence0SpeedLimit = 30     -- in kmh
  local defaultSpeedLimit = 100      -- in kmh
  local speedingTimeOver = 1         -- in seconds


  -- gps settings: terminal outside geofence 0, moving with speed above geofence0SpeedLimit threshold
  local gpsSettings={
              speed = geofence0SpeedLimit+1,   -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 2,                   -- degrees, outside geofence 0
              simulateLinearMotion = false,
                     }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)


  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+10)  -- to get the moving state outside geofence 0

  -- gps settings: terminal inside geofence 0 and speed above geofence0SpeedLimit
  local gpsSettings={
              speed = geofence0SpeedLimit+10 , -- 10 kmh, above speeding threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, inside geofence 0
              simulateLinearMotion = false,
                     }

  gateway.setHighWaterMark()                         -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+geofenceInterval+10) -- waiting until terminal enters the zone and the report is generated
  timeOfEventTc = os.time()                             -- to get the correct value in the report

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.speedingStart))
  assert_not_nil(next(matchingMessages), "SpeedingStart message not received") -- checking if any SpeedingStart message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = timeOfEventTc,
                  SpeedLimit = geofence0SpeedLimit,   -- speed limit of detected Speeding event should be the one defined in the geofence

                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end



--- TC checks if SpeedingEnd message is sent when terminal is in speeding state and moves to geofence with speed limit higher than current speed
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds, geofence0SpeedLimit to 90 kmh
  -- geofence128SpeedLimit to 60 kmh, speedingTimeOver and speedingTimeUnder to 1 second and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50, longitude = 2 (that is outside of geofence 0) and speed above geofence128SpeedLimit - to get speeding
  -- state; then change terminals position to inside of the geofence 0 (speed is below geofence0SpeedLimit) and check if speedingEnd message is sent
  -- and reports fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal sends SpeedingEnd message in geofence 0 and fields in report have correct values
function test_GeofenceSpeeding_WhenTerminalIsInSpeedingStateAndEntersZoneWithDefinedSpeedLimitAndSpeedIsBelowThldForPeriodAboveThl_SpeedingEndMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence0SpeedLimit = 90     -- in kmh
  local geofence128SpeedLimit = 60   -- in kmh
  local speedingTimeOver = 1         -- in seconds
  local speedingTimeUnder = 1        -- in seconds


  -- gps settings: terminal outside geofence 0, moving with speed above defaultSpeedLimit threshold
  local gpsSettings={
              speed = geofence128SpeedLimit+10,   -- 10 kmh above speeding threshold
              heading = 90,                       -- degrees
              latitude = 50,                      -- degrees
              longitude = 2,                      -- degrees, outside geofence 0 (inside 128)
              simulateLinearMotion = false,
                     }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0 and 128
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	local message = {SIN = 126, MIN = 7}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}},{Index=1,Fields={{Name="ZoneId",Value=128},{Name="SpeedLimit",Value=geofence128SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+10)  -- to get the speeding state outside geofence 0 (inside 128)


  --checking the state of terminal, speeding state is ecpected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

  -- gps settings: terminal inside geofence 0 and speed above geofence128SpeedLimit
  local gpsSettings={
              speed = geofence128SpeedLimit+10 ,    -- 10 kmh above speeding threshold but below geofence0SpeedLimit
              heading = 90,                         -- degrees
              latitude = 50,                        -- degrees
              longitude = 3,                        -- degrees, iniside geofence 0
              simulateLinearMotion = false,
                     }

  gateway.setHighWaterMark()                             -- to get the newest messages
  timeOfEventTc = os.time()                              -- to get the correct value in the report
  gps.set(gpsSettings)
  framework.delay(speedingTimeUnder+geofenceInterval+15) -- waiting until terminal enters the zone and the speeding end report is generated


  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for SpeedingEnd messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.speedingEnd))
  assert_not_nil(next(matchingMessages), "SpeedingEnd message not received") -- checking if any SpeedingEnd message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingEnd",
                  currentTime = timeOfEventTc,
                  maxSpeed = geofence128SpeedLimit+10,   -- maximal registered speed
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  --checking the state of terminal, speeding state is not expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal incorrectly in the speeding state")

end

--- TC checks if ZoneExit message is sent and reported geofence ID is 128 when terminal leaves area with defined geofence and stays
  -- there longer than geofenceHisteresis period
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 10 seconds and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 3 (that is inside of
  -- zone 0); then change terminals position to latitude = 50, longitude = 1 (this is area with no defined geofence) and check
  -- if in ZoneExit message reported CurrentZoneId is 128;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- ZoneExit message is sent when terminal goes out of the area with defined geofence and reported id of zone is 128
function test_Geofence_WhenTerminalEntersAreaWithNoDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriod_ZoneId128IsReportedInZoneExitMessage()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, that is inside geofence 0
              simulateLinearMotion = false,
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                                       -- applying gps settings
  framework.delay(geofenceInterval+geofenceHisteresis)       -- waiting until terminal gets Moving state true

  -- changing gps settings - outside the geofence 0
  local gpsSettings={
              speed = 5,                       -- one kmh above threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 1,                   -- degrees, that is outside geofence 0, no defined geozone
              simulateLinearMotion = false,
                     }

  gps.set(gpsSettings)                                     -- applying gps settings
  timeOfEventTc = os.time()                                -- to get the correct value for verification
  gateway.setHighWaterMark()                               -- to get the newest messages
  framework.delay(geofenceInterval+geofenceHisteresis+10)   -- waiting longer than geofenceHisteresis

  local receivedMessages = gateway.getReturnMessages()
  -- look for ZoneExit messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneExit))
  assert_not_nil(next(matchingMessages), "ZoneExit message not received") -- checking if any ZoneExit message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneExit",
                  currentTime = timeOfEventTc,
                  CurrentZoneId = 128,       -- no geofence defined in this area - expected ID 128
                  PreviousZoneId = 0         -- for latitude 50 and longitude 3 geofence ID is 0

                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

end



--- TC checks if SpeedingStart message is sent when terminal is in area of two overlapping geofences and moves with the speed above speed limit of the geofence with lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds, geofence0SpeedLimit to 60 kmh
  -- geofence1SpeedLimit to 90 kmh, speedingTimeOver and speedingTimeUnder to 1 second and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 3 (that is inside geofence 0 and 1) and speed above geofence0SpeedLimit (SpeedingStart
  -- event should consider this geofence0SpeedLimit)
  -- and reports fields have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal sends SpeedingStart message and reported speed limit is the limit defined for geofence 0
function test_GeofenceSpeeding_WhenTwoGeofencesAreOverlappingSpeedlimitIsDefinedByGofenceWithLowerIdAnd_SpeedingMessageIsSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence0SpeedLimit = 60     -- in kmh
  local geofence1SpeedLimit = 90     -- in kmh
  local speedingTimeUnder = 1        -- in seconds
  local speedingTimeOver = 1        -- in seconds


  -- gps settings: terminal inside geofence 0 and , moving with speed above geofence0SpeedLimit threshold
  local gpsSettings={
              speed = geofence0SpeedLimit+10,     -- 10 kmh above speeding threshold
              heading = 90,                       -- degrees
              latitude = 50.3,                    -- degrees, this is are of two overlapping geofences (0 and 1)
              longitude = 3,                      -- degrees, this is are of two overlapping geofences (0 and 1)
              simulateLinearMotion = false,
                     }

  -- sending setGeoSpeedLimits message to define speed limit in geofence 0 and 1
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setGeoSpeedLimits}
	local message = {SIN = 126, MIN = 7}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}},{Index=1,Fields={{Name="ZoneId",Value=1},{Name="SpeedLimit",Value=geofence1SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.speedingTimeOver, speedingTimeOver},
                                                {avlConstants.pins.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  timeOfEventTc = os.time()
  gps.set(gpsSettings) -- applying gps settings
  framework.delay(speedingTimeOver+geofenceInterval+15)  -- speed above geofence0SpeedLimit to get the speeding state,

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.speedingStart))
  assert_not_nil(next(matchingMessages), "SpeedingStart message not received") -- checking if any SpeedingStart message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = timeOfEventTc,
                  speedLimit = geofence0SpeedLimit,   -- the speed limit of geofence 0 should be considered
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  --checking the state of terminal, speeding state is expected
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Speeding, "terminal not in the speeding state")

end


--- TC checks if when terminal enters area of two overlapping geofences the ZoneEntry report contains the lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 1 (that is outside geofence 0 and 1) and speed above stationarySpeedThld to get moving state
  -- then simulate terminals position to latitude = 50.3, longitude = 3 (inside geofence 0 and geofence 1) and check if the ZoneEntry report contains CurrentZoneId = 0
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal sends ZoneEntry message and reported CurrentZoneId is correct
function test_Geofence_WhenTerminalEntersAreaOfTwoOverlappingGeofences_LowerGeofenceIdIsReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds


  -- gps settings: terminal outside geofence 0, moving with speed above defaultSpeedLimit threshold
  local gpsSettings={
              speed = stationarySpeedThld+10,     -- 10 kmh above moving threshold
              heading = 90,                       -- degrees
              latitude = 50.3,                    -- degrees, this is outside geofence 0 and 1
              longitude = 1,                      -- degrees, this is outside geofence 0 and 1
              simulateLinearMotion = false,
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                  -- applying gps settings
  framework.delay(geofenceInterval+15)  -- to make sure terminal is outside geofence 0 and 1


  -- gps settings: terminal inside geofence 0 and 1
  local gpsSettings={
              speed = stationarySpeedThld+10,     -- 10 kmh above moving threshold
              heading = 90,                       -- degrees
              latitude = 50.3,                    -- degrees, this is inside of two overlapping geofences (0 and 1)
              longitude = 3,                      -- degrees, this is inside of two overlapping geofences (0 and 1)
              simulateLinearMotion = false,
                     }

  timeOfEventTc = os.time()
  gps.set(gpsSettings) -- applying gps settings
  framework.delay(geofenceInterval+15)  -- wait until report is generated

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for ZoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneEntry))
  assert_not_nil(next(matchingMessages), "ZoneEntry message not received") -- checking if any ZoneEntry message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneEntry",
                  currentTime = timeOfEventTc,
                  CurrentZoneId = 0,         -- lower Id should be reported
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end



--- TC checks if when terminal exits area of two overlapping geofences the ZoneExit report contains the lower ID
  -- *actions performed:
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to 1, geofenceInterval to 10 seconds and geofenceHisteresis to 1 second;
  -- simulate terminals initial position to latitude = 50.3, longitude = 3 (that is inside geofence 0 and 1) and speed above stationarySpeedThld to get moving state
  -- then simulate terminals position to latitude = 50.3, longitude = 1 (outside geofence 0 and geofence 1) and check if the ZoneExit report contains PreviousZoneId = 0
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal sends ZoneExit message and reported PreviousZoneId is correct
function test_Geofence_WhenTerminalExitsAreaOfTwoOverlappingGeofences_LowerGeofenceIdIsReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds


  -- gps settings: terminal inside geofence 0, moving with speed above defaultSpeedLimit threshold
  local gpsSettings={
              speed = stationarySpeedThld+10,     -- 10 kmh above moving threshold
              heading = 90,                       -- degrees
              latitude = 50.3,                    -- degrees, this is inside geofence 0 and 1
              longitude = 3,                      -- degrees, this is inside geofence 0 and 1
              simulateLinearMotion = false,
                     }

  --applying properties of AVL service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                  -- applying gps settings
  framework.delay(geofenceInterval+15)  -- to make sure terminal is outside geofence 0 and 1


  -- gps settings: terminal outside geofence 0 and 1
  local gpsSettings={
              speed = stationarySpeedThld+10,     -- 10 kmh above moving threshold
              heading = 90,                       -- degrees
              latitude = 50.3,                    -- degrees, this is outside of two overlapping geofences (0 and 1)
              longitude = 1,                      -- degrees, this is outside of two overlapping geofences (0 and 1)
              simulateLinearMotion = false,
                     }

  timeOfEventTc = os.time()
  gps.set(gpsSettings) -- applying gps settings
  framework.delay(geofenceInterval+15)  -- wait until report is generated

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneExit messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.zoneExit))
  assert_not_nil(next(matchingMessages), "ZoneExit message not received") -- checking if any ZoneExit message has been received
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneExit",
                  currentTime = timeOfEventTc,
                  PreviousZoneId = 0,         -- lower Id should be reported
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end


--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone with defined DwellTimelimit and stays there for longer than
  -- this limit
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second; send message setting DwellTimes for
  -- geofence 2 = 1 minute, geofence 3 = 15 minutes and AllZonesTime = 240 minutes; then simulate terminals  position to latitude = 50.5, longitude = 4.5
  -- (that is inside zone 2); wait longer than geofence2DwellTime (1 minute) and check if GeoDwellStart message is sent, reports fields
  -- have correct values and Geodwelling is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerrThanDwellTimeLimitPeriod_GeoDwellStartMessageSent()

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
              simulateLinearMotion = false,
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
  framework.delay(geofence2DwellTime*60+10)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence2DwellTime     -- in minutes, DwellTimeLimit defined in geofence2
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerrThanDwellTimeLimitPeriod_GeoDwellStartMessageSentGpsFixAgeReported()

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
              simulateLinearMotion = false,
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
  framework.delay(gpsReadInterval+3)              -- wait until position of terminal is read
  gpsSettings.fixType = 1                         -- no valid fix provided
  gps.set(gpsSettings)                            -- applying gps settings
  framework.delay(geofence2DwellTime*60+40)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence2DwellTime,     -- in minutes, DwellTimeLimit defined in geofence2
                  GpsFixAge = 101,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
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
              simulateLinearMotion = false,
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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
                     }

  --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {lsfConstants.pins.geofenceInterval, geofenceInterval},
                                                {lsfConstants.pins.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)                            -- applying gps settings
  framework.delay(geofence2DwellTime*60+10)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 5,                       -- kmh
              heading = 90,                    -- degrees
              latitude = 1,                    -- degrees, that is outside geofence 2
              longitude = 1,                   -- degrees, that is outside geofence 2
              simulateLinearMotion = false,
                     }

  gateway.setHighWaterMark()                      -- to get the newest messages
  local timeOfEventTc = os.time()                -- to get correct value in the report
  gps.set(gpsSettings)                            -- applying gps settings

  framework.delay(6)   -- wait until report is generated

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellEnd messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellEnd))
  assert_not_nil(next(matchingMessages), "GeoDwellEnd message not received")  -- checking if any of GeoDwellEnd messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellEnd",
                  currentTime = timeOfEventTc,
                                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Geodwelling, "Terminal not in Geodwelling state")

end


--- TC checks if GeoDwellStart message is correctly sent when terminal enters zone and and stays there longer than DefaultGeoDwellTime
  -- but there are no defined DwellTimelimits
  -- *actions performed:
  -- set geofenceEnabled to true, geofenceInterval to 10 seconds, geofenceHisteresis to 1 second and DefaultGeoDwellTime to 1 minute;
  -- then simulate terminals  position to latitude = 50.3, longitude = 3.1 (that is inside zone 1); wait longer than geofence2DwellTime (1 minute)
  -- and check if GeoDwellStart message is sent, reports fields have correct values and Geodwelling is true
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
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
  framework.delay(defaultGeoDwellTime*60+10)      -- waiting until defaultGeoDwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = defaultGeoDwellTime     -- in minutes, defaultGeoDwellTime
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- position of terminal outside of any of the defined geofences
  -- *expected results:
  -- GeoDwellStart message is sent after reaching dwell limit and report fields have correct values, terminal goes to Geodwelling true
function test_Geodwell_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanDwellTimeLimitDefinedForAllZones_GeoDwellStartMessageSent()

  local geofenceEnabled = true      -- to enable geofence feature
  local geofenceInterval = 10        -- in seconds
  local geofenceHisteresis = 1       -- in seconds
  local geofence2DwellTime = 1       -- in minutes
  local geofence3DwellTime = 15      -- in minutes
  local allZonesDwellTime = 1        -- in minutes
  local defaultGeoDwellTime = 2      -- in minutes

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
              simulateLinearMotion = false,
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
  gateway.setHighWaterMark()                     -- to get the newest messages
  local timeOfEventTc = os.time()               -- to get correct value in the report
  gps.set(gpsSettings)                           -- applying gps settings
  framework.delay(allZonesDwellTime*60+10)       -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = AllZonesTime     -- in minutes, AllZonesTime defined in geofence 1
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
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
              simulateLinearMotion = false,
                     }
  gps.set(gpsSettings)                           -- applying gps settings

  gateway.setHighWaterMark()                     -- to get the newest messages
  local timeOfEventTc = os.time()               -- to get correct value in the report
  framework.delay(geofence128DwellTime*60+10)    -- waiting until geofence128DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence128DwellTime     -- in minutes, geofence128DwellTime defined in geofence 128
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
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
  framework.delay(geofence2DwellTime*60+10)     -- waiting until geofence2DwellTime time passes and report is generated (multiplied by 60 to convert minutes to seconds)

  local receivedMessages = gateway.getReturnMessages()
  -- look for GeoDwellStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.geoDwellStart))
  assert_not_nil(next(matchingMessages), "GeoDwellStart message not received")  -- checking if any of GeoDwellStart messages has been received

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "GeoDwellStart",
                  currentTime = timeOfEventTc,
                  DwellTimeLimit = geofence2DwellTime     -- in minutes, geofence2DwellTime defined in geofence 2
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
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
              simulateLinearMotion = false,
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


--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


