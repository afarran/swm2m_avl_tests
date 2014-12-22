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

    -- setting the IO properties - disabling all 4 I/O ports
    lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[4], 0},      -- port disabled
                                          }
    )
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