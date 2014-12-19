-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestGeofencesModule

module("TestSensorsModule", package.seeall)

-------------------------------------------------------------------------------------

local Sensor = {}
  Sensor.__index = Sensor
  setmetatable(Sensor, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})
  
  function Sensor:_init(number)
    self.name = "Sensor".. number
    self.mins = {MaxStart = avlConstants.mins[self.name .. "MaxStart"],
                MaxEnd = avlConstants.mins[self.name .. "MaxEnd"],
                MinStart = avlConstants.mins[self.name .. "MinStart"],
                MinEnd = avlConstants.mins[self.name .. "MinEnd"],
                Change = avlConstants.mins[self.name .. "Change"],
                SensorInterval = avlConstants.mins.SensorInterval
      }
    self.pins = {
                  Source = avlConstants.pins[self.name .. "Source"],
                  ChangeThld = avlConstants.pins[self.name .. "ChangeThld"],
                  MinThld = avlConstants.pins[self.name .. "MinThld"],
                  MaxThld = avlConstants.pins[self.name .. "MaxThld"],
                  MaxReportInterval = avlConstants.pins[self.name .. "MaxReportInterval"],
                  NormalSampleInterval = avlConstants.pins[self.name .. "NormalSampleInterval"],
                  LpmSampleInterval = avlConstants.pins[self.name .. "LpmSampleInterval"],}
    
    self.pinValues = {MinThld = 0,
                       MaxThld = 0,
                       Source = {},
                       MaxReportInterval = 0,
                       NormalSampleInterval = 0,
                       LpmSampleInterval = 0,
                       ChangeThld = 0,
                       }
  end
  
  function Sensor:setPinValues(pinValues)
    self.pinValues = pinValues
  end
  
  function Sensor:applyPinValues(pinValues)
    if pinValues then
      self.pinValues = pinValues
    else
      pinValues = self.pinValues
    end
    pinValues = {{self.pins.Source, framework.base64Encode({pinValues.Source.SIN, pinValues.Source.PIN}), "data"},
                 {self.pins.ChangeThld, pinValues.ChangeThld},
                 {self.pins.MinThld, pinValues.MinThld, "signedint"},
                 {self.pins.MaxThld, pinValues.MaxThld, "signedint"},
                 {self.pins.MaxReportInterval, pinValues.MaxReportInterval},
                 {self.pins.NormalSampleInterval, pinValues.NormalSampleInterval},
                 {self.pins.LpmSampleInterval, pinValues.LpmSampleInterval},
                }
    
    lsf.setProperties(avlConstants.avlAgentSIN, pinValues)
  end

-----------------------------------------------

local SensorTester = {}
  SensorTester.__index = SensorTester
  setmetatable(SensorTester, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})
  
  function SensorTester:_init(value, min, max, step)
    value = value or 0
    step = step or 1
    self.previousValue = nil
    self.initial = value
    self.min = min
    self.max = max
    self.step = step
    self.conversion = 1
    SensorTester.setValue(self, self.initial)
  end
  
  function SensorTester:getSin()
    return self.sin
  end
  
  function SensorTester:getPin()
    return self.pin
  end
  
  function SensorTester:setValue(value)
    self.previousValue = self.currentValue
    self.currentValue = value
  end
  
  function SensorTester:getNormalized(val)
    return val * self.conversion
  end
  
  function SensorTester:getNormalizedValue()
    if not self.currentValue then return nil end
    return self:getNormalized(self.currentValue)
  end
  
  function SensorTester:getNormalizedPreviousValue()
    if not self.previousValue then return nil end
    return self:getNormalized(self.previousValue)
  end
  
  function SensorTester:setValueToMax(offset)
    self:setValue(self.max + offset)
  end
  
  function SensorTester:setValueToMin(offset)
    self:setValue(self.min + offset)
  end
    
  function SensorTester:stepUp(times)
    times = times or 1
    self:setValue(self.currentValue + self.step*times)
  end
  
  function SensorTester:stepDown(times)
    times = times or 1
    self:setValue(self.currentValue - self.step*times)
  end
  
  function SensorTester:setConf(initial, min, max, step)
    self.initial = initial
    self.min = min
    self.max = max
    self.step = step
  end
  
  function SensorTester:setValueToInitial()
    self:setValue(self.initial)
  end
  
