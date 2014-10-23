--- AVL Agent test consants definitions

-- AVL Agent SIN number
cons = {
             avlAgentSIN = 126,
             avlStateNames = {"InLPM", "onMainPower", "Speeding", "Moving", "Towing", "GPSJammed", "CellJammed", "Tamper", "AirCommunicationBlocked",
                              "Reserved", "SeatbeltViolation", "IgnitionON", "EngineIdling", "SM1Active", "SM2Active", "SM3Active", "SM4Active", "Geodwelling" },  -- table of states of agent
             digitalStatesNames = {"IgnitionON", "SeatbeltOFF", "SM1Active", "SM2Active", "SM3Active", "SM4Active" },
             systemSIN = 16,
             powerSIN = 17,
             EioSIN = 25,
             geofenceSIN = 21,
             positionSIN = 20,
             coldFixDelay = 40,
             idpSIN = 27,
             funcDigInp = { ["Disabled"] = 0, ["GeneralPurpose"] = 1, ["IgnitionOn"] = 2, ["SeatbeltOff"] = 3, ["IgnitionAndSM0"] = 4,
                            ["SM1"] = 5, ["SM2"] = 6, ["SM3"] = 7, ["SM4"] = 8},

             digStatesDefBitmap = { ["IgnitionOn"] = 0  , ["SeatbeltOff"] = 1, ["SM1Active"] = 2, ["SM2Active"] = 3, ["SM3Active"] = 4 ,  ["SM4Active"] = 5},

             funcDigOut =  { ["LowPower"] = 0, ["MainPower"] = 1, ["Speeding"] = 2, ["Moving"] = 3, ["Towing"] = 4, ["GpsJammed"] = 5, ["CellJammed"] = 6,
                             ["Tamper"] = 7, ["AirBlocked"] = 8, ["LoggedIn"] = 9, ["SeatbeltViol"] = 10, ["IgnitionOn"] = 11, ["Idling"] = 12, ["SM1ON"] = 13,
                             ["SM2ON"] = 14, ["SM3ON"] = 15, ["SM4ON"] = 16, ["GeoDwelling"] = 17, ["AntCut"] = 18 },

             digOutActiveBitmap = { ["FuncDigOut1"] = 0, ["FuncDigOut2"] = 1, ["FuncDigOut3"] = 2, ["FuncDigOut4"] = 3, ["FuncDigOut5"] = 4 },

             modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                        ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10}

              }


--- AVL Agent test Messages MINs definitions
--
mins = {
                  positionRequest = 1,
                  powerMain = 2,
                  powerBackup = 3,
                  ignitionON = 4,
                  ignitionOFF = 5,
                  movingStart = 6,
                  movingEnd = 7,
                  speedingStart = 8,
                  speedingEnd = 9,
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
                  setGeoSpeedLimits = 7,
                  geoDwellStart = 30,
                  geoDwellEnd = 40,
                  setGeoDwellTimes = 9,
                  longDriving = 29,
                  distanceSat = 23,
                  getServiceMeter = 12,
                  setServiceMeter = 11,
                  loggedPosition = 15,
                  getDiagnostics = 13,
                  serviceMeter = 31,
                  diagnosticsInfo = 32,
                  digitalInp1Hi = 50,
                  digitalInp1Lo = 51,
                  digitalInp2Hi = 52,
                  digitalInp2Lo = 53,
                  digitalInp3Hi = 54,
                  digitalInp3Lo = 55,
                  digitalInp4Hi = 56,
                  digitalInp4Lo = 57,
                  digitalInp5Hi = 58,
                  digitalInp5Lo = 59,
                  digitalInp6Hi = 60,
                  digitalInp6Lo = 61,
                  digitalInp7Hi = 62,
                  digitalInp7Lo = 63,
                  digitalInp8Hi = 64,
                  digitalInp8Lo = 65,
                  digitalInp9Hi = 66,
                  digitalInp9Lo = 67,
                  digitalInp10Hi = 68,
                  digitalInp10Lo = 69,
                  digitalInp11Hi = 70,
                  digitalInp11Lo = 71,
                  digitalInp12Hi = 72,
                  digitalInp12Lo = 73,
                  saveProperties = 11,
                  serviceProperties = 201,
                  getProperties = 6,
                  propertyValues = 5,
	        			}

--- AVL Agentproperties PINs definitions
--
pins = {
          stationarySpeedThld = 1,
          stationaryDebounceTime = 2,
          movingDebounceTime = 3,
          defaultSpeedLimit = 5,
          speedingTimeOver = 6,
          speedingTimeUnder = 7,
          stationaryIntervalSat = 11,
          movingIntervalSat = 12,
          positionMsgInterval = 26,
          lpmTrigger = 31,
          avlStates = 41,
          digStatesDefBitmap =  46,
          funcDigInp1 = 47,
          funcDigInp2 = 48,
          funcDigInp3 = 49,
          funcDigInp4 = 50,
          funcDigInp5 = 51,
          funcDigInp6 = 52,
          funcDigInp7 = 53,
          funcDigInp8 = 54,
          funcDigInp13 = 59,
          port1Config = 1,
          port1EdgeDetect = 4,
          port1EdgeSampleCount = 5,
          port2Config = 12,
          port2EdgeDetect = 15,
          port2EdgeSampleCount = 16,
          port3Config = 23,
          port3EdgeDetect = 26,
          port3EdgeSampleCount = 27,
          port4Config = 34,
          port4EdgeDetect = 37,
          port4EdgeSampleCount = 38,
          maxIdlingTime = 23,
          seatbeltDebounceTime = 115,
          lpmEntryDelay = 32,
          funcDigInp13 = 59,
          extPowerPresentStateDetect = 5,
          extPowerPresent = 8,
          turnThreshold = 16,
          turnDebounceTime = 17,
          geofenceEnabled = 1,
          geofenceInterval = 2,
          geofenceHisteresis = 3,
          defaultGeoDwellTime = 25,
          deleteData = 201,
          maxDrivingTime = 20,
          minRestTime = 21,
          odometerDistanceIncrement = 14,
          odometer = 15,
          distanceCellThld = 18,
          distanceSatThld = 19,
          loggingPositionsInterval = 8,
          digPorts = 24,
          temperatureValue = 51,
          digOutActiveBitmap = 116,
          funcDigOut1 = 117,
          funcDigOut2 = 118,
          funcDigOut3 = 119,
          funcDigOut4 = 120,
          funcDigOut5 = 120,
          gpsReadInterval = 15,
          lpmGeoInterval  = 33,
          lpmModemWakeUpInterval = 34,
          wakeUpInterval = 11,
          ledControl = 6,
          funcDigInp = { [1]= 47, [2] = 48, [3] = 49, [4] = 50, [5] = 51, [6] = 52, [7] = 53, [8] = 54, [9] = 55, [10] = 56, [11] = 57, [12] = 58, [13] = 59 },
          portConfig = { [1] = 1, [2] = 12, [3] = 23, [4] = 34},
          portEdgeDetect = { [1] = 4, [2] = 15, [3] = 26, [4] = 37},
          powerMode = 10,
			}

return function() return cons, mins, pins end
