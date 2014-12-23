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
    if info.msg then file:write("MESSAGE: " .. info.msg.."\n") end
    if info.line then file:write("LINE: " .. info.line.."\n") end
    if info.reason then file:write("REASON: " .. info.reason.."\n") end
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
self.avlMaper[2] = "StationaryDebounceTime"
self.avlMaper[3] = "MovingDebounceTime"
self.avlMaper[4] = "CurrentZoneId"
self.avlMaper[5] = "DefaultSpeedLimit"
self.avlMaper[6] = "SpeedingTimeOver"
self.avlMaper[7] = "SpeedingTimeUnder"
self.avlMaper[8] = "LoggingPositionsInterval"
self.avlMaper[9] = "StationaryIntervalCell"
self.avlMaper[10] = "MovingIntervalCell"
self.avlMaper[11] = "StationaryIntervalSat"
self.avlMaper[12] = "MovingIntervalSat"
self.avlMaper[13] = "SmReportingHour"
self.avlMaper[14] = "OdometerDistanceIncrement"
self.avlMaper[15] = "Odometer"
self.avlMaper[16] = "TurnThreshold"
self.avlMaper[17] = "TurnDebounceTime"
self.avlMaper[18] = "DistanceCellThld"
self.avlMaper[19] = "DistanceSatThld"
self.avlMaper[20] = "MaxDrivingTime"
self.avlMaper[21] = "MinRestTime"
self.avlMaper[22] = "AirBlockageTime"
self.avlMaper[23] = "MaxIdlingTime"
self.avlMaper[24] = "DigPorts"
self.avlMaper[25] = "DefaultGeoDwellTime"
self.avlMaper[26] = "PositionMsgInterval"
self.avlMaper[27] = "OptionalFieldsInMsgs"
self.avlMaper[28] = "GpsJamDebounceTime"
self.avlMaper[29] = "CellJamDebounceTime"
self.avlMaper[30] = "Version"
self.avlMaper[31] = "LpmTrigger"
self.avlMaper[32] = "LpmEntryDelay"
self.avlMaper[33] = "LpmGeoInterval"
self.avlMaper[34] = "LpmModemWakeupInterval"
self.avlMaper[35] = "TowMotionThld"
self.avlMaper[36] = "TowStartCheckInterval"
self.avlMaper[37] = "TowStartDebCount"
self.avlMaper[38] = "TowStopCheckInterval"
self.avlMaper[39] = "TowStopDebCount"
self.avlMaper[40] = "TowInterval"
self.avlMaper[41] = "AvlStates"
self.avlMaper[42] = "SendMsgBitmap"
self.avlMaper[43] = "LogMsgBitmap"
self.avlMaper[44] = "PersistentMsgBitmap"
self.avlMaper[45] = "CellOnlyMsgBitmap"
self.avlMaper[46] = "DigStatesDefBitmap"
self.avlMaper[47] = "FuncDigInp1"
self.avlMaper[48] = "FuncDigInp2"
self.avlMaper[49] = "FuncDigInp3"
self.avlMaper[50] = "FuncDigInp4"
self.avlMaper[51] = "FuncDigInp5"
self.avlMaper[52] = "FuncDigInp6"
self.avlMaper[53] = "FuncDigInp7"
self.avlMaper[54] = "FuncDigInp8"
self.avlMaper[55] = "FuncDigInp9"
self.avlMaper[56] = "FuncDigInp10"
self.avlMaper[57] = "FuncDigInp11"
self.avlMaper[58] = "FuncDigInp12"
self.avlMaper[59] = "FuncDigInp13"
self.avlMaper[60] = "SensorReportingInterval"
self.avlMaper[61] = "Sensor1Source"
self.avlMaper[62] = "Sensor1NormalSampleInterval"
self.avlMaper[63] = "Sensor1LpmSampleInterval"
self.avlMaper[64] = "Sensor1MaxReportInterval"
self.avlMaper[65] = "Sensor1ChangeThld"
self.avlMaper[66] = "Sensor1MinThld"
self.avlMaper[67] = "Sensor1MaxThld"
self.avlMaper[68] = "Sensor2Source"
self.avlMaper[69] = "Sensor2NormalSampleInterval"
self.avlMaper[70] = "Sensor2LpmSampleInterval"
self.avlMaper[71] = "Sensor2MaxReportInterval"
self.avlMaper[72] = "Sensor2ChangeThld"
self.avlMaper[73] = "Sensor2MinThld"
self.avlMaper[74] = "Sensor2MaxThld"
self.avlMaper[75] = "Sensor3Source"
self.avlMaper[76] = "Sensor3NormalSampleInterval"
self.avlMaper[77] = "Sensor3LpmSampleInterval"
self.avlMaper[78] = "Sensor3MaxReportInterval"
self.avlMaper[79] = "Sensor3ChangeThld"
self.avlMaper[80] = "Sensor3MinThld"
self.avlMaper[81] = "Sensor3MaxThld"
self.avlMaper[82] = "Sensor4Source"
self.avlMaper[83] = "Sensor4NormalSampleInterval"
self.avlMaper[84] = "Sensor4LpmSampleInterval"
self.avlMaper[85] = "Sensor4MaxReportInterval"
self.avlMaper[86] = "Sensor4ChangeThld"
self.avlMaper[87] = "Sensor4MinThld"
self.avlMaper[88] = "Sensor4MaxThld"
self.avlMaper[91] = "SM0Time"
self.avlMaper[92] = "SM0Distance"
self.avlMaper[93] = "SM1Time"
self.avlMaper[94] = "SM1Distance"
self.avlMaper[95] = "SM2Time"
self.avlMaper[96] = "SM2Distance"
self.avlMaper[97] = "SM3Time"
self.avlMaper[98] = "SM3Distance"
self.avlMaper[99] = "SM4Time"
self.avlMaper[100] = "SM4Distance"
self.avlMaper[101] = "HarshBrakingThld"
self.avlMaper[102] = "MinHarshBrakingTime"
self.avlMaper[103] = "ReArmHarshBrakingTime"
self.avlMaper[104] = "HarshBrakingCount"
self.avlMaper[105] = "HarshAccelThld"
self.avlMaper[106] = "MinHarshAccelTime"
self.avlMaper[107] = "ReArmHarshAccelTime"
self.avlMaper[108] = "HarshAccelCount"
self.avlMaper[109] = "AccidentThld"
self.avlMaper[110] = "MinAccidentTime"
self.avlMaper[112] = "AccidentCount"
self.avlMaper[113] = "AccidentAccelDataCapture"
self.avlMaper[114] = "AccidentGpsDataCapture"
self.avlMaper[115] = "SeatbeltDebounceTime"
self.avlMaper[116] = "DigOutActiveBitmap"
self.avlMaper[117] = "FuncDigOut1"
self.avlMaper[118] = "FuncDigOut2"
self.avlMaper[119] = "FuncDigOut3"
self.avlMaper[120] = "FuncDigOut4"
self.avlMaper[121] = "FuncDigOut5"
self.avlMaper[130] = "DriverIdPort"
self.avlMaper[131] = "DriverIdPollingInterval"
self.avlMaper[132] = "DriverIdAutoLogoutDelay"
self.avlMaper[133] = "DriverId"
self.avlMaper[134] = "ExternalSpeedSource"
self.avlMaper[135] = "ExternalOdometerSource"
self.avlMaper[201] = "DeleteData"
self.avlMaper[202] = "ParamSaveInterval"
self.avlMaper[203] = "ParamSaveIntervalLpm"
self.avlMaper[204] = "ParamSaveThrtlInterval"
self.avlMaper[205] = "MaxBatteryTime"
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