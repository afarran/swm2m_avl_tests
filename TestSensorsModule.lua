-----------
-- Sensors test module
-- - contains AVL sensors related test cases
-- @module TestSensorsModule

module("TestSensorsModule", package.seeall)

require "Sensors/Sensor"
require "Sensors/SensorTester"

-- initialize sensor tester, (current_value, MIN, MAX, STEP)
local sensorTester = SensorTesterGps(-0.05, -0.07, -0.03, 0.01)
local NEAR_ZERO = 0.0001

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

  -- disable LPM - tests will fail if the device is in LPM
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

  assert_not_nil(receivedMessages, 'Sensor Change messages not received during suite setup!')
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
  if TEARDOWN_LPM then
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
    TEARDOWN_LPM = false
  end
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
function test_Sensors_ForPeriodicalReportsWhenSensorReportingIntervalIsSetProperly_SensorIntervalMessagesAreSentPeriodicallyAndContainCorrectSensorValues()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_PeriodicallySendingMessageContainingSensorValues)
end

-- Sending a message when a sensor value has changed by more than set threshold
function test_Sensors_whenSensorValueChangedByMoreThanThresholdForReportingIntervalAboveZero_SensorChangeMessageIsSent()
  local ReportingInterval = 1
  tcRandomizer:runTestRandomParam(1, 4, generic_test_changeSensorValueByAmount, setup, teardown, ReportingInterval)
end

-- Sending a message when a sensor 1 value has changed by more than set amount (when report interval zero)
function test_Sensors_whenSensorValueChangedByMoreThanThresholdAndReportIntervalZero_SensorChangeMessageIsSent()
  local ReportingInterval = 0
  local NormalSampleInterval = 1
  tcRandomizer:runTestRandomParam(1, 4, generic_test_changeSensorValueByAmount, setup, teardown, ReportingInterval, NormalSampleInterval)
end

-- Sending a message when a sensor value has changed by less than set threshold
function test_Sensors_whenSensorValueChangedByLessThanThreshold_SensorChangeMessageNotSent()
  ReportingInterval = 1
  tcRandomizer:runTestRandomParam(1, 4, generic_test_changeSensorValueByLessThanAmount, setup, teardown, ReportingInterval)
end

function test_Sensors_WhenSensorValueGoesAboveMaxThresholdAndThenGoesBackBelowMaxThreshold_MaxStartAndMaxEndMessageSent()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_SendMessageWhenValueAboveThreshold, setup, teardown)
end

function test_Sensors_WhenSensorValueGoesBelowMinThresholdAndThenGoesBackAboveMinThreshold_MinStartAndMinEndMessageSent()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_SendMessageWhenValueBelowThreshold, setup, teardown)
end

function test_Sensors_WhenSensorValueBelowMinThresholdAndThenAboveMaxThreshold_MinStartMessageMinEndMessageAndMaxStartMessageSent()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold, setup, teardown)
end

function test_Sensors_WhenSensorValueAboveMaxThresholdAndThenBelowMinThreshold_MaxStartMessageMaxEndMessageAndMinStartMessageSent()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_SendMessageWhenValueAboveAndJumpBelowThreshold, setup, teardown)
end

-- test verifies whether SensorXNormalSampleInterval property works properly
-- Messages timestamps are checked when terminal is in Normal mode
function test_Sensors_WhenTerminalNotInLPMAndSamplingIntervalSetToValueAboveZero_MaxStartAndMaxEndMessagesAreSentAccordingToSamplingInterval()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_NormalSamplingInterval_MaxStartMaxEndMsgTimestampsDifferBySamplingInterval, setup, teardown)
end

function test_Sensors_WhenTerminalNotInLPMAndSamplingIntervalSetToZero_MaxStartMessageNotSent()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_NormalSamplingIntervalSetToZero_MaxStartMessageNotSent, setup, teardown)
end

-- test verifies whether SensorXLpmSampleInterval property works properly
-- Messages timestamps are checked when terminal is in LPM mode
function test_Sensors_WhenTerminalInLPM_MaxStartAndMaxEndMessagesAreSentAfterLPMSampleInterval()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval, setup, teardown)
end

-- test verifies if MaxReportInterval sensor property works properly
-- Two messages timestamps are checked
function test_Sensors_WhenMaxReportIntervalSetAboveZero_SensorMaxStartAndSensorMaxEndMessagesSentAccordingMaxRerportInterval()
  tcRandomizer:runTestRandomParam(1, 4, generic_test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval, setup, teardown)
end

-- test verifies whether Messages are sent from all Sensors at the same time
function test_Sensors_ForAll4SenorsActive_SensorMaxStartMessagesSentFromAll4Sensors()
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
    assert_equal(sensorTester:getNormalizedValue(), tonumber(msg[sensor.name]), NEAR_ZERO, 'MaxStart message Sensor value not correct')
  end

end