----------------------------------------------------------------------
-- Implementation for sensor as GPS  
local SensorTesterGps = {}
  SensorTesterGps.__index = SensorTesterGps
  setmetatable(SensorTesterGps, {
    __index = SensorTester, -- this is what makes the inheritance work
    __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
    end,
  })
  
  function SensorTesterGps:_init(value, ...)
    SensorTester._init(self, value, ...)
    self.sin = 20
    self.pin = 6
    self.conversion = 60000
    self.initialFix = {speed = 0, heading = 0, latitude = value, longitude = 0}
    
  end
  
  function SensorTesterGps:setValue(value)
    SensorTester.setValue(self, value)
    self.fix = self.initialFix
    self.fix.latitude = value
    -- set new gps fix
    gps.set(self.fix)
    framework.delay(GPS_READ_INTERVAL)
  end
  
  function SensorTesterGps:setup()
    lsf.setProperties(lsfConstants.sins.position,{{lsfConstants.pins.gpsReadInterval, GPS_READ_INTERVAL},})
    framework.delay(GPS_READ_INTERVAL)
  end
  
  function SensorTesterGps:teardown()
    lsf.setProperties(lsfConstants.sins.position,{{lsfConstants.pins.gpsReadInterval, GPS_READ_INTERVAL},})
    framework.delay(GPS_READ_INTERVAL)
  end
  
local sensorTester = SensorTesterGps(-0.05, -0.07, -0.03, 0.01)
local NEAR_ZERO = 0.0001
-- Run for all Sensors or only one random per each test
local RUN_ALL = false

local function RandomSensorRun(func, ...)
  if RUN_ALL then
    for i=1,4 do
      func(i, ...)
      teardown()
      setup()
    end
    teardown()
  else
    return func(math.random(1,4), ...)
  end
end

-------------------------------------------------------------------------------------
  
-- Setup and Teardown

--- suite_setup
 -- suite_setup description

function suite_setup()
  sensorTester:setup()
end

-- executed after each test suite
function suite_teardown()
  sensorTester:teardown()
end

--- setup function
  -- setup function description
function setup()
end

-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()
  -- disable all sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {
                     --{avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor2Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor3Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor4Source, framework.base64Encode(""), "data"},
                     {avlConstants.pins.Sensor1NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor2NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor3NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor4NormalSampleInterval, 0},
                     {avlConstants.pins.Sensor1LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor2LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor3LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor4LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor1ChangeThld, 0},
                     {avlConstants.pins.Sensor2ChangeThld, 0},
                     {avlConstants.pins.Sensor3ChangeThld, 0},
                     {avlConstants.pins.Sensor4ChangeThld, 0},
                     {avlConstants.pins.Sensor1MinThld, 0},
                     {avlConstants.pins.Sensor2MinThld, 0},
                     {avlConstants.pins.Sensor3MinThld, 0},
                     {avlConstants.pins.Sensor4MinThld, 0},
                     {avlConstants.pins.Sensor1MaxThld, 0},
                     {avlConstants.pins.Sensor2MaxThld, 0},
                     {avlConstants.pins.Sensor3MaxThld, 0},
                     {avlConstants.pins.Sensor4MaxThld, 0},
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })

  device.setIO(1, 0) -- port is supposed to be in low level before every TC

   -- setting the EIO properties
  lsf.setProperties(lsfConstants.sins.io,{{lsfConstants.pins.portConfig[1], 0},     -- port disabled
                                         })

  local lpmTrigger = 0        -- 1 is for IgnitionOff

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{{avlConstants.pins.funcDigInp[1], 0},               -- line number 1 disabled
                                              {avlConstants.pins.lpmTrigger, lpmTrigger},         -- setting lpmTrigger
                                             })
  -- enable gps continuous mode
  lsf.setProperties(lsfConstants.sins.position, {{lsfConstants.pins.gpsReadInterval, GPS_READ_INTERVAL}})
  sensorTester:setValueToInitial()
