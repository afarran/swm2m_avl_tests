Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 680
----------------------------------------------------------------------
Profile680 = {}
  Profile680.__index = Profile680
  setmetatable(Profile680, {
    __index = Profile, -- this is what makes the inheritance work
    __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
    end,
  })

  function Profile680:getRandomPortNumber()
    return math.random(1,4)
  end

  function Profile680:hasFourIOs()
    return true
  end

  function Profile680:hasThreeIOs()
    return false
  end

  function Profile680:hasLine13()
    return false
  end

  function Profile680:setupIO(lsf, device, lsfConstants)
    for counter = 1, 4, 1 do
       device.setIO(counter, 0) -- setting all 4 ports to low state
    end

    if lsfConstants ~= nil then
      -- setting the IO properties - disabling all 4 I/O ports
      lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[4], 0},      -- port disabled
                                              {lsfConstants.pins.portEdgeSampleCount[1], 1},  -- edge detected after 1 ms
                                              {lsfConstants.pins.portEdgeSampleCount[2], 1},  -- edge detected after 1 ms
                                              {lsfConstants.pins.portEdgeSampleCount[3], 1},  -- edge detected after 1 ms
                                              {lsfConstants.pins.portEdgeSampleCount[4], 1},  -- edge detected after 1 ms
                                          }
      )
    end
  end

  function Profile680:hasDualPowerSource()
    return false
  end

  function Profile680:isSeries600()
    return true
  end

  function Profile680:isSeries700()
    return false
  end

  function Profile680:isSeries800()
    return false
  end

  function Profile680:setupIOInLPM(device)
    for counter = 1, 4, 1 do
      device.setIO(counter, 0)
    end
  end

  function Profile680:setupBatteryVoltage(device,ext_voltage,batt_voltage)
    device.setPower(9, ext_voltage)  -- setting external power voltage
    device.setIO(31, ext_voltage)    -- setting external power voltage (in eio service)
    self.isBVSetup = false
  end