-- Test logic
function generic_test_PeriodicallySendingMessageContainingSensorValues(sensorNo)
  -- print("Testing test_PeriodicallySendingMessageContainingSensorValues using sensor " .. sensorNo)
  local sensor = Sensor(sensorNo)

  sensor.pinValues.Source = {SIN = sensorTester:getSin(), PIN = sensorTester:getPin()}
  sensor.pinValues.SensorReportingInterval = 1 -- 60 secs
  --set monitored value in position service
  sensorTester:setValueToInitial()
  sensor:applyPinValues()
  gateway.setHighWaterMark()

  -- waiting for periodical report 1
  local expectedMins = {sensor.mins.SensorInterval}
  local receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins, sensor.pinValues.SensorReportingInterval*60 + 10)
  local firstMessage = receivedMessages[sensor.mins.SensorInterval]
  -- set monitored value in position service to expected value
  sensorTester:stepUp()
  
  -- waiting for periodical report no 2
  receivedMessages = avlHelperFunctions.matchReturnMessages(expectedMins,sensor.pinValues.SensorReportingInterval*60 + 10)
  local secondMessage = receivedMessages[sensor.mins.SensorInterval]
  
  assert_equal(secondMessage.EventTime - firstMessage.EventTime , sensor.pinValues.SensorReportingInterval*60, 1, "Sensor Reporting Interval test failed - wrong time difference between two periodic messages")

  -- checking if reported value is monitored properly
  assert_equal(sensorTester:getNormalizedValue() , tonumber(receivedMessages[sensor.mins.SensorInterval][sensor.name]), 0, "Sensor Reporting Interval test failed - wrong expected value of sensor")

end


--Sending a message when a sensor value has changed by more than change threshold
-- generic logic
function generic_test_changeSensorValueByAmount(sensorNo, ReportingInterval, NormalSampleInterval)
  -- print("Testing test_changeSensorValueByAmount using sensor " .. sensorNo)
  ReportingInterval = ReportingInterval or 1
  NormalSampleInterval = NormalSampleInterval or 1
  local sensor = Sensor(sensorNo)

  sensor.pinValues.ChangeThld = 1000
  sensor.pinValues.SensorReportingInterval = ReportingInterval
  sensor.pinValues.NormalSampleInterval = NormalSampleInterval
  sensor.pinValues.Source = {SIN = sensorTester:getSin(), PIN = sensorTester:getPin()}

  -- set first value
  sensorTester:setValueToInitial()
  sensor:applyPinValues()
  gateway.setHighWaterMark()

  -- increase sensor value by 110 % of threshold
  sensorTester:setValue(sensorTester.currentValue + 1.1 * sensor.pinValues.ChangeThld / sensorTester.conversion)

  -- waiting for change message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.Change}, GATEWAY_TIMEOUT)

  assert_not_nil(receivedMessages[sensor.mins.Change], "SensorChange message not received after sensor value change above threshold")
  -- checking value (whitch triggered threshold)
  assert_equal(sensorTester:getNormalizedValue() , tonumber(receivedMessages[sensor.mins.Change][sensor.name]), 1, "Current sensor value in SensorChange message is incorrect")
end

-- generic logic
function generic_test_changeSensorValueByLessThanAmount(sensorNo, ReportingInterval)
  -- print("Testing test_changeSensorValueByLessThanAmount using sensor " .. sensorNo)

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
  assert_nil(receivedMessages[sensor.mins.Change], "Message should not be delivered (change in sensor value is below threshold)")

end


-------------------------

-- Generic logic.
-- Check if Message is sent if sensor value goes above threshold and then goes back below it
function generic_test_Sensors_SendMessageWhenValueAboveThreshold(sensorNo)
  -- print("Testing test_Sensors_SendMessageWhenValueAboveThreshold using sensor " .. sensorNo)
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
  -- print("Testing test_Sensors_SendMessageWhenValueBelowThreshold using sensor " .. sensorNo)
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
  -- print("Testing test_Sensors_SendMessageWhenValueBelowAndJumpAboveThreshold using sensor " .. sensorNo)
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
  -- print("Testing test_Sensors_SendMessageWhenValueAboveAndJumpBelowThreshold using sensor " .. sensorNo)
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

function generic_test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval(sensorNo)
  TEARDOWN_LPM = true
  -- print("Testing test_LPMSamplingInterval_MaxStartMaxEndMsgTimestampsDifferByLPMSamplingInterval using sensor " .. sensorNo)
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

function generic_test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval(sensorNo)
  -- print("Testing test_Sensors_MaxReportInterval_MessageReceivedAfterMaxRerportInterval using sensor " .. sensorNo)
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

-- Check NormalSampleInterval set to 0  - Feature should be disabled
function generic_test_Sensors_NormalSamplingIntervalSetToZero_MaxStartMessageNotSent(sensorNo)
  local sensor = Sensor(sensorNo)
  sensor.pinValues.Source.SIN = sensorTester:getSin()
  sensor.pinValues.Source.PIN = sensorTester:getPin()
  sensor.pinValues.MinThld = sensorTester:getNormalized(sensorTester.min)
  sensor.pinValues.MaxThld = sensorTester:getNormalized(sensorTester.max)
  sensor.pinValues.ChangeThld = 0
  sensor.pinValues.MaxReportInterval = 0
  sensor.pinValues.NormalSampleInterval = 0
  sensor.pinValues.LpmSampleInterval = 0

  sensorTester:setValueToInitial()
  sensor:applyPinValues()
  gateway.setHighWaterMark()

  sensorTester:setValueToMax(sensorTester.step)
  -- wait for max start message
  receivedMessages = avlHelperFunctions.matchReturnMessages({sensor.mins.MaxStart}, GATEWAY_TIMEOUT)
  local msg = receivedMessages[sensor.mins.MaxStart]
  assert_nil(msg, "SensorMaxStart message not expected")

end

-- Check if correnct Messages are sent if sensor value goes above max threshold and then jumps below min threshold
function generic_test_Sensors_NormalSamplingInterval_MaxStartMaxEndMsgTimestampsDifferBySamplingInterval(sensorNo)
  -- print("Testing test_Sensors_SendMessageMaxMinDependingOnNormalSamplingInterval using sensor " .. sensorNo)
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
