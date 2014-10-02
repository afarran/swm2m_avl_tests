-----------
-- Periodic and distance reports test module
-- - contains test cases related to periodic and distance based reports
-- @module TestPeriodicReportsModule


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

  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")


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
  local geofenceEnabled = false       -- to enable geofence feature

  --setting properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                              {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                              {avlPropertiesPINs.stationaryDebounceTime, stationaryDebounceTime},
                                             }
                    )
 --applying properties of geofence service
  lsf.setProperties(avlAgentCons.geofenceSIN,{
                                                {avlPropertiesPINs.geofenceEnabled, geofenceEnabled, "boolean"},
                                             }
                   )


  -- gps settings table
  local gpsSettings={
              latitude = 1,
              longitude = 1,
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


--- TC checks if StationaryIntervalSat message is sent periodically when terminal is in stationary state
  -- *actions performed:
  -- check if terminal is in stationary state, set stationaryIntervalSat to 10 seconds, wait for
  -- 20 seconds and collect all the receive messages during that time; count the number of receivedMessages
  -- stationaryIntervalSat reports in collected messages; verify alle the fields of single report
  -- set stationaryIntervalSat to 0 to disable reports (not to cause any troubles in other TCs)ate
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- StationaryIntervalSat reports received periodically, content of the report is correct
function test_PeriodicStationaryIntervalSat_WhenTerminalStationaryAndStationaryIntervalSatGreaterThenZero_StationaryIntervalSatReportsMessageSentPeriodically()

  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  local stationaryIntervalSat = 10       -- seconds
  local numberOfReports = 2              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gateway.setHighWaterMark()                                -- to get the newest messages
  local timeOfEventTc = os.time()                          -- time of receiving first stationaryIntervalSat report
  framework.delay(stationaryIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))

  gpsSettings.heading = 361 -- for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "StationaryIntervalSat",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received stationaryIntervalSat reports is incorrect")

  -- back to stationaryIntervalSat = 0 to get no more reports
  local stationaryIntervalSat = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )


end



--- TC checks if StationaryIntervalSat message is sent periodically when terminal is in stationary state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- check if terminal is in stationary state, set stationaryIntervalSat to 5 seconds, wait for coldFixDelay plus
  -- 20 seconds and collect all the receive messages during that time; count the number of receivedMessages
  -- stationaryIntervalSat reports in collected messages; verify alle the fields of single report
  -- set stationaryIntervalSat to 0 to disable reports (not to cause eny troubles in other TCs)ate
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- StationaryIntervalSat reports received periodically, content of the report is correct
function test_PeriodicStationaryIntervalSat_WhenTerminalStationaryAndStationaryIntervalSatGreaterThanZero_StationaryIntervalSatMessageSentPeriodicallyGpxFixReported()

  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
                     }
  gps.set(gpsSettings)

  local stationaryIntervalSat = 5        -- seconds
  local numberOfReports = 5              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

                         --  to get fix older than 5 seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gps.set({fixType = 1})                      -- no fix provided
  framework.delay(avlAgentCons.coldFixDelay)

  gateway.setHighWaterMark()                               -- to get the newest messages

  local timeOfEventTc = os.time()                          -- time of receiving first stationaryIntervalSat report
  framework.delay(stationaryIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports


  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))

  gpsSettings.heading = 361 -- for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "StationaryIntervalSat",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 51,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[2], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received stationaryIntervalSat reports is incorrect")

  -- back to stationaryIntervalSat = 0 to get no more reports
  local stationaryIntervalSat = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

end



--- TC checks if StationaryIntervalSat message is deffered by Position message (for terminal in stationary state)
  -- *actions performed:
  -- set stationaryIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- simulate terminal in stationary state and send Position message request; then check if StationaryIntervalSat message
  -- has been correctly deffered - calculate difference in time between Position message and MovingIntervalSat message - that
  -- should be equal to full StationaryIntervalSat period if the report has been correctly deffered
  -- in the end set stationaryIntervalSat to 0 to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- StationaryIntervalSat message sent after full StationaryIntervalSat period (deffered by Position message)
