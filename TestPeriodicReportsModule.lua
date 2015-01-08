-----------
-- Periodic and distance reports test module
-- - contains test cases related to periodic and distance based reports
-- @module TestPeriodicReportsModule

module("TestPeriodicReportsModule", package.seeall)

-- Setup and Teardown

--- suite_setup function ensures that terminal is not in the moving state and not in the low power mode
 -- executed before each test suite
 -- * actions performed:
 -- lpmTrigger is set to 0 so that nothing can put terminal into the low power modeFSM
 -- function checks if terminal is not the low power mode (condition necessary for all GPS related test cases)
 -- *initial conditions:
 -- running Terminal Simulator with installed AVL Agent, running Modem Simulator with Gateway Web Service and
 -- GPS Web Service switched on
 -- *Expected results:
 -- lpmTrigger set correctly and terminal is not in the Low Power mode
 function suite_setup()

  -- reset of properties of SIN 126 and 25
	local message = {SIN = 16, MIN = 10}
	message.Fields = {{Name="list",Elements={{Index=0,Fields={{Name="sin",Value=126},}},{Index=1,Fields={{Name="sin",Value=25},}}}}}
	gateway.submitForwardMessage(message)

  -- restarting AVL agent after running module
	local message = {SIN = lsfConstants.sins.system,  MIN = lsfConstants.mins.restartService}
  message.Fields = {{Name="sin",Value=avlConstants.avlAgentSIN}}
  gateway.submitForwardMessage(message)

  -- wait until service is up and running again and sends Reset message
  local expectedMins = {avlConstants.mins.reset}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.reset], "Reset message after reset of AVL not received")

  -- setting lpmTrigger to 0 (nothing can put terminal into the low power mode)
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.lpmTrigger, 0},
                                             }
                    )

  framework.delay(3)
  -- checking the terminal state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "Terminal is incorrectly in low power mode")


end


-- executed after each test suite
function suite_teardown()

end

--- the setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets GPS_READ_INTERVAL (in position service) to the value of GPS_READ_INTERVAL
  -- executed before each unit test
  -- *actions performed:
  -- setting of the GPS_READ_INTERVAL (in the position service) is made using global GPS_READ_INTERVAL variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state
function setup()

  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}     -- setting the continues mode of position service (SIN 20, PIN 15)
                                               }
                   )

  local geofenceEnabled = false       -- to disable geofence feature

  gps.set({blockage = false})

 --applying properties of geofence service
  lsf.setProperties(lsfConstants.sins.geofence,{
                                                 {lsfConstants.pins.geofenceEnabled, geofenceEnabled, "boolean"},
                                               }
                   )
  avlHelperFunctions.putTerminalIntoStationaryState()


end
-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

  gps.set({blockage = false})

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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
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

  local STATIONARY_INTERVAL_SAT = 10       -- seconds
  local NUMBER_OF_REPORTS = 4              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                             }
                   )

  gateway.setHighWaterMark()                                                           -- to get the newest messages
  local timeOfEvent = os.time() +  STATIONARY_INTERVAL_SAT                             -- time of receiving first stationaryIntervalSat report
  framework.delay(STATIONARY_INTERVAL_SAT*NUMBER_OF_REPORTS + GPS_READ_INTERVAL+ 2)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to stationaryIntervalSat = 0 to get no more reports
  local STATIONARY_INTERVAL_SAT = 0     -- seconds
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.stationaryIntervalSat))

  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages) , 2, "The number of received stationaryIntervalSat reports is incorrect")

  assert_equal(gpsSettings.longitude*60000, tonumber(matchingMessages[1].Payload.Longitude), "StationaryIntervalSat message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(matchingMessages[1].Payload.Latitude), "StationaryIntervalSat message has incorrect latitude value")
  assert_equal("StationaryIntervalSat", matchingMessages[1].Payload.Name, "StationaryIntervalSat message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(matchingMessages[1].Payload.EventTime), 10, "StationaryIntervalSat message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(matchingMessages[1].Payload.Speed), "StationaryIntervalSat message has incorrect speed value")
  assert_equal(361, tonumber(matchingMessages[1].Payload.Heading), "StationaryIntervalSat message has incorrect heading value")



end


--- TC checks if StationaryIntervalSat message is sent periodically when terminal is in stationary state
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- check if terminal is in stationary state, set stationaryIntervalSat to 5 seconds, wait for coldFixDelay plus
  -- 20 seconds and collect all the receive messages during that time; count the number of receivedMessages
  -- stationaryIntervalSat reports in collected messages; verify alle the fields of single report
  -- set stationaryIntervalSat to 0 to disable reports (not to cause eny troubles in other TCs)ate
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
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

  local STATIONARY_INTERVAL_SAT = 5        -- seconds
  local NUMBER_OF_REPORTS = 3              -- number of expected reports received during the TC

  -- check if terminal is in the stationary state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).Moving, "terminal incorrectly in the moving state")


  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                             }
                   )

  gps.set({fixType = 1})                      -- no fix provided
  framework.delay(lsfConstants.coldFixDelay)

  gateway.setHighWaterMark()                                                            -- to get the newest messages
  framework.delay(STATIONARY_INTERVAL_SAT*NUMBER_OF_REPORTS + GPS_READ_INTERVAL + 2)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to stationaryIntervalSat = 0 to get no more reports
  local STATIONARY_INTERVAL_SAT = 0       -- seconds
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.stationaryIntervalSat))

  assert_equal(51, tonumber(matchingMessages[1].Payload.GpsFixAge), 15,  "StationaryIntervalSat message has incorrect GpsFixAge value")


end



