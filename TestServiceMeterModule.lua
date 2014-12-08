-----------
-- ServiceMeter test module
-- - contains Service Meter related test cases
-- @module TestServiceMeterModule

module("TestServiceMeterModule", package.seeall)

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


--- setup function puts terminal into the stationary state and checks if that state has been correctly obtained
  -- it also sets GPS_READ_INTERVAL (in position service) to the value of GPS_READ_INTERVAL, sets all 4 ports to low state
  -- and checks if terminal is not in the IgnitionOn state
  -- executed before each unit test
  -- *actions performed:
  -- setting of the GPS_READ_INTERVAL (in the position service) is made using global GPS_READ_INTERVAL variable
  -- function sets stationaryDebounceTime to 1 second, stationarySpeedThld to 5 kmh and simulated gps speed to 0 kmh
  -- then function waits until the terminal get the non-moving state and checks the state by reading the avlStatesProperty
  -- set all 4 ports to low state and check if terminal is not in the IgnitionOn state
  -- *initial conditions:
  -- terminal not in the low power mode
  -- *expected results:
  -- terminal correctly put in the stationary state and IgnitionOn false state
function setup()

  -- setting the continues mode of position service (SIN 20, PIN 15)
  lsf.setProperties(lsfConstants.sins.position,{
                                                  {lsfConstants.pins.gpsReadInterval,GPS_READ_INTERVAL}
                                               }
                    )

  -- put terminal into stationary state
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

  device.setIO(1, 0)                 -- that should trigger IgnitionOff
  framework.delay(2)                 -- wait until settings are applied

  -- checking IgnitionOn state - terminal is expected not be in the IgnitionON state
  local avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
  assert_false(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal incorrectly in the IgnitionOn state")

  -- setting the EIO properties - disabling all 4 I/O ports
  lsf.setProperties(lsfConstants.sins.io,{
                                            {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                            {lsfConstants.pins.portConfig[4], 0},      -- port disabled
                                        }
                    )

  -- disabling all digital input lines in AVL
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], 0},   -- 0 is for line disabled
                                                {avlConstants.pins.funcDigInp[2], 0},
                                                {avlConstants.pins.funcDigInp[3], 0},
                                                {avlConstants.pins.funcDigInp[4], 0},
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

function test_ServiceMeter_ForTerminalMovingWhenSMRandomActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    
    testCase = getRandomSm()
    
    if testCase == 0 then
      random_test_ServiceMeter_ForTerminalMovingWhenSM0ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    elseif testCase == 1 then
      random_test_ServiceMeter_ForTerminalMovingWhenSM1ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    elseif testCase == 2 then
      random_test_ServiceMeter_ForTerminalMovingWhenSM2ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    elseif testCase == 3 then
      random_test_ServiceMeter_ForTerminalMovingWhenSM3ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    elseif testCase == 4 then
      random_test_ServiceMeter_ForTerminalMovingWhenSM4ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
    end
    
  end
    

--- TC checks if ServiceMeter message is sent after GetServiceMeter request and SM0Time and SM0Distance fields
  -- are populated
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with IgnitionOnAndSM0 line
  -- set the high state of the port to be a trigger for line activation and activate IgnitionOn in DigStatesDefBitmap
  -- send setServiceMeter message to set SM0Distance and SM0Time to zero; then simulate port 1 value change to high state
  -- to activate SM0 (and IgnitionON); enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify the fields in the received reportorted fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; SM0Time and SM0Distance correctly reported
function random_test_ServiceMeter_ForTerminalMovingWhenSM0ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
  
   -- test configuration
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  configuration.numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  configuration.odometerDistanceIncrement = 10  -- in meters
  
  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = configuration.stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                   }
                   
  configuration.funcDigInp = avlConstants.funcDigInp.IgnitionAndSM0
  configuration.bitmap = {"IgnitionOn"}
  configuration.name_time = "SM0Time"
  configuration.name_distance = "SM0Distance"

  -- test implementation
  generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)
  
  -- part of implementation unique for SM0
  device.setIO(1, 0)  -- port 1 to low level - that should trigger IgnitionOff and deactivate SM0
  framework.delay(5)  -- wait until IgnitionOn message

end



--- TC checks if SetServiceMeter message correctly sets SM0Time and SM0Distance
  -- are populated
  -- *actions performed:
  -- in funcDigInp set line 1 as IgnitionAndSM0 and activate IgnitionOn in DigStatesDefBitmap
  -- send setServiceMeter message to set SM0Distance and SM0Time to known values; then send GetServiceMeter request
  -- and check if ServiceMeter message is sent after that and values of SM0Time and SM0Distance are correct (as set in TC)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- SetServiceMeter message correctly sets SM0Time and SM0Distance