end

-------------------------
-- Test Cases
-------------------------


-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor1
function test_PeriodicallySendingMessageContainingSensor1Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor1', source = 'Sensor1Source'})
end

-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor2
function test_PeriodicallySendingMessageContainingSensor2Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor2', source = 'Sensor2Source'})
end

-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor3
function test_PeriodicallySendingMessageContainingSensor3Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor3', source = 'Sensor3Source'})
end

-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Testing Sensor4
function test_PeriodicallySendingMessageContainingSensor4Values()
  generic_test_PeriodicallySendingMessageContainingSensorValues({name = 'Sensor4', source = 'Sensor4Source'})
end

-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Test logic
function generic_test_PeriodicallySendingMessageContainingSensorValues(configuration)

    local SENSOR_REPORTING_INTERVAL = 1 -- 60 secs
    local AVL_RESPONSE_MIN = 74
    local SENSOR_EXPECTED_VALUE = 0.02
    local DEFAULT_TIMEOUT = 5*60


    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins[configuration.source], framework.base64Encode({lsfConstants.sins.position, lsfConstants.pins.latitude}), "data" }
                                             }
                    )

    -- set monitored value in position service
    sensorTester:setValueToInitial()

    -- waiting for periodical report 1
    local expectedMins = {AVL_RESPONSE_MIN}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, DEFAULT_TIMEOUT+5)

    -- set monitored value in position service to expected value
    sensorTester:setValue(SENSOR_EXPECTED_VALUE)

    local startTime = os.time()

    -- waiting for periodical report 2
    receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,60+5)

    -- checking if timeout between two reports is ok
    local timeDiff = os.time() - startTime
    assert_equal(timeDiff , 60, 5, "Sensor Reporting Interval test failed - wrong timeout between messages")

    -- checking if raported value is monitored properly
    assert_equal(sensorTester:getNormalizedValue() , tonumber(receivedMessages[AVL_RESPONSE_MIN][configuration.name]), 0, "Sensor Reporting Interval test failed - wrong expected value")

end


--Sending a message when a sensor 1 value has changed by more than set amount
function test_changeSensor1ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor1ChangeThld'
  configuration.min = 77 -- 82, 87, 92
  configuration.source = 'Sensor1Source'
  configuration.sample_interval = 'Sensor1NormalSampleInterval'
  configuration.name = 'Sensor1'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByAmount(configuration)
end

--Sending a message when a sensor 2 value has changed by more than set amount
function test_changeSensor2ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor2ChangeThld'
  configuration.min = 82
  configuration.source = 'Sensor2Source'
  configuration.sample_interval = 'Sensor2NormalSampleInterval'
  configuration.name = 'Sensor2'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByAmount(configuration)
end

--Sending a message when a sensor 3 value has changed by more than set amount
function test_changeSensor3ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor3ChangeThld'
  configuration.min = 87
  configuration.source = 'Sensor3Source'
  configuration.sample_interval = 'Sensor3NormalSampleInterval'
  configuration.name = 'Sensor3'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByAmount(configuration)
end

--Sending a message when a sensor 4 value has changed by more than set amount
function test_changeSensor4ValueByAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor4ChangeThld'
  configuration.min = 92
  configuration.source = 'Sensor4Source'
  configuration.sample_interval = 'Sensor4NormalSampleInterval'
  configuration.name = 'Sensor4'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByAmount(configuration)
end

