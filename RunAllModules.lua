
lunatest      = require "lunatest"
lunatest.suite("TestGPSModule")
lunatest.suite("TestLPMModule")
lunatest.suite("TestDigitalInputsModule")
lunatest.suite("TestDigitalOutputsModule")
lunatest.suite("TestGeofencesModule")
lunatest.suite("TestPeriodicReportsModule")
lunatest.suite("TestServiceMeterModule")



lunatest.run()
framework.printResults()


