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
    -- setting the IO properties - disabling all 3 I/O ports
    lsf.setProperties(lsfConstants.sins.io,{
                                              {lsfConstants.pins.portConfig[1], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[2], 0},      -- port disabled
                                              {lsfConstants.pins.portConfig[3], 0},      -- port disabled
                                          }
    )
  end
  
  function Profile800:hasDualPowerSource() 
    return true
  end
  