--- TC checks if StationaryIntervalSat message is deffered by Position message (for terminal in stationary state)
  -- *actions performed:
  -- set stationaryIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- simulate terminal in stationary state and send Position message request; then check if StationaryIntervalSat message
  -- has been correctly deffered - calculate difference in time between Position message and MovingIntervalSat message - that
  -- should be equal to full StationaryIntervalSat period if the report has been correctly deffered
  -- in the end set stationaryIntervalSat to 0 to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
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
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                                {avlConstants.pins.stationaryIntervalSat, stationaryIntervalSat},
                                             }
                   )

  gps.set(gpsSettings)                       -- applying gps settings
  framework.delay(3)                         -- to make sure terminal is stationary
  gateway.setHighWaterMark()                 -- to get the newest messages
  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(message)

  framework.delay(stationaryIntervalSat+3)  -- wait longer than stationaryIntervalSat receive report

  local receivedMessages = gateway.getReturnMessages() -- receiving all from mobile messages sent after setHighWaterMark()
  -- looking for stationaryIntervalSatMessage and Position messages
  local stationaryIntervalSatMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.stationaryIntervalSat))
  local positionMessage = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.position))

  -- back to stationaryIntervalSat = 0 to get no more reports
   lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationaryIntervalSat, 0},

                                             }
                   )
  -- checking if expected messages has been received
  assert_not_nil(next(stationaryIntervalSatMessage), "stationaryIntervalSat message message not received")   -- if StationaryIntervalSat message not received assertion fails
  assert_not_nil(next(positionMessage), "Position message not received")                                     -- if Position message not received assertion fails

  -- difference in time of occurence of Position report and StationaryIntervalSat report
  local differenceInTimestamps =  stationaryIntervalSatMessage[1].Payload.EventTime - positionMessage[1].Payload.EventTime
  -- checking if difference in time is correct - full StationaryIntervalSat period is expected
  assert_equal(stationaryIntervalSat, differenceInTimestamps, 2, "StationaryIntervalSat has not been correctly deffered")


end


--- TC checks if MovingIntervalSat message is periodically sent when terminal is in moving state
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime; then check if terminal is
  -- correctly in the moving state then wait for 20 seconds and check if movingIntervalSat messages have been
  -- sent and verify the fields of single report; after verification set movingIntervalSat to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndMovingIntervalSatGreaterThanZero_MovingIntervalSatMessageSentPeriodically()

  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local MOVING_INTERVAL_SAT = 10       -- seconds
  local NUMBER_OF_REPORTS = 3          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEvent = os.time()
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + 1) -- one second is added to make sure the gps is read and processed by agent

  -- MovingStart message expected
  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received, moving state true is necessary condition in this TC")

  framework.delay(MOVING_INTERVAL_SAT*NUMBER_OF_REPORTS + GPS_READ_INTERVAL + 2)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to movingIntervalSat = 0 to get no more reports
  MOVING_INTERVAL_SAT = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingIntervalSat))
  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages) , 2 , "The number of received MovingIntervalSat reports is incorrect")

  assert_equal(gpsSettings.longitude*60000, tonumber(matchingMessages[1].Payload.Longitude), "MovingIntervalSat message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(matchingMessages[1].Payload.Latitude), "MovingIntervalSat message has incorrect latitude value")
  assert_equal("MovingIntervalSat", matchingMessages[1].Payload.Name, "MovingIntervalSat message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(matchingMessages[1].Payload.EventTime), 20, "MovingIntervalSat message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(matchingMessages[1].Payload.Speed), "MovingIntervalSat message has incorrect speed value")
  assert_equal(gpsSettings.heading, tonumber(matchingMessages[1].Payload.Heading), "MovingIntervalSat message has incorrect heading value")




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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  MovingIntervalSat message sent periodically and fields of the reports have correct values
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndMovingIntervalSatGreaterThanZero_MovingIntervalSatMessageSentPeriodicallyGpsFixReported()


  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local MOVING_INTERVAL_SAT = 10       -- seconds
  local NUMBER_OF_REPORTS = 3          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEvent = os.time()
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME) -- one second is added to make sure the gps is read and processed by agent

  -- MovingStart message expected
  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received, moving state true is necessary condition in this TC")

  gps.set({fixType = 1})    -- no fix provided
  framework.delay(lsfConstants.coldFixDelay)

  framework.delay(MOVING_INTERVAL_SAT*NUMBER_OF_REPORTS + GPS_READ_INTERVAL + 2)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to MOVING_INTERVAL_SAT = 0 to get no more reports
  MOVING_INTERVAL_SAT = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingIntervalSat))

  assert_equal(43, tonumber(matchingMessages[1].Payload.GpsFixAge), 15,  "MovingIntervalSat message has incorrect GpsFixAge value")


end


--- TC checks if MovingIntervalSat message is deffered by Position message (for terminal in moving state)
  -- *actions performed:
  -- set movingIntervalSat to 10 seconds, movingDebounceTime to 1 second and stationarySpeedThld to 5 kmh;
  -- increase speed one kmh above threshold; wait for time longer than movingDebounceTime to make terminal moving
  -- then request Position message and check if movingIntervalSat message is correctly deffered by it -  calculate difference
  -- in time between Position message and MovingIntervalSat message - that should be equal to full movingIntervalSat period
  -- in the end set MovingIntervalSat to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  MovingIntervalSat message sent after full movingIntervalSat period (deffered by Position message)
function test_PeriodicMovingIntervalSat_WhenTerminalInMovingStateAndPositionEventoccurs_MovingIntervalSatMessageSentAfterFullMovingIntervalSatPeriodIfDeffered()

  local MOVING_DEBOUNCE_TIME = 1       -- seconds
  local STATIONARY_SPEED_THLD = 5      -- kmh
  local MOVING_INTERVAL_SAT = 20       -- seconds


  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 1,  -- one kmh above threshold
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  gateway.setHighWaterMark()                 -- to get the newest messages
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)         -- wait until terminal gets moving state

  -- MovingStart message expected
  local expectedMins = {avlConstants.mins.movingStart}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.movingStart], "MovingStart message not received, moving state true is necessary condition in this TC")

  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(message)
  framework.delay(MOVING_INTERVAL_SAT)                   -- wait longer than movingIntervalSat to receive report

  expectedMins = {avlConstants.mins.movingIntervalSat, avlConstants.mins.position}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, 7)     -- timeout is short on purpose

  -- back to movingIntervalSat = 0 to get no more reports
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.movingIntervalSat, 0},
                                             }
                   )

  assert_not_nil(receivedMessages[avlConstants.mins.movingIntervalSat], "MovingIntervalSat message expected but not received")
  assert_not_nil(receivedMessages[avlConstants.mins.position], "MovingIntervalSat expected but not received")

  -- difference in time of occurence of Position report and movingIntervalSat report
  local differenceInTimestamps =  receivedMessages[avlConstants.mins.movingIntervalSat].EventTime - receivedMessages[avlConstants.mins.position].EventTime
  -- checking if difference in time is correct - full MovingIntervalSat period is expected
  assert_equal(MOVING_INTERVAL_SAT, differenceInTimestamps, 8, "MovingIntervalSat has not been correctly deffered")

