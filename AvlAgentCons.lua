--- AVL Agent test consants definitions

-- AVL Agent SIN number
avlAgentCons = {
             avlAgentSIN = 126,
             avlStateNames = {"InLPM", "onMainPower", "Speeding", "Moving", "Towing", "GPSJammed", "CellJammed", "Tamper", "AirCommunicationBlocked",
                              "Reserved", "SeatbeltViolation", "IgnitionON", "EngineIdling", "SM1Active", "SM2Active", "SM3Active", "SM4Active", "Geodwelling" },  -- table of states of agent
             digitalStatesNames = {"IgnitionON", "SeatbeltOFF", "SM1Active", "SM2Active", "SM3Active", "SM4Active" },
             EioSIN = 25,
             geofenceSIN = 21,
             positionSIN = 20,
             coldFixDelay = 40,
             funcDigInp = { ["Disabled"] = 0, ["GeneralPurpose"] = 1, ["IgnitionOn"] = 2, ["SeatbeltOff"] = 3, ["IgnitionAndSM0"] = 4,
                            ["SM1"] = 5, ["SM2"] = 6, ["SM3"] = 7, ["SM4"] = 8},

             digStatesDefBitmap = { ["IgnitionOn"] = 0  , ["SeatbeltOff"] = 1, ["SM1Active"] = 2, ["SM2Active"] = 3, ["SM3Active"] = 4 ,  ["SM4Active"] = 5},

             funcDigOut =  { ["LowPower"] = 0, ["MainPower"] = 1, ["Speeding"] = 2, ["Moving"] = 3, ["Towing"] = 4, ["GpsJammed"] = 5, ["CellJammed"] = 6,
                             ["Tamper"] = 7, ["AirBlocked"] = 8, ["LoggedIn"] = 9, ["SeatbeltViol"] = 10, ["IgnitionOn"] = 11, ["Idling"] = 12, ["SM1ON"] = 13,
                             ["SM2ON"] = 14, ["SM3ON"] = 15, ["SM4ON"] = 16, ["GeoDwelling"] = 17, ["AntCut"] = 18 },

             digOutActiveBitmap = { ["FuncDigOut1"] = 0, ["FuncDigOut2"] = 1, ["FuncDigOut3"] = 2, ["FuncDigOut4"] = 3, ["FuncDigOut5"] = 4 },
             lpmModemWakeupIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                        ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10}

              }


return avlAgentCons
