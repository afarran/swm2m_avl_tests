--- LSF Services consants definitions
lsfConstants = {
                  -- Services SINs and other
                  sins = {
                            system = 16,
                            power = 17,
                            geofence = 21,
                            position = 20,
                            idp = 27,
                          },
                  -- Messages MINs
                  mins = {
                            saveProperties = 11,    -- to mobile, system service
                            propertyValues = 5,     -- from mobile, system service
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

                         },
                  modemWakeUpIntervalValues = { ["5_seconds"] = 0, ["30_seconds"] = 1, ["1_minute"] = 2, ["3_minutes"] = 3, ["10_minutes"] = 4, ["30_minutes"] = 5, ["60_minutes"] = 6,
                                                ["2_minutes"] = 7, ["5_minutes"] = 8, ["15_minutes"] = 9, ["20_minutes"] = 10 },

                  coldFixDelay = 40,

              }

-- IO service requires special treatment - there is EIO in 600's and 800's and EEIO in 700' - different SIN and PINs are applied
if terminalInUse == (800 or 600) then

  lsfConstants.sins.io = 25                                                      -- sin of EIO Service in 600's and 800's
  lsfConstants.pins.portEdgeDetect = { [1] = 4, [2] = 15, [3] = 26, [4] = 37}
  lsfConstants.pins.portConfig = { [1] = 1, [2] = 12, [3] = 23, [4] = 34}
  lsfConstants.pins.temperatureValue = 51

else

  -- TODO:
  -- add 700's IO service SIN and PINs

end



return lsfConstants