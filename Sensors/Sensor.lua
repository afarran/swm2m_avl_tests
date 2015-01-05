Sensor = {}
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