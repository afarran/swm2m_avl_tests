--- Lua Services Test Framework Configuration
-- <br /><br />
-- PLEASE DO NOT MODIFY THIS FILE. UPDATE THESE VALUES FROM YOUR TEST SUITE FILE INSTEAD.
-- <br /><br />
-- For example, gateway web service location may be configured like so: <br />
-- <span style="font-family:monospace">cfg.GATEWAY_URL = "http://localhost:8080"	-- assuming service running on port 8080</span>
-- <br /><br />
-- Note: It is NOT necessary to require this file from the test suite.
-- @module TestConfiguration

--- Configuration table
-- @field HTTP_PROXY	URL of http proxy if needed; set it to <span style="font-family:monospace">http://127.0.0.1:8888</span> if using
-- fiddler to snoop on traffic to and from web services running on localhost.
-- @field GATEWAY_URL 	address of simulated Gateway; run from Modem Simulator.
-- @field GATEWAY_SUFFIX gateway suffix
--
-- @field DEVICE_URL 	address of device web service; run from Terminal Simulator
-- @field GPS_URL		address of GPS web service; run from Modem Simulator
-- @field ACCESS_ID 	Simulated gateway access ID; don't change
--
-- @field PASSWORD 		Simulated gateway access password; don't change
-- @field MOBILE_ID 	Simulated mobile ID; don't change
-- @field GATEWAY_TIMEOUT Seconds framework waits for a particular message from gateway before timing out
cfg = {
	HTTP_PROXY 		= nil,                                  -- Uncomment if not snooping on traffic using Fiddler
	--HTTP_PROXY = "http://127.0.0.1:8888",                 -- Uncomment if using Fiddler to snoop traffic
	GATEWAY_URL 	= "http://localhost:8080",
	GATEWAY_SUFFIX 	= "/GLGW/GWServices_v1/RestMessages.svc",
	DEVICE_URL 		= "http://localhost:8080/DeviceWebService",
	GPS_URL 		= "http://localhost:8080/GpsWebService",

	ACCESS_ID 		= "00000000",
	PASSWORD 		= "password",
	MOBILE_ID 		= "00000000SKYEE3D",
	GATEWAY_TIMEOUT = 12
}
return cfg