function test_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSM0TimeAndSM0DistanceAndAfterServiceMeterRequestSent_ServiceMeterMessageSent()
  
  -- test configuration
  
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.SMTimeTC = 10                  -- hours
  configuration.SMDistanceTC = 500             -- kilometers


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = 0,                        -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                 }
                 
  configuration.funcDigInp = avlConstants.funcDigInp.IgnitionAndSM0
  configuration.bitmap = {"IgnitionOn"}
  configuration.name_time = "SM0Time"
  configuration.name_distance = "SM0Distance"
          
  -- test implementation (common for every SM)        
  generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)

end

--- TC checks if ServiceMeter message is sent after GetServiceMeter request and SM1Time and SM1Time fields
  -- are populated
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with SM1 line
  -- set the high state of the port to be a trigger for line activation and activate SM1 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM1Distance and SM1Time to zero; then simulate port 1 value change to high state
  -- to activate SM1; enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify the fields in the received reportorted fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; SM1Time and SM1Distance correctly reported
function random_test_ServiceMeter_ForTerminalMovingWhenSM1ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
  
  -- test configuration
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  configuration.numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  configuration.odometerDistanceIncrement = 10  -- in meters


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = configuration.stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                   }
                   
  configuration.funcDigInp = avlConstants.funcDigInp.SM1
  configuration.bitmap = {"SM1Active"}
  configuration.name_time = "SM1Time"
  configuration.name_distance = "SM1Distance"

  -- test implementation
  generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)

end


--- TC checks if SetServiceMeter message correctly sets SM1Time and SM1Distance
  -- are populated
  -- *actions performed:
  -- in funcDigInp set line 1 as SM1 and activate SM1 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM1Distance and SM1Time to known values; then send GetServiceMeter request
  -- and check if ServiceMeter message is sent after that and values of SM1Time and SM1Distance are correct (as set in TC)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- SetServiceMeter message correctly sets SM1Time and SM1Distance
function test_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSM1TimeAndSM1DistanceAndAfterServiceMeterRequestSent_ServiceMeterMessageSent()
  
  -- test configuration
  
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.SMTimeTC = 10                  -- hours
  configuration.SMDistanceTC = 500             -- kilometers


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = 0,                        -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                 }
                 
  configuration.funcDigInp = avlConstants.funcDigInp.SM1
  configuration.bitmap = {"SM1Active"}
  configuration.name_time = "SM1Time"
  configuration.name_distance = "SM1Distance"
          
  -- test implementation        
  generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)

end




--- TC checks if ServiceMeter message is sent after GetServiceMeter request and SM2Time and SM2Time fields
  -- are populated
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with SM2 line
  -- set the high state of the port to be a trigger for line activation and activate SM1 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM2Distance and SM2Time to zero; then simulate port 1 value change to high state
  -- to activate SM2; enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify the fields in the received reportorted fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; SM2Time and SM2Distance correctly reported
function random_test_ServiceMeter_ForTerminalMovingWhenSM2ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
  
  -- test configuration
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  configuration.numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  configuration.odometerDistanceIncrement = 10  -- in meters
  
  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = configuration.stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                   }
                   
  configuration.funcDigInp = avlConstants.funcDigInp.SM2
  configuration.bitmap = {"SM2Active"}
  configuration.name_time = "SM2Time"
  configuration.name_distance = "SM2Distance"

  -- test implementation
  generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)

end



--- TC checks if SetServiceMeter message correctly sets SM2Time and SM2Distance
  -- are populated
  -- *actions performed:
  -- in funcDigInp set line 1 as SM2 and activate SM2 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM2Distance and SM2Time to known values; then send GetServiceMeter request
  -- and check if ServiceMeter message is sent after that and values of SM2Time and SM2Distance are correct (as set in TC)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- SetServiceMeter message correctly sets SM2Time and SM2Distance
function test_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSM2TimeAndSM2DistanceAndAfterServiceMeterRequestSent_ServiceMeterMessageSent()
  
    -- test configuration
  
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.SMTimeTC = 10                  -- hours
  configuration.SMDistanceTC = 500             -- kilometers


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = 0,                        -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                 }
                 
  configuration.funcDigInp = avlConstants.funcDigInp.SM2
  configuration.bitmap = {"SM2Active"}
  configuration.name_time = "SM2Time"
  configuration.name_distance = "SM2Distance"
          
  -- test implementation (common for every SM)        
  generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)

