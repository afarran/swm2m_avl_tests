--- LSF Services consants definitions
lsfConstantsAllTerminals = {
                              [600] = {
                                                -- Services SINs and other
                                                sins = {
                                                          system = 16,
                                                          power = 17,
                                                          geofence = 21,
                                                          position = 20,
                                                          idp = 27,
                                                          io = 25,
                                                        },
                                                -- Messages MINs
                                                mins = {
                                                          saveProperties = 11,    -- to mobile, system service
                                                          propertyValues = 5,     -- from mobile, system service
                                                          getTerminalInfo = 1,    -- to mobile, system service
                                                          terminalInfo = 1,       -- from mobile , system service
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
                                                          temperatureValue = 51,

                                                       },
                                                modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                                              ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10 },

                                                coldFixDelay = 40,
                                            },

                             [700] = {
                                                  -- TODO: add this in future
                                                  },

                             [800] = {
                                                -- Services SINs and other
                                                sins = {
                                                          system = 16,
                                                          power = 17,
                                                          geofence = 21,
                                                          position = 20,
                                                          idp = 27,
                                                          io = 25,
                                                        },
                                                -- Messages MINs
                                                mins = {
                                                          saveProperties = 11,    -- to mobile, system service
                                                          propertyValues = 5,     -- from mobile, system service
                                                          getTerminalInfo = 1,    -- to mobile, system service
                                                          terminalInfo = 1,       -- from mobile , system service
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
                                                          temperatureValue = 51,

                                                       },
                                                modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                                              ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10 },

                                                coldFixDelay = 40,
                                            },
        }
return lsfConstantsAllTerminals
