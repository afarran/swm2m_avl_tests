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