end


--- TC checks if ServiceMeter message is sent after GetServiceMeter request and SM3Time and SM3Time fields
  -- are populated
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with SM3 line
  -- set the high state of the port to be a trigger for line activation and activate SM3 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM3Distance and SM3Time to zero; then simulate port 1 value change to high state
  -- to activate SM3; enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify the fields in the received reportorted fields
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; SM3Time and SM3Distance correctly reported
function random_test_ServiceMeter_ForTerminalMovingWhenSM3ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
  
  -- test configuration
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  configuration.numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  configuration.odometerDistanceIncrement = 10  -- in meters
  
  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = configuration.stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                   }
                   
  configuration.funcDigInp = avlConstants.funcDigInp.SM3
  configuration.bitmap = {"SM3Active"}
  configuration.name_time = "SM3Time"
  configuration.name_distance = "SM3Distance"

  -- test implementation
  generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)
  

end

--- TC checks if SetServiceMeter message correctly sets SM3Time and SM3Distance
  -- are populated
  -- *actions performed:
  -- in funcDigInp set line 1 as SM3 and activate SM3 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM3Distance and SM3Time to known values; then send GetServiceMeter request
  -- and check if ServiceMeter message is sent after that and values of SM3Time and SM3Distance are correct (as set in TC)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- SetServiceMeter message correctly sets SM3Time and SM3Distance
function test_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSM3TimeAndSM3DistanceAndAfterServiceMeterRequestSent_ServiceMeterMessageSent()
  
    -- test configuration
  
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.SMTimeTC = 10                  -- hours
  configuration.SMDistanceTC = 500             -- kilometers


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = 0,                        -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                 }
                 
  configuration.funcDigInp = avlConstants.funcDigInp.SM3
  configuration.bitmap = {"SM3Active"}
  configuration.name_time = "SM3Time"
  configuration.name_distance = "SM3Distance"
          
  -- test implementation (common for every SM)        
  generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)

end


--- TC checks if ServiceMeter message is sent after GetServiceMeter request and SM4Time and SM4Time fields
  -- are populated
  -- *actions performed:
  -- configure port 1 as a digital input and associate this port with SM4 line
  -- set the high state of the port to be a trigger for line activation and activate SM4 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM4Distance and SM4Time to zero; then simulate port 1 value change to high state
  -- to activate SM4; enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify the fields in the received report
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; SM4Time and SM4Distance correctly reported
function random_test_ServiceMeter_ForTerminalMovingWhenSM4ActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()
  
   -- test configuration
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  configuration.numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  configuration.odometerDistanceIncrement = 10  -- in meters
  
  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = configuration.stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                   }
                   
  configuration.funcDigInp = avlConstants.funcDigInp.SM4
  configuration.bitmap = {"SM4Active"}
  configuration.name_time = "SM4Time"
  configuration.name_distance = "SM4Distance"

  -- test implementation
  generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)

end


--- TC checks if SetServiceMeter message correctly sets SM4Time and SM4Distance
  -- are populated
  -- *actions performed:
  -- in funcDigInp set line 1 as SM4 and activate SM4 in DigStatesDefBitmap
  -- send setServiceMeter message to set SM4Distance and SM4Time to known values; then send GetServiceMeter request
  -- and check if ServiceMeter message is sent after that and values of SM4Time and SM4Distance are correct (as set in TC)
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- SetServiceMeter message correctly sets SM4Time and SM4Distance
function test_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSM4TimeAndSM4DistanceAndAfterServiceMeterRequestSent_ServiceMeterMessageSent()
  
    -- test configuration
  
  configuration = {}

  -- properties values to be used in TC
  configuration.movingDebounceTime = 1          -- seconds
  configuration.stationarySpeedThld = 5         -- kmh
  configuration.SMTimeTC = 10                  -- hours
  configuration.SMDistanceTC = 500             -- kilometers


  -- gpsSettings table to be sent to simulator
  configuration.gpsSettings={
              speed = 0,                        -- terminal in stationary state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                 }
                 
  configuration.funcDigInp = avlConstants.funcDigInp.SM4
  configuration.bitmap = {"SM4Active"}
  configuration.name_time = "SM4Time"
  configuration.name_distance = "SM4Distance"
          
  -- test implementation (common for every SM)        
  generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)

