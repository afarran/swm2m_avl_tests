
local lunatest      = require "lunatest"
local TestGPSModule = require "TestGPSModule"
local TestLPMModule = require "TestLPMModule"
local TestDigitalInputsModule  = require "TestDigitalInputsModule"
local TestDigitalOutputsModule  = require "TestDigitalOutputsModule"
local TestGeofencesModule = require "TestGeofencesModule"
local TestPeriodicReportsModule = require "TestPeriodicReportsModule"
local TestServiceMeterModule = require "TestServiceMeterModule"



for i=1, 1, 1 do
  lunatest.run()
end


framework.printResults()


