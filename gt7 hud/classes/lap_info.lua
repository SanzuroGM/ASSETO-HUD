LapInfo = class('LapInfo')
local function getSlowestLap(laps)
    local sorted = table.clone(laps)
    sorted = table.filter(sorted, function(lap1)
        return lap1.lapTime ~= -1 and lap1.lap ~= 1
    end)
    table.sort(sorted, function(lap1, lap2)
        return lap1.lapTime > lap2.lapTime
    end)
    return sorted[1]
end

---@param lapInfo LapInfo
function getColorBasedOnTime(lapInfo)
    if lapInfo.lapTime == -1 then
        return rgbm(0, 0, 0, 0.7)
    end

    -- color lap RED and add letter "P" when was in Pitlane that lap
    -- color lap RED when slowest personal laptime
    if lapInfo.inPits == true or lapInfo.isValid == false then
        return rgbm(1, 0, 0, 0.7)
    end

    -- color lap PURPLE when overall best laptime
    local fastestLapOverall = fastestDriverInSession()
    if fastestLapOverall and (lapInfo.lapTime <= fastestLapOverall.fastestLap) then
        return rgbm(0.58, 0.23, 0.75, 0.7)
    end

    -- color lap BLUE when personal best laptime
    local myFastestLap = MY_DRIVER.fastestLap
    if lapInfo.lapTime == myFastestLap then
        return rgbm(0, 0.38, 0.82, 0.7)
    end


    return rgbm(0, 0, 0, 0.7)
end

function LapInfo:initialize(lap) -- constructor
    self.lap = lap
    self.lapTime = -1
    self.inPits = false
    self.isValid = true
end

function LapInfo:updateLapTime(lapTime, isInPit)
    self.lapTime = lapTime
    self.inPits = isInPit
end

function LapInfo:updateValidity(isValid)
    self.isValid = isValid
end
