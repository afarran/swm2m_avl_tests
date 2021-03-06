-- PropertiesMessagesGenerator generates message
-- with all properties randomly picked
-- or with default values.
local PropertiesMessagesGenerator = {
  message = {},
  messageFields = {}
}

function PropertiesMessagesGenerator:getMessageWithRandomValues()
  self:initPropertiesDescriptions()
  self:prepareMessage(true)
  return self.messageFields
end

function PropertiesMessagesGenerator:getMessageWithDefaultValues()
  self:initPropertiesDescriptions()
  self:prepareMessage(false)
  return self.messageFields
end

-- TODO: private method
function PropertiesMessagesGenerator:prepareMessage(random)
  math.randomseed(os.time())
  local RANDOM_ITEMS = 30
  for i = 1, #self.message.Fields do
    self.messageFields[i]={}
    self.messageFields[i].Name = self.message.Fields[i].Name
    if random == false or self.message.Fields[i].Range == nil   then
      self.messageFields[i].Value = self.message.Fields[i].Value
    else
      if random and #self.message.Fields[i].Range == 1 then
        self.messageFields[i].Value = self.message.Fields[i].Range[1]
      elseif i < RANDOM_ITEMS and random and type(self.message.Fields[i].Range[1]) == "string" then
        local index = math.random(1,#self.message.Fields[i].Range)
        self.messageFields[i].Value = self.message.Fields[i].Range[index]
      elseif i < RANDOM_ITEMS and random and type(self.message.Fields[i].Range[1]) == "number" then
        self.messageFields[i].Value = math.random(self.message.Fields[i].Range[1],self.message.Fields[i].Range[2])
      elseif random then
        self.messageFields[i].Value = self.message.Fields[i].Value
      end
    end
  end
end

function PropertiesMessagesGenerator:initPropertiesDescriptions()
  self.message.Fields = {}
  self.message.Fields[1] = {}
	self.message.Fields[1].Name = "SaveChanges"
	self.message.Fields[1].Value = 0
  self.message.Fields[1].Range = {0,0}  -- Always zero!!
	self.message.Fields[2] = {}
	self.message.Fields[2].Name = "StationarySpeedThld"
	self.message.Fields[2].Value = 8
  self.message.Fields[2].Range = {5,10}
	self.message.Fields[3] = {}
	self.message.Fields[3].Name = "StationaryDebounceTime"
	self.message.Fields[3].Value = 60
  self.message.Fields[3].Range = {60,90}
	self.message.Fields[4] = {}
	self.message.Fields[4].Name = "MovingDebounceTime"
	self.message.Fields[4].Value = 10
  self.message.Fields[4].Range = {10,60}
	self.message.Fields[5] = {}
	self.message.Fields[5].Name = "DefaultSpeedLimit"
	self.message.Fields[5].Value = 120
  self.message.Fields[5].Range = {90,120}
	self.message.Fields[6] = {}
	self.message.Fields[6].Name = "SpeedingTimeOver"
	self.message.Fields[6].Value = 180
  self.message.Fields[6].Range = {100,180}
	self.message.Fields[7] = {}
	self.message.Fields[7].Name = "SpeedingTimeUnder"
	self.message.Fields[7].Value = 30
  self.message.Fields[7].Range = {15,30}
	self.message.Fields[8] = {}
	self.message.Fields[8].Name = "LoggingPositionsInterval"
	self.message.Fields[8].Value = 10
  self.message.Fields[8].Range = {10,30}
	self.message.Fields[9] = {}
	self.message.Fields[9].Name = "StationaryIntervalCell"
	self.message.Fields[9].Value = 1800
  self.message.Fields[9].Range = {1000,1800}
	self.message.Fields[10] = {}
	self.message.Fields[10].Name = "MovingIntervalCell"
	self.message.Fields[10].Value = 60
  self.message.Fields[10].Range = {30,60}
	self.message.Fields[11] = {}
	self.message.Fields[11].Name = "StationaryIntervalSat"
	self.message.Fields[11].Value = 0
  self.message.Fields[11].Range = {0,1}
	self.message.Fields[12] = {}
	self.message.Fields[12].Name = "MovingIntervalSat"
	self.message.Fields[12].Value = 900
  self.message.Fields[12].Range = {600,900}
	self.message.Fields[13] = {}
	self.message.Fields[13].Name = "SmReportingHour"
	self.message.Fields[13].Value = 0
  self.message.Fields[13].Range = {0,1}
	self.message.Fields[14] = {}
	self.message.Fields[14].Name = "OdometerDistanceIncrement"
	self.message.Fields[14].Value = 100
  self.message.Fields[14].Range = {100,120}
	self.message.Fields[15] = {}
	self.message.Fields[15].Name = "TurnThreshold"
	self.message.Fields[15].Value = 0
  self.message.Fields[15].Range = {0,1}
	self.message.Fields[16] = {}
	self.message.Fields[16].Name = "TurnDebounceTime"
	self.message.Fields[16].Value = 7
  self.message.Fields[16].Range = {4,10}
	self.message.Fields[17] = {}
	self.message.Fields[17].Name = "DistanceCellThld"
	self.message.Fields[17].Value = 0
  self.message.Fields[17].Range = {0,1}
	self.message.Fields[18] = {}
	self.message.Fields[18].Name = "DistanceSatThld"
	self.message.Fields[18].Value = 0
  self.message.Fields[18].Range = {0,1}
	self.message.Fields[19] = {}
	self.message.Fields[19].Name = "MaxDrivingTime"
	self.message.Fields[19].Value = 0
  self.message.Fields[19].Range = {0,1}
	self.message.Fields[20] = {}
	self.message.Fields[20].Name = "MinRestTime"
	self.message.Fields[20].Value = 480
  self.message.Fields[20].Range = {200,500}
	self.message.Fields[21] = {}
	self.message.Fields[21].Name = "AirBlockageTime"
	self.message.Fields[21].Value = 20
  self.message.Fields[21].Range = {20,60}
	self.message.Fields[22] = {}
	self.message.Fields[22].Name = "MaxIdlingTime"
	self.message.Fields[22].Value = 600
  self.message.Fields[22].Range = {100,800}
	self.message.Fields[23] = {}
	self.message.Fields[23].Name = "DefaultGeoDwellTime"
	self.message.Fields[23].Value = 0
  self.message.Fields[23].Range = {0,1}
	self.message.Fields[24] = {}
	self.message.Fields[24].Name = "PositionMsgInterval"
	self.message.Fields[24].Value = 0
  self.message.Fields[24].Range = {0,1}
	self.message.Fields[25] = {}
	self.message.Fields[25].Name = "OptionalFieldsInMsgs"
	self.message.Fields[25].Value = 0
  self.message.Fields[25].Range = {0,1}
	self.message.Fields[26] = {}
	self.message.Fields[26].Name = "GpsJamDebounceTime"
	self.message.Fields[26].Value = 10
  self.message.Fields[26].Range = {3,10}
	self.message.Fields[27] = {}
	self.message.Fields[27].Name = "CellJamDebounceTime"
	self.message.Fields[27].Value = 10
  self.message.Fields[27].Range = {2,15}
	self.message.Fields[28] = {}
	self.message.Fields[28].Name = "LpmTrigger"
	self.message.Fields[28].Value = 1
  self.message.Fields[28].Range = {0,1}
	self.message.Fields[29] = {}
	self.message.Fields[29].Name = "LpmEntryDelay"
	self.message.Fields[29].Value = 0
  self.message.Fields[29].Range = {0,1}
	self.message.Fields[30] = {}
	self.message.Fields[30].Name = "LpmGeoInterval"
	self.message.Fields[30].Value = 604800
  self.message.Fields[30].Range = {604800,604900}
	self.message.Fields[31] = {}
	self.message.Fields[31].Name = "LpmModemWakeupInterval"
	self.message.Fields[31].Value = "60_minutes"
  self.message.Fields[31].Range = {"60_minutes"}
	self.message.Fields[32] = {}
	self.message.Fields[32].Name = "TowMotionThld"
	self.message.Fields[32].Value = 100
  self.message.Fields[32].Range = {100,120}
	self.message.Fields[33] = {}
	self.message.Fields[33].Name = "TowStartCheckInterval"
	self.message.Fields[33].Value = 20
  self.message.Fields[33].Range = {20,30}
	self.message.Fields[34] = {}
	self.message.Fields[34].Name = "TowStartDebCount"
	self.message.Fields[34].Value = 3
  self.message.Fields[34].Range = {2,4}
	self.message.Fields[35] = {}
	self.message.Fields[35].Name = "TowStopCheckInterval"
	self.message.Fields[35].Value = 60
  self.message.Fields[35].Range = {30,90}
	self.message.Fields[36] = {}
	self.message.Fields[36].Name = "TowStopDebCount"
	self.message.Fields[36].Value = 3
  self.message.Fields[36].Range = {2,4}
	self.message.Fields[37] = {}
	self.message.Fields[37].Name = "TowInterval"
	self.message.Fields[37].Value = 900
  self.message.Fields[37].Range = {800,920}
	self.message.Fields[38] = {}
	self.message.Fields[38].Name = "SendMsgBitmap"
	self.message.Fields[38].Value = ""
  self.message.Fields[38].Range = {"",""}
	self.message.Fields[39] = {}
	self.message.Fields[39].Name = "LogMsgBitmap"
	self.message.Fields[39].Value = ""
  self.message.Fields[39].Range = {"",""}
	self.message.Fields[40] = {}
	self.message.Fields[40].Name = "PersistentMsgBitmap"
	self.message.Fields[40].Value = ""
  self.message.Fields[40].Range = {"",""}
	self.message.Fields[41] = {}
	self.message.Fields[41].Name = "CellOnlyMsgBitmap"
	self.message.Fields[41].Value = ""
  self.message.Fields[41].Range = {"",""}
	self.message.Fields[42] = {}
	self.message.Fields[42].Name = "DigStatesDefBitmap"
	self.message.Fields[42].Value = 1
  self.message.Fields[42].Range = {1,20}
	self.message.Fields[43] = {}
	self.message.Fields[43].Name = "FuncDigInp1"
	self.message.Fields[43].Value = "Disabled"
  self.message.Fields[43].Range = {"Disabled","Enabled"}
	self.message.Fields[44] = {}
	self.message.Fields[44].Name = "FuncDigInp2"
	self.message.Fields[44].Value = "Disabled"
  self.message.Fields[44].Range = {"Disabled","Enabled"}
	self.message.Fields[45] = {}
	self.message.Fields[45].Name = "FuncDigInp3"
	self.message.Fields[45].Value = "Disabled"
  self.message.Fields[45].Range = {"Disabled","Enabled"}
	self.message.Fields[46] = {}
	self.message.Fields[46].Name = "FuncDigInp4"
	self.message.Fields[46].Value = "Disabled"
  self.message.Fields[46].Range = {"Disabled","Enabled"}
	self.message.Fields[47] = {}
	self.message.Fields[47].Name = "FuncDigInp5"
	self.message.Fields[47].Value = "Disabled"
  self.message.Fields[47].Range = {"Disabled","Enabled"}
	self.message.Fields[48] = {}
	self.message.Fields[48].Name = "FuncDigInp6"
	self.message.Fields[48].Value = "Disabled"
  self.message.Fields[48].Range = {"Disabled","Enabled"}
	self.message.Fields[49] = {}
	self.message.Fields[49].Name = "FuncDigInp7"
	self.message.Fields[49].Value = "Disabled"
  self.message.Fields[49].Range = {"Disabled","Enabled"}
	self.message.Fields[50] = {}
	self.message.Fields[50].Name = "FuncDigInp8"
	self.message.Fields[50].Value = "Disabled"
  self.message.Fields[50].Range = {"Disabled","Enabled"}
	self.message.Fields[51] = {}
	self.message.Fields[51].Name = "FuncDigInp9"
	self.message.Fields[51].Value = "Disabled"
	self.message.Fields[52] = {}
	self.message.Fields[52].Name = "FuncDigInp10"
	self.message.Fields[52].Value = "Disabled"
	self.message.Fields[53] = {}
	self.message.Fields[53].Name = "FuncDigInp11"
	self.message.Fields[53].Value = "Disabled"
	self.message.Fields[54] = {}
	self.message.Fields[54].Name = "FuncDigInp12"
	self.message.Fields[54].Value = "Disabled"
	self.message.Fields[55] = {}
	self.message.Fields[55].Name = "FuncDigInp13"
	self.message.Fields[55].Value = "GeneralPurpose"
	self.message.Fields[56] = {}
	self.message.Fields[56].Name = "SensorReportingInterval"
	self.message.Fields[56].Value = 0
	self.message.Fields[57] = {}
	self.message.Fields[57].Name = "Sensor1Source"
	self.message.Fields[57].Value = ""
	self.message.Fields[58] = {}
	self.message.Fields[58].Name = "Sensor1NormalSampleInterval"
	self.message.Fields[58].Value = 0
	self.message.Fields[59] = {}
	self.message.Fields[59].Name = "Sensor1LpmSampleInterval"
	self.message.Fields[59].Value = 0
	self.message.Fields[60] = {}
	self.message.Fields[60].Name = "Sensor1MaxReportInterval"
	self.message.Fields[60].Value = 300
	self.message.Fields[61] = {}
	self.message.Fields[61].Name = "Sensor1ChangeThld"
	self.message.Fields[61].Value = 0
	self.message.Fields[62] = {}
	self.message.Fields[62].Name = "Sensor1MinThld"
	self.message.Fields[62].Value = -32768
	self.message.Fields[63] = {}
	self.message.Fields[63].Name = "Sensor1MaxThld"
	self.message.Fields[63].Value = 32767
	self.message.Fields[64] = {}
	self.message.Fields[64].Name = "Sensor2Source"
	self.message.Fields[64].Value = ""
	self.message.Fields[65] = {}
	self.message.Fields[65].Name = "Sensor2NormalSampleInterval"
	self.message.Fields[65].Value = 0
	self.message.Fields[66] = {}
	self.message.Fields[66].Name = "Sensor2LpmSampleInterval"
	self.message.Fields[66].Value = 0
	self.message.Fields[67] = {}
	self.message.Fields[67].Name = "Sensor2MaxReportInterval"
	self.message.Fields[67].Value = 300
	self.message.Fields[68] = {}
	self.message.Fields[68].Name = "Sensor2ChangeThld"
	self.message.Fields[68].Value = 0
	self.message.Fields[69] = {}
	self.message.Fields[69].Name = "Sensor2MinThld"
	self.message.Fields[69].Value = -32768
	self.message.Fields[70] = {}
	self.message.Fields[70].Name = "Sensor2MaxThld"
	self.message.Fields[70].Value = 32767
	self.message.Fields[71] = {}
	self.message.Fields[71].Name = "Sensor3Source"
	self.message.Fields[71].Value = ""
	self.message.Fields[72] = {}
	self.message.Fields[72].Name = "Sensor3NormalSampleInterval"
	self.message.Fields[72].Value = 0
	self.message.Fields[73] = {}
	self.message.Fields[73].Name = "Sensor3LpmSampleInterval"
	self.message.Fields[73].Value = 0
	self.message.Fields[74] = {}
	self.message.Fields[74].Name = "Sensor3MaxReportInterval"
	self.message.Fields[74].Value = 300
	self.message.Fields[75] = {}
	self.message.Fields[75].Name = "Sensor3ChangeThld"
	self.message.Fields[75].Value = 0
	self.message.Fields[76] = {}
	self.message.Fields[76].Name = "Sensor3MinThld"
	self.message.Fields[76].Value = -32768
	self.message.Fields[77] = {}
	self.message.Fields[77].Name = "Sensor3MaxThld"
	self.message.Fields[77].Value = 32767
	self.message.Fields[78] = {}
	self.message.Fields[78].Name = "Sensor4Source"
	self.message.Fields[78].Value = ""
	self.message.Fields[79] = {}
	self.message.Fields[79].Name = "Sensor4NormalSampleInterval"
	self.message.Fields[79].Value = 0
	self.message.Fields[80] = {}
	self.message.Fields[80].Name = "Sensor4LpmSampleInterval"
	self.message.Fields[80].Value = 0
	self.message.Fields[81] = {}
	self.message.Fields[81].Name = "Sensor4MaxReportInterval"
	self.message.Fields[81].Value = 300
	self.message.Fields[82] = {}
	self.message.Fields[82].Name = "Sensor4ChangeThld"
	self.message.Fields[82].Value = 0
	self.message.Fields[83] = {}
	self.message.Fields[83].Name = "Sensor4MinThld"
	self.message.Fields[83].Value = -32768
	self.message.Fields[84] = {}
	self.message.Fields[84].Name = "Sensor4MaxThld"
	self.message.Fields[84].Value = 32767
	self.message.Fields[85] = {}
	self.message.Fields[85].Name = "HarshBrakingThld"
	self.message.Fields[85].Value = 500
	self.message.Fields[86] = {}
	self.message.Fields[86].Name = "MinHarshBrakingTime"
	self.message.Fields[86].Value = 1000
	self.message.Fields[87] = {}
	self.message.Fields[87].Name = "ReArmHarshBrakingTime"
	self.message.Fields[87].Value = 150
	self.message.Fields[88] = {}
	self.message.Fields[88].Name = "HarshAccelThld"
	self.message.Fields[88].Value = 1000
	self.message.Fields[89] = {}
	self.message.Fields[89].Name = "MinHarshAccelTime"
	self.message.Fields[89].Value = 1000
	self.message.Fields[90] = {}
	self.message.Fields[90].Name = "ReArmHarshAccelTime"
	self.message.Fields[90].Value = 150
	self.message.Fields[91] = {}
	self.message.Fields[91].Name = "AccidentThld"
	self.message.Fields[91].Value = 2000
	self.message.Fields[92] = {}
	self.message.Fields[92].Name = "MinAccidentTime"
	self.message.Fields[92].Value = 1000
	self.message.Fields[93] = {}
	self.message.Fields[93].Name = "SeatbeltDebounceTime"
	self.message.Fields[93].Value = 0
	self.message.Fields[94] = {}
	self.message.Fields[94].Name = "DigOutActiveBitmap"
	self.message.Fields[94].Value = 255
	self.message.Fields[95] = {}
	self.message.Fields[95].Name = "FuncDigOut1"
	self.message.Fields[95].Value = "None"
	self.message.Fields[96] = {}
	self.message.Fields[96].Name = "FuncDigOut2"
	self.message.Fields[96].Value = "None"
	self.message.Fields[97] = {}
	self.message.Fields[97].Name = "FuncDigOut3"
	self.message.Fields[97].Value = "None"
	self.message.Fields[98] = {}
	self.message.Fields[98].Name = "FuncDigOut4"
	self.message.Fields[98].Value = "None"
	self.message.Fields[99] = {}
	self.message.Fields[99].Name = "FuncDigOut5"
	self.message.Fields[99].Value = "None"
  self.message.Fields[100] = {}
	self.message.Fields[100].Name = "DriverIdPort"
	self.message.Fields[100].Value = "rs232aux"
	self.message.Fields[101] = {}
	self.message.Fields[101].Name = "DriverIdPollingInterval"
	self.message.Fields[101].Value = 0
  self.message.Fields[101].Range = {0,1}
	self.message.Fields[102] = {}
	self.message.Fields[102].Name = "DriverIdAutoLogoutDelay"
	self.message.Fields[102].Value = 0
  self.message.Fields[102].Range = {0,1}
	self.message.Fields[103] = {}
	self.message.Fields[103].Name = "AccidentAccelDataCapture"
	self.message.Fields[103].Value = 1
  self.message.Fields[103].Range = {0,1}
	self.message.Fields[104] = {}
	self.message.Fields[104].Name = "AccidentGpsDataCapture"
	self.message.Fields[104].Value = 1
  self.message.Fields[104].Range = {0,1}
	self.message.Fields[105] = {}
	self.message.Fields[105].Name = "ExternalSpeedSource"
	self.message.Fields[105].Value = ""
	self.message.Fields[106] = {}
	self.message.Fields[106].Name = "ExternalOdometerSource"
	self.message.Fields[106].Value = ""
  self.message.Fields[107] = {}
	self.message.Fields[107].Name = "FuncDigOut6"
	self.message.Fields[107].Value = "None"
	self.message.Fields[108] = {}
	self.message.Fields[108].Name = "ParamSaveInterval"
	self.message.Fields[108].Value = 60
  self.message.Fields[109] = {}
	self.message.Fields[109].Name = "ParamSaveIntervalLpm"
	self.message.Fields[109].Value = 120
	self.message.Fields[110] = {}
	self.message.Fields[110].Name = "ParamSaveThrtlInterval"
	self.message.Fields[110].Value = 1
	self.message.Fields[111] = {}
	self.message.Fields[111].Name = "MaxBatteryTime"
	self.message.Fields[111].Value = 1


end

return function() return PropertiesMessagesGenerator end