end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds and wait for 20 seconds; verify
  -- if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_PeriodicPosition_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodically()

  local POSITION_MSG_INTERVAL = 10     -- seconds
  local NUMBER_OF_REPORTS = 6          -- number of expected reports received during the TC


  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = 0,                      -- stationary state
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages
  local timeOfEventTc = os.time()
  framework.delay(POSITION_MSG_INTERVAL*NUMBER_OF_REPORTS + 2)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to positionMsgInterval = 0 to get no more reports
  POSITION_MSG_INTERVAL = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for StationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.position))

  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages), 2, "The number of received Position reports is incorrect")


end



--- TC checks if Position message is sent when requested by MIN 1 for stationary terminal
  -- *actions performed:
  -- for terminal in stationary state set positionMsgInterval to 0 seconds; send request of Position message (SIN 126, MIN 1)
  -- verify if position messages has been received and check if fields of the single report are correct
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  Position message sent after request and fields of the reports have correct values
function test_Position_WhenTerminalInStationaryStateAndRequestedPositionMessageByMIN1_PositionMessageSent()

  local POSITION_MSG_INTERVAL =  0     -- seconds (periodic sending disabled)

  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = 0,                      -- terminal stationary
                      heading = 90,                   -- degrees
                      latitude = 1,                   -- degrees
                      longitude = 1                   -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(2)     -- wait until settings are applied

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  gateway.setHighWaterMark() -- to get the newest messages

  local requestPositionMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(requestPositionMessage)

  local timeOfEvent = os.time()

  -- Position message is expected after request
  local expectedMins = {avlConstants.mins.position}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.position], "Position message has not been received after request")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.position].Longitude), "Position message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.position].Latitude), "Position message has incorrect latitude value")
  assert_equal("Position", receivedMessages[avlConstants.mins.position].Name, "Position message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.position].EventTime), 5, "Position message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.position].Speed), "Position message has incorrect speed value")
  assert_equal(361, tonumber(receivedMessages[avlConstants.mins.position].Heading), "Position message has incorrect heading value")

end


--- TC checks if Position message is sent when requested by MIN 1 for moving terminal
  -- *actions performed:
  -- simulate terminal moving, set positionMsgInterval to 0 seconds; send request of Position message (SIN 126, MIN 1)
  -- verify if position messages has been received and check if fields of the single report are correct
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  Position message sent after request and fields of the reports have correct values
function test_Position_WhenTerminalInMovingStateAndRequestedPositionMessageByMIN1_PositionMessageSent()

  local POSITION_MSG_INTERVAL =  0     -- seconds (periodic sending disabled)
  local STATIONARY_SPEED_THLD = 10       -- kmh
  local MOVING_DEBOUNCE_TIME = 1         -- seconds


  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                               {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                               {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                             }
                   )

  -- gps settings table to be sent to simulator
  local gpsSettings={
                      speed = STATIONARY_SPEED_THLD + 2,  -- terminal moving
                      heading = 90,                       -- degrees
                      latitude = 1,                       -- degrees
                      longitude = 1                       -- degrees
                     }
  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL+ GPS_PROCESS_TIME)

  gateway.setHighWaterMark() -- to get the newest messages

  local requestPositionMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.positionRequest}      -- to trigger Position event
	gateway.submitForwardMessage(requestPositionMessage)

  local timeOfEvent = os.time()

  -- Position message is expected after request
  local expectedMins = {avlConstants.mins.position}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.position], "Position message has not been received after request")
  assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.position].Longitude), "Position message has incorrect longitude value")
  assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.position].Latitude), "Position message has incorrect latitude value")
  assert_equal("Position", receivedMessages[avlConstants.mins.position].Name, "Position message has incorrect message name")
  assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.position].EventTime), 5, "Position message has incorrect EventTime value")
  assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.position].Speed), "Position message has incorrect speed value")
  assert_equal(gpsSettings.heading, tonumber(receivedMessages[avlConstants.mins.position].Heading), "Position message has incorrect heading value")


end


--- TC checks if Position message is sent after full positionMsgInterval when DiagnosticsInfo event deffers it
  -- *actions performed:
  -- set positionMsgInterval and meanwhile trigger DiagnosticsInfo message; check if Position message has been correctly deffered
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- Position messages correctly deffered by DiagnosticsInfo event
function test_PeriodicPosition_WhenPositionMsgIntervalIsGreaterThanZeroAndDiagnosticsInfoDeffers_PositionMessageSentAfterFullPositionMsgInterval()

  local POSITION_MSG_INTERVAL = 20     -- seconds

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  gateway.setHighWaterMark()              -- to get the newest messages
  framework.delay(5)

  -- sending getDiagnostics message to make DiagnosticsInfo deffer position periodic report
  local getDiagnosticsMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getDiagnostics}   -- to trigger DiagnosticsInfo message
	gateway.submitForwardMessage(getDiagnosticsMessage)

  framework.delay(POSITION_MSG_INTERVAL + 3)  -- wait longer than positionMsgInterval to receive report

  -- back to positionMsgInterval = 0 to get no more reports
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.positionMsgInterval, 0},
                                             }
                   )

  local expectedMins = {avlConstants.mins.diagnosticsInfo, avlConstants.mins.position}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, 5)     -- timeout is short on purpose

  assert_not_nil(receivedMessages[avlConstants.mins.diagnosticsInfo], "DiagnosticsInfo message expected but not received")
  assert_not_nil(receivedMessages[avlConstants.mins.position], "Position expected but not received")

  -- difference in time of occurence of Position report and movingIntervalSat report
  local differenceInTimestamps =  receivedMessages[avlConstants.mins.position].EventTime - receivedMessages[avlConstants.mins.diagnosticsInfo].EventTime
  -- checking if difference in time is correct - full MovingIntervalSat period is expected
  assert_equal(POSITION_MSG_INTERVAL, differenceInTimestamps, 7, "PositionMsgInterval has not been correctly deffered")


