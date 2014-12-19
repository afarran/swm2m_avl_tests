--- Lua Services Test Framework.
-- You may find it convenient to run your test suite from SciTE.
-- @usage
-- shell> lua -e "debugLevel = 0|1|2" <test file name>
-- @usage
-- -- debugLevel defaults to 0 if not specified
-- shell> lua <test file name>
-- @usage
-- -- If 'lua' file extension is associated with the lua runtime, you can simply run (in debugLevel 0) like so:
-- shell> MyTestSuite.lua
-- @module TestFramework

local rev = "$Revision: 1983 $"

local http = require("socket.http")
local ltn12 = require("ltn12")
local mime = require("mime")
local io = require("io")
local json = require("json")
local cfg = require("TestConfiguration")

local startUTC = os.time()
local testNum = 0
local b64map='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'	--needed for b64 encoding.
local lastForwardID = 0
local testStartTime = os.time()
local calledGateway = false
local terminalInfo = nil
local gatewayVersion = nil
local timeOffset = 0

local gateway = {}
local lsf = {}
local device = {}
local gps = {}
local tf = {}

gateway.returnMsgList = {}
cfg.PORTMAP = {}

local function getTableLength(table)
	local len = 0
	for _ in pairs(table) do len = len + 1 end
	return len
end

cfg.mt = {}
cfg.mt.__index = function(table, key)
	if getTableLength(table) == 0 then return key end
	error("Invalid I/O port: " .. tostring(key))
end
setmetatable(cfg.PORTMAP, cfg.mt)

function printf(...)
	io.write(string.format(...))
end

function printfLine(...)
	printf(...)
	io.write("\n")
end

function printfLineDate(...)
	io.write(os.date("![%Y-%m-%d %X] "))
	printfLine(...)
end

function doNothing() end

--------------------Local Framework Functions--------------------

local function getRevision()
	for number in rev:gmatch("%d+") do
		return number
	end
end

local function lowerCaseNoSpace(str)
	if str == nil then return nil end
	return str:gsub("%s", ""):lower()
end

--- print regardless of debugLevel
-- @function tf.trace0
-- @param ... variable arguments that could be passed to string.format
-- @usage
-- -- output will be similar to this:
-- -- [2014-06-24 21:18:16] Hello World!
-- tf.trace0("Hello %s!", "World")
-- @within tf

--- print when debug level is 1 or higher
-- @function tf.trace1
-- @param ... variable arguments that could be passed to string.format
-- @usage
-- -- output will be similar to this:
-- -- [2014-06-24 21:18:16] Today's day of week: Tuesday
-- tf.trace1("Today's day of week: %s", os.date("%A"))
-- @within tf

--- print when debug level is 2
-- @function tf.trace2
-- @param ... variable arguments that could be passed to string.format
-- @usage
-- -- output will be similar to this:
-- -- [2014-06-24 21:18:16] He said, "thank you".
-- tf.trace2("He said, %q.", "thank you")
-- @within tf

