

avlConstants = {
                    -- AVL Agent MINs
                    mins = {
                              positionRequest = 1,    -- to mobile
                              reset = 1,
                              setDigitalOutputs = 2,  -- to mobile
                              powerMain = 2,
                              powerBackup = 3,
                              ignitionON = 4,
                              ignitionOFF = 5,
                              movingStart = 6,
                              getProperties = 6,      -- to mobile
                              movingEnd = 7,
                              setGeoSpeedLimits = 7,  -- to mobile
                              speedingStart = 8,
                              speedingEnd = 9,
                              setGeoDwellTimes = 9,   -- to mobile
                              turn = 14,
                              idlingStart = 21,
                              seatbeltViolationStart = 19,
                              seatbeltViolationEnd = 20,
                              idlingEnd = 41,
                              stationaryIntervalSat = 49,
                              movingIntervalSat = 22,
                              position = 16,
                              zoneEntry = 10,
                              zoneExit = 11,
                              geoDwellStart = 30,
                              geoDwellEnd = 40,
                              longDriving = 29,
                              distanceSat = 23,
                              setServiceMeter = 11,    -- to mobile
                              getServiceMeter = 12,    -- to mobile
                              getDiagnostics = 13,     -- to mobile
                              loggedPosition = 15,
                              serviceMeter = 31,
                              diagnosticsInfo = 32,
                              digitalInp1Hi = 50, digitalInp1Lo = 51,
                              digitalInp2Hi = 52, digitalInp2Lo = 53,
                              digitalInp3Hi = 54, digitalInp3Lo = 55,
                              digitalInp4Hi = 56, digitalInp4Lo = 57,
                              digitalInp5Hi = 58, digitalInp5Lo = 59,
                              digitalInp6Hi = 60, digitalInp6Lo = 61,
                              digitalInp7Hi = 62, digitalInp7Lo = 63,
                              digitalInp8Hi = 64, digitalInp8Lo = 65,
                              digitalInp9Hi = 66, digitalInp9Lo = 67,
                              digitalInp10Hi = 68, digitalInp10Lo = 69,
                              digitalInp11Hi = 70, digitalInp11Lo = 71,
                              digitalInp12Hi = 72, digitalInp12Lo = 73,
                              serviceProperties = 201,
                          },
                    -- AVL Agent PINs
                    pins = {
                              stationarySpeedThld = 1,
                              stationaryDebounceTime = 2,
                              movingDebounceTime = 3,
                              defaultSpeedLimit = 5,
                              speedingTimeOver = 6,
                              speedingTimeUnder = 7,
                              loggingPositionsInterval = 8,
                              stationaryIntervalSat = 11,
                              movingIntervalSat = 12,
                              odometerDistanceIncrement = 14,
                              odometer = 15,
                              turnThreshold = 16,
                              turnDebounceTime = 17,
                              distanceCellThld = 18,
                              distanceSatThld = 19,
                              maxDrivingTime = 20,
                              minRestTime = 21,
                              maxIdlingTime = 23,
                              digPorts = 24,
                              defaultGeoDwellTime = 25,
                              positionMsgInterval = 26,
                              lpmTrigger = 31,
                              lpmEntryDelay = 32,
                              lpmGeoInterval = 33,
                              lpmModemWakeUpInterval = 34,
                              avlStates = 41,
                              digStatesDefBitmap =  46,
                              funcDigInp = {47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59},
                              seatbeltDebounceTime = 115,
                              digOutActiveBitmap = 116,
                              funcDigOut1 = 117,
                              funcDigOut2 = 118,
                              funcDigOut3 = 119,
                              funcDigOut4 = 120,
                              funcDigOut5 = 120,
                              funcDigOut = {117, 118, 119, 120},
                              deleteData = 201,
                              SM0Time = 91, SM0Distance = 92,
                              SM1Time = 93, SM1Distance = 94,
                              SM2Time = 95, SM2Distance = 96,
                              SM3Time = 97, SM3Distance = 98,
                              SM4Time = 99, SM4Distance = 100,

                          },

                          avlAgentSIN = 126,
                          
                          -- table of states of agent
                          avlStateNames = {"InLPM", "onMainPower", "Speeding", "Moving", "Towing", "GPSJammed", "CellJammed", 
                                           "Tamper", "AirCommunicationBlocked", "Reserved", "SeatbeltViolation", "IgnitionON", 
                                           "EngineIdling", "SM1Active", "SM2Active", "SM3Active", "SM4Active", "Geodwelling"},
                          
                          digitalStatesNames = {"IgnitionON", "SeatbeltOFF", "SM1Active", "SM2Active", "SM3Active", "SM4Active"},
                          
                          funcDigInp = {Disabled = 0, GeneralPurpose = 1, IgnitionOn = 2, SeatbeltOff = 3, IgnitionAndSM0 = 4,
                                         SM1 = 5, SM2 = 6, SM3 = 7, SM4 = 8},
                          
                          digStatesDefBitmap = {IgnitionOn = 0  , SeatbeltOff = 1, SM1Active = 2, SM2Active = 3, SM3Active = 4 ,  SM4Active = 5},

                          funcDigOut =  {LowPower = 0, MainPower = 1, Speeding = 2, Moving = 3, Towing = 4, GpsJammed = 5, CellJammed = 6,
                                          Tamper = 7, AirBlocked = 8, LoggedIn = 9, SeatbeltViol = 10, IgnitionOn = 11, Idling = 12, SM1ON = 13,
                                          SM2ON = 14, SM3ON = 15, SM4ON = 16, GeoDwelling = 17, AntCut = 18},
                                        
                          digOutActiveBitmap = {FuncDigOut1 = 0, FuncDigOut2 = 1, FuncDigOut3 = 2, FuncDigOut4 = 3, FuncDigOut5 = 4},
          }

return avlConstants

