--- AVL Agent test consants definitions

-- AVL Agent SIN number
avlAgentCons = {
                      avlAgentSIN = 126,
                      avlStateNames = {"InLPM", "onMainPower", "Speeding", "Moving", "Towing", "GPSJammed", "CellJammed", "Tamper", "AirCommunicationBlocked",
                                      "Reserved", "SeatbeltViolation", "IgnitionON", "EngineIdling", "SM1Active", "SM2Active", "SM3Active", "SM4Active", "Geodwelling" },  -- table of states of agent
                      digitalStatesNames = {"IgnitionON", "SeatbeltOFF", "SM1Active", "SM2Active", "SM3Active", "SM4Active" },
                      EioSIN = 25,



              }



return avlAgentCons
