-----------
-- GPS test module
-- - contains gps related test cases
-- @module TestGPSModule


local cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
local lunatest              = require "lunatest"
local avlMessagesMINs       = require("MessagesMINs")           -- the MINs of the messages are taken from the external file
local avlPopertiesPINs      = require("PropertiesPINs")         -- the PINs of the properties are taken from the external file
local avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
local avlAgentCons          = require("AvlAgentCons")

-- global variables used in the tests
gpsReadInterval   = 1 -- used to configure the time interval of updating the position , in seconds


-- Setup and Teardown


--- suite_setup function ensures that terminal is not in the moving state and not in the low power mode
 -- it sends fences.dat file to the terminal
 -- executed before each test suite
 -- * actions performed:
 -- lpmTrigger is set to 0 so that nothing can put terminal into the low power mode
 -- function checks if terminal is not the low power mode (condition necessary for all GPS related test cases)
 -- *initial conditions:
 -- running Terminal Simulator with installed AVL Agent, running Modem Simulator with Gateway Web Service and
 -- GPS Web Service switched on
 -- *Expected results:
 -- lpmTrigger set correctly and terminal is not in the Low Power mode
 -- geofences file successfully send to the terminal
function suite_setup()

 -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.lpmTrigger, 0},
                                             }
                    )
  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")


  -- sending fences.dat file with definiton of geofences used in TCs
  local message = {SIN = 24, MIN = 1}
  message.Fields = {{Name="path",Value="/data/svc/geofence/fences.dat"},{Name="offset",Value=0},{Name="flags",Value="Overwrite"},{Name="data",Value="ABIABQAtxsAAAr8gAACcQAAAAfQEagAOAQEALg0QAAK/IAAATiABnA=="}}
 	gateway.submitForwardMessage(message)

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
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state
function setup()

  lsf.setProperties(20,{
                        {15,gpsReadInterval}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                                 -- gps will be read every gpsReadInterval (in seconds)
                      }
                    )

  local stationaryDebounceTime = 1      -- seconds
  local stationarySpeedThld = 5         -- kmh

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                             }
                    )


  -- gps settings table
  local gpsSettings={
              heading = 90,                 -- degrees
              speed = 0,                    -- to get stationary state
              fixType=3,                    -- valid 3D gps fix
              simulateLinearMotion = false, -- terminal not moving
                     }

  -- set the speed to zero and wait for stationaryDebounceTime to make sure the moving state is false
  gps.set(gpsSettings) -- applying settings of gps simulator
  framework.delay(stationaryDebounceTime+gpsReadInterval+3) -- three seconds are added to make sure the gps is read and processed by agent
  framework.delay(3)                                        -- this delay is for reliability reasons
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  -- assertion gives the negative result if terminal does not change the moving state to false
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal in the moving state")


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
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 2.9977 (that is edge of
  -- zone 0); set heading to 90 (moving towards east) and simulate linear motion with the speed of 99 kmh;
  -- wait until terminal enters zone 0 and then check if ZoneEntry message has been sent; verify the fields of the report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal enters zone 0 and ZoneEntry message has been sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriodZoneEntryMessageSent()

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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))

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
  -- set movingDebounceTime to 1 second, stationarySpeedThld to 5 kmh; geofenceEnabled to true, geofenceInterval to 50 seconds and
  -- geofenceHisteresis to 1 second; simulate terminals initial position to latitude = 50, longitude = 2.9977 (that is edge of
  -- zone 0); set heading to 90 (moving towards east) and simulate linear motion with the speed of 99 kmh;
  -- let terminal go through the zone 0 (that takes ca 36 seconds) and then check if ZoneEntry message has not been sent;
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- terminal goes through zone 0 and ZoneEntry message is not sent
function test_Geofence_WhenTerminalEntersDefinedGeozoneAndStaysThereShorterThanGeofenceHisteresisPeriodZoneEntryMessageNotSent()

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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))
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
function test_Geofence_WhenTerminalExitsDefinedGeozoneForTimeLongerThanGeofenceHisteresisPeriodZoneExitMessageSent()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local geofenceEnabled = true       -- to enable geofence feature
  local geofenceInterval = 10         -- in seconds
  local geofenceHisteresis = 1       -- in seconds

  --applying properties of AVL service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  framework.delay(geofenceHisteresis+geofenceInterval)       -- terminal enters geofence 0 and moving state true

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
  framework.delay(geofenceHisteresis+geofenceInterval)    -- terminal enters geofence 128

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneExit messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneExit))
  print(framework.dump(matchingMessages))
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
function test_GeofenceSpeeding_WhenTerminalIsInZoneWithDefinedSpeedLimitAndSpeedIsAboveThldForPeriodAboveThldSpeedingStartMessageSent()

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
  local message = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.setGeoSpeedLimits}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)


  --applying properties of AVL service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1)  -- to get the moving state outside geofence 0

  -- gps settings: terminal inside geofence 0 and speed above geofence0SpeedLimit
  local gpsSettings={
              speed = geofence0SpeedLimit+10 , -- 10 kmh, above speeding threshold
              heading = 90,                    -- degrees
              latitude = 50,                   -- degrees
              longitude = 3,                   -- degrees, iniside geofence 0
              simulateLinearMotion = false,
                     }

  gateway.setHighWaterMark()                         -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+geofenceInterval) -- waiting until terminal enters the zone and the report is generated
  timeOfEventTc = os.time()                          -- to get the correct value in the report

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))

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
function test_GeofenceSpeeding_WhenTerminalIsInSpeedingStateAndEntersZoneWithDefinedSpeedLimitAndSpeedIsBelowThldForPeriodAboveThlSpeedingEndSent()

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
  local message = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.setGeoSpeedLimits}
	local message = {SIN = 126, MIN = 7}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}},{Index=1,Fields={{Name="ZoneId",Value=128},{Name="SpeedLimit",Value=geofence128SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)

  --applying properties of AVL service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  gps.set(gpsSettings)
  framework.delay(speedingTimeOver+gpsReadInterval+10)  -- to get the speeding state outside geofence 0 (inside 128)


  --checking the state of terminal, speeding state is ecpected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingEnd))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingEnd",
                  currentTime = timeOfEventTc,
                  maxSpeed = geofence128SpeedLimit+10,   -- maximal registered speed
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  --checking the state of terminal, speeding state is not expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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
function test_Geofence_WhenTerminalEntersAreaWithNoDefinedGeozoneAndStaysThereLongerThanGeofenceHisteresisPeriodZoneId128IsReportedInZoneExitMessage()

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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  framework.delay(geofenceInterval+geofenceHisteresis+5)   -- waiting longer than geofenceHisteresis

  local receivedMessages = gateway.getReturnMessages()
  -- look for zoneEntry messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneExit))
  assert_true(next(matchingMessages), "ZoneExit report not received")   -- checking if any ZoneEntry message has been caught

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
function test_GeofenceSpeeding_WhenTwoGeofencesAreOverlappingSpeedlimitIsDefinedByGofenceWithLowerIdAndSpeedingMessageIsSent()

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
  local message = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.setGeoSpeedLimits}
	local message = {SIN = 126, MIN = 7}
	message.Fields = {{Name="ZoneSpeedLimits",Elements={{Index=0,Fields={{Name="ZoneId",Value=0},{Name="SpeedLimit",Value=geofence0SpeedLimit}}},{Index=1,Fields={{Name="ZoneId",Value=1},{Name="SpeedLimit",Value=geofence1SpeedLimit}}}}},}
	gateway.submitForwardMessage(message)

  --applying properties of AVL service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                                {avlPropertiesPINs.speedingTimeUnder, speedingTimeUnder},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
                                              }
                   )

  timeOfEventTc = os.time()
  gps.set(gpsSettings) -- applying gps settings
  framework.delay(speedingTimeOver+geofenceInterval+15)  -- speed above geofence0SpeedLimit to get the speeding state,

  -- receiving all messages
  local receivedMessages = gateway.getReturnMessages()
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.speedingStart))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "SpeedingStart",
                  currentTime = timeOfEventTc,
                  speedLimit = geofence0SpeedLimit,   -- the speed limit of geofence 0 should be considered
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  --checking the state of terminal, speeding state is expected
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
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
function test_Geofence_WhenTerminalEntersAreaOfTwoOverlappingGeofencesLowerGeofenceIdIsReported()

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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneEntry))

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
function test_Geofence_WhenTerminalExitsAreaOfTwoOverlappingGeofencesLowerGeofenceIdIsReported()

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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                                {avlPropertiesPINs.geofenceInterval, geofenceInterval},
                                                {avlPropertiesPINs.geofenceHisteresis, geofenceHisteresis},
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
  -- look for SpeedingStart messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.zoneExit))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ZoneExit",
                  currentTime = timeOfEventTc,
                  PreviousZoneId = 0,         -- lower Id should be reported
                       }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end



--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()


