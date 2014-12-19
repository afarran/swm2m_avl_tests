Profile =  require("Profile/Profile")

----------------------------------------------------------------------
-- Profile for device 680
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