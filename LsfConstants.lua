--- LSF Services consants definitions
lsfConstantsAllTerminals = {
                              [1] = {
                                                -- Services SINs and other
                                                sins = {
                                                          system = 16,
                                                          power = 17,
                                                          geofence = 21,
                                                          position = 20,
                                                          log = 23,
                                                          filesystem =  24,
                                                          idp = 27,
                                                          io = 25,
                                                        },
                                                -- Messages MINs
                                                mins = {
                                                          setDataLogFilter = 1,   -- to mobile message, log service
                                                          setCircle = 1,          -- to mobile message, geofences service
                                                          setRectangle = 7,       -- to mobile message, geofences service
                                                          write = 1,              -- to mobile message, filesystem service
                                                          saveProperties = 11,    -- to mobile, system service
                                                          propertyValues = 5,     -- from mobile, system service
                                                          getTerminalInfo = 1,    -- to mobile, system service
                                                          terminalInfo = 1,       -- from mobile , system service
                                                          restartService = 5,     -- to mobile message
                                                          getDataLogEntries = 5,  -- to mobile message, log service
                                                          dataLogEntries = 5,     -- from mobile message, log service

                                                       },
                                                -- Properties PINs
                                                pins = {
                                                          -- Power Service
                                                          extPowerPresentStateDetect = 5,
                                                          extPowerPresent = 8,
                                                          -- Geofence Service
                                                          geofenceEnabled = 1,
                                                          geofenceInterval = 2,
                                                          geofenceHisteresis = 3,
                                                          -- Position service
                                                          latitude = 6,
                                                          gpsReadInterval = 15,    -- continunes property, position service
                                                          -- IDP Service
                                                          wakeUpInterval = 11,    -- wake up interval
                                                          ledControl = 6,         -- system service
                                                          powerMode = 10,
                                                          portEdgeDetect = {},
                                                          portConfig = {},
                                                          -- io properties
                                                          portEdgeDetect = { [1] = 4, [2] = 15, [3] = 26, [4] = 37},
                                                          portConfig = { [1] = 1, [2] = 12, [3] = 23, [4] = 34},
                                                          portEdgeSampleCount = { [1] = 5, [2] = 16, [3] = 27, [4] = 38},
                                                          temperatureValue = 51,

                                                       },
                                                modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                                              ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10 },

                                                coldFixDelay = 40,
                                            },

                             [2] = {
                                                  -- TODO: add this in future
                                                  },

                             [3] = {
                                                -- Services SINs and other
                                                sins = {
                                                          system = 16,
                                                          power = 17,
                                                          geofence = 21,
                                                          position = 20,
                                                          log = 23,
                                                          filesystem =  24,
                                                          idp = 27,
                                                          io = 25,
                                                        },
                                                -- Messages MINs
                                                mins = {
                                                          setDataLogFilter = 1,   -- to mobile message, log service
                                                          setCircle = 1,          -- to mobile message, geofences service
                                                          setRectangle = 7,       -- to mobile message, geofences service
                                                          write = 1,              -- to mobile message, filesystem service
                                                          saveProperties = 11,    -- to mobile, system service
                                                          propertyValues = 5,     -- from mobile, system service
                                                          getTerminalInfo = 1,    -- to mobile, system service
                                                          terminalInfo = 1,       -- from mobile , system service
                                                          restartService = 5,     -- to mobile message, system service
                                                          getDataLogEntries = 5,  -- to mobile message, log service
                                                          dataLogEntries = 5,     -- from mobile message, log service
                                                       },
                                                -- Properties PINs
                                                pins = {
                                                          -- Power Service
                                                          extPowerPresentStateDetect = 5,
                                                          extPowerPresent = 8,
                                                          -- Geofence Service
                                                          geofenceEnabled = 1,
                                                          geofenceInterval = 2,
                                                          geofenceHisteresis = 3,
                                                          -- Position service
                                                          latitude = 6,
                                                          gpsReadInterval = 15,    -- continunes property, position service
                                                          -- IDP Service
                                                          wakeUpInterval = 11,    -- wake up interval
                                                          ledControl = 6,         -- system service
                                                          powerMode = 10,
                                                          portEdgeDetect = {},
                                                          portConfig = {},
                                                          -- io properties
                                                          portEdgeDetect = { [1] = 4, [2] = 15, [3] = 26, [4] = 37},
                                                          portConfig = { [1] = 1, [2] = 12, [3] = 23, [4] = 34},
                                                          portEdgeSampleCount = { [1] = 5, [2] = 16, [3] = 27, [4] = 38},
                                                          temperatureValue = 51,

                                                       },
                                                modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                                              ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10 },

                                                coldFixDelay = 40,
                                            },
        }
return lsfConstantsAllTerminals
