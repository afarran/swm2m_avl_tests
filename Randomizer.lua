RANDOM_TEST_CHOOSE = not FORCE_ALL_TESTCASES

-- Test Cases Randomizer
local Randomizer = {}
  Randomizer.__index = Randomizer
  setmetatable(Randomizer, {
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

  function Randomizer:_init()
    --print("initing randomizer ...")
  end
  
  function Randomizer:chooseTest(title, tests, psetup, pteardown)
    if RANDOM_TEST_CHOOSE == true then
      if title == "Port" then
        --print("Choosing port..")
        testCase = Randomizer:getRandomPort()
      elseif title == "SM" then
        --print("Choosing SM..")
        testCase = Randomizer:getRandomSm()
      end
      tests[title..testCase]()
    else
      for i, tc in pairs(tests) do
        --print(i.." choosen.")
        psetup()
        tc()
        pteardown()
      end
    end
  end
  
  function Randomizer:getRandomPort()
    if profile:hasFourIOs() then
      testCase = lunatest.random_int (1, 4)
    else
      testCase = lunatest.random_int (1, 3)
    end
    return testCase
  end
  
  function Randomizer:getRandomSm()
    testCase = lunatest.random_int (1, 4)
    return testCase
  end
  
  function Randomizer:runTestRandomParam(min, max, ptest, psetup, pteardown, ...)
    if FORCE_ALL_TESTCASES then
      for i= min, max do
        ptest(i, ...)
        if (i < max) then
          pteardown()
          psetup()
        end
      end
      pteardown()
    else
      return ptest(math.random(min, max), ...)
    end
  end
  
return Randomizer