function test_PeriodicStationaryIntervalSat_WhenTerminalInStationaryStateAndPositionEventOccurs_StationaryIntervalSatMessageSentAfterFullStationaryIntervalSatPeriodIfDeffered()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local stationaryIntervalSat = 10   -- seconds

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- for stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gps.set(gpsSettings)                       -- applying gps settings
  framework.delay(3)                         -- to make sure terminal is stationary
  gateway.setHighWaterMark()                 -- to get the newest messages
  local message = {SIN = 126, MIN = 1}      -- to trigger Position event
	gateway.submitForwardMessage(message)

  framework.delay(stationaryIntervalSat+3)  -- wait longer than stationaryIntervalSat receive report

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for stationaryIntervalSatMessage and Position messages
  local stationaryIntervalSatMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))
  local positionMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  -- checking if expected messages has been received
  assert_not_nil(next(stationaryIntervalSatMessage), "stationaryIntervalSat message message not received")   -- if StationaryIntervalSat message not received assertion fails
  assert_not_nil(next(positionMessage), "Position message not received")                                     -- if Position message not received assertion fails

  -- difference in time of occurence of Position report and StationaryIntervalSat report
  local differenceInTimestamps =  stationaryIntervalSatMessage[1].Payload.EventTime - positionMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full StationaryIntervalSat period is expected
  assert_equal(stationaryIntervalSat, differenceInTimestamps, 2, "StationaryIntervalSat has not been correctly deffered")

  -- back to stationaryIntervalSat = 0 to get no more reports
  stationaryIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},

                                             }
                   )

end


--- TC checks if MovingIntervalSat message is periodically sent when terminal is in moving state
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime; then check if terminal is
  -- correctly in the moving state then wait for 20 seconds and check if movingIntervalSat messages have been
  -- sent and verify the fields of single report; after verification set movingIntervalSat to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndMovingIntervalSatGreaterThanZero_MovingIntervalSatMessageSentPeriodically()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 10       -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  framework.delay(movingIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingIntervalSat",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received MovingIntervalSat reports is incorrect")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

end


--- TC checks if MovingIntervalSat message is periodically sent when terminal is in moving state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime; then check if terminal is
  -- correctly in the moving state; then change fixType to 1 (no fix) and  wait for coldFixDelay plus 20 seconds
  -- after that check if movingIntervalSat messages have been sent and verify the fields of single report;
  -- after verification set movingIntervalSat to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndMovingIntervalSatGreaterThanZero_MovingIntervalSatMessageSentPeriodicallyGpsFixReported()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 10       -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )



  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1) -- one second is added to make sure the gps is read and processed by agent

  -- checking if terminal is moving state
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal not in the moving state")

  gps.set({fixType = 1})    -- no fix displayed
  framework.delay(avlAgentCons.coldFixDelay)
  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(movingIntervalSat*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "MovingIntervalSat",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 43
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  assert_equal(numberOfReports, table.getn(matchingMessages) , 1, "The number of received MovingIntervalSat reports is incorrect")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

end


--- TC checks if MovingIntervalSat message is deffered by Position message (for terminal in moving state)
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime to make terminal moving
  -- then request Position message and check if movingIntervalSat message is correctly deffered by it -  calculate difference
  -- in time between Position message and MovingIntervalSat message - that should be equal to full movingIntervalSat period
  -- in the end set MovingIntervalSat to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  MovingIntervalSat message sent after full movingIntervalSat period (deffered by Position message)
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndPositionEventoccurs_MovingIntervalSatMessageSentAfterFullMovingIntervalSatPeriodIfDeffered()

  local movingDebounceTime = 1       -- seconds
  local stationarySpeedThld = 5      -- kmh
  local movingIntervalSat = 10       -- seconds


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+1,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},
                                             }
                   )

  gateway.setHighWaterMark()                 -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(6)                         -- wait until terminal gets moving state

  local message = {SIN = 126, MIN = 1}      -- to trigger Position event
	gateway.submitForwardMessage(message)
  framework.delay(movingIntervalSat+5)                   -- wait longer than movingIntervalSat to receive report
  local receivedMessages = gateway.getReturnMessages()  -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for movingIntervalSatMessage and Position messages
  local movingIntervalSatMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingIntervalSat))
  local positionMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  -- checking if expected messages has been received
  assert_not_nil(next(movingIntervalSatMessage), "MovingIntervalSat message message not received")     -- if MovingIntervalSat message not received assertion fails
  assert_not_nil(next(positionMessage), "Position message not received")                               -- if Position message not received assertion fails

  -- difference in time of occurence of Position report and movingIntervalSat report
  local differenceInTimestamps =  movingIntervalSatMessage[1].Payload.EventTime - positionMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full MovingIntervalSat period is expected
  assert_equal(movingIntervalSat, differenceInTimestamps, 2, "MovingIntervalSat has not been correctly deffered")

  -- back to movingIntervalSat = 0 to get no more reports
  movingIntervalSat = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.movingIntervalSat, movingIntervalSat},

                                             }
                   )

