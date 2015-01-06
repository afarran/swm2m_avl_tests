Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 780
----------------------------------------------------------------------
-- 3.4.3 Input/Output Interface Specifications
-- The terminal supports the following I/Os:
-- 4 general purpose input ports configurable as either
--    a) Digital high-side input
--    b) Digital low-side input
--    c) Analog input
-- 7 digital input ports, active low
-- 5 digital output ports (maximum 250 mA sink)
-- 1 digital input port, active high for ignition detection)

Profile780 = {}
  Profile780.__index = Profile780
  setmetatable(Profile780, {
    __index = Profile, -- this is what makes the inheritance work
    __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
    end,
  })

  function Profile780:getRandomPortNumber()
    return math.random(1,4)
  end

  function Profile780:hasFourIOs()
    return true
  end

  function Profile780:hasThreeIOs()
    return false
  end

  function Profile780:hasLine13()
    return false
  end

  function Profile780:setupIO(lsf, device, lsfConstants)
    -- 4 general purpose input ports configurable as digital
    for counter = 1, 4, 1 do
      device.setIO(counter, 0)
    end
    -- 7 digital input ports, active low
    for counter = 5, 11, 1 do
      device.setIO(counter, 0)
    end
    -- 1 digital input port, active high for ignition detection
    device.setIO(17, 0)

    if lsfConstants ~= nil then
      -- setting the IO properties - disabling all 4 I/O ports
      lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[4], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[5], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[6], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[7], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[8], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[9], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[10], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[11], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[17], 0},      -- port disabled
                                             }
      )
    end
  end

  function Profile780:hasDualPowerSource()
    return false
  end

  function Profile780:isSeries600()
    return false
  end

  function Profile780:isSeries700()
    return true
  end

  function Profile780:isSeries800()
    return false
  end

  function Profile780:setupBatteryVoltage(device,ext_voltage,batt_voltage)
    device.setPower(3, batt_voltage) -- setting battery voltage
    device.setPower(9, ext_voltage)  -- setting external power voltage
    device.setIO(31, ext_voltage)    -- setting external power voltage (in eio service)

    -- setting external power source
    device.setPower(8,0)                    -- external power not present (terminal unplugged from external power source)
    framework.delay(2)
    self.isBVSetup = true
  end

  function Profile780:setupIOInLPM(device)

  end
