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
    self.pins = { SensorReportingInterval = avlConstants.pins.SensorReportingInterval,
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
                       SensorReportingInterval = 0
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
                 {self.pins.SensorReportingInterval, pinValues.SensorReportingInterval},
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
    self:setValueToInitial()
  end

  function SensorTesterGps:teardown()
    self:setValue(0)
    lsf.setProperties(lsfConstants.sins.position,{{lsfConstants.pins.gpsReadInterval, GPS_READ_INTERVAL},})
    framework.delay(GPS_READ_INTERVAL)
  end

local sensorTester = SensorTesterGps(-0.05, -0.07, -0.03, 0.01)
local NEAR_ZERO = 0.0001
-- Run for all Sensors or only one random per each test
local RUN_ALL = FORCE_ALL_TESTCASES

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


  sensorTester:setup()
  sensorTester:setValueToMax(sensorTester.step)

  -- Reset sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {
                     {avlConstants.pins.Sensor1Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor2Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor3Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor4Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor1NormalSampleInterval, 1}, {avlConstants.pins.Sensor2NormalSampleInterval, 1},
                     {avlConstants.pins.Sensor3NormalSampleInterval, 1}, {avlConstants.pins.Sensor4NormalSampleInterval, 1},
                     {avlConstants.pins.Sensor1LpmSampleInterval, 0}, {avlConstants.pins.Sensor2LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor3LpmSampleInterval, 0}, {avlConstants.pins.Sensor4LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor1ChangeThld, 1}, {avlConstants.pins.Sensor2ChangeThld, 1},
                     {avlConstants.pins.Sensor3ChangeThld, 1}, {avlConstants.pins.Sensor4ChangeThld, 1},
                     {avlConstants.pins.Sensor1MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor2MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor3MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor4MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor1MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor2MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor3MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor4MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor1MaxReportInterval, 0}, {avlConstants.pins.Sensor2MaxReportInterval, 0},
                     {avlConstants.pins.Sensor3MaxReportInterval, 0}, {avlConstants.pins.Sensor4MaxReportInterval, 0},
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })

  -- All sensors to initial state
  gateway.setHighWaterMark()
  sensorTester:setValueToInitial()
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1Change, avlConstants.mins.Sensor2Change,
                                                                   avlConstants.mins.Sensor3Change, avlConstants.mins.Sensor4Change}, GATEWAY_TIMEOUT)
  -- disable sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {
                     {avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
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
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })
  gateway.setHighWaterMark()
end

-- executed after each test suite
function suite_teardown()
  sensorTester:teardown()
end

--- setup function
  -- setup function description
function setup()
  sensorTester:setValueToInitial()
  gateway.setHighWaterMark()

end