end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds and wait for 20 seconds; verify
  -- if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_PeriodicPosition_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodically()

  local positionMsgInterval = 15     -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- stationary state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(positionMsgInterval*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  assert_equal(numberOfReports, table.getn(matchingMessages) , 2, "The number of received Position reports is incorrect")

  gpsSettings.heading = 361                 -- that is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields

  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if Position message is sent when requested by MIN 1 for stationary terminal
  -- *actions performed:
  -- for terminal in stationary state set positionMsgInterval to 0 seconds; send request of Position message (SIN 126, MIN 1)
  -- verify if position messages has been received and check if fields of the single report are correct
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position message sent after request and fields of the reports have correct values
function test_Position_WhenTerminalInStationaryStateAndRequestedPositionMessageByMIN1_PositionMessageSent()

  local positionMsgInterval =  0     -- seconds (periodic sending disabled)

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,                      -- terminal stationary
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  local requestPositionMessage = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(requestPositionMessage)

  local timeOfEventTc = os.time()
  framework.delay(2)    -- wait until message is processed

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  gpsSettings.heading = 361                 -- that is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end


--- TC checks if Position message is sent when requested by MIN 1 for moving terminal
  -- *actions performed:
  -- simulate terminal moving, set positionMsgInterval to 0 seconds; send request of Position message (SIN 126, MIN 1)
  -- verify if position messages has been received and check if fields of the single report are correct
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position message sent after request and fields of the reports have correct values
function test_Position_WhenTerminalInMovingStateAndRequestedPositionMessageByMIN1_PositionMessageSent()

  local positionMsgInterval =  0     -- seconds (periodic sending disabled)
  local stationarySpeedThld = 10     -- kmh
  local movingDebounceTime = 1       -- seconds


  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+2,  -- terminal moving
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(movingDebounceTime+gpsReadInterval+1)

  gateway.setHighWaterMark() -- to get the newest messages

  local requestPositionMessage = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(requestPositionMessage)

  local timeOfEventTc = os.time()
  framework.delay(2)    -- wait until message is processed

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


end


--- TC checks if Position message is sent after full positionMsgInterval when MovingStart event deffers it
  -- *actions performed:
  -- set positionMsgInterval to 20 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh,
  -- simulate speed above stationarySpeedThld and wait longer than positionMsgInterval (MovingStart message is sent meanwhile)
  -- check if positionMsgInterval message has been sent after full positionMsgInterval period after MovingStart event
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- Position messages correctly deffered by MovingStart event
function test_PeriodicPosition_WhenPositionMsgIntervalIsGreaterThanZeroAndMovingStartEventDeffers_PositionMessageSentAfterFullPositionMsgInterval()

  local positionMsgInterval = 20     -- seconds
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
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  gateway.setHighWaterMark()              -- to get the newest messages
  gps.set(gpsSettings)                    -- applying gps settings to generate MovingStart message
  framework.delay(positionMsgInterval+3)  -- wait longer than positionMsgInterval to receive report

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for positionMsgInterval and MovingStart messages
  local positionMsgIntervalMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))
  local movingStartMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.movingStart))

  print(framework.dump(receivedMessages))

  -- checking if expected messages has been received
  assert_not_nil(next(positionMsgIntervalMessage), "PositionMsgInterval message message not received")       -- if PositionMsgInterval message not received assertion fails
  assert_not_nil(next(movingStartMessage), "MovingStart message not received")                               -- if MovingStart message not received assertion fails

  -- difference in time of occurence of MovingStart report and movingIntervalSat report
  local differenceInTimestamps =  positionMsgIntervalMessage[1].Payload.EventTime - movingStartMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full positionMsgInterval period is expected
  assert_equal(positionMsgInterval, differenceInTimestamps, 2, "PositionMsgInterval message has not been correctly deffered")


  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds, set fixType to 1 (no fix) and wait for coldFixDelay plus 20 seconds;
  -- verify if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_PeriodicPosition_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodicallyGpsFixReported()

  local positionMsgInterval = 10     -- seconds
  local numberOfReports = 2          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
              speed = 0,  -- one kmh above threshold
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )
  gps.set({fixType=1})            -- simulating no fix
  framework.delay(avlAgentCons.coldFixDelay)
  gateway.setHighWaterMark()      -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(positionMsgInterval*numberOfReports)    -- wait for time interval of generating report multiplied by number of expected reports

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))

  gpsSettings.heading = 361                 -- that is for stationary state
  local expectedValues={
                  gps = gpsSettings,
                  messageName = "Position",
                  currentTime = timeOfEventTc,
                  GpsFixAge = 50,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields



  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

end


--- TC checks if DistanceSat messages are sent when terminal travels distance above defined distanceSatThld
  -- *actions performed:
  -- set distanceSatThld to 100 km and odometerDistanceIncrement to 10 meters, simulate terminals initial position to
  -- lat = 0, long = 0 then move terminal to the next position which is 111 kilometers away from previous (distanceJumpStep)
  -- for every position change check if DistanceSat has been generated and verify fields of the report
  -- in the end set distanceSatThld back to 0 to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- DistanceSat set after terminal travels distanceSatThld, content of the reports is correct
function test_Odometer_WhenTerminalTravelsDistanceSatThld_DistanceSatMessageSent()

  local distanceSatThld = 100000         -- in meters, 100 kilometers
  local stationarySpeedThld = 10         -- in kmh
  local odometerDistanceIncrement = 10   -- in meters
  local stationarySpeedThld = 20         -- in kmh
  local movingDebounceTime = 1           -- in seconds
  local gpsSettings = {}
  local distanceJumpStep = 1             -- in degrees, 1 degree is 111 kilometers
  local numberOfJumps = 4                -- number of position changes


  -- definition of locations
  -- 1 st - initial position
  gpsSettings={
                 speed = 72,                     -- 20 m/s
                 heading = 30,                   -- degrees
                 latitude = 0,                   -- degrees
                 longitude = 0,                  -- degrees
                 simulateLinearMotion = false,
                   }


  gps.set(gpsSettings)  -- applying gps settings for initial position

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                                {avlPropertiesPINs.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                             }
                   )


  -- loop simulating terminal travelling by changing position of terminal with step of distanceJumpStep for numberOfJumps times
  -- after every jump received distanceSat report is verified
  for i = 1, numberOfJumps, 1 do

    gateway.setHighWaterMark()        -- to get the newest messages
    gpsSettings.longitude = gpsSettings.longitude+distanceJumpStep  -- longitude increased by distanceJumpStep
    gps.set(gpsSettings)              -- applying gps settings
    local timeOfEventTc = os.time()  -- to get correct time for verification in report
    framework.delay(3)                -- wait until report is generated

    -- receiving all from mobile messages sent after setHighWaterMark()
    local receivedMessages = gateway.getReturnMessages()
    -- look for DistanceSat messages
    local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.distanceSat))
    assert_true(next(matchingMessages), "DistanceSat report not received")  -- DistanceSat report is expected

    local expectedValues={
                  gps = gpsSettings,
                  messageName = "DistanceSat",
                  currentTime = timeOfEventTc,
                        }
    avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the DistanceSa treport fields

  end

  -- back to distanceSatThld = 0 to get no more reports
  local distanceSatThld = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                             }
                   )