--Sending a message when a sensor value has changed by more than set amount
function generic_test_changeSensorValueByAmount(configuration)
  local AVL_RESPONSE_MIN = configuration.min
  local CHANGE_THLD = 1000
  local DEFAULT_TIMEOUT = 5*60

  local INIT_VALUE = 0.01
  local SENSOR_REPORTING_INTERVAL = configuration.reporting_interval
  local MSG_TIMEOUT = 65
  local SAMPLE_INTERVAL = 1
  local AVL_REPORT_MIN = avlConstants.mins.SensorInterval

  -- set first value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE, longitude = 1})

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins[configuration.change_thld_name], CHANGE_THLD},
                        {avlConstants.pins[configuration.sample_interval], SAMPLE_INTERVAL},
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins[configuration.source], framework.base64Encode({lsfConstants.sins.position, lsfConstants.pins.latitude}), "data" }
                                             }
                    )

  -- waiting for first change report msg
  local expectedMins = {AVL_RESPONSE_MIN,}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT+5)
  -- print(framework.dump(receivedMessages))

  -- set second value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE + 2*(CHANGE_THLD/60000) , longitude = 1})

  -- waiting for change message
  expectedMins = {AVL_RESPONSE_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT+5)
  -- print(framework.dump(receivedMessages))

  assert_not_nil(receivedMessages[AVL_RESPONSE_MIN], "Message with report not delivered")
  -- checking value (whitch triggered threshold)
  assert_equal( (INIT_VALUE + 2*(CHANGE_THLD/60000)) * 60000 , tonumber(receivedMessages[AVL_RESPONSE_MIN][configuration.name]), 1, "Problem with triggering change with threshold.")
end

--Sending a message when a sensor value has changed by less than set amount
function generic_test_changeSensorValueByLessThanAmount(configuration)
  local AVL_RESPONSE_MIN = configuration.min
  local CHANGE_THLD = 1000
  local DEFAULT_TIMEOUT = 5*60

  local INIT_VALUE = 0.01
  local SENSOR_REPORTING_INTERVAL = configuration.reporting_interval
  local MSG_TIMEOUT = 65
  local SAMPLE_INTERVAL = 1
  local AVL_REPORT_MIN = avlConstants.mins.SensorInterval

  -- set first value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE, longitude = 1})

  -- setting AVL properties
  lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins[configuration.change_thld_name], CHANGE_THLD},
                        {avlConstants.pins[configuration.sample_interval], SAMPLE_INTERVAL},
                        {avlConstants.pins.SensorReportingInterval, SENSOR_REPORTING_INTERVAL},
                        {avlConstants.pins[configuration.source], framework.base64Encode({lsfConstants.sins.position, lsfConstants.pins.latitude}), "data" }
                                             }
                    )

  -- message can be received - we establish previous report value for further calculations
  local expectedMins = {AVL_RESPONSE_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT+5)
  -- print(framework.dump(receivedMessages))

  -- set second value
  gps.set({  speed = 1, heading = 90, latitude = INIT_VALUE + 0.5*(CHANGE_THLD/60000) , longitude = 1})

  -- message should not be received
  expectedMins = {AVL_RESPONSE_MIN,}
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, MSG_TIMEOUT+5)
  -- print(framework.dump(receivedMessages))
  assert_nil(receivedMessages[AVL_RESPONSE_MIN], "Message should not be delivered (amount less than threshold)")

end

-- TC for seting single value of gps
function test_SettingGpsValue()
    local GPS_EXPECTED_VALUE = 2


    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{
                        {avlConstants.pins.Sensor1Source, framework.base64Encode({lsfConstants.sins.position, lsfConstants.pins.latitude}), "data" }
                                             }
                    )

    gps.set({  speed = 1, heading = 90, latitude = GPS_EXPECTED_VALUE, longitude = 2})
    framework.delay(3)

    --checking if raported value is set properly
    currentProperties = avlHelperFunctions.propertiesToTable(lsf.getProperties(lsfConstants.sins.position, {lsfConstants.pins.latitude}))
    sensor1Value = tonumber(currentProperties[lsfConstants.pins.latitude])
    assert_equal(GPS_EXPECTED_VALUE * 60000 , sensor1Value , 0, "Problem with gps setting (a sensor source)")
end

-- 666
-- Sending a message when a sensor 1 value has changed by more than set amount (when report interval zero)
function off_test_ChangeThresholdWhenReportIntervalZeroForSensor1()
  configuration = {}
  configuration.change_thld_name = 'Sensor1ChangeThld'
  configuration.min = 77
  configuration.source = 'Sensor1Source'
  configuration.sample_interval = 'Sensor1NormalSampleInterval'
  configuration.name = 'Sensor1'
  configuration.reporting_interval = 0

  generic_test_changeSensorValueByAmount(configuration)
