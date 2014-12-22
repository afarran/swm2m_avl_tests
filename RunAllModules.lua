cfg, framework, gateway, lsf, device, gps = require "TestFramework"()
avlHelperFunctions    = require "avlHelperFunctions"()    -- all AVL Agent related functions put in avlHelperFunctions file
avlConstants =  require("AvlAgentConstants")
lsfConstantsAllTerminals = require("LsfConstants")
lunatest = require "lunatest"
profileFactory = require("Profile/ProfileFactory")()

-- global variables used in the tests
FORCE_ALL_TESTCASES = false                                         -- determines whether to run all TCs or to use random TC for similar features - e.g Sensors / ServiceMeters
GPS_PROCESS_TIME = 1                                                -- seconds
GATEWAY_TIMEOUT = 60                                                -- in seconds
TIMEOUT_MSG_NOT_EXPECTED = 20                                       -- in seconds
GEOFENCE_INTERVAL = 10                                              -- in seconds
GPS_READ_INTERVAL = 1                                               -- used to configure the time interval of updating the position , in seconds
AVL_SIN = 126                                                       -- AVL SIN is constant
hardwareVariant = avlHelperFunctions.getTerminalHardwareVersion()   -- 1,2 and 3 for 600, 700 and 800 available
lsfConstants= lsfConstantsAllTerminals[hardwareVariant]             -- getting constants specific for the terminal under test
profile = profileFactory.create(hardwareVariant)

--- Called before the start of any test suites
local function setup()
  print("*** AVL Feature Tests Started ***")
  math.randomseed(os.time())
  io.output():setvbuf("no")
  --include the following test suites in the feature tests:
  --lunatest.suite("TestGPSModule")
  lunatest.suite("TestLPMModule")
  --lunatest.suite("TestDigitalInputsModule")
  --lunatest.suite("TestServiceMeterModule")
  --lunatest.suite("TestDigitalOutputsModule")
  --lunatest.suite("TestGeofencesModule")
  --lunatest.suite("TestPeriodicReportsModule")
  --lunatest.suite("TestSensorsModule")
  --lunatest.suite("TestAdminConfigModule")
  --lunatest.suite("TestDriverIdentModule")

end

local function teardown()
  print("*** AVL Feature Tests Completed ***")
  framework.printResults()
end

--- Runs Feature Tests
-- @tparam table args array of string arguments
-- @usage
-- [-v]                     Verbose option
-- [-t] [<string pattern>]  Execute test cases that match string pattern
-- [-s] [<string pattern>]  Execute test suites that match string pattern
for idx, val in ipairs(arg) do print(idx, val) end

setup()

lunatest.run(nil, arg)

teardown()