local function escape(s)
	s = string.gsub(tostring(s), "[&=+:%%%c]", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	s = string.gsub(s, " ", "+")
	return s
end

local function encode(t)
	local b = { }
	for k, v in pairs(t) do
		b[#b + 1] = (escape(k) .. "=" .. escape(v))
	end
	return table.concat(b, "&")
end

local firstCallHouseKeeping

local function webServiceGet(fullURL, decode)
	local encoded = json.encode(nil)
	local source = ltn12.source.string(encoded);
	local response = {}
	local sink = ltn12.sink.table(response)
	local headers = {
			["Content-Type"] = "application/json",
			["Content-Length"] = 0		-- TODO: keep this? breaks something else?
		}
	if decode == nil then
		decode = true
	end
	tf.trace2(fullURL)
	ok, code, headers = http.request {
		url = fullURL,
		proxy = cfg.HTTP_PROXY,
		method = "GET", headers = headers, source = source, sink = sink
	}
	if ok and code == 200 then
		local response1 = response[1];
		if decode then
			return json.decode(response1)
		end
	else
		return false, code
	end
end

local function webServiceGetResource(url, resource, params, decode)
	params = params == nil and "" or "?" .. encode(params)
	return webServiceGet(url .. "/" .. resource .. ".json/" .. params, decode)
end

-- returns a resource value; the resource must be published by the web service (like info_utc_time)
-- See document N201 for list of gateway web resources.
local function gatewayGetResource(resource, params)
	firstCallHouseKeeping()
	local returnVal, code = webServiceGetResource(cfg.GATEWAY_URL .. cfg.GATEWAY_SUFFIX, resource, params)
	if not returnVal then
		error("Gateway unreachable. HTTP Error code: " .. tostring(code))
	end
	return returnVal
end

local function collapseFields(fields)
	local t = { }
	for i = 1, #fields do
		local value = fields[i].Value
		local elements = fields[i].Elements
		t[fields[i].Name] = value and value or elements
	end
	return t
end

local function oneLineDump(var)
	if type(var) == "string" then
		return '"' .. var .. '"'
	elseif type(var) == "table" then
		out = ""
		for k,v in pairs(var) do
			if type(v) ~= "table" then
				out = out .. " ".. k .."=" .. tostring(v)
			end
		end
		return out
	else
		return tostring(var)
	end
end

-- msg: collapsed return message
local function recordAndPrintMsg(msg)
	local brief = {id=msg.ID, time=msg.MessageUTC, sin=msg.SIN, name=msg.Payload.Name}
	if msg.SIN == 18 and msg.Payload.MIN == 3 then
		print("Invalid to-terminal msg: " .. tf.dump(msg))
	elseif msg.SIN == 18 and msg.Payload.MIN == 4 then
		print("Terminal couldn't process msg: " .. tf.dump(msg))
	elseif msg.SIN == 26 and msg.Payload.MIN == 1 and msg.Payload.success=="False" then
		print("Invalid shell command: " .. tf.dump(msg))
	else
		if tf.trace2 == doNothing then
			tf.trace1("Received: " ..  oneLineDump(msg.Payload))
		else
			tf.trace2("Received: " .. tf.dump(msg.Payload))
		end
	end
	gateway.returnMsgList[#gateway.returnMsgList+1] = brief
end

local function checkShellResponse(msg, substring)
	if msg then
		if msg.Payload.SIN == 26 and msg.Payload.MIN == 1 then
			substring = substring and substring or ""
			local colmsg = tf.collapseMessage(msg)
			return colmsg.Payload.output:find(substring)
		end
	end
	return false
end

local function assertSinRange(sin)
	assert(type(sin) == "number" and 1 <= sin and sin <= 255, "Expected SIN between 1 and 255; got " .. tostring(sin))
end

local function checkValueType(t)
	--unsignedint, signedint, string, boolean, enum, data
	return t == "unsignedint" or t == "signedint" or t == "enum" or t == "string" or t == "boolean" or t == "data"
end

local function getSettingsTable(settings)
	if type(settings[1]) ~= "table" then
		settings = {settings}
	end
	sTable = {}
	for i=1,#settings do
		sTable[i]={}
		settings[i][3] = settings[i][3] and settings[i][3] or "unsignedint"
		assert(settings[i][1] ~= nil and settings[i][2] ~= nil and settings[i][3] ~= nil, "settings must be array of {1=pin, 2=value, 3=valType}")
		assert(checkValueType(settings[i][3]), "Value type must one of: unsignedint, signedint, string, boolean, enum, data; is " .. tostring(valType))
		sTable[i].Index=i-1
		sTable[i].Fields={{Name="pin",Value=settings[i][1]},
			{Name="value",Value=settings[i][2],Type=settings[i][3]}}
	end
	return sTable
end

-- Converts timestamp (unsigned int) to its equivalent string representation
-- <br /><br />
-- See <span style="font-family:monospace">ISOToEpoch</span> which has the opposite affect
-- @tparam number timestamp the timestamp to convert to string
-- @treturn string the string representation of the timestamp
local function EpochToISO(timestamp)
	if timestamp then
		return os.date("%Y-%m-%d %H:%M:%S", timestamp)
	end
	return nil
end

-- converts date in yyyy-MM-dd hh:mm:ss format to timestamp (unsigned int)
-- <br /><br />
-- See <span style="font-family:monospace">EpochToISO</span> which has the opposite affect
-- @tparam string s string representation of date in "yyyy-MM-dd hh:mm:ss" format
-- @treturn number the corresponding timestamp
local function ISOToEpoch(s)
	local year, month, day, hour, min, sec = s:match("(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d)")
	return os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
end

local function getReturnMessages()
	firstCallHouseKeeping()
	local encoded = json.encode(msgs)
	local source = ltn12.source.string(encoded);
	local response = {}
	local sink = ltn12.sink.table(response)
	local headers = {
		["Content-Type"] = "application/json",
	}
	local startTime = EpochToISO(startUTC)
	local params = {
		["access_id"] = cfg.ACCESS_ID,
		["password"] = cfg.PASSWORD,
		["start_utc"] = startTime
	}
	local url = cfg.GATEWAY_URL .. cfg.GATEWAY_SUFFIX .. "/get_return_messages.json/?" .. encode(params)
	ok, code, headers = http.request {
		url = url,
		proxy = cfg.HTTP_PROXY,
		method = "GET", headers = headers, source = source, sink = sink
	}
	if ok and code == 200 then
		local response1 = response[1];
		for i=2,10 do
			if response[i] ~= nil then
				response1 = response1 .. response[i]
			else
				break
			end
		end
		local result, decoded = pcall(json.decode, response1)
		if not result then
			error("JSON decode failed: " .. decoded)
		elseif decoded.ErrorID == 0 then
			if decoded.NextStartUTC ~= "" then
				startUTC = ISOToEpoch(decoded.NextStartUTC)
			end
			return decoded.Messages
		else
			error("Gateway message retrieval error... ErrorID: " .. tostring(decoded.ErrorID))
		end
	else
		error("Gateway message retrieval error... OK?" .. tostring(ok) .. ", code: " .. tostring(code))
	end
	return nil
end

-- Returns a number representing current gateway time
local function getGatewayTime()
	local decoded = gatewayGetResource("info_utc_time")
	return ISOToEpoch(decoded)
end

local function getTerminalResponse(payload, checkFunction, cbfParam)
	gateway.setHighWaterMark()
	gateway.submitForwardMessage(payload)
	return gateway.getReturnMessage(checkFunction, cbfParam)
end

function firstCallHouseKeeping()
	if not calledGateway then
		calledGateway = true
		local gatewayTime = getGatewayTime()
		local localTime = os.time()
		timeOffset = gatewayTime - localTime
		gatewayVersion = gatewayGetResource("info_version")
		gateway.setHighWaterMark()
		gateway.submitForwardMessage{SIN = 16, MIN = 1}
		local msg = gateway.getReturnMessage(tf.checkMessageType(16, 1))
		if msg then
			local colmsg = tf.collapseMessage(msg)
			if debugLevel == 2 then
				terminalInfo = "Terminal info: " .. tf.dump(colmsg.Payload);
			else
				terminalInfo = colmsg.Payload.packageVersion and "Terminal package: " .. colmsg.Payload.packageVersion or "LSF Version: " .. colmsg.Payload.LSFVersion
			end
		else
			print "Unable to retrieve terminal info. Tests will continue."
		end
	end
end

-----------------Test Framework Helper Functions-----------------

tf.version = "2.0." .. getRevision()
tf.failureCount = 0

--- Gets string representation of a table; normally used to print tables.
-- @return string representation of Lua object
-- @tparam table var object whose string representation is desired; need not be a table
-- @tparam[opt=0] ?number depth #spaces to indent table
-- @usage
-- local x = {1, "a", {"b"}}
-- print(tf.dump(x))
-- -- this prints:
-- {
--     1 = 1
--     2 = "a"
--     3 = {
--         1 = "b"
--     }
-- }
-- @within tf
function tf.dump(var, depth)
	depth = depth or 0
	if type(var) == "string" then
		return '"' .. var .. '"\n'
	elseif type(var) == "table" then
		depth = depth + 1
		out = "{\n"
		for k,v in pairs(var) do
			out = out .. (" "):rep(depth*4) .. tostring(k) .." = " .. tf.dump(v, depth)
		end
		return out .. (" "):rep((depth-1)*4) .. "}\n"
	else
		return tostring(var) .. "\n"
	end
end

--- Returns a function that can then be passed to <span style="font-family:monospace">getReturnMessage</span>
-- or <span style="font-family:monospace">filterReturnMessages</span> as the callback function; the callback function
-- verifies the SIN and MIN specified.<br /><br />
-- NOTE: In general, callback functions are written by users to match precise criteria.<br /><br />
-- NOTE: Use "Message Editor" application to automatically generate useful callback functions.
-- @tparam number sin SIN to check for
-- @tparam number min MIN to check for
-- @usage
-- -- send a to-mobile message with SIN 16, MIN 3; no additional data required for this simple message
-- local payload = {SIN=16, MIN=3}
-- gateway.submitForwardMessage(payload)
-- -- verify that from-mobile message with (SIN, MIN) = (16, 3) is received; (serviceList)
-- local msg = gateway.getReturnMessage(tf.checkMessageType(16, 3))
-- print(tf.dump(msg))
-- @within tf
function tf.checkMessageType(sin, min)
	return function(msg)
		if msg and msg.Payload and msg.Payload.SIN == sin and msg.Payload.MIN == min then
			return true
		end
		return false
	end
end

--- Sleep specified number of seconds before executing next line of code
-- @number seconds duration to sleep
-- @within tf
function tf.delay(seconds)
	socket.sleep(seconds)
end

--- Data fields in to-or-from terminal messages are encoded in base64 format; this function encodes string data to base64 format
-- @param data string or array or numbers in range [0, 255]: the data to encode
-- @treturn string base64-encoded data
-- @usage
-- -- These are equivalent calls:
-- tf.base64Encode({65, 66, 67})
-- tf.base64Encode("ABC")
-- @within tf
function tf.base64Encode(data)
	local data1 = data
	if type(data) == "table" then
		data1 = string.char(unpack(data))
	end
    return ((data1:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b64map:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data1%3+1])
end

local function base64Decode(data)
    data = string.gsub(data, '[^'..b64map..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r,f='',(b64map:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

--- Decode base64 string data, complementary to base64Encode
-- @tparam string data string data to decode
-- @treturn table table of numbers in range [0, 255] (byte representation of decoded string)
-- @treturn string decoded string
-- @usage
-- -- This is how getSinList uses b64dec to decode data represented in b64 format:
-- local payload = {SIN=16, MIN=3}
-- gateway.submitForwardMessage(payload)
-- local msg = gateway.getReturnMessage(tf.checkMesssageType(16, 3))
-- local sinList = msg.Payload.sinList
-- sinList = tf.base64Decode(sinList)
-- @within tf
function tf.base64Decode(data)
    local str = base64Decode(data)
	return {str:byte(1, str:len())}, str
end

local function collapseMsg(tbl)
	for k,v in pairs(tbl) do
		if k == "Index" and type(v) == "number" then
			tbl[k] = nil
		elseif k == "Fields" then
			for k2,v2 in pairs(collapseFields(v)) do
				tbl[k2] = v2
			end
			tbl[k] = nil
		end
	end
	for k,v in pairs(tbl) do
		if type(v) == "table" then
			tbl[k] = tf.collapseMessage(v)
		end
	end
end

--- Simplify a to-or-from gateway message (or array of messages) for printing and accessing fields
-- @tparam table tbl the table to collapse
-- @treturn table collapsed table
-- @usage
-- -- This gets return messages from the gateway and makes them more readable
-- local msgs = getReturnMessages()
-- for _, msg in ipairs(msgs) do
-- 	msg = tf.collapseMessage(msg)
--	print(tf.dump(msg))
-- end
-- -- or simply:
-- tf.dump(getReturnMessages())
-- @within tf
function tf.collapseMessage(tbl)
	if not tbl then
		return nil
	end
	local t2 = {}
	for k,v in pairs(tbl) do
		if k == "Index" and type(v) == "number" then
			-- ignore key/value
		elseif k == "Fields" then
			for k2,v2 in pairs(collapseFields(v)) do
				t2[k2] = v2
			end
		else
			t2[k] = v
		end
	end
	for k,v in pairs(t2) do
		if type(v) == "table" then
			t2[k] = tf.collapseMessage(v)
		end
	end
	return t2
end

--- Filter the return messages that conform to a check function
-- @tparam table msgs output of getReturnMessages()
-- @tparam function checkFunction function that determines whether each message is of the type that is being checked for
-- @tparam[opt] ?AnyType checkParam parameter to pass to the call back function; if >1 parameters needed, pass a table.
-- @usage
-- -- get return messages from gateway and determine how many are position reports (SIN 20, MIN 1)
-- local msgs = gateway.getReturnMessages()
-- local matching = tf.filterMessages(msgs, checkMessageType (20, 1))
-- @within tf
function tf.filterMessages(msgs, checkFunction, checkParam)
	local filtered = {}
	for _, msg in ipairs(msgs) do
		local success, retVal = pcall(checkFunction, msg, checkParam)
		if success and retVal == true then
			filtered[#filtered + 1] = msg
		end
	end
	return filtered
end

--- Test suite run can be looped multiple times. This function prints statistics after the test run; call after runTests().
-- See TestSuiteExample0X for details.
-- @tparam[opt=false] bool ?testSuiteSuccess
-- @within tf
function tf.printResults(testSuiteSuccess)
	if testSuiteSuccess == false then	-- no param if using lunatest; don't treat it as failure
		tf.failureCount = tf.failureCount + 1
	end
	print()
	print("--------------------------------")
	local msgTypes = {}
	local printTitle = true
	for k,v in ipairs(gateway.returnMsgList) do
		v.name = v.name and v.name or "<Unnamed>"
		msgTypes[v.name] = msgTypes[v.name] and msgTypes[v.name] + 1 or 1
	end
	print "Return messages statistics:"
	for k,v in pairs(msgTypes) do
		print("Received " .. tostring(v) .. " " .. k .. " messages.")
	end
	print("")
	local diff = os.difftime(os.time(), testStartTime)
	print("Time to run tests: " .. os.date("!%H:%M:%S", diff) .. ".")
	print("")
	printf("Framework version: %s \n", tf.version)
	if gatewayVersion then
		printf("Gateway version: %s \n", gatewayVersion)
	end
	--if debugLevel == 2 then all msgs are logged automatically
	if terminalInfo then
		print(terminalInfo)
	end
	--resetStats
	testStartTime = os.time()
	gateway.returnMsgList = {}
	print("\r\n\r\n");
end

--------------------Message Gateway Functions--------------------

--- Submits a forward message payload. Specify only the payload - message metadata can be configured in the TestConfiguration file.
-- @tparam table payload the payload field of the forward message
-- @tparam[opt=false] ?boolean raw nil regarded as false; if true, this specifies the message's RawPayload field.
-- @usage
-- -- Submit (SIN, MIN) = (16, 1) (getTerminalInfo) message to terminal
-- gateway.submitForwardMessage{SIN = 16, MIN = 1}
-- @within gateway
function gateway.submitForwardMessage(payload, raw)
	firstCallHouseKeeping()
	local msg = { DestinationID = cfg.MOBILE_ID, UserMessageID = lastForwardID+1}
	lastForwardID = lastForwardID + 1
	if raw then
		msg.RawPayload = payload
	else
		msg.Payload = payload
	end
	local msgs = { ["accessID"] = cfg.ACCESS_ID, ["password"] =  cfg.PASSWORD, ["messages"] = { msg } }
	local encoded = json.encode(msgs)
	local source = ltn12.source.string(encoded);
	local response = {}
	local sink = ltn12.sink.table(response)
	local headers = {
		["Content-Type"] = "application/json",
		["content-length"] = #encoded
	}
	local ok, code
	ok, code, headers = http.request {
		url = cfg.GATEWAY_URL .. cfg.GATEWAY_SUFFIX .. "/submit_messages.json/",
		proxy = cfg.HTTP_PROXY,
		method = "POST", headers = headers, source = source, sink = sink
	}
	if not raw then
		if tf.trace2 == doNothing then
			tf.trace1("Submitted: " .. oneLineDump(payload))
		else
			tf.trace2("Submitted: " .. tf.dump(tf.collapseMessage(payload)))
		end
	end

	-- retry submission if gateway temporarily unavailable.
	while code == 503 do
		print "Gateway temporarily unavailable; retry submission."
		tf.delay(2)
		ok, code, headers = http.request {
			url = cfg.GATEWAY_URL .. cfg.GATEWAY_SUFFIX .. "/submit_messages.json/",
			proxy = cfg.HTTP_PROXY,
			method = "POST", headers = headers, source = source, sink = sink
		}
	end

	if ok and code == 200 then
		local response1 = response[1];
		local decoded = json.decode(response1)
		local submitResult = decoded.SubmitForwardMessages_JResult
		if submitResult.ErrorID == 0 then
			local submissions = submitResult.Submissions
			local submission = submissions[1]
			if submission.ErrorID == 0 then
				return submission
			else
				error("Forward msg not submitted; Gateway Error ID: " .. tostring(submission.ErrorID) .. "; refer to N201.")
			end
		end
	end
	error("Forward message not submitted; HTTP error code : " .. tostring(code))
	return nil
end

--- Retrieves return messages from the gateway, and returns the first one that matches criteria specified by the checkFunction.<br /><br />
-- NOTE: Use tf.checkMessageType(sin, min) as the checkFunction to match return message by SIN and MIN only.
-- @tparam function checkFunction function to call to determine if criteria matches; should throw exception if criteria doesn't match
-- @tparam[opt=nil] ?AnyType checkParam callback function parameter; use table if >1 parameter needed
-- @tparam[opt=DEFAULT] ?number timeout parameter to control the timeout for this function
-- @treturn table the first message that matches criteria; nil otherwise
-- @usage
-- -- See TestSuiteExample* for more details...
-- gateway.getReturnMessage(<your own callback or tf.checkMessageType>)
-- @within gateway
function gateway.getReturnMessage(checkFunction, checkParam, timeout)
	assert(checkFunction, "checkFunction not provided to getReturnMessage")
	time1 = os.time()
	timeout = timeout and timeout or cfg.GATEWAY_TIMEOUT
	while(true) do
		local msgs = getReturnMessages()
		if msgs then
			for i, msg in ipairs(msgs) do
				colmsg = tf.collapseMessage(msg)
				colmsg.Payload = colmsg.Payload and colmsg.Payload or {}
				recordAndPrintMsg(colmsg)
				if checkFunction(msg, checkParam) then
					return msg
				end
			end
		end
		if os.time() - time1 >= timeout then
			checkFunction(nil, checkParam)
			break;
		end
		tf.delay(3)
	end
	return nil
end

--- Retrieves return messages from the gateway. Also records them for statistics records.
-- @tparam[opt=DEFAULT] ?number timeout number of seconds to wait before requesting messages from gateway; DEFAULT=cfg.GATEWAY_TIMEOUT
-- @treturn table array of messages retrieved from gateway
-- @within gateway
function gateway.getReturnMessages(timeout)
	timeout = timeout and timeout or cfg.GATEWAY_TIMEOUT
	tf.delay(timeout)
	local msgs = getReturnMessages()
	local retMsgs = {}
	for i,msg in ipairs(msgs) do
		msg = tf.collapseMessage(msg)
		local colmsg = tf.collapseMessage(msg)
		colmsg.Payload = colmsg.Payload and colmsg.Payload or {}
		recordAndPrintMsg(colmsg)
		retMsgs[#retMsgs+1] = msg
	end
	return retMsgs
end

--- Update the high water mark so that only newer messages are retrieved
-- @tparam[opt=os.time()] number _date date/time to which to update the high water mark (number of secs since epoch - os.time())
-- @within gateway
function gateway.setHighWaterMark(_date)
	local _time
	if _date then
		_time = _date
	else
		_time = os.time()
		if startUTC and os.difftime(_time, startUTC - timeOffset) < 1 then
			tf.delay(1)
			_time = os.time()
		end
	end
	startUTC = _time + timeOffset
end

--- Get Test Framework's high water mark.
-- @treturn number timestamp of current high water mark
-- @within gateway
function gateway.getHighWaterMark()
	return startUTC - timeOffset
end

--------------------------LSF Functions--------------------------

--- Set a service's property(s)
-- @tparam number sin SIN of affected service
-- @tparam table settings array of settings: <span style="font-family:monospace">{pin, value, valType}</span>
-- OR a single setting: <span style="font-family:monospace">{pin, value, valType}</span>
-- <br /><br />
-- NOTE: valType can take following values: "unsignedint", "signedint", "string", "boolean", "enum", "data".
-- <br />
-- valType is optional if it is unsignedint
-- @usage gateway.setProperties(20, {{17, true, "boolean"}, {15, 10}})
-- @usage gateway.setProperties(20, {15, 10, "unsignedint"})
-- @within lsf
function lsf.setProperties(sin, settings)
	if type(value) == "boolean" then
		value = value and "True" or "False"
	end
	local payload = {SIN=16, MIN=9, Fields={
	{Elements={
		{Fields={{Name="sin",Value=sin},{Name="propList", Elements=getSettingsTable(settings)}},Index=0}
		},
		Name="list"
	},
	{Name="save",Value="False"}
	}}
	local messageID = gateway.submitForwardMessage(payload)
end

-- send a shell command (string) to terminal
local function shellCommand(cmd)
	local rawPayload = {26, 1, 0, cmd:len()}
	for i=1,cmd:len() do
		rawPayload[i+4] = string.byte(cmd, i)
	end
	tf.trace2("submit shell command: " .. cmd)
	return gateway.submitForwardMessage(rawPayload, true)
end

--- Get property values for a given service
-- @number sin service identifier
-- @tparam table pinList array of PINs corresponding to properties being requested
-- @treturn array array of: {pin="x", value="y"}
-- @usage local props = lsf.getProperties(20, {1, 2})
-- @within lsf
function lsf.getProperties(sin, pinList)
	if type(pinList) ~= "table" then
		pinList = {pinList}
	end
	local b64str = tf.base64Encode(string.char(unpack(pinList)))
	local payload={SIN=16,MIN=8,Fields={{Elements={{Fields={{Name="sin",Value=sin},{Name="pinList",Value=b64str}},Index=0}},Name="list"}}}
	local msg = getTerminalResponse(payload, tf.checkMessageType(16, 5))
	if not msg then
		return nil
	end
	msg = tf.collapseMessage(msg)
	return msg.Payload.list[1].propList
end

--- Get SIN of enabled and disabled services on the terminal
-- @treturn table <span style="font-family:monospace">{sinList=&lt;array of installed SINs&gt;, disabledList=&lt;array of disabled SINs&gt;}</span>
-- @within lsf
function lsf.getSinList()
	local payload = {SIN=16, MIN=3}
	local msg = getTerminalResponse(payload, tf.checkMessageType(16, 3))
	if msg == nil then return nil end
	msg = tf.collapseMessage(msg)
	local sinList = msg.Payload.sinList
	local disabledList = msg.Payload.disabledList
	sinList = tf.base64Decode(sinList)
	disabledList = tf.base64Decode(disabledList)
	return {sinList = sinList, disabledList = disabledList}
end

--- Restart specified service
-- @number sin SIN of service being restarted
-- @within lsf
function lsf.restartService(sin)
	assertSinRange(sin)
	payload={Fields={{Name="sin",Value=sin}},MIN=5,SIN=16}
	gateway.submitForwardMessage(payload)
end

--params: sin - Service being affected
--        min - 10 (reset), or 11 (save), or 12 (revert)
local function systemPropertyCall(sin, min)
	assertSinRange(sin)
	local payload={SIN=16,MIN=min,Fields={{Elements={{Fields={{Name="sin",Value=sin}},Index=0}},Name="list"}}}
	gateway.submitForwardMessage(payload)
end

--- Reset all properties of a given service to their default values.
-- @number sin SIN of service whose properties are to be reset
-- @within lsf
function lsf.resetProperties(sin)
	systemPropertyCall(sin, 10)
end

--- Save all properties of a given service.
-- @number sin SIN of service whose properties are to be saved
-- @within lsf
function lsf.saveProperties(sin)
	systemPropertyCall(sin, 11)
end

--- Revert all properties of a given service to their last saved values.
-- @number sin SIN of service whose properties are to be reverted
-- @within lsf
function lsf.revertProperties(sin)
	systemPropertyCall(sin, 12)
end

--- Submits a getPosition request and responds with position report.<br /><br />
-- NOTE: Call this function with forceNewFix = true to ensure a new GPS fix is requested.
-- @tparam[opt=false] ?boolean forceNewFix indicates whether new fix is needed or if recent data will suffice
-- @treturn table position message containing lat/long/alt/speed etc.
-- @within lsf
function lsf.getPosition(forceNewFix)
	forceNewFix = forceNewFix and forceNewFix or false
	tf.delay(2)
	local age = forceNewFix and 1 or 30
	payload={SIN=20,MIN=1,Fields={{Name="fixType",Value="3D"},{Name="timeout",Value=cfg.GATEWAY_TIMEOUT},{Name="age",Value=age}}}
	gateway.submitForwardMessage(payload)
	return gateway.getReturnMessage(tf.checkMessageType(20,1))
end

--- Sends a shell command and responds with the result if needed
-- @string shellCmd shell command to execute
-- @tparam[opt=false] ?bool needResponse whether to wait for a response to the shell command
-- @return returns first shell response received if result needed; immediately returns true if result not requested; returns false if result requested but not received
-- @usage
-- -- this prints the output of "mem" command on the terminal; note: since the response contains "%" character, you cannot use tf.trace0 here.
-- print(lsf.shellCommand("mem", true))
-- @within lsf
function lsf.shellCommand(shellCmd, needResponse)
	needResponse = needResponse and needResponse or false
	gateway.setHighWaterMark()
	shellCommand(shellCmd)
	if not needResponse then
	  return true
	end
	local msg = gateway.getReturnMessage(checkShellResponse)
	if not msg then
		return nil
	end
	msg = tf.collapseMessage(msg)
	return msg and msg.Payload and msg.Payload.output
end

-------------------------Device Functions------------------------

local function configureDevice(device, typ, port, value)
	local source = ltn12.source.string(null);
	local response = {}
	local sink = ltn12.sink.table(response)
	local headers = {
		["Content-Type"] = "application/json",
		["Content-Length"] = 0
	}
	local url = cfg.DEVICE_URL .. "/" .. device .. "/" .. port .. "/" .. typ .. "/" .. value
	ok, code, headers = http.request {
		url = url,
		proxy = cfg.HTTP_PROXY,
		method = "POST", headers = headers, source = source, sink = sink
	}
	if ok and code == 200 then
		return true
	end
	error("Unable to configure device. HTTP error code: " .. tostring(code))
end

--- Write 0 or 1 to the external device port.
-- @tparam number port<br/>
-- 1, 2, 3, 4 - I/O port (value: digital [0, 1], analog [0, 3000])<br/>
-- 30 - Temperature (value: [-99, 85] degrees Celsius)<br/>
-- 31 - Power (value: [24000, 33000] millivolts)
-- @number value the value to write
-- @usage  -- switch on port 1 (line must be configured as digital input)
-- device.setIO(1, 1)
-- @within device
function device.setIO(port, value)
	if type(value) == "boolean" then
		value = value and "1" or "0"
	end
	tf.trace1("set device port %s value to %s", tostring(port), tostring(value))
	return configureDevice("GPIO", "value", cfg.PORTMAP[port], value)
end

-- For Raspberry Pi only: Configure external device port function.
-- port: range [1, 4] - IDP terminal port
-- func: "in" or "out"
function device.setPortFunction(port, func)
	assert(func == "in" or func == "out", "Function must be one of two string values: 'in' or 'out'")
	tf.trace1("set device port %d function to %s", port, func)
	return configureDevice("GPIO", "function", port, func)
end

--- Raise motion or shock event for accel service with axis and direction
-- @usage device.setAccel("motion", "X+")
-- @usage device.setAccel("shock", "Z-")
-- @within device
function device.setAccel(
			id, 				-- string: possible values: 'motion' or 'shock'
			value				-- string: possible values: 'X+', 'X-', 'Y+', 'Y-', 'Z+', 'Z-'
		)
	assert(id == "motion" or id == "shock", "setAccel id must be 'motion' or 'shock'")
	local possibleVals = {"X+", "X-", "Y+", "Y-", "Z+", "Z-"}
	value = value:upper()
	local found = false
	for _, v in pairs(possibleVals) do
		if v == value then
			found = true
			break
		end
	end
	if not found then
		error("setAccel accepts these values: " .. "'X+', 'X-', 'Y+', 'Y-', 'Z+', 'Z-'")
	end
	tf.trace1("set accel id %d value to %s", id, value)
	return configureDevice("accel", "value", id, value)	-- TODO: "value" is redundant; shouldn't need to pass
end

--- Configure power service parameters
-- @usage -- set battery voltage to 15V
-- device.setPower(3, 15000)
-- @tparam number id power service property (corresponds to PID of power service)<br/>
-- 3 - battery voltage (value: [0, 32000] millivolts)<br/>
-- 4 - battery temperature (value: [-90, 85] degrees Celsius)<br/>
-- 8 - external power present (value: [0, 1])<br/>
-- 9 - external power voltage (value: [0, 33000] millivolts)<br/>
-- 18 - pre-load voltage (value: [0, 32000] millivolts)<br/>
-- 19 - post-load voltage (value: [0, 32000] millivolts)
-- @number value the value to write
-- @within device
function device.setPower(id, value)
	-- TODO: error checking.
	return configureDevice("power", "value", id, value)	-- TODO: "value" is redundant; shouldn't need to pass
end

--- Get external device IO port value.
-- @tparam number port<br/>
-- 1, 2, 3, 4 - I/O port (return value: digital [0, 1], analog millivolts [0, 3000])<br/>
-- 30 - Temperature (return value: [-99, 85] degrees Celsius)<br/>
-- 31 - Power (return value: [24000, 33000] millivolts)
-- @treturn number I/O port value
-- @usage local port1value = device.getIO(1)
-- @usage local temp = device.getIO(30)
-- @usage local power = device.getIO(31)
-- @within device
function device.getIO(port)
	return webServiceGet(cfg.DEVICE_URL .. "/GPIO/" .. cfg.PORTMAP[port] .. "/value")
end

--- Get accelerometer state.
-- @string id "motion" or "shock"
-- @treturn number 0 if disarmed, 1 if armed.
-- @usage local armed = device.getAccel("shock")
-- @within device
function device.getAccel(id)
	return webServiceGet(cfg.DEVICE_URL .. "/accel/" .. id .. "/value")
end

--- Get external device port value.
-- @number id power service property (corresponds to PID of power service)<br/>
-- 3 - battery voltage (return value: [0, 32000] millivolts)<br/>
-- 4 - battery temperature (return value: [-90, 85] degrees Celsius)[<br/>
-- 8 - external power present (return value: [0, 1])<br/>
-- 9 - external power voltage (return value: [0, 33000] millivolts)<br/>
-- 18 - pre-load voltage (return value: [0, 32000] millivolts)<br/>
-- 19 - post-load voltage (return value: [0, 32000] millivolts)
-- @treturn number
-- @usage local batteryTemp = device.getPower(4)
-- @within device
function device.getPower(id)
	return webServiceGet(cfg.DEVICE_URL .. "/power/" .. id .. "/value")
end

---------------------GPS Simulator Functions---------------------

local function gpsGetResource(resource, params)
	return webServiceGetResource(cfg.GPS_URL, resource, params, false)
end

-- set GPS simulator fix type
-- fixType valid values: (0, 1, 2, 3) = (no time, no fix, 2d fix, 3d fix)
local function gpsSetFixType(fixType)
	assert(fixType >= 0 and fixType <= 3, "ERROR - gpsSetFixType: fix type should be between 0 and 3.")
	local retval, code = gpsGetResource("set_fix_type", {fix_type = fixType})
	if not retval and code then print("GPS Server responded with code " .. tostring(code)) end
end

-- set location on the GPS simulator
local function gpsSetLocation(
			latitude, 		-- number: valid range [-90.0, 90.0]
			longitude, 		-- number: valid range [-180.0, 180.0]
			altitude		-- ?number: meters above sea level TODO: must be integer?
		)
	assert(type(latitude) == "number", "ERROR - " .. debug.getinfo(1, "n").name .. ": latitude should be a number")
	assert(type(longitude) == "number", "ERROR - " .. debug.getinfo(1, "n").name .. ": longitude should be a number")
	assert(altitude == nil or type(altitude) == "number", "ERROR - " .. debug.getinfo(1, "n").name .. ": altitude should be a number")
	altitude=altitude and altitude or 0
	local retval, code = gpsGetResource("set_location", {
		latitude = latitude,
		longitude = longitude,
		altitude = altitude
	})
	if not retval and code then print("GPS Server responded with code " .. tostring(code)) end
end

-- set speed and heading on the GPS simulator
local function gpsSetSpeedHeading(
			speed,			-- number: speed GPS speed in km/h
			heading,		-- integer: heading in degrees valid range [0 - 360]
			linearMotion	-- ?bool: whether to update the lat/long values according to the movement and heading
		)
	if linearMotion == nil then
		linearMotion = true
	end
	assert(type(speed) == "number", "ERROR - " .. debug.getinfo(1, "n").name .. ": speed should be a number")
	assert(type(heading) == "number", "ERROR - " .. debug.getinfo(1, "n").name .. ": heading should be a number")
	assert(type(linearMotion) == "boolean", "ERROR - " .. debug.getinfo(1, "n").name .. ": linearMotion should be true or false")
	local retval, code = gpsGetResource("set_speed_heading", {
		speed = speed,
		heading = heading,
		simulate_linear_motion = linearMotion
	})
	if not retval and code then print("GPS Server responded with code " .. tostring(code)) end
end

-- set jamming detection on the GPS simulator
local function gpsSetJamming(jammingStatus, jammingLevel, jammingDetect, antennaCutDetect)
	local retval, code = gpsGetResource("set_jamming", {
		jammingStatus = jammingStatus,
		jammingLevel = jammingLevel,
		jammingDetect = tostring(jammingDetect),
		antennaCutDetect = tostring(antennaCutDetect)
	})
	if not retval and code then print("GPS Server responded with code " .. tostring(code)) end
end

-- set satellite blockage status on the GPS simulator
local function gpsSetBlockage(blocked)
	local retval, code = gpsGetResource("set_blockage", { blocked = blocked } );
	if not retval and code then print("GPS Server responded with code " .. tostring(code)) end
end

local gpsValues = {
	latitude = 0,
	longitude = 0,
	altitude = 0,
	speed = 0,
	heading = 0,
	simulateLinearMotion = false,
	fixType = 3,
	jammingStatus = 1,
	jammingLevel = 0,
	jammingDetect = false,
	antennaCutDetect = false,
	blockage = false
}

local gpsKeys = {
	latitude = gpsSetLocation,
	longitude = gpsSetLocation,
	altitude = gpsSetLocation,
	speed = gpsSetSpeedHeading,
	heading = gpsSetSpeedHeading,
	simulateLinearMotion = gpsSetSpeedHeading,
	fixType = gpsSetFixType,
	jammingStatus = gpsSetJamming,
	jammingLevel = gpsSetJamming,
	jammingDetect = gpsSetJamming,
	antennaCutDetect = gpsSetJamming,
	blockage = gpsSetBlockage
}

--- set one ore more of: {fixType, latitude, longitude, altitude, speed, heading, and simulateLinearMotion} on the GPS simulator
-- <b>Allowed values:</b>
-- <ul>
-- <li>fixType: (0, 1, [2|3]) = (no time, no fix, valid fix) </li>
-- <li>latitude: decimal degrees [-90.0, 90.0] </li>
-- <li>longitude: decimal degrees [-180.0, 180.0]</li>
-- <li>altitude: meters above sea level [-10000, 200000]</li>
-- <li>speed: decimal km/h [0.0, 200.0]</li>
-- <li>heading: integer degrees [0, 360]</li>
-- <li>simulateLinearMotion: (true, false) - enable latitude/longitude to update based on speed/heading</li>
-- <li>jammingStatus: (0, 1, 2, 3) = (unknown, OK, warning, critical)</li>
-- <li>jammingLevel: integer [0, 255]</li>
-- <li>jammingDetect: (true, false) - true if GPS signal jamming is detected</li>
-- <li>antennaCutDetect: (true, false) - true if external antenna is not connected</li>
-- <li>blockage: (true, false) - true if simulating loss of satellite communications</li>
-- </ul>
-- @param parameters a table of GPS settings
-- @usage
-- -- This sets the speed to 50km/h, heading to East, and enables updates to position based on speed and heading
-- gps.set({speed=50, heading=90, simulateLinearMotion=true})
-- @within gps
function gps.set(parameters)
	local callFunction = {}
	for k1, v1 in pairs(parameters) do
		local found = false
		for k2, v2 in pairs(gpsKeys) do
			if k1 == k2 then
				callFunction[v2] = true
				gpsValues[k1] = v1
				found = true
				break
			end
		end
		if not found then
			tf.trace0("*** Unknown parameter passed to gps.set(): %s. Accepted parameters:", k1)
			for k, v in pairs(gpsKeys) do
				tf.trace0(k)
			end
		end
	end
	for k, _ in pairs(callFunction) do
		if k == gpsSetFixType then
			k(gpsValues.fixType)
		elseif k == gpsSetLocation then
			k(gpsValues.latitude, gpsValues.longitude, gpsValues.altitude)
		elseif k == gpsSetSpeedHeading then
			k(gpsValues.speed, gpsValues.heading, gpsValues.simulateLinearMotion)
		elseif k == gpsSetJamming then
			k(gpsValues.jammingStatus, gpsValues.jammingLevel, gpsValues.jammingDetect, gpsValues.antennaCutDetect)
		elseif k == gpsSetBlockage then
			k(gpsValues.blockage)
		end
	end
end

print("Test Framework v" .. tf.version)
if debugLevel == 2 then
	tf.trace1 = printfLineDate
	tf.trace2 = printfLineDate
	print("tf.trace1 ON, tf.trace2 ON")
elseif debugLevel == 1 then
	tf.trace1 = printfLineDate
	tf.trace2 = doNothing
	print("tf.trace1 ON, tf.trace2 OFF")
else
	tf.trace1 = doNothing
	tf.trace2 = doNothing
	print("tf.trace1 OFF, tf.trace2 OFF")
end
tf.trace0 = printfLineDate

return function() return cfg, tf, gateway, lsf, device, gps end