end



--- TC checks if DistanceSat message is not sent when terminal travels distance below distanceSatThld
  -- *actions performed:
  -- set distanceSatThld to 100 km and odometerDistanceIncrement to 10 meters, simulate terminals initial position to
  -- lat = 0, long = 0 then move terminal to the second position 89 km away; check if DistanceSat report has not been sent;
  -- set distanceSatThld to 0 not to get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- DistanceSat not sent when covered distance is below distanceSatThld
function test_Odometer_WhenTerminalTravelsDistanceBelowdistanceSatThld_DistanceSatMessageNotSent()

  local distanceSatThld = 100000         -- in meters
  local stationarySpeedThld = 10         -- in kmh
  local odometerDistanceIncrement = 10   -- in meters
  local stationarySpeedThld = 20         -- in kmh
  local movingDebounceTime = 1           -- in seconds
  local gpsSettings = {}                 -- gps settings table to be used in TC

  -- definition of terminal position during simulated travel
  -- gps settings for 1st position
  gpsSettings[1]={
              speed = 72,                     -- 20 m/s
              heading = 30,                   -- degrees
              latitude = 0,                   -- degrees
              longitude = 0,                  -- degrees
              simulateLinearMotion = false,
                     }

  -- gps settings for 2nd position -- 89 kilometers from 1st position
  gpsSettings[2]={
              speed = 72,                     -- 20 m/s
              heading = 30,                   -- degrees
              latitude = 0,                   -- degrees
              longitude = 0.8,                -- degrees
                 }

  gps.set(gpsSettings[1])  -- applying gps settings for initial position
  framework.delay(3)       -- wait until report is generated

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                                {avlPropertiesPINs.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                             }
                   )

  -- terminal moved to next location, that is 89 km away from first one (below distanceSatThld)
  gps.set(gpsSettings[2]) -- applying gps settings for seconds position
  framework.delay(3)      -- wait until report is generated

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for DistanceSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.distanceSat))
  assert_false(next(matchingMessages), "DistanceSat report not expected") -- distanceSat message is not expected

  -- back to distanceSatThld = 0 to get no more reports
  local distanceSatThld = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                             }
                   )