end

-- Sending a message when a sensor 2 value has changed by more than set amount (when report interval zero)
function off_test_ChangeThresholdWhenReportIntervalZeroForSensor2()
  configuration = {}
  configuration.change_thld_name = 'Sensor2ChangeThld'
  configuration.min = 82
  configuration.source = 'Sensor2Source'
  configuration.sample_interval = 'Sensor2NormalSampleInterval'
  configuration.name = 'Sensor2'
  configuration.reporting_interval = 0

  generic_test_changeSensorValueByAmount(configuration)
end

-- Sending a message when a sensor 3 value has changed by more than set amount (when report interval zero)
function off_test_ChangeThresholdWhenReportIntervalZeroForSensor3()
  configuration = {}
  configuration.change_thld_name = 'Sensor3ChangeThld'
  configuration.min = 77
  configuration.source = 'Sensor3Source'
  configuration.sample_interval = 'Sensor3NormalSampleInterval'
  configuration.name = 'Sensor3'
  configuration.reporting_interval = 0

  generic_test_changeSensorValueByAmount(configuration)
end



-- Sending a message when a sensor 4 value has changed by more than set amount (when report interval zero)
function off_test_ChangeThresholdWhenReportIntervalZeroForSensor4()
  configuration = {}
  configuration.change_thld_name = 'Sensor4ChangeThld'
  configuration.min = 92
  configuration.source = 'Sensor4Source'
  configuration.sample_interval = 'Sensor4NormalSampleInterval'
  configuration.name = 'Sensor4'
  configuration.reporting_interval = 0

  generic_test_changeSensorValueByAmount(configuration)
end

-- Sending a message when a sensor 1 value has changed by less than set amount
function test_changeSensor1ValueByLessThanAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor1ChangeThld'
  configuration.min = 77
  configuration.source = 'Sensor1Source'
  configuration.sample_interval = 'Sensor1NormalSampleInterval'
  configuration.name = 'Sensor1'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByLessThanAmount(configuration)
end

-- Sending a message when a sensor 2 value has changed by more than set amount
function test_changeSensor2ValueByLessThanAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor2ChangeThld'
  configuration.min = 82
  configuration.source = 'Sensor2Source'
  configuration.sample_interval = 'Sensor2NormalSampleInterval'
  configuration.name = 'Sensor2'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByLessThanAmount(configuration)
end

-- Sending a message when a sensor 3 value has changed by more than set amount
function test_changeSensor3ValueByLessThanAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor3ChangeThld'
  configuration.min = 77
  configuration.source = 'Sensor3Source'
  configuration.sample_interval = 'Sensor3NormalSampleInterval'
  configuration.name = 'Sensor3'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByLessThanAmount(configuration)
end

-- Sending a message when a sensor 4 value has changed by more than set amount
function test_changeSensor4ValueByLessThanAmount()
  configuration = {}
  configuration.change_thld_name = 'Sensor4ChangeThld'
  configuration.min = 92
  configuration.source = 'Sensor4Source'
  configuration.sample_interval = 'Sensor4NormalSampleInterval'
  configuration.name = 'Sensor4'
  configuration.reporting_interval = 1

  generic_test_changeSensorValueByLessThanAmount(configuration)
end


-------------------------

-- Check if Message is sent if sensor value goes above threshold and then goes back below it
function generic_test_Sensors_SendMessageWhenValueAboveThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueAboveThreshold using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = 1
  sensor.pinValues.LPMSampleInterval = 3

  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()
  
  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(sensorTester.step)

  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")
  local FirstSampleTime = tonumber(msg.EventTime)

  sensorTester:setValueToMax(-sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxEnd}, GATEWAY_TIMEOUT)
  msg = receivedMessages[sensor.mins.MaxEnd]
  assert_not_nil(msg, 'Sensor did not send Max End message')
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMax), NEAR_ZERO, "SensorMax has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")
  local SecondSampleTime = tonumber(msg.EventTime)
  assert_gt(FirstSampleTime, SecondSampleTime, 'Message EventTime is too small')

end

