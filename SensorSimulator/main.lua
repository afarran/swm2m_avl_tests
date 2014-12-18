--
-- Service: NewService
-- Created: 2014-12-11
--

module(..., package.seeall)

--
-- Version information (required)
--
_VERSION = "1.0.0"
local stimer = nil
local timeChanges = {}
local msgHandler = nil
local startTime = nil
--
-- Run service (required)
--
function entry()

  local qtimer = sched.createEventQ(5, '_TIMER', stimer)
  local messageQueue = sched.createEventQ(5, msgHandler)
  
  startTime = 0
    
  while true do
  
      stimer:arm(10)
      
      local result = { sched.waitQ(-1, qtimer, messageQueue) }
      
      if result[1] == messageQueue then
        processMessageQueue(result)
      elseif result[1] == qtimer then
        processTimeChange()    
      end
         
  end
  

end

function processMessageQueue(result)
    
    local min = result[3].min
    local eventName = result[2]
    
    -- load time changes
    if eventName == 'RX_DECODED' and min == 1 then
      startTime = os.time()
      timeChanges = result[3].fields.TimeChanges
      logvar(timeChanges)
    end
    
    -- restart start time
    if eventName == 'RX_DECODED' and min == 2 then
      startTime = os.time()
    end
    
end

function processTimeChange()
    
    
    local currentTimePoint
    local secondsFromStart = os.time() - startTime
    
    for i, timePoint in ipairs(timeChanges) do
      
      if timePoint.time <= secondsFromStart then 
        currentTimePoint = timePoint
      end
    end
    
    if currentTimePoint then
      properties.currentValue = currentTimePoint.value
    end
    
    logvar(properties.currentValue)
    
  
end

function logvar(value)
  if properties.printLog then
    dumpvar(value)
  end

end

--
-- Initialize service (required)
--
function init()
  stimer = sys.timer.create()
  msgHandler = svc.message.register(_SIN)
end

function setTimeChanges(inputTimeChanges)
  timeChanges = inputTimeChanges
end

function clearTimeChanges()
  timeChanges = {}
end