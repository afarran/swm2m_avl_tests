Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 780
----------------------------------------------------------------------
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
    --TODO
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