end



--- TC checks if ServiceMeter message reports correct values of all active ServiceMeters (SM1 to SM4)
  -- are populated
  -- *actions performed:
  -- configure all 4 ports a digital input and associate them with all 4 ServiceMeters lines
  -- set the high state of the port to be a trigger for line activation and activate all ServiceMeters in DigStatesDefBitmap
  -- send setServiceMeter message to set ServiceMeters initial distances and times; then simulate all 4 ports value change to high state
  -- to activate ServiceMeters; enter loop with numberOfSteps iterations and change terminals positon of distanceOfStep
  -- distance with every run; in every iteration send GetServiceMeter message and check if ServiceMeter message is sent after the
  -- request; verify if all 4 ServiceMeters values are correctly reported
  -- *initial conditions:
  -- terminal not in the moving state and not in the low power mode, gps read periodically with interval of
  -- GPS_READ_INTERVAL; all 4 ports in LOW state, terminal not in the IgnitionOn state
  -- *expected results:
  -- ServiceMeter message send after GetServiceMeter request; All SMTimes and SMDistances are correctly reported
function test_ServiceMeter_ForTerminalMovingWhenAllServiceMetersActiveAndGetServiceMeterRequestSent_ServiceMeterMessageSent()

  -- properties values to be used in TC
  local movingDebounceTime = 1          -- seconds
  local stationarySpeedThld = 5         -- kmh
  local distanceOfStep = 1              -- degrees (1 degree = 111,12 km)
  local numberOfSteps = 4               -- number of steps in terminal travel (with length of stepOfTravel)
  local odometerDistanceIncrement = 10  -- in meters
  local SM1TimeInitial = 0              -- hours, initial value of ServiceMeter
  local SM1DistanceInitial = 0          -- km, initial value of ServiceMeter
  local SM2TimeInitial = 100            -- hours, initial value of ServiceMeter
  local SM2DistanceInitial = 200        -- km, initial value of ServiceMeter
  local SM3TimeInitial = 44             -- hours, initial value of ServiceMeter
  local SM3DistanceInitial = 44         -- km, initial value of ServiceMeter
  local SM4TimeInitial = 500            -- hours, initial value of ServiceMeter
  local SM4DistanceInitial = 500        -- km, initial value of ServiceMeter


  -- gpsSettings table to be sent to simulator
  local gpsSettings={
              speed = stationarySpeedThld+10,   -- terminal in moving state
              latitude = 1,                     -- degrees
              longitude = 1,                    -- degrees
              fixType = 3,                      -- valid fix provided, no GpsFixAge expected in the report
              heading = 100,                    -- degrees
                     }

  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[2], 3},     -- port 2 as digital input
                                                {lsfConstants.pins.portEdgeDetect[2], 3}, -- detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[3], 3},     -- port 3 as digital input
                                                {lsfConstants.pins.portEdgeDetect[3], 3}, -- detection for both rising and falling edge
                                                {lsfConstants.pins.portConfig[4], 3},     -- port 4 as digital input
                                                {lsfConstants.pins.portEdgeDetect[4], 3}, -- detection for both rising and falling edge
                                         }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.SM1},    -- line number 1 set for SM1
                                                {avlConstants.pins.funcDigInp[2], avlConstants.funcDigInp.SM2},    -- line number 2 set for SM2
                                                {avlConstants.pins.funcDigInp[3], avlConstants.funcDigInp.SM3},    -- line number 3 set for SM3
                                                {avlConstants.pins.funcDigInp[4], avlConstants.funcDigInp.SM4},    -- line number 4 set for SM4
                                                {avlConstants.pins.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                 )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap({"SM1Active","SM2Active","SM3Active","SM4Active",})


  device.setIO(1, 0)  -- port 1 to low level - that should trigger SM1 = OFF
  device.setIO(2, 0)  -- port 2 to low level - that should trigger SM2 = OFF
  device.setIO(3, 0)  -- port 3 to low level - that should trigger SM3 = OFF
  device.setIO(4, 0)  -- port 4 to low level - that should trigger SM4 = OFF

  gps.set(gpsSettings) -- applying gps settings

  framework.delay(movingDebounceTime+10)  -- wait until terminal goes into moving state

  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setServiceMeter}
	message.Fields = {{Name="SM1Time",Value=SM1TimeInitial},{Name="SM1Distance",Value=SM1DistanceInitial},{Name="SM2Time",Value=SM2TimeInitial},{Name="SM2Distance",Value=SM2DistanceInitial},
                    {Name="SM3Time",Value=SM3TimeInitial},{Name="SM3Distance",Value=SM3DistanceInitial},{Name="SM4Time",Value=SM4TimeInitial},{Name="SM4Distance",Value=SM4DistanceInitial}}
	gateway.submitForwardMessage(message)

  device.setIO(1, 1)  -- port 1 to high level - that should trigger SM1 = ON
  device.setIO(2, 1)  -- port 2 to high level - that should trigger SM2 = ON
  device.setIO(3, 1)  -- port 3 to high level - that should trigger SM3 = ON
  device.setIO(4, 1)  -- port 4 to high level - that should trigger SM4 = ON
  framework.delay(5)  -- wait until ServiceMeters are active


  -- loop with numberOfSteps iterations changing position of terminal and requesting ServiceMeter message with every run
  for counter = 1, numberOfSteps, 1 do

    -- terminal moving to another point distanceOfStep away from the initial position
    gpsSettings.latitude = gpsSettings.latitude + distanceOfStep
    gps.set(gpsSettings)               -- applying gps settings
    framework.delay(2)                 -- wait until settings are applied

    gateway.setHighWaterMark()         -- to get the newest messages

    -- sending getServiceMeter message
    local getServiceMeterMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getServiceMeter}    -- to trigger ServiceMeter event
    gateway.submitForwardMessage(getServiceMeterMessage)
    --ServiceMeter message is expected
    message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.serviceMeter),nil,GATEWAY_TIMEOUT)
    assert_not_nil(message, "ServiceMeter message not received")
    local expectedValues={
                    gps = gpsSettings,
                    messageName = "ServiceMeter",
                    currentTime = os.time(),
                    SM1Time = SM1TimeInitial,                                          -- zero hours of increase SM1 is expected
                    SM1Distance = SM1DistanceInitial + (distanceOfStep*111.12)*counter,  -- with every loop run distance increases of distanceOfStep multiplied by 111 kilometers and number iteration
                    SM2Time = SM2TimeInitial,                                      -- zero hours of increase SM2 is expected
                    SM2Distance = SM2DistanceInitial + (distanceOfStep*111.12)*counter,  -- with every loop run distance increases of distanceOfStep multiplied by 111 kilometers and number iteration
                    SM3Time = SM3TimeInitial,                                      -- zero hours of increase SM3 is expected
                    SM3Distance = SM3DistanceInitial + (distanceOfStep*111.12)*counter,  -- with every loop run distance increases of distanceOfStep multiplied by 111 kilometers and number iteration
                    SM4Time = SM4TimeInitial,                                      -- zero hours of increase SM4 is expected
                    SM4Distance = SM4DistanceInitial + (distanceOfStep*111.12)*counter,  -- with every loop run distance increases of distanceOfStep multiplied by 111 kilometers and number iteration
                          }
    if(hardwareVariant==3) then
      expectedValues.SM4Time = nil       -- 800 has only 3 I/O's
      expectedValues.SM4Distance = nil   -- 800 has only 3 I/O's
    end

    avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields


 end