end


--- TC checks if Position message is periodically sent according to positionMsgInterval
  -- and GpsFixAge is included in the report (for fixes older than 5 seconds related to EventTime)
  -- *actions performed:
  -- set positionMsgInterval to 10 seconds, set fixType to 1 (no fix) and wait for coldFixDelay plus 20 seconds;
  -- verify if position messages has been received and check if fields of the single report are correct
  -- after verification set positionMsgInterval to 0 not get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  --  Position messages sent periodically and fields of the reports have correct values
function test_PeriodicPosition_ForPositionMsgIntervalGreaterThanZero_PositionMessageSentPeriodicallyGpsFixReported()

  local POSITION_MSG_INTERVAL = 10     -- seconds
  local NUMBER_OF_REPORTS = 2          -- number of expected reports received during the TC


  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  gps.set({fixType=1})            -- simulating no fix
  framework.delay(lsfConstants.coldFixDelay)
  gateway.setHighWaterMark()      -- to get the newest messages

  framework.delay(POSITION_MSG_INTERVAL*NUMBER_OF_REPORTS)    -- wait for time interval of generating report multiplied by number of expected reports

  -- back to positionMsgInterval = 0 to get no more reports
  positionMsgInterval = 0       -- seconds
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.positionMsgInterval, positionMsgInterval},
                                             }
                   )

  local expectedMins = {avlConstants.mins.diagnosticsInfo, avlConstants.mins.position}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)     -- timeout is short on purpose

  assert_not_nil(receivedMessages[avlConstants.mins.position], "Position message expected but not received")

  assert_equal(50, tonumber(receivedMessages[avlConstants.mins.position].GpsFixAge), 20,  "Position message has incorrect GpsFixAge value")

end


--- TC checks if DistanceSat messages are sent when terminal travels distance above defined distanceSatThld
  -- *actions performed:
  -- set distanceSatThld to 100 km and odometerDistanceIncrement to 10 meters, simulate terminals initial position to
  -- lat = 0, long = 0 then move terminal to the next position which is 111 kilometers away from previous (distanceJumpStep)
  -- for every position change check if DistanceSat has been generated and verify fields of the report
  -- in the end set distanceSatThld back to 0 to get no more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- DistanceSat set after terminal travels distanceSatThld, content of the reports is correct
function test_Odometer_WhenTerminalTravelsDistanceSatThld_DistanceSatMessageSent()

  local DISTANCE_SAT_THLD = 100000       -- in meters, 100 kilometers
  local STATIONARY_SPEED_THLD  = 10      -- in kmh
  local ODOMETER_DISTANCE_INCREMENT = 10 -- in meters
  local MOVING_DEBOUNCE_TIME = 1         -- in seconds
  local gpsSettings = {}
  local DISTANCE_JUMP_STEP = 1           -- in degrees, 1 degree is 111 kilometers
  local NUMBER_OF_JUMPS = 4              -- number of position changes


  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                               {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                             }
                   )

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
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                               {avlConstants.pins.odometerDistanceIncrement, ODOMETER_DISTANCE_INCREMENT},
                                             }
                   )

  -- loop simulating terminal travelling by changing position of terminal with step of distanceJumpStep for numberOfJumps times
  -- after every jump received distanceSat report is verified
  for i = 1, NUMBER_OF_JUMPS, 1 do

    gateway.setHighWaterMark()        -- to get the newest messages
    gpsSettings.longitude = gpsSettings.longitude + DISTANCE_JUMP_STEP  -- longitude increased by distanceJumpStep
    gps.set(gpsSettings)
    local timeOfEvent = os.time()  -- to get correct time for verification in report

    -- DistanceSat message is expected
    local expectedMins = {avlConstants.mins.distanceSat}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
    assert_not_nil(receivedMessages[avlConstants.mins.distanceSat], "DistanceSat message has not been received after travelling distance above threshold")
    assert_equal(gpsSettings.longitude*60000, tonumber(receivedMessages[avlConstants.mins.distanceSat].Longitude), "DistanceSat message has incorrect longitude value")
    assert_equal(gpsSettings.latitude*60000, tonumber(receivedMessages[avlConstants.mins.distanceSat].Latitude), "DistanceSat message has incorrect latitude value")
    assert_equal("DistanceSat", receivedMessages[avlConstants.mins.distanceSat].Name, "DistanceSat message has incorrect message name")
    assert_equal(timeOfEvent, tonumber(receivedMessages[avlConstants.mins.distanceSat].EventTime), 5, "DistanceSat message has incorrect EventTime value")
    assert_equal(gpsSettings.speed, tonumber(receivedMessages[avlConstants.mins.distanceSat].Speed), "DistanceSat message has incorrect speed value")
    assert_equal(gpsSettings.heading, tonumber(receivedMessages[avlConstants.mins.distanceSat].Heading), "DistanceSat message has incorrect heading value")

  end

  -- back to DISTANCE_SAT_THLD = 0 to get no more reports
  DISTANCE_SAT_THLD = 0       -- meters
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                             }
                   )


end



