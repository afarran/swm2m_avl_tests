Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 800
----------------------------------------------------------------------
Profile800 = {}
  Profile800.__index = Profile800
  setmetatable(Profile800, {
    __index = Profile, -- this is what makes the inheritance work
    __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
    end,
  })

  function Profile800:getRandomPortNumber()
    return math.random(1,3)
  end

  function Profile800:hasFourIOs()
    return false
  end

  function Profile800:hasThreeIOs()
    return true
  end

  function Profile800:hasLine13()
    return true
  end

  function Profile800:setupIO(lsf, device, lsfConstants)
    for counter = 1, 3, 1 do
      device.setIO(counter, 0) -- setting all 3 ports to low state
    end

    if lsfConstants ~= nil then
      -- setting the IO properties - disabling all 3 I/O ports
      lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                              {lsfConstants.pins.portEdgeSampleCount[1], 1},  -- edge detected after 1 ms
                                              {lsfConstants.pins.portEdgeSampleCount[2], 1},  -- edge detected after 1 ms
                                              {lsfConstants.pins.portEdgeSampleCount[3], 1},  -- edge detected after 1 ms
                                          }
      )
    end
  end

  function Profile800:hasDualPowerSource()
    return true
  end

  function Profile800:setupPowerService(lsf, lsfConstants)
    lsf.setProperties(lsfConstants.sins.power,{
                                                {lsfConstants.pins.extPowerPresentStateDetect, 3}       -- setting detection for Both rising and falling edge
                                              }
    )
  end

  function Profile800:isSeries600()
    return false
  end

  function Profile800:isSeries700()
    return false
  end

  function Profile800:isSeries800()
    return true
  end

  function Profile800:setupBatteryVoltage(device,ext_voltage,batt_voltage)
    device.setPower(3, batt_voltage) -- setting battery voltage
    device.setPower(9, ext_voltage)  -- setting external power voltage
    device.setIO(31, ext_voltage)    -- setting external power voltage (in eio service)

    -- setting external power source
    device.setPower(8,0)                    -- external power not present (terminal unplugged from external power source)
    framework.delay(2)
    self.isBVSetup = true
  end

  function Profile800:setupIOInLPM(device)
    for counter = 1, 3, 1 do
      device.setIO(counter, 0)
    end
  end