end


-- common implemetation for several of test cases
function generic_ServiceMeter_ForTerminalStationarySetServiceMeterMessageSetsSMX(configuration)
  
  local movingDebounceTime = configuration.movingDebounceTime
  local stationarySpeedThld = configuration.stationarySpeedThld
  local SMTimeTC = configuration.SMTimeTC
  local SMDistanceTC = configuration.SMDistanceTC 
  local gpsSettings= configuration.gpsSettings
                  
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], configuration.funcDigInp},    -- line number 1 set for SM1
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                 )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap(configuration.bitmap)
  
  gps.set(gpsSettings) -- applying gps settings

  framework.delay(5)  -- wait until settings are applied

  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setServiceMeter}
	message.Fields = {{Name=configuration.name_time,Value=SMTimeTC},{Name=configuration.name_distance,Value=SMDistanceTC},}
	gateway.submitForwardMessage(message)

  framework.delay(5)  -- wait until message is processed

  gateway.setHighWaterMark()         -- to get the newest messages

  -- sending getServiceMeter message
  local getServiceMeterMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getServiceMeter}    -- to trigger ServiceMeter event
	gateway.submitForwardMessage(getServiceMeterMessage)
  gpsSettings.heading = 361  -- for stationary state
  --ServiceMeter message is expected
  message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.serviceMeter),nil,GATEWAY_TIMEOUT)
  assert_not_nil(message, "ServiceMeter message not received")

  local expectedValues={
                  gps = gpsSettings,
                  messageName = "ServiceMeter",
                  currentTime = os.time(),
                  [configuration.name_time] = SMTimeTC,           -- excpected value is SMTimeTC
                  [configuration.name_distance] =  SMDistanceTC   -- expected value is SMDistanceTC
                        }
  
  avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
  
  -- verify properties
  propList = {avlConstants.pins[configuration.name_time], avlConstants.pins[configuration.name_distance]}
  currentProperties = lsf.getProperties(avlConstants.avlAgentSIN, propList)
  expectedProperties = {[avlConstants.pins[configuration.name_time]] = SMTimeTC*60*60, 
                              [avlConstants.pins[configuration.name_distance]] = SMDistanceTC*1000}
                            
  for index, value in ipairs(currentProperties) do
    assert_equal(tonumber(value.value), expectedProperties[tonumber(value.pin)], 0,
                 'Service Meter property ' .. value.pin .. ' value different than expected')
  end