end




--- TC checks if DistanceSat message is deffered by Position report
  -- *actions performed:
  -- set distanceSatThld to 100 km and odometerDistanceIncrement to 10 meters, simulate terminals initial position to
  -- lat = 0, long = 0 then move terminal to the second position 89 km away; trigger Positon report and simulate second position
  -- 33 km away from first - check if DistanceSat report has not been sent; then simulate third position 122 km away from the second
  -- and check if DistanceSat message is sent and field in report have correct values
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- DistanceSat correctly deffered by Position message
function test_Odometer_WhenTerminalTravelsDistanceSatThldAndPositionReportDeffersIt_DistanceSatMessageNotSent()

  local distanceSatThld = 100000         -- in meters, 100 kilometers
  local stationarySpeedThld = 10         -- in kmh
  local odometerDistanceIncrement = 10   -- in meters
  local stationarySpeedThld = 20         -- in kmh
  local movingDebounceTime = 1           -- in seconds
  local gpsSettings = {}                 -- gps settings table to be sent to simulator

  -- definition of terminal position during simulated travel
  -- gps settings for 1st position
  gpsSettings[1]={
              speed = 72,                     -- 20 m/s
              heading = 30,                   -- degrees
              latitude = 0,                   -- degrees
              longitude = 0,                  -- degrees
              simulateLinearMotion = false,
                     }

  -- gps settings for 2nd position -- 89 kilometers from 1st position
  gpsSettings[2]={
              latitude = 0,                   -- degrees
              longitude = 0.8,                -- degrees
                 }

  -- gps settings for 3rd position -- 33 kilometers from 2nd position
  gpsSettings[3]={
              latitude = 0,                   -- degrees
              longitude = 1.1,                -- degrees
                 }

  -- gps settings for 4th position -- 122 kilometers from 3rd
  gpsSettings[4]={
              speed = 72,                     -- 20 m/s   - speed is added for verification in report
              heading = 30,                   -- degrees  - heading is added for verification in report
              latitude = 1.1,                 -- degrees
              longitude = 1.1,                -- degrees
                 }


  -- setting terminals initial position
  gps.set(gpsSettings[1])  -- applying gps settings for 1st position
  framework.delay(3)       -- wait until settings are applied

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                                {avlPropertiesPINs.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                             }
                   )

  gps.set(gpsSettings[2])  -- applying gps settings for 2nd position - 89 kilometres from initial position (below distanceSatThld)
  framework.delay(3)       -- wait until report is generated

  -- generate Position message to deffer distanceSat report
  local positionRequestMessage = {SIN = avlAgentCons.avlAgentSIN, MIN = messagesMINs.positionRequest}     -- to trigger Position event
	gateway.submitForwardMessage(positionRequestMessage)
  framework.delay(3)                        -- wait until Position message is processed
  gateway.setHighWaterMark()                -- to get the newest messages

  gps.set(gpsSettings[3])                   -- applying gps settings for 3rd position, 33 kilometers from 2nd (89 + 33 kilometers is above distanceSatThld)
  framework.delay(3)                        -- wait until report is generated

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for DistanceSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.distanceSat))
  assert_false(next(matchingMessages), "DistanceSat report not expected") -- distanceSat message is not expected (deffered by Position message)

  gateway.setHighWaterMark()  -- to get the newest messages
  gps.set(gpsSettings[4])     -- applying gps settings for 4th position - 122 km from 3rd - DistanceSat message is expected after that move
  local timeOfEventTc = os.time()  -- to get the correct value for verification
  framework.delay(3)                -- wait until report is generated

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for DistanceSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.distanceSat))
  assert_true(next(matchingMessages), "DistanceSat report not received") -- distanceSat message is expected

  local expectedValues={
                  gps = gpsSettings[4],
                  messageName = "DistanceSat",
                  currentTime = timeOfEventTc,
                        }
  avlHelperFunctions.reportVerification(matchingMessages[1], expectedValues ) -- verification of the report fields


  -- back to distanceSatThld = 0 to get no more reports
  local distanceSatThld = 0       -- seconds
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.distanceSatThld, distanceSatThld},
                                             }
                   )


