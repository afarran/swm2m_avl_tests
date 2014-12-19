require("Profile/Profile680")
require("Profile/Profile780")
require("Profile/Profile800")

----------------------------------------------------------------------
-- Profile factory method
----------------------------------------------------------------------
local profileFactory = {}

function profileFactory.create(hardwareVariant)
  if hardwareVariant == 1 then
    print("Creating profile for 680")
    return Profile680()
  elseif hardwareVariant == 2 then
    print("Creating profile for 780")
    return Profile780()
  elseif hardwareVariant == 3 then
    print("Creating profile for 800")
    return Profile800()
  else
    print("This hardware variant is not implemented yet!!!")
    return nil
  end
end

return function() return profileFactory end