-- Check if Message is sent if sensor value goes below threshold and then goes back above it
function generic_test_Sensors_SendMessageWhenValueBelowThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueBelowThreshold using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = 1
  sensor.pinValues.LPMSampleInterval = 3

  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")
  local FirstSampleTime = tonumber(msg.EventTime)

  sensorTester:setValueToMin(sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinEnd}, GATEWAY_TIMEOUT)
  msg = receivedMessages[sensor.mins.MinEnd]
  assert_not_nil(msg, 'Sensor did not send Min End message')
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMin), NEAR_ZERO, "SensorMin has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")
  local SecondSampleTime = tonumber(msg.EventTime)
  assert_gt(FirstSampleTime, SecondSampleTime, 'Message EventTime is too small')
end

-- Check if correnct Messages are sent if sensor value goes below min threshold and then jumps above max threshold
function generic_test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = 1
  sensor.pinValues.LPMSampleInterval = 3

  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  
  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinEnd, sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  -- check if min end message was sent
  msg = receivedMessages[sensor.mins.MinEnd]
  assert_not_nil(msg, 'Sensor did not send Min End message')
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMin), NEAR_ZERO, "SensorMin has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")

  msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")

end

-- Check if correnct Messages are sent if sensor value goes above max threshold and then jumps below min threshold
function generic_test_Sensors_SendMessageWhenValueAboveAndJumpBelowThreshold(sensorNo)
  print("Testing test_Sensors_SendMessageWhenValueAboveAndJumpBelowThreshold using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = 1
  sensor.pinValues.LPMSampleInterval = 3

  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  
  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart,
                                                             sensor.mins.MaxEnd}, GATEWAY_TIMEOUT)
  -- check if min end message was sent
  msg = receivedMessages[sensor.mins.MaxEnd]
  assert_not_nil(msg, 'Sensor did not send Max End message')
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMax), NEAR_ZERO, "SensorMax has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

  msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

end

function test_Sensors_ValueAboveAndBelowMaxThreshold_MaxStartMaxEndReceived()
  RandomSensorRun(generic_test_Sensors_SendMessageWhenValueAboveThreshold)
end

function test_Sensors_ValueBelowAndAboveMinThreshold_MinStartMinEndReceived()
  RandomSensorRun(generic_test_Sensors_SendMessageWhenValueBelowThreshold)
end

function test_Sensors_ValueBelowMinThenAboveMaxThreshold_MinStartMinEndMaxStartReceived()
  RandomSensorRun(generic_test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold)
end

function test_Sensors_ValueAboveMaxThenBelowMinThreshold_MaxStartMaxEndMinStartReceived()
  RandomSensorRun(generic_test_Sensors_SendMessageWhenValueAboveAndJumpBelowThreshold)
end

-- Check if correnct Messages are sent if sensor value goes above max threshold and then jumps below min threshold
function generic_test_Sensors_NormalSamplingInterval_MaxStartMaxEndMsgTimestampsDifferBySamplingInterval(sensorNo)
  print("Testing test_Sensors_SendMessageMaxMinDependingOnNormalSamplingInterval using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  local INITIAL_SAMPLE_INTERVAL = 1
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = INITIAL_SAMPLE_INTERVAL
  sensor.pinValues.LpmSampleInterval = 15
  
  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()
  
  -- to make sure the test starts from initial point
  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensor.pinValues.NormalSampleInterval = 7
  sensor:applyPinValues()
  framework.delay(sensor.pinValues.NormalSampleInterval)

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")
  local FirstSampleTimestamp = msg.EventTime

  -- Check if Max End message is send after time determined by Sample Interval
  sensorTester:setValueToMax(-sensorTester.step)
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxEnd,}, 1.5 * sensor.pinValues.NormalSampleInterval)
  msg = receivedMessages[sensor.mins.MaxEnd]
  local SecondSampleTimestamp = msg.EventTime
  assert_equal(SecondSampleTimestamp - FirstSampleTimestamp, sensor.pinValues.NormalSampleInterval, 1, 'Message Timestamps do not match sampling interval')

  -- Check if going above max and below max during single sampling time frame will not generate an event
  sensorTester:setValueToMax(sensorTester.step)
  framework.delay(INITIAL_SAMPLE_INTERVAL)
  sensorTester:setValueToMax(-sensorTester.step)
  framework.delay(INITIAL_SAMPLE_INTERVAL)
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart,
                                                             sensor.mins.MaxEnd}, 1.5 * sensor.pinValues.NormalSampleInterval)
  -- check if MaxStart or MaxEnd message was sent
  assert_nil(receivedMessages[sensor.mins.MaxEnd], 'Sensor send Max End message')
  assert_nil(receivedMessages[sensor.mins.MaxStart], 'Sensor send Max Start message')

