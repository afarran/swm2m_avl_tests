-- Simple debuger , it outputs
-- 1) Failed TC info
-- 2) Avl Props
-- 3) Position Props
-- 4) EIO Props
local AvlDebuger = {}
  AvlDebuger.__index = AvlDebuger
  setmetatable(AvlDebuger, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

  function AvlDebuger:debug(name,info)
  
    -- avl properties
    avl_props = lsf.getProperties(avlConstants.avlAgentSIN , {})
    avl_dump_props = framework.dump( self:mapProps(self.avlMaper, avl_props) )
  
    -- position properties
    local POSITION_SIN = 20
    gps_props = lsf.getProperties(POSITION_SIN , {})
    dump_gps_props = framework.dump( gps_props )
  
    -- eio properties
    local EIO_SIN = 25
    eio_props = lsf.getProperties(EIO_SIN , {})
    dump_eio_props = framework.dump( eio_props )
  
    local file = io.open("avl.log", "a")
    file:write("[ "..os.date().." ]-------------------------- start of ".. name .." ---------------------------- \n")
    file:write("MESSAGE: " .. info.msg.."\n")
    file:write("LINE: " .. info.line.."\n")
    file:write("REASON: " .. info.reason.."\n")
    file:write("AVL PROPERTIES: \n")
    file:write(avl_dump_props)
    file:write("GPS PROPERTIES: \n")
    file:write(dump_gps_props)
    file:write("EIO PROPERTIES: \n")
    file:write(dump_eio_props)
    file:write("---------------------------- end of "..  name .." -------------------------- \n")
    file:close()
  
  end

  function AvlDebuger:_init()
    self.avlMaper = {}
    self.avlMaper[1] = "StationarySpeedThld"
    --TODO: other mappings..
  end
  
  function AvlDebuger:mapProps(maper,target)
    for idx, val in ipairs(target) do 
      if maper[idx] ~= nil then 
        target[idx] = {maper[idx], val}
      end
    end
    return target
  end
  
return AvlDebuger