end



--- TC checks if LoggedPosition message is periodically saved according to LoggingPositionsInterval for moving terminal
  -- *actions performed:
  -- configure loggingPositionsInterval to 20 seconds, simulate terminal in first position in Speeding and IgnitionOn state
  -- wait until report is saved in log, simulate terminal in second position (different than first) in non-speeding and IgnitionOff
  -- state and wait until report is saved in log; set LoggingPositionsInterval back to 0 not to get any more reports; send message to configure
  -- log filter and select entries created during the TC collect log form terminal and analyse every single field in the saved LoggedPosition reports
  -- (values in log should be the same as the state of terminal when message saved)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- LoggedPosition messages saved periodically in log according to LoggingPositionsInterval, fields of report have correct values
function test_LoggedPosition_ForTerminalInMovingStateAndLoggingPositionsIntervallGreaterThanZero_LoggedPositionMessageSavedPeriodically()

  local loggingPositionsInterval = 25     -- seconds
  local numberOfReports = 2               -- number of expected reports received during the TC
  local movingDebounceTime = 1            -- seconds
  local stationarySpeedThld = 5           -- kmh
  local defaultSpeedLimit = 80            -- kmh
  local speedingTimeOver = 3              -- seconds
  local timeOfLogEntry = {}               -- helper variables
  local digPortsVerification = {}         -- helper variables
  local avlStateVerification = {}         -- helper variables
  local gpsSettings = {}                  -- gpsSettings to be sent to simulator

  -- definition of first position of terminal
  gpsSettings[1] = {
              speed = defaultSpeedLimit+10,   -- above speeding threshold to get speeding state
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1                   -- degrees
                     }

  -- definition of second position of terminal
  gpsSettings[2] = {
              speed = 5,                      -- below speeding threshold
              heading = 30,                   -- degrees - different than in first position
              latitude = 5,                   -- degrees - different than in first position
              longitude = 5                   -- degrees - different than in first position
                     }

  -- setting the EIO properties (for IgnitionON)
  lsf.setProperties(avlAgentCons.EioSIN,{
                                                {avlPropertiesPINs.port1Config, 3},     -- port 1 as digital input
                                                {avlPropertiesPINs.port1EdgeDetect, 3}  -- detection for both rising and falling edge
                                        }
                   )

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.funcDigInp1, avlAgentCons.funcDigInp["IgnitionOn"]},              -- line number 1 set for Ignition function
                                                {avlPropertiesPINs.defaultSpeedLimit, defaultSpeedLimit},
                                                {avlPropertiesPINs.speedingTimeOver, speedingTimeOver},
                                             }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  local loggingStartTime = os.time()     -- time of start of logging - to be used in log filter message

  device.setIO(1, 1)                      -- port 1 to high level - that should trigger IgnitionOn

  gps.set(gpsSettings[1])                        -- apply settings for first position and speeding state
  framework.delay(loggingPositionsInterval+3)    -- wait for LoggingPositionsInterval (LoggedPosition message saved)
  timeOfLogEntry[1] = os.time()                  -- save timestamp for first log entry

  -- saving AvlStates and DigPorts properties for analysis
  local avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  avlStateVerification[1] = tonumber(avlStatesProperty[1].value)
  -- saving digPortsProperty and DigPorts properties for analysis
  local digPortsProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.digPorts)
  digPortsVerification[1] = tonumber(digPortsProperty[1].value)

  device.setIO(1, 0)  -- port 1 to low level - that should trigger IgnitionOff

  gps.set(gpsSettings[2])                        -- apply settings for second position and non-speeding state
  framework.delay(loggingPositionsInterval+4)    -- wait for LoggingPositionsInterval (LoggedPosition message saved)
  timeOfLogEntry[2] = os.time()                  -- save timestamp for second log entry

  -- saving AvlStates and DigPorts properties for analysis
  avlStatesProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.avlStates)
  avlStateVerification[2] = tonumber(avlStatesProperty[1].value)
  -- saving digPortsProperty and DigPorts properties for analysis
  digPortsProperty = lsf.getProperties(avlAgentCons.avlAgentSIN,avlPropertiesPINs.digPorts)
  digPortsVerification[2] = tonumber(digPortsProperty[1].value)

  loggingPositionsInterval = 0     -- not to get any more messages saved
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                             }
                   )
  local loggingEndTime = os.time()     -- time of end of logging - to be used in log filter message

  -- send setDataLogFilter to log service (to filter only LoggedPosition messages)
	local setDataLogFilterMessage = {SIN = 23, MIN = 1}
  -- minList =  15 (filter only LoggedPosition)
  setDataLogFilterMessage.Fields = {{Name="timeStart",Value=loggingStartTime},{Name="timeEnd",Value=loggingEndTime},{Name="reverse",Value=false},
                                   {Name="list",Elements={{Index=0,Fields={{Name="sin",Value=126},{Name="minList",Value="Dw=="}}}}},}
  gateway.submitForwardMessage(setDataLogFilterMessage)

  framework.delay(2)           -- wait until message is processed
  gateway.setHighWaterMark()   -- to get the newest messages

  -- send getDataLogEntries message
  local getDataLogEntriesMessage = {SIN = 23, MIN = 5} -- add maximum entries to limit TODO
  getDataLogEntriesMessage.Fields = {{Name="maxEntries",Value=10},}
  gateway.submitForwardMessage(getDataLogEntriesMessage)
  framework.delay(2)  -- wait until message is processed

  -- DataLogEntries message is expected (SIN 23, MIN 5)
  local logEntriesMessage = gateway.getReturnMessage(framework.checkMessageType(23, 5))

  -- check if values of the fields reported in LoggedPosition reports are correct (2 runs of the loop for two messages)
  for i = 1, 2, 1 do
    assert_equal(gpsSettings[i].latitude*60000, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[1].Value), "Latitude value is not correct in report")   -- multiplied by 60000 for conversion from miliminutes
    assert_equal(gpsSettings[i].longitude*60000, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[2].Value), "Longitude value is not correct in report") -- multiplied by 60000 for conversion from miliminutes
    assert_equal(gpsSettings[i].speed, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[3].Value), "Speed value is not correct in report")
    assert_equal(gpsSettings[i].heading, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[4].Value), "Heading value is not correct in report")
    assert_equal(timeOfLogEntry[i], tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[5].Value),10, "EventTime value is not correct in report")
    assert_equal(avlStateVerification[i], tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[6].Value), "AvlStates value is not correct in report")
    assert_equal(digPortsVerification[i], tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[7].Value),"DigitalPorts value is not correct in report")

  end

