SensorTester = {}
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

  -- This function can be overrided to use e.g GPS module as sensor source
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

  function SensorTester:setNormalizedValue(newValue)
    self:setValue(newValue / self.conversion)
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
SensorTesterGps = {}
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
