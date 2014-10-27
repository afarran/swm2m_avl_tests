--- LSF Services consants definitions
lsfConstants =
              {
                  -- Services SINs and other
                  cons = {
                            systemSIN = 16,
                            powerSIN = 17,
                            EioSIN = 25,
                            geofenceSIN = 21,
                            positionSIN = 20,
                            idpSIN = 27,
                            coldFixDelay = 40,
                            modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                          ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10}
                          },
                  -- Messages MINs
                  mins = {
                            saveProperties = 11,    -- to mobile, system service
                            propertyValues = 5,     -- from mobile, system service
                         },
                  -- Properties PINs
                  pins = {
                            -- IO service
                            port1Config = 1,
                            port1EdgeDetect = 4,
                            port2Config = 12,
                            port2EdgeDetect = 15,
                            port3Config = 23,
                            port3EdgeDetect = 26,
                            port4Config = 34,
                            port4EdgeDetect = 37,
                            portEdgeDetect = { [1] = 4, [2] = 15, [3] = 26, [4] = 37},
                            portConfig = { [1] = 1, [2] = 12, [3] = 23, [4] = 34},
                            temperatureValue = 51,
                            -- Power Service
                            extPowerPresentStateDetect = 5,
                            extPowerPresent = 8,
                            -- Geofence Serrvice
                            geofenceEnabled = 1,
                            geofenceInterval = 2,
                            geofenceHisteresis = 3,
                            -- Position service
                            gpsReadInterval = 15,    -- continunes property, position service
                            -- IDP Service
                            wakeUpInterval = 11,    -- wake up interval
                            ledControl = 6,         -- system service
                            powerMode = 10,
                         },
            }

return lsfConstants
