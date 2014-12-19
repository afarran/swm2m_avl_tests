-- Profile interface definition
local Profile = {}
  Profile.__index = Profile
  setmetatable(Profile, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

  function Profile:_init()
      math.randomseed(os.time())                
  end
  
  function Profile:getRandomPortNumber() end
  function Profile:hasFourIOs() end
  
return Profile