-----------------------------------------------------------------------------------------------
--- teardown function executed after each unit test
function teardown()

  -- disable LPM
    device.setIO(1, 0) -- port is supposed to be in low level before every TC

     -- setting the EIO properties
    lsf.setProperties(lsfConstants.sins.io,{{lsfConstants.pins.portConfig[1], 0},     -- port disabled
                                           })

    local lpmTrigger = 0        -- 1 is for IgnitionOff

    -- setting AVL properties
    lsf.setProperties(avlConstants.avlAgentSIN,{{avlConstants.pins.funcDigInp[1], 0},               -- line number 1 disabled
                                                {avlConstants.pins.lpmTrigger, lpmTrigger},         -- setting lpmTrigger
                                               })


  sensorTester:setup()
  sensorTester:setValueToMax(sensorTester.step)

  -- Reset sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {
                     {avlConstants.pins.Sensor1Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor2Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor3Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor4Source, framework.base64Encode({sensorTester:getSin(), sensorTester:getPin()}), "data"},
                     {avlConstants.pins.Sensor1NormalSampleInterval, 1}, {avlConstants.pins.Sensor2NormalSampleInterval, 1},
                     {avlConstants.pins.Sensor3NormalSampleInterval, 1}, {avlConstants.pins.Sensor4NormalSampleInterval, 1},
                     {avlConstants.pins.Sensor1LpmSampleInterval, 0}, {avlConstants.pins.Sensor2LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor3LpmSampleInterval, 0}, {avlConstants.pins.Sensor4LpmSampleInterval, 0},
                     {avlConstants.pins.Sensor1ChangeThld, 1}, {avlConstants.pins.Sensor2ChangeThld, 1},
                     {avlConstants.pins.Sensor3ChangeThld, 1}, {avlConstants.pins.Sensor4ChangeThld, 1},
                     {avlConstants.pins.Sensor1MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor2MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor3MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor4MinThld, sensorTester:getNormalized(sensorTester.min), "signedint"},
                     {avlConstants.pins.Sensor1MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor2MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor3MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor4MaxThld, sensorTester:getNormalized(sensorTester.max), "signedint"},
                     {avlConstants.pins.Sensor1MaxReportInterval, 0}, {avlConstants.pins.Sensor2MaxReportInterval, 0},
                     {avlConstants.pins.Sensor3MaxReportInterval, 0}, {avlConstants.pins.Sensor4MaxReportInterval, 0},
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })

  -- All sensors to initial state
  gateway.setHighWaterMark()
  sensorTester:setValueToInitial()
  local receivedMessages = avlHelperFunctions.matchReturnMessages({avlConstants.mins.Sensor1Change, avlConstants.mins.Sensor2Change,
                                                                   avlConstants.mins.Sensor3Change, avlConstants.mins.Sensor4Change}, GATEWAY_TIMEOUT)

  -- disable sensors
  lsf.setProperties(avlConstants.avlAgentSIN,
                    {
                     {avlConstants.pins.Sensor1Source, framework.base64Encode(""), "data"},
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
                     {avlConstants.pins.SensorReportingInterval, 0}
                    })
end

-------------------------
-- Test Cases
-------------------------


-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
function test_ConfigurePeriodicalReports_ReceiveMessageContainingSensorValues()
  RandomSensorRun(generic_test_PeriodicallySendingMessageContainingSensorValues)
end

-- Test for: Periodically sending a message
-- Testing if report timeout is set properly
-- Testing if report has proper value
-- Test logic
function generic_test_PeriodicallySendingMessageContainingSensorValues(sensorNo)
  print("Testing test_PeriodicallySendingMessageContainingSensorValues using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)
  local DEFAULT_TIMEOUT = 5*60

  sensor.pinValues.Source = {SIN = sensorTester:getSin(), PIN = sensorTester:getPin()}
  sensor.pinValues.SensorReportingInterval = 1 -- 60 secs
  --set monitored value in position service
  sensorTester:setValueToInitial()
  sensor:applyPinValues()
  gateway.setHighWaterMark()

  -- waiting for periodical report 1
    local expectedMins = {sensor.mins.SensorInterval}
    local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, DEFAULT_TIMEOUT+5)

    -- set monitored value in position service to expected value
    sensorTester:stepUp()

    local startTime = os.time()

    -- waiting for periodical report 2
    receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,sensor.pinValues.SensorReportingInterval*60 + 5)

    -- checking if timeout between two reports is ok
    local timeDiff = os.time() - startTime
    assert_equal(timeDiff , sensor.pinValues.SensorReportingInterval*60, 5, "Sensor Reporting Interval test failed - wrong timeout between messages")

    -- checking if raported value is monitored properly
    assert_equal(sensorTester:getNormalizedValue() , tonumber(receivedMessages[sensor.mins.SensorInterval][sensor.name]), 0, "Sensor Reporting Interval test failed - wrong expected value")

end


--Sending a message when a sensor value has changed by more than set amount
function test_Sensors_ChangeValueOverChangeThld_ReceiveChangeMsg()
  local ReportingInterval = 1
  RandomSensorRun(generic_test_changeSensorValueByAmount, ReportingInterval)
end