end

function generic_ServiceMeter_ForTerminalMovingWhenSMX(configuration)
  
  local movingDebounceTime = configuration.movingDebounceTime
  local stationarySpeedThld = configuration.stationarySpeedThld
  local distanceOfStep = configuration.distanceOfStep
  local numberOfSteps = configuration.numberOfSteps
  local odometerDistanceIncrement = configuration.odometerDistanceIncrement
  
  local gpsSettings= configuration.gpsSettings
  
  
  -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{
                                                {lsfConstants.pins.portConfig[1], 3},     -- port 1 as digital input
                                                {lsfConstants.pins.portEdgeDetect[1], 3}, -- detection for both rising and falling edge
                                         }
                   )
  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                                                {avlConstants.pins.funcDigInp[1], configuration.funcDigInp},    -- line number 1 set for SM1
                                                {avlConstants.pins.odometerDistanceIncrement, odometerDistanceIncrement},
                                                {avlConstants.pins.stationarySpeedThld, stationarySpeedThld},
                                                {avlConstants.pins.movingDebounceTime, movingDebounceTime},
                                             }
                 )
  -- activating special input function
  avlHelperFunctions.setDigStatesDefBitmap(configuration.bitmap)

  gps.set(gpsSettings) -- applying gps settings

  framework.delay(movingDebounceTime+10)  -- wait until terminal goes into moving state

  local message = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.setServiceMeter}
  
	message.Fields = {{Name = configuration.name_time,Value=0},{Name = configuration.name_distance,Value=0},}
	gateway.submitForwardMessage(message)

  device.setIO(1, 1)  -- port 1 to high level - that should trigger SM1 = ON
  framework.delay(5)  -- wait until IgnitionOn message

  -- loop with numberOfSteps iterations changing position of terminal and requesting ServiceMeter message with every run
  for counter = 1, numberOfSteps, 1 do

    -- terminal moving to another point distanceOfStep away from the initial position
    gpsSettings.latitude = gpsSettings.latitude + distanceOfStep
    gps.set(gpsSettings)               -- applying gps settings
    framework.delay(4)                 -- wait until settings are applied

    gateway.setHighWaterMark()         -- to get the newest messages

    -- sending getServiceMeter message
    local getServiceMeterMessage = {SIN = avlConstants.avlAgentSIN, MIN = avlConstants.mins.getServiceMeter}    -- to trigger ServiceMeter event
    gateway.submitForwardMessage(getServiceMeterMessage)

    --ServiceMeter message is expected
    message = gateway.getReturnMessage(framework.checkMessageType(avlConstants.avlAgentSIN, avlConstants.mins.serviceMeter),nil,GATEWAY_TIMEOUT)
    assert_not_nil(message, "ServiceMeter message not received")

    local expectedValues={
                    gps = gpsSettings,
                    messageName = "ServiceMeter",
                    currentTime = os.time(),
                    [configuration.name_time] = 0,                             -- zero hours of SM1 is expected, value has been set to 0 a moment ago
                    [configuration.name_distance] = (distanceOfStep*111.12)*counter  -- with every loop run distance increases of distanceOfStep multiplied by 111 kilometers and number iteration
                          }

    avlHelperFunctions.reportVerification(message, expectedValues ) -- verification of the report fields
    
  end
  
end

function getRandomSm()
  testCase = lunatest.random_int (0, 4)
  print("SM"..testCase.." choosen.")
  return testCase
end

--]]