--- TC checks if DistanceSat message is not sent when terminal travels distance below distanceSatThld
  -- *actions performed:
  -- set distanceSatThld to 100 km and odometerDistanceIncrement to 10 meters, simulate terminals initial position to
  -- lat = 0, long = 0 then move terminal to the second position 89 km away; check if DistanceSat report has not been sent;
  -- set distanceSatThld to 0 not to get more reports
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- DistanceSat not sent when covered distance is below distanceSatThld
function test_Odometer_WhenTerminalTravelsDistanceBelowdistanceSatThld_DistanceSatMessageNotSent()

  local DISTANCE_SAT_THLD = 100000       -- in meters, 100 kilometers
  local STATIONARY_SPEED_THLD  = 10      -- in kmh
  local ODOMETER_DISTANCE_INCREMENT = 10 -- in meters
  local MOVING_DEBOUNCE_TIME = 1         -- in seconds
  local gpsSettings = {}

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                               {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                               {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                             }
                   )

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
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)       -- wait until terminal goes to moving state

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                              {avlConstants.pins.odometerDistanceIncrement, ODOMETER_DISTANCE_INCREMENT},
                                             }
                   )

  -- terminal moved to next location, that is 89 km away from first one (below distanceSatThld)
  gps.set(gpsSettings[2]) -- applying gps settings for seconds position

  -- DistanceSat message is not expected
  local expectedMins = {avlConstants.mins.distanceSat}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.distanceSat], "DistanceSat message received but not expected")

  -- back to distanceSatThld = 0 to get no more reports
  DISTANCE_SAT_THLD = 0       -- meters
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- DistanceSat correctly deffered by Position message
function test_Odometer_WhenTerminalTravelsDistanceSatThldAndPositionReportDeffersIt_DistanceSatMessageNotSent()

  local DISTANCE_SAT_THLD = 100000         -- in meters, 100 kilometers
  local STATIONARY_SPEED_THLD = 10         -- in kmh
  local ODOMETER_DISTANCE_INCREMENT = 10   -- in meters
  local MOVING_DEBOUNCE_TIME = 1           -- in seconds
  local gpsSettings = {}                   -- gps settings table to be sent to simulator

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
                  latitude = 1.1,                 -- degrees
                  longitude = 1.1,                -- degrees
                 }


  -- setting terminals initial position
  gps.set(gpsSettings[1])  -- applying gps settings for 1st position
  framework.delay(3)       -- wait until settings are applied

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                                {avlConstants.pins.odometerDistanceIncrement, ODOMETER_DISTANCE_INCREMENT},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                             }
                   )

  gps.set(gpsSettings[2])  -- applying gps settings for 2nd position - 89 kilometres from initial position (below distanceSatThld)
  framework.delay(3)       -- wait until report is generated

  -- generate Position message to deffer distanceSat report
  local positionRequestMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.positionRequest}     -- to trigger Position event
	gateway.submitForwardMessage(positionRequestMessage)
  framework.delay(3)                        -- wait until Position message is processed
  gateway.setHighWaterMark()                -- to get the newest messages

  gps.set(gpsSettings[3])                   -- applying gps settings for 3rd position, 33 kilometers from 2nd (89 + 33 kilometers is above distanceSatThld)
  framework.delay(3)                        -- wait until report is generated

  -- DistanceSat message is not expected
  local expectedMins = {avlConstants.mins.distanceSat}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, TIMEOUT_MSG_NOT_EXPECTED)
  assert_nil(receivedMessages[avlConstants.mins.distanceSat], "DistanceSat message received but not expected (should be deffered by Position message)")

  gateway.setHighWaterMark()  -- to get the newest messages
  gps.set(gpsSettings[4])     -- applying gps settings for 4th position - 122 km from 3rd - DistanceSat message is expected after that move
  local timeOfEventTc = os.time()  -- to get the correct value for verification
  framework.delay(3)                -- wait until report is generated

  -- back to distanceSatThld = 0 to get no more reports
  DISTANCE_SAT_THLD = 0       -- meters
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                             }
                   )

  -- DistanceSat message is expected
  expectedMins = {avlConstants.mins.distanceSat}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins)
  assert_not_nil(receivedMessages[avlConstants.mins.distanceSat], "DistanceSat message expected but not received")

end



--- TC checks if LoggedPosition message is periodically saved according to LoggingPositionsInterval for moving terminal
  -- *actions performed:
  -- configure loggingPositionsInterval to 20 seconds, simulate terminal in first position in Speeding and IgnitionOn state
  -- wait until report is saved in log, simulate terminal in second position (different than first) in non-speeding and IgnitionOff
  -- state and wait until report is saved in log; set LoggingPositionsInterval back to 0 not to get any more reports; send message to configure
  -- log filter and select entries created during the TC collect log form terminal and analyse every single field in the saved LoggedPosition reports
  -- (values in log should be the same as the state of terminal when message saved)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- LoggedPosition messages saved periodically in log according to LoggingPositionsInterval, fields of report have correct values