--Sending a message when a sensor value has changed by more than set amount
function generic_test_changeSensorValueByAmount(sensorNo, ReportingInterval)
  print("Testing test_changeSensorValueByAmount using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)

  sensor.pinValues.ChangeThld = 1000
  sensor.pinValues.SensorReportingInterval = ReportingInterval
  sensor.pinValues.NormalSampleInterval = ReportingInterval
  sensor.pinValues.Source = {SIN = sensorTester:getSin(), PIN = sensorTester:getPin()}

  -- set first value
  sensorTester:setValueToInitial()
  sensor:applyPinValues()
  gateway.setHighWaterMark()

  -- set value
  sensorTester:setValue(sensorTester.currentValue + 2 * sensor.pinValues.ChangeThld / sensorTester.conversion)

  -- waiting for change message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.Change}, GATEWAY_TIMEOUT)

  assert_not_nil(receivedMessages[sensor.mins.Change], "Message with report not delivered")
  -- checking value (whitch triggered threshold)
  assert_equal(sensorTester:getNormalizedValue() , tonumber(receivedMessages[sensor.mins.Change][sensor.name]), 1, "Problem with triggering change with threshold.")
end

--Sending a message when a sensor value has changed by less than set amount
function generic_test_changeSensorValueByLessThanAmount(sensorNo, ReportingInterval)
  print("Testing test_changeSensorValueByLessThanAmount using sensor " .. sensorNo)

  local sensor = Sensor(sensorNo)
  sensor.pinValues.ChangeThld = 1000
  sensor.pinValues.SensorReportingInterval = ReportingInterval
  sensor.pinValues.NormalSampleInterval = 1
  sensor.pinValues.Source = {SIN = sensorTester:getSin(), PIN = sensorTester:getPin()}

  -- set first value
  sensorTester:setValueToInitial()
  -- setting AVL properties
  sensor:applyPinValues()
  gateway.setHighWaterMark()
  -- set second value
  sensorTester:setValue(sensorTester.currentValue + 0.8 * sensor.pinValues.ChangeThld / sensorTester.conversion)

  -- message should not be received
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.Change}, GATEWAY_TIMEOUT)
  assert_nil(receivedMessages[sensor.mins.Change], "Message should not be delivered (amount less than threshold)")

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

-- Sending a message when a sensor 1 value has changed by more than set amount (when report interval zero)
function test_ChangeThresholdWhenReportIntervalZeroForSensor()
  local ReportingInterval = 0
  RandomSensorRun(generic_test_changeSensorValueByAmount, ReportingInterval)
end