end


--- TC checks if LoggedPosition message does not deffer sending periodic Position message
  -- *actions performed:
  -- set loggingPositionsInterval to 2 seconds and positionMsgInterval to 10 seconds; apply property settings and wait for time
  -- of positionMsgInterval multiplied by number of expected positon reports; then set loggingPositionsInterval and positionMsgInterval
  -- to 0 not get more reports and check how many periodic Position reports has been sent; if periodic position message has not been deffered by
  -- saving LoggedPosition this number is expected to be numberOfPositionReports defined in TC
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- saving LoggedPosition messages does not deffer periodic Position message
  function test_LoggedPosition_WhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingPeriodicPositionMessage()

  local loggingPositionsInterval =  2   -- seconds
  local positionMsgInterval = 10        -- seconds
  local numberOfPositionReports = 3     -- number of expected reports received during the TC
  local stationaryIntervalSat = 5

  -- definition of first position of terminal
  local gpsSettings = {
              speed = 0,                      -- terminal stationary
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided
                       }
  gps.set(gpsSettings)                        -- apply settings
  framework.delay(3)                          -- wait until settings are applied

  gateway.setHighWaterMark()   -- to get the newest messages
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )


  framework.delay(numberOfPositionReports*positionMsgInterval+3)    -- wait for position message interval multiplied by number of expected reports

  loggingPositionsInterval = 0     -- seconds, not to get any more messages saved in log
  positionMsgInterval = 0          -- seconds, not to get any more position messages
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                                {avlPropertiesPINs.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for Position messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.position))
  -- checking the number of received Position messages
  assert_equal(numberOfPositionReports, table.getn(matchingMessages) , "The number of received Position reports is incorrect")