function test_LoggedPosition_ForTerminalInMovingStateAndLoggingPositionsIntervallGreaterThanZero_LoggedPositionMessageSavedPeriodically()

  local LOGGING_POSITIONS_INTERVAL = 25     -- seconds
  local NUMBER_OF_REPORTS = 2               -- number of expected reports received during the TC
  local MOVING_DEBOUNCE_TIME = 1            -- seconds
  local STATIONARY_SPEED_THLD = 5           -- kmh
  local timeOfLogEntry = {}               -- helper variables
  local digPortsVerification = {}         -- helper variables
  local avlStateVerification = {}         -- helper variables
  local gpsSettings = {}                  -- gpsSettings to be sent to simulator

  -- definition of first position of terminal
  gpsSettings[1] = {
                    speed = STATIONARY_SPEED_THLD + 10,   -- above speeding threshold to get speeding state
                    heading = 90,                         -- degrees
                    latitude = 1,                         -- degrees
                    longitude = 1                         -- degrees
                   }

  -- definition of second position of terminal
  gpsSettings[2] = {
                    speed = STATIONARY_SPEED_THLD,  -- terminal moving
                    heading = 30,                   -- degrees - different than in first position
                    latitude = 5,                   -- degrees - different than in first position
                    longitude = 5                   -- degrees - different than in first position
                    }

  -- setting the EIO properties (for IgnitionON)
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                        }
                   )

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn},       -- line number 1 set for Ignition function
                                              }
                   )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

  local loggingStartTime = os.time()     -- time of start of logging - to be used in log filter message

  -------------------------------------------------------------------------------------------------------------------------
  -- #1 log entry settings
  -------------------------------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[1])                          -- apply settings for first position and speeding state
  device.setIO(1, 1)                               -- port 1 to high level - that should trigger IgnitionOn
  framework.delay(LOGGING_POSITIONS_INTERVAL + 3)  -- wait for LoggingPositionsInterval (LoggedPosition message saved)
  timeOfLogEntry[1] = os.time()                    -- save timestamp for first log entry

  -- saving AvlStates and DigPorts properties for analysis
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  avlStateVerification[1] = tonumber(avlStatesProperty[1].value)
  -- saving digPortsProperty and DigPorts properties for analysis
  local digPortsProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.digPorts)
  digPortsVerification[1] = tonumber(digPortsProperty[1].value)


  -------------------------------------------------------------------------------------------------------------------------
  -- #2 log entry settings
  -------------------------------------------------------------------------------------------------------------------------
  gps.set(gpsSettings[2])                            -- apply settings for second position and non-speeding state
  device.setIO(1, 0)                                 -- port 1 to low level - that should trigger IgnitionOff
  framework.delay(LOGGING_POSITIONS_INTERVAL + 4)    -- wait for LoggingPositionsInterval (LoggedPosition message saved)
  timeOfLogEntry[2] = os.time()                      -- save timestamp for second log entry

  -- saving AvlStates and DigPorts properties for analysis
  avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  avlStateVerification[2] = tonumber(avlStatesProperty[1].value)
  -- saving digPortsProperty and DigPorts properties for analysis
  digPortsProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.digPorts)
  digPortsVerification[2] = tonumber(digPortsProperty[1].value)

  -------------------------------------------------------------------------------------------------------------------------
  -- disabling logging
  -------------------------------------------------------------------------------------------------------------------------
  LOGGING_POSITIONS_INTERVAL = 0     -- not to get any more messages saved
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                             }
                   )
  local loggingEndTime = os.time()     -- time of end of logging - to be used in log filter message

  -------------------------------------------------------------------------------------------------------------------------
  -- setting log filter
  -------------------------------------------------------------------------------------------------------------------------

  -- send setDataLogFilter to log service (to filter only LoggedPosition messages)
	local setDataLogFilterMessage = {SIN = lsfConstants.sins.log, MIN = lsfConstants.mins.setDataLogFilter}
  -- minList =  15 (filter only LoggedPosition)
  setDataLogFilterMessage.Fields = {{Name="timeStart",Value=loggingStartTime},{Name="timeEnd",Value=loggingEndTime},{Name="reverse",Value=false},
                                   {Name="list",Elements={{Index=0,Fields={{Name="sin",Value=126},{Name="minList",Value="Dw=="}}}}},}
  gateway.submitForwardMessage(setDataLogFilterMessage)

  -------------------------------------------------------------------------------------------------------------------------
  -- getting log entries
  -------------------------------------------------------------------------------------------------------------------------

  framework.delay(2)           -- wait until message is processed
  gateway.setHighWaterMark()   -- to get the newest messages

  -- send getDataLogEntries message
  local getDataLogEntriesMessage = {SIN = lsfConstants.sins.log, MIN = lsfConstants.mins.getDataLogEntries} -- add maximum entries to limit TODO
  getDataLogEntriesMessage.Fields = {{Name="maxEntries",Value=10},}
  gateway.submitForwardMessage(getDataLogEntriesMessage)

  -- DataLogEntries message is expected (SIN 23, MIN 5)
  local logEntriesMessage = gateway.getReturnMessage(framework.checkMessageType(lsfConstants.sins.log, lsfConstants.mins.dataLogEntries),nil,GATEWAY_TIMEOUT)

  assert_not_nil(next(logEntriesMessage.Payload.Fields[1].Elements), "Received LogEntries message is empty")

  -- check if values of the fields reported in LoggedPosition reports are correct (2 runs of the loop for two messages)
  for i = 1, 2, 1 do
    assert_equal(gpsSettings[i].latitude*60000, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[1].Value), "Latitude value is not correct in report")   -- multiplied by 60000 for conversion from miliminutes
    assert_equal(gpsSettings[i].longitude*60000, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[2].Value), "Longitude value is not correct in report") -- multiplied by 60000 for conversion from miliminutes
    assert_equal(gpsSettings[i].speed, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[3].Value), "Speed value is not correct in report")
    assert_equal(gpsSettings[i].heading, tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[4].Value), "Heading value is not correct in report")
    assert_equal(timeOfLogEntry[i], tonumber(logEntriesMessage.Payload.Fields[1].Elements[i].Fields[4].Message.Fields[5].Value),15, "EventTime value is not correct in report")
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
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- saving LoggedPosition messages does not deffer periodic Position message
  function test_LoggedPosition_WhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingPeriodicPositionMessage()

  local LOGGING_POSITIONS_INTERVAL =  2   -- seconds
  local POSITION_MSG_INTERVAL = 10        -- seconds
  local NUMBER_OF_POSITION_REPORTS = 3    -- number of expected reports received during the TC

  gateway.setHighWaterMark()   -- to get the newest messages
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )


  framework.delay(NUMBER_OF_POSITION_REPORTS*POSITION_MSG_INTERVAL + 3)    -- wait for position message interval multiplied by number of expected reports

  LOGGING_POSITIONS_INTERVAL = 0     -- seconds, not to get any more messages saved in log
  POSITION_MSG_INTERVAL = 0          -- seconds, not to get any more position messages

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.positionMsgInterval, POSITION_MSG_INTERVAL},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for Position messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.position))
  -- checking the number of received Position messages
  assert_equal(NUMBER_OF_POSITION_REPORTS, table.getn(matchingMessages) , "The number of received Position reports is incorrect")

end