-- Sending a message when a sensor value has changed by less than set amount
function test_changeSensorValueByLessThanChangeThld_NoMessageExpected()
  ReportingInterval = 1
  RandomSensorRun(generic_test_changeSensorValueByLessThanAmount, ReportingInterval)
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
  gateway.setHighWaterMark()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(sensorTester.step)

  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  gateway.setHighWaterMark()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")
  local FirstSampleTime = tonumber(msg.EventTime)

  sensorTester:setValueToMin(sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinEnd}, GATEWAY_TIMEOUT)
  msg = receivedMessages[sensor.mins.MinEnd]
  assert_not_nil(msg, 'Sensor did not send Min End message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  gateway.setHighWaterMark()

  framework.delay(sensor.pinValues.NormalSampleInterval)

  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinEnd, sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  -- check if min end message was sent
  msg = receivedMessages[sensor.mins.MinEnd]
  assert_not_nil(msg, 'Sensor did not send Min End message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMin), NEAR_ZERO, "SensorMin has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name .. " has incorrect value")

  msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  gateway.setHighWaterMark()

  framework.delay(sensor.pinValues.NormalSampleInterval)

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

  sensorTester:setValueToMin(-sensorTester.step)
  -- wait for min end message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MinStart,
                                                             sensor.mins.MaxEnd}, GATEWAY_TIMEOUT)
  -- check if min end message was sent
  msg = receivedMessages[sensor.mins.MaxEnd]
  assert_not_nil(msg, 'Sensor did not send Max End message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_equal(sensorTester:getNormalizedPreviousValue(), tonumber(msg.SensorMax), NEAR_ZERO, "SensorMax has incorrect value")
  assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, sensor.name.. " has incorrect value")

  msg = receivedMessages[sensor.mins.MinStart]
  assert_not_nil(msg, 'Sensor did not send Min Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  gateway.setHighWaterMark()

  -- to make sure the test starts from initial point
  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensor.pinValues.NormalSampleInterval = 7
  sensor:applyPinValues()
  framework.delay(sensor.pinValues.NormalSampleInterval)

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  assert_nil(receivedMessages[sensor.mins.MaxEnd], 'Sensor send Max End message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_nil(receivedMessages[sensor.mins.MaxStart], 'Sensor send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )

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
  gateway.setHighWaterMark()

  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_not_nil(msg, 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
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
  assert_not_nil(receivedMessages[sensor.mins.MaxStart], 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  assert_not_nil(receivedMessages[sensor.mins.MaxStart], 'Sensor did not send Max Start message. Sensor property value is: ' .. sensorTester:getNormalizedValue() .. ' thresholds are: MIN ' .. sensor.pinValues.MinThld .. ' MAX ' .. sensor.pinValues.MaxThld )
  local SecondSampleTimestamp = msg.EventTime

  assert_equal(SecondSampleTimestamp - FirstSampleTimestamp, sensor.pinValues.LpmSampleInterval, 1, 'Message Timestamps do not match LPM sampling interval')


end

function test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval()
  RandomSensorRun(generic_test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval)
end

function generic_test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval(sensorNo)
  print("Testing test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval using sensor " .. sensorNo)
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
  gateway.setHighWaterMark()

  sensorTester:setValueToMax(sensorTester.step)
  local receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart,}, GATEWAY_TIMEOUT)

  sensor.pinValues.MaxReportInterval = 10
  sensor:applyPinValues()

  sensorTester:setValueToMax(-sensorTester.step)
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxEnd,}, GATEWAY_TIMEOUT)

  local msg = receivedMessages[sensor.mins.MaxEnd]
  assert_not_nil(msg, 'Initial MaxEnd message not received')
  local FirstSampleTime = msg.EventTime

  sensorTester:setValueToMax(sensorTester.step)
  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(-sensorTester.step)
  framework.delay(sensor.pinValues.NormalSampleInterval)
  sensorTester:setValueToMax(sensorTester.step)
  framework.delay(sensor.pinValues.NormalSampleInterval)

  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart, sensor.mins.MaxEnd}, GATEWAY_TIMEOUT/2)
  local msg2 = receivedMessages[sensor.mins.MaxStart]
  local SecondSampleTime = msg2.EventTime
  assert_not_nil(msg2, 'MaxStart message not received')
  assert_nil(receivedMessages[sensor.mins.MaxEnd], 'MaxEnd message unexpectedly received')
  assert_equal(SecondSampleTime - FirstSampleTime, sensor.pinValues.MaxReportInterval, 1, 'Report intervals are incorrect')

end

function test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval()
  RandomSensorRun(generic_test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval)
end

function test_Sensors_AllSensorsAtTime_ReceiveMessagesFromAllSensors()
  sensors = {Sensor(1), Sensor(2), Sensor(3), Sensor(4)}

  for i=1, #sensors do
    local sensor = sensors[i]
    sensor.pinValues.Source.SIN = sensorTester:getSin()
    sensor.pinValues.Source.PIN = sensorTester:getPin()
    sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
    sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
    sensor.pinValues.ChangeThld = 0
    sensor.pinValues.MaxReportInterval = 0
    sensor.pinValues.NormalSampleInterval = 1
    sensor.pinValues.LpmSampleInterval = 0
    sensor:applyPinValues()
  end

  sensorTester:setValueToMax(sensorTester.step)

  local messagesToGet = {}
  for i=1,#sensors do
    messagesToGet[#messagesToGet +1] = sensors[i].mins.MaxStart
  end

  local receivedMessages = avlHelperFunctions.matchReturnMessages(messagesToGet, GATEWAY_TIMEOUT)

  for i=1, #sensors do
    local sensor = sensors[i]
    msg = receivedMessages[sensor.mins.MaxStart]
    assert_not_nil(msg, 'MaxStart message not received from sensor ' .. i)
    assert_equal(sensorTester:getNormalizedValue(), msg[sensor.name], 1, 'MaxStart message Sensor value not correct')
  end

end