end


--- TC checks if LoggedPosition message does not deffer sending periodic StationaryIntervalSat message
  -- *actions performed:
  -- make sure terminal is stationary; set loggingPositionsInterval to 2 seconds and stationaryIntervalSat to 5 seconds;
  -- apply property settings and wait for time of stationaryIntervalSat multiplied by number of expected reports; then set loggingPositionsInterval
  -- and stationaryIntervalSat to 0 not get more reports and check how many periodic stationaryIntervalSat reports has been sent;
  -- if stationaryIntervalSat message has not been deffered by saving LoggedPosition this number is expected to be numberOfReports defined in TC
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of gpsReadInterval
  -- *expected results:
  -- saving LoggedPosition messages does not deffer periodic stationaryIntervalSat message
  function test_LoggedPosition_ForTerminalStationaryWhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingStationaryIntervalSat()

  local loggingPositionsInterval =  2   -- seconds
  local numberOfReports = 3             -- number of expected reports received during the TC
  local stationaryIntervalSat = 10      -- seconds
  local stationarySpeedThld = 10        -- kmh
  local movingDebounceTime = 1          -- seconds

  -- definition of first position of terminal
  local gpsSettings = {
              speed = 0,                      -- kmh, terminal stationary
              heading = 90,                   -- degrees
              latitude = 1,                   -- degrees
              longitude = 1,                  -- degrees
              fixType = 3,                    -- valid fix provided
                       }

  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.stationarySpeedThld, stationarySpeedThld},
                                                {avlPropertiesPINs.movingDebounceTime, movingDebounceTime},
                                             }
                   )

  gps.set(gpsSettings)                                         -- apply settings
  framework.delay(movingDebounceTime+gpsReadInterval+2)        -- wait until terminal is stationary

  gateway.setHighWaterMark()   -- to get the newest messages
  --applying properties of the service, messages are saved to log and sent from mobile until now
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                            }
                   )

  framework.delay(numberOfReports*stationaryIntervalSat+3)    -- wait for stationaryIntervalSat interval multiplied by number of expected reports

  loggingPositionsInterval = 0       -- seconds, not to get any more messages saved in log
  stationaryIntervalSat = 0          -- seconds, not to get any more StationaryIntervalSat messages
  --applying properties of the service
  lsf.setProperties(avlAgentCons.avlAgentSIN,{
                                                {avlPropertiesPINs.loggingPositionsInterval, loggingPositionsInterval},
                                                {avlPropertiesPINs.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for stationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlAgentCons.avlAgentSIN, messagesMINs.stationaryIntervalSat))
  -- checking the number of received stationaryIntervalSat messages
  assert_equal(numberOfReports, table.getn(matchingMessages) , "The number of received StationaryIntervalSat reports is incorrect")

end





--[[Start the tests]]
for i=1, 1, 1 do     -- to check the reliability, will be removed
  lunatest.run()
end

framework.printResults()