--- TC checks if LoggedPosition message does not deffer sending periodic StationaryIntervalSat message
  -- *actions performed:
  -- make sure terminal is stationary; set loggingPositionsInterval to 2 seconds and stationaryIntervalSat to 10 seconds;
  -- apply property settings and wait for time of stationaryIntervalSat multiplied by number of expected reports; then set loggingPositionsInterval
  -- and stationaryIntervalSat to 0 not get more reports and check how many periodic stationaryIntervalSat reports has been sent;
  -- if stationaryIntervalSat message has not been deffered by saving LoggedPosition this number is expected to be numberOfReports defined in TC
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- saving LoggedPosition messages does not deffer periodic stationaryIntervalSat message
  function test_LoggedPosition_ForTerminalStationaryWhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingStationaryIntervalSat()

  local LOGGING_POSITIONS_INTERVAL =  2   -- seconds
  local NUMBER_OF_REPORTS = 3             -- number of expected reports received during the TC
  local STATIONARY_INTERVAL_SAT = 10      -- seconds
  local STATIONARY_SPEED_THLD = 10        -- kmh
  local MOVING_DEBOUNCE_TIME = 1          -- seconds

  -- applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  gps.set({speed = 0}) -- terminal stationary
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)        -- wait until terminal is stationary

  gateway.setHighWaterMark()   -- to get the newest messages
  --applying properties of the service, messages are saved to log and sent from mobile until now
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                            }
                   )

  framework.delay(NUMBER_OF_REPORTS*STATIONARY_INTERVAL_SAT + 3)    -- wait for stationaryIntervalSat interval multiplied by number of expected reports

  LOGGING_POSITIONS_INTERVAL = 0       -- seconds, not to get any more messages saved in log
  STATIONARY_INTERVAL_SAT = 0          -- seconds, not to get any more StationaryIntervalSat messages
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.stationaryIntervalSat, STATIONARY_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for stationaryIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.stationaryIntervalSat))
  -- checking the number of received stationaryIntervalSat messages
  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages) , "The number of received StationaryIntervalSat reports is incorrect")

end


--- TC checks if LoggedPosition message does not deffer sending periodic MovingIntervalSat message
  -- *actions performed:
  -- make sure terminal is moving; set loggingPositionsInterval to 2 seconds and movingIntervalSat to 10 seconds;
  -- apply property settings and wait for time of movingIntervalSat multiplied by number of expected reports; then set loggingPositionsInterval
  -- and movingIntervalSat to 0 not get more reports and check how many periodic MovingIntervalSat reports has been sent;
  -- if MovingIntervalSat message has not been deffered by saving LoggedPosition this number is expected to be numberOfReports defined in TC
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- saving LoggedPosition messages does not deffer periodic MovingIntervalSat message
  function test_LoggedPosition_ForTerminalMovingWhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingMovingIntervalSat()

  local LOGGING_POSITIONS_INTERVAL =  2   -- seconds
  local NUMBER_OF_REPORTS = 6             -- number of expected reports received during the TC
  local MOVING_INTERVAL_SAT = 10          -- seconds
  local STATIONARY_SPEED_THLD = 10        -- kmh
  local MOVING_DEBOUNCE_TIME = 1          -- seconds



  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )
  gps.set({speed = STATIONARY_SPEED_THLD + 10})     -- 10 kmh above threshold, to make terminal moving

  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL+ GPS_PROCESS_TIME) -- wait until terminal is moving

  gateway.setHighWaterMark()   -- to get the newest messages
  -- applying properties of the service, messages are saved to log and sent from mobile until now
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                            }
                   )

  framework.delay(NUMBER_OF_REPORTS*MOVING_INTERVAL_SAT + 3)    -- wait for movingIntervalSat interval multiplied by number of expected reports

  LOGGING_POSITIONS_INTERVAL = 0       -- seconds, not to get any more messages saved in log
  MOVING_INTERVAL_SAT = 0          -- seconds, not to get any more MovingIntervalSatmessages
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.movingIntervalSat, MOVING_INTERVAL_SAT},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for movingIntervalSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.movingIntervalSat))
  -- checking the number of received movingIntervalSat messages
  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages), 2 ,  "The number of received MovingIntervalSat reports is incorrect")

end




--- TC checks if LoggedPosition message does not deffer sending periodic DistanceSat messsage
  -- *actions performed:
  -- msimulate terminal moving with speed of 20 m/s (72 kmh); set loggingPositionsInterval to 2 seconds and distanceSatThld to 200 meters;
  -- apply property settings and wait for time of (distanceSatThld[m]/speed[m/s]) multiplied by numberOfReports; then set loggingPositionsInterval
  -- and distanceSatThld to 0 not get more reports and check how many  DistanceSat reports has been sent;
  -- if DistanceSat message has not been deffered by saving LoggedPosition this number is expected to be numberOfReports defined in TC
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of GPS_READ_INTERVAL
  -- *expected results:
  -- saving LoggedPosition messages does not deffer DistanceSat message
  function test_LoggedPosition_ForTerminalMovingyWhenLoggedPositionIntervalGreaterThanZero_SavingToLogDoesNotDefferSendingDistanceSatMessage()

  local LOGGING_POSITIONS_INTERVAL =  2   -- seconds
  local NUMBER_OF_REPORTS = 3             -- number of expected reports received during the TC
  local DISTANCE_SAT_THLD = 1112          -- meters - that is equivalent to 0,1 degree
  local STATIONARY_SPEED_THLD = 10        -- kmh
  local MOVING_DEBOUNCE_TIME = 1          -- seconds

  -- definition of first position of terminal
  local gpsSettings = {
                        speed = 72,                     -- kmh, 20 m/s
                        heading = 90,                   -- degrees
                        latitude = 1,                   -- degrees
                        longitude = 1,                  -- degrees
                        fixType = 3,                    -- valid fix provided
                        simulateLinearMotion = false
                       }

  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                                                {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                                             }
                   )

  gps.set(gpsSettings)
  framework.delay(MOVING_DEBOUNCE_TIME + GPS_READ_INTERVAL + GPS_PROCESS_TIME)        -- wait until terminal is moving

  gateway.setHighWaterMark()   -- to get the newest messages
  --applying properties of the service, messages are saved to log and sent from mobile until now
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                            }
                   )

  gps.set({latitude = gpsSettings.latitude + 0.1}) -- terminal travels 1112 m (0,1 degree)
  framework.delay(3)                               -- wait until distanceSat message is sent
  gps.set({latitude = gpsSettings.latitude + 0.2}) -- terminal travels 1112 m (0,1 degree)
  framework.delay(3)                               -- wait until distanceSat message is sent
  gps.set({latitude = gpsSettings.latitude + 0.3}) -- terminal travels 1112 m (0,1 degree)
  framework.delay(3)                               -- wait until distanceSat message is sent

  LOGGING_POSITIONS_INTERVAL = 0           -- seconds, not to get any more messages saved in log
  DISTANCE_SAT_THLD = 0                    -- seconds, not to get any more distanceSat messages
  --applying properties of the service
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.loggingPositionsInterval, LOGGING_POSITIONS_INTERVAL},
                                                {avlConstants.pins.distanceSatThld, DISTANCE_SAT_THLD},
                                             }
                   )

  -- receiving all from mobile messages sent after setHighWaterMark()
  local receivedMessages = gateway.getReturnMessages()
  -- look for distanceSat messages
  local matchingMessages = framework.filterMessages(receivedMessages, framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.distanceSat))
  -- checking the number of received distanceSat messages
  assert_equal(NUMBER_OF_REPORTS, table.getn(matchingMessages) , "The number of received DistanceSat reports is incorrect")

