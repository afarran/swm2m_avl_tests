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
  
