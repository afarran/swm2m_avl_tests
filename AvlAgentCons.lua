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
                      funcDigInp = { ["Disabled"] = 0, ["GeneralPurpose"] = 1, ["IgnitionOn"] = 2, ["Seatbelt"] = 3, ["IgnitionAndSM0"] = 4, ["SM1"] = 5, ["SM2"] = 6, ["SM2"] = 7, ["SM4"] = 8},


              }



return avlAgentCons