end

---------------------

-- test if an Air Communication Blocked (AirCommBlocked MIN 33) event occurs after blockage longer than AirBlockageTime
function test_AirCommBlockage_WhenAirCommIsBlockedForTimeLongerThanAirBlockagePeriod_AirCommBlockageEventGenerated()

  local AIR_BLOCKAGE_TIME = 1 -- minutes
  local AIR_BLOCKAGE_TIMEOUT = AIR_BLOCKAGE_TIME*60 + 10 -- seconds
  local WAIT_FOR_EVENT_TIMEOUT = 2 * AIR_BLOCKAGE_TIMEOUT
  local STATIONARY_SPEED_THLD = 1
  local MOVING_DEBOUNCE_TIME = 1
  local AIR_COMM_BLOCKED_MIN  = 33
  local EXPECTED_VALUE = 10

  -- set property AirBlockageTime
  lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.AirBlockageTime, AIR_BLOCKAGE_TIME},
                                             }
                    )

  -- triggering message to start blockage timing
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )
  gps.set({speed = EXPECTED_VALUE})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gateway.setHighWaterMark()

  gps.set({blockage = true})
  framework.delay(AIR_BLOCKAGE_TIMEOUT)
  gps.set({blockage = false})

  -- wait for event
  expectedMins = {AIR_COMM_BLOCKED_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check if event occurs
  assert_not_nil(receivedMessages[AIR_COMM_BLOCKED_MIN], "AirCommBlocked message not received.")
  -- check if value is correct
  assert_equal(EXPECTED_VALUE, tonumber(receivedMessages[AIR_COMM_BLOCKED_MIN].Speed) , 0, "Uncorrect value in AirCommBlocked message ")

end

-- test if an Air Communication Blocked (AirCommBlocked MIN 33) event doesn't occur after blockage less than AirBlockageTime
function test_AirCommBlockage_WhenAirCommIsBlockedForTimeShorterThanAirBlockagePeriod_AirCommBlockageEventNotGenerated()

  local AIR_BLOCKAGE_TIME = 1 -- minutes
  local AIR_BLOCKAGE_TIMEOUT = (AIR_BLOCKAGE_TIME*60) / 2  -- seconds
  local WAIT_FOR_EVENT_TIMEOUT = 30
  local STATIONARY_SPEED_THLD = 1
  local MOVING_DEBOUNCE_TIME = 1
  local AIR_COMM_BLOCKED_MIN  = 33
  local EXPECTED_VALUE = 10

  -- set property AirBlockageTime
  lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.AirBlockageTime, AIR_BLOCKAGE_TIME},
                                             }
                    )

  -- triggering message to start blockage timing
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )
  gps.set({speed = 0})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)
  gps.set({speed = EXPECTED_VALUE})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gateway.setHighWaterMark()

  gps.set({blockage = true})

  framework.delay(AIR_BLOCKAGE_TIMEOUT)

  gps.set({blockage = false})

  -- wait for event
  expectedMins = {AIR_COMM_BLOCKED_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check if event doesn't occur
  assert_nil(receivedMessages[AIR_COMM_BLOCKED_MIN], "AirCommBlocked message incorrectly received!")

end


function test_AirCommBlockage_WhenAirCommIsBlockedForTimeLongerThanAirBlockagePeriod_AirCommBlockageEventGeneratedAndDataIsReportedFromTheMomentWhenConditionWasMet()

  local AIR_BLOCKAGE_TIME = 1 -- minutes
  local AIR_BLOCKAGE_TIMEOUT = AIR_BLOCKAGE_TIME*60 + 10 -- seconds
  local WAIT_FOR_EVENT_TIMEOUT = 2 * AIR_BLOCKAGE_TIMEOUT -- it's max time of waiting for message
  local STATIONARY_SPEED_THLD = 1
  local MOVING_DEBOUNCE_TIME = 1
  local AIR_COMM_BLOCKED_MIN  = 33
  local NOT_EXPECTED_VALUE = 15
  local EXPECTED_VALUE = 10

  -- set property AirBlockageTime
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                              {avlConstants.pins.AirBlockageTime, AIR_BLOCKAGE_TIME},
                                             }
                    )

  -- triggering message to start blockage timing
  lsf.setProperties(AVL_SIN,{
                             {avlConstants.pins.stationarySpeedThld, STATIONARY_SPEED_THLD},
                             {avlConstants.pins.movingDebounceTime, MOVING_DEBOUNCE_TIME},
                            }
                   )
  gps.set({speed = EXPECTED_VALUE})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)

  gateway.setHighWaterMark()
  gps.set({blockage = true})
  framework.delay(AIR_BLOCKAGE_TIMEOUT/2)

 -- set value during blockage time
  gps.set({speed = EXPECTED_VALUE + 10})
  framework.delay(GPS_READ_INTERVAL + GPS_PROCESS_TIME)
  framework.delay(AIR_BLOCKAGE_TIMEOUT/2)
  gps.set({blockage = false})

  -- wait for event
  expectedMins = {AIR_COMM_BLOCKED_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, WAIT_FOR_EVENT_TIMEOUT)

  -- check if event occurs
  assert_not_nil(receivedMessages[AIR_COMM_BLOCKED_MIN], "AirCommBlocked message not received.")
  -- check if value is correct
  assert_equal(EXPECTED_VALUE, tonumber(receivedMessages[AIR_COMM_BLOCKED_MIN].Speed) , 0, "Uncorrect value in AirCommBlocked message ")

end

