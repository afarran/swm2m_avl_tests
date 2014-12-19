Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 680
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