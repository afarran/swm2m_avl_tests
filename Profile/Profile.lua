-- Profile interface definition
local Profile = {}
  Profile.__index = Profile
  setmetatable(Profile, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

  function Profile:_init()
      math.randomseed(os.time())
      self.isBVSetup = false
  end
  
  function Profile:getRandomPortNumber() end
  function Profile:hasFourIOs() end
  function Profile:hasThreeIOs() end
  function Profile:hasLine13() end
  function Profile:setupIO(lsf, device, lsfConstants) end
  function Profile:hasDualPowerSource() end
  function Profile:setupPowerService(lsf, lsfConstants) end
  function Profile:isSeries600() end
  function Profile:isSeries700() end
  function Profile:isSeries800() end
  function Profile:setupBatteryVoltage(device,ext_voltage,batt_voltage) end
  function Profile:setupIOInLPM(device) end
  
  function Profile:isBatteryVoltageSetup() return self.isBVSetup end
  
return Profile