end

function test_Sensors_NormalSamplingInterval_MaxStartMaxEndMsgTimestampsDifferBySamplingInterval()
  RandomSensorRun(generic_test_Sensors_NormalSamplingInterval_MaxStartMaxEndMsgTimestampsDifferBySamplingInterval)
end

function generic_test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval(sensorNo)
  print("Testing test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  local INITIAL_SAMPLE_INTERVAL = 1
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = INITIAL_SAMPLE_INTERVAL
  sensor.pinValues.LpmSampleInterval = 7

  sensorTester:setValueToInitial()
  
  sensor:applyPinValues()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message')
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

  --* Go into LPM mode

    local lpmEntryDelay = 0    -- in minutes
    local lpmTrigger = 1       -- 1 is for IgnitionOff

    -- setting the EIO properties
    lsf.setProperties(lsfConstants.sins.io,{{lsfConstants.pins.portConfig[1], 3},     -- port as digital input
                                            {lsfConstants.pins.portEdgeDetect[1], 3}  -- detection for both rising and falling edge
                                           })
    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{{avlConstants.pins.funcDigInp[1], avlConstants.funcDigInp.IgnitionOn}, -- line number 1 set for Ignition function
                                                {avlConstants.pins.lpmEntryDelay, lpmEntryDelay},                    -- time of lpmEntryDelay, in minutes
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},                                   -- setting lpmTrigger
                                               })
    -- activating special input function
    avlHelperFunctions.setDigStatesDefBitmap({"IgnitionOn"})

    device.setIO(1, 1) -- that should trigger IgnitionOn
    framework.delay(2)
    -- checking if terminal correctly goes to IgnitionOn state
    avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
    assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).IgnitionON, "terminal not in the IgnitionOn state")

    device.setIO(1, 0)                 -- port transition to low state; that should trigger IgnitionOff
    receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.ignitionOFF,}, GATEWAY_TIMEOUT)
    assert_not_nil(receivedMessages[avlConstants.mins.ignitionOFF], 'Terminal not in IgnitionOff / LPM state')

    framework.delay(lpmEntryDelay*60+5)    -- multiplication by 60 because lpmEntryDelay is in minutes

    avlStatesProperty = lsf.getProperties(avlConstants.avlAgentSIN,avlConstants.pins.avlStates)
    assert_true(avlHelperFunctions.stateDetector(avlStatesProperty).InLPM, "terminal not in the Low Power Mode state")
  --* End of Setting LPM

  -- Check if Max End message is send after time determined by Sample Interval

  --re enable continuous gps mode
  sensorTester:setup()
  
  sensorTester:setValueToMax(-sensorTester.step)
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxEnd,}, 1.5 * sensor.pinValues.LpmSampleInterval)
  msg = receivedMessages[sensor.mins.MaxEnd]
  assert_not_nil(msg, 'Message Max end not received')
  local FirstSampleTimestamp = msg.EventTime

  sensorTester:setValueToMax(sensorTester.step)
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart,}, 1.5 * sensor.pinValues.LpmSampleInterval)
  msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(receivedMessages[sensor.mins.MaxStart], 'Sensor did not send Max Start message')
  local SecondSampleTimestamp = msg.EventTime
  
  assert_equal(SecondSampleTimestamp - FirstSampleTimestamp, sensor.pinValues.LpmSampleInterval, 1, 'Message Timestamps do not match LPM sampling interval')   
    
  
end

function test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval()
  RandomSensorRun(generic_test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval)
end
