function avl_debug(info)
  
  -- TODO: NAME Mapper
  local properties_names_maper = {}
  properties_names_maper["1"] = "StationarySpeedThld"
  
  -- avl properties
  avl_props = lsf.getProperties(avlConstants.avlAgentSIN , {})
  avl_dump_props = framework.dump( avl_props )
  
  -- position properties
  local POSITION_SIN = 20
  gps_props = lsf.getProperties(POSITION_SIN , {})
  dump_gps_props = framework.dump( gps_props )
  
  -- eio properties
  local EIO_SIN = 25
  eio_props = lsf.getProperties(EIO_SIN , {})
  dump_eio_props = framework.dump( eio_props )
  
  local file = io.open("avl.log", "a")
  file:write("------------------------------------------------------ \n")
  file:write("MESSAGE: " .. info.msg.."\n")
  file:write("LINE: " .. info.line.."\n")
  file:write("REASON: " .. info.reason.."\n")
  file:write("AVL PROPERTIES: \n")
  file:write(avl_dump_props)
  file:write("GPS PROPERTIES: \n")
  file:write(dump_gps_props)
  file:write("EIO PROPERTIES: \n")
  file:write(dump_eio_props)
  file:write("------------------------------------------------------ \n")
  file:close()
  
end