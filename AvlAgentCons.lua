--- AVL Agent test consants definitions

-- AVL Agent SIN number
avlAgentCons = {
                      avlAgentSIN = 126,
                      avlStateNames = {"InLPM", "onMainPower", "Speeding", "Moving", "Towing", "GPSJammed", "CellJammed", "Tamper", "AirCommunicationBlocked",
                                      "Reserved", "SeatbeltViolation", "IgnitionON", "EngineIdling", "SM1Active", "SM2Active", "SM3Active", "SM4Active", "Geodwelling" },  -- table of states of agent
                      digitalStatesNames = {"IgnitionON", "SeatbeltOFF", "SM1Active", "SM2Active", "SM3Active", "SM4Active" },
                      EioSIN = 25,
                      geofenceSIN = 21,
                      coldFixDelay = 40,
                      funcDigInp = { ["Disabled"] = 0, ["GeneralPurpose"] = 1, ["IgnitionOn"] = 2, ["SeatbeltOff"] = 3, ["IgnitionAndSM0"] = 4, ["SM1"] = 5, ["SM2"] = 6, ["SM2"] = 7, ["SM4"] = 8},
                      digStatesDefBitmap = { ["IgnitionOn"] = 0  , ["SeatbeltOff"] = 1, ["SM1Active"] = 2, ["SM2Active"] = 3, ["SM3Active"] = 4 ,  ["SM4Active"] = 5},

              }


return avlAgentCons
