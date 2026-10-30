Driver = class('Driver')


function Driver:initialize(driverIndex, driverName, carName, driverCountry) -- constructor
    self.index = driverIndex
    self.car = ac.getCar(driverIndex)
    self.name = driverName
    self.carName = carName
    self.country = driverCountry
    self.racePosition = 0
    self.prevRacePosition = 0
    self.carDistance = 0
    self.speedMS = 0
    self.totalSplineLength = 0
    self.currentLap = 0
    self.gapToDriverInFront = 0
    self.gapToLeader = 0;
    self.isHidden = false;
    self.sectorTimes = {}
    self.fastestLap = -1
    self.prevFastestLap = -1

    --- MINI SECTORS / SPLITS
    self.splits = { -1 }
    self.currentSplit = 0
    self.fastestSplits = {}
    self.normFastestSplits = {}
    self.currentSplitGap = 0
    self.currentSplitLarger = true

    --- SECTORS
    self.currentSectorIndex = 1
    self.sectorTimeGap = -1
    self.prevFastestSectors = {}
    self.fastestSectors = {}
    self.currentSectors = {}
    self.previousSectors = {}


    self.laps = {}
    self.leaderboardDrawPos = vec2(0, 0)
    self.isInPitLane = self.car.isInPitlane;
    self.isRetired = false

    for _ = 1, #SIM.lapSplits, 1 do
        table.insert(self.fastestSectors, 9999999)
        table.insert(self.previousSectors, 9999999)
    end

    for i = 1, NSPLITS, 1 do
        self.splits[i - 1] = -1
    end

    local newLapInfo = LapInfo(1)
    if not self.car.isInPit then
        newLapInfo:updateValidity(false)
    end
    table.insert(self.laps, newLapInfo)

    -- RADAR Stuff
    self.currentWorldPosition = vec3(0, 0, 0)
    self.wheelFLContact = vec3(0, 0, 0)
    self.wheelFRContact = vec3(0, 0, 0)
    self.nearbyCars = {}

    if SIM.raceSessionType == 4 then
        self.currentLap = 0
    else
        self.currentLap = 1
    end


    -- MP Fallback Stuff

    self.splinePosition = 0
    self.lapTime = 0
    self.prevLapTime = 0

    -- Topspeed Stuff
    local carJson = ac.getFolder(ac.FolderID.ContentCars) .. '//' .. ac.getCarID(driverIndex) .. '//ui/ui_car.json'
    self.topSpeed = 320

    if io.fileExists(carJson) then
        local file = io.open(carJson)
        local fileContents = file:read('a')
        local topSpeedFull = fileContents:match('"topspeed":%s+"([^"]+)"')
        if topSpeedFull then
            local topSpeed = tonumber(topSpeedFull:match("(%d+)"))
            if topSpeed then
                local has_plus = topSpeedFull:match("^%+")
                if has_plus then topSpeed = topSpeed * 1.1 end
                topSpeed = math.ceil(topSpeed / 20) * 20
                self.topSpeed = topSpeed
            end
        end
    end


    -- BOOST Stuff
    local engineIni = ac.INIConfig.carData(driverIndex, "engine.ini") --loads car engine.ini data.
    local t0MaxBoost = engineIni:get('TURBO_0', 'MAX_BOOST', 0)
    local t1MaxBoost = engineIni:get('TURBO_1', 'MAX_BOOST', 0)
    local t2MaxBoost = engineIni:get('TURBO_2', 'MAX_BOOST', 0)
    local t3MaxBoost = engineIni:get('TURBO_3', 'MAX_BOOST', 0)
    local t4MaxBoost = engineIni:get('TURBO_4', 'MAX_BOOST', 0)
    local t5MaxBoost = engineIni:get('TURBO_5', 'MAX_BOOST', 0)
    local t6MaxBoost = engineIni:get('TURBO_6', 'MAX_BOOST', 0)
    local t7MaxBoost = engineIni:get('TURBO_7', 'MAX_BOOST', 0)
    self.carMaxEngineBoost = math.ceil(t0MaxBoost + t1MaxBoost + t2MaxBoost + t3MaxBoost + t4MaxBoost + t5MaxBoost +
        t6MaxBoost + t7MaxBoost)
end

function Driver:updateLeaderboardDrawPos(x, y)
    self.leaderboardDrawPos = vec2(x, y)
end

function Driver:updatePitLaneStatus()
    self.isInPitLane = self.car.isInPitlane
    -- FOR debug
    -- self.isInPitLane = true
end

function Driver:updateRadar()
    local car = self.car
    self.currentWorldPosition = car.position:clone()
    self.wheelFLContact = car.wheels[0].contactPoint:clone()
    self.wheelFRContact = car.wheels[1].contactPoint:clone()
    self.playerDistance = 0

    if self.index == SIM.focusedCar then
        local newList = {}

        table.forEach(DRIVERS, function(driver)
            if self == driver then
                return
            end

            local otherDriver = driver
            local otherCar = driver.car
            local distance = self.currentWorldPosition:distance(otherDriver.currentWorldPosition)

            local myVector = (self.wheelFLContact + self.wheelFRContact) / 2 - self.wheelFRContact
            local other = (self.wheelFLContact + self.wheelFRContact) / 2 - otherDriver.currentWorldPosition

            local rad = math.acos(((myVector.x * other.x) + (myVector.y * other.y) + (myVector.z * other.z)) /
                ((myVector.x ^ 2 + myVector.y ^ 2 + myVector.z ^ 2) ^ 0.5 *
                    (other.x ^ 2 + other.y ^ 2 + other.z ^ 2) ^ 0.5))

            local isToLeft = math.deg(rad) > 95
            local isToRight = math.deg(rad) < 85

            table.insert(newList, BlindspotDriver(distance, isToLeft, isToRight, otherCar.splinePosition))
        end)
        self.nearbyCars = newList
    end
end

SORTEDDRIVERS = nil

function Driver:updateSplits()
    local car = self.car
    self.racePosition = car.racePosition


    if SIM.raceSessionType == ac.SessionType.Race then
        if SORTEDDRIVERS == nil or self.racePosition ~= self.prevRacePosition then
            SORTEDDRIVERS = raceSortedDrivers(DRIVERS)
        end
    elseif SIM.raceSessionType ~= ac.SessionType.Race then
        if SORTEDDRIVERS == nil or self.racePosition ~= self.prevRacePosition or self.prevLapTime ~= self.lapTime then
            SORTEDDRIVERS = qualySortedDrivers(DRIVERS)
        end
    end

    self.prevRacePosition = self.racePosition
    self.isRetired = self.car.isRetired


    local newSplit = math.floor(car.splinePosition / (1 / NSPLITS))
    local leadingDriver = SORTEDDRIVERS[1]
    if self.racePosition == 1 or self.index == SIM.focusedCar or self.racePosition == MY_DRIVER.racePosition + 1 or self.racePosition == MY_DRIVER.racePosition + 2 or self.racePosition == MY_DRIVER.racePosition - 1 or self.racePosition == MY_DRIVER.racePosition - 2 or self.lapTime ~= self.prevLapTime then
        self.sectorTimes = car.currentSplits
        local newSpline = #self.laps + 1 + car.splinePosition
        if newSpline > self.totalSplineLength then
            self.totalSplineLength = newSpline
        end


        if car.speedKmh < 5 then
            if self.racePosition ~= 1 then
                local driverInFront = SORTEDDRIVERS[self.racePosition - 1]
                local sortedSplitsLeader = sortedDriverSplits(leadingDriver)
                local sortedSplitsInFront = sortedDriverSplits(driverInFront)
                local driverInFrontLastSplit = sortedSplitsInFront[1]
                local driverInFrontMySplit = driverInFront.splits[newSplit]
                local leaderLastSplit = sortedSplitsLeader[1]
                local leaderMySplit = leadingDriver.splits[newSplit]


                if driverInFrontLastSplit ~= nil and driverInFrontMySplit ~= nil then
                    self.gapToDriverInFront = gapBetweenTimes(driverInFrontLastSplit, driverInFrontMySplit)
                end

                if leaderLastSplit ~= nil and leaderMySplit ~= nil then
                    self.gapToLeader = gapBetweenTimes(leaderLastSplit, leaderMySplit)
                end
            end
            self.currentSplitGap = self.fastestLap - CAR.estimatedLapTimeMs
            self.currentSplitLarger = true
        elseif self.currentSplit ~= newSplit then
            self.currentSplit = newSplit
            self.splits[self.currentSplit] = SIM.time
            if SIM.raceSessionType == ac.SessionType.Race then                
                if self.racePosition ~= 1 then
                    local driverInFront = SORTEDDRIVERS[self.racePosition - 1]
                    self.gapToDriverInFront = getGapBetweenDrivers(self, driverInFront)
                    self.gapToLeader = getGapBetweenDrivers(self, leadingDriver)                  
                end
            else
                local myQualiIndex = table.indexOf(SORTEDDRIVERS, self)
                if (myQualiIndex ~= 1) then                    
                    local driverInFront = SORTEDDRIVERS[myQualiIndex-1]
                    self.gapToDriverInFront = getGapBetweenDrivers(self, driverInFront)
                    self.gapToLeader = getGapBetweenDrivers(self, leadingDriver)    
                end
            end

            local currentNormSplits = normalizeSplits(self.splits)
            local cur = currentNormSplits[self.currentSplit]
            local fastest = self.normFastestSplits[self.currentSplit]

            if cur ~= nil and fastest ~= nil then
                local curGapToPrev = cur - (currentNormSplits[self.currentSplit - 1] or cur)
                local fastestGapToPrev = fastest - (self.normFastestSplits[self.currentSplit - 1] or fastest)
                self.currentSplitGap = cur - fastest
                self.currentSplitLarger = (curGapToPrev - fastestGapToPrev) < 0
            end
        end
        if leadingDriver.currentLap > 1 and self.racePosition ~= 1 then
            if self.totalSplineLength <= leadingDriver.totalSplineLength - 1 then
                local gapInLaps = math.floor(leadingDriver.totalSplineLength - self.totalSplineLength)

                if gapInLaps > 1 then
                    self.gapToLeader = gapInLaps .. ' LAPS'
                else
                    self.gapToLeader = gapInLaps .. ' LAP'
                end
            end
            local driverInFront = SORTEDDRIVERS[self.racePosition - 1]

            if self.totalSplineLength <= driverInFront.totalSplineLength - 1 then
                local gapInLaps = math.floor(driverInFront.totalSplineLength - self.totalSplineLength)


                if gapInLaps > 1 then
                    self.gapToDriverInFront = gapInLaps .. ' LAPS'
                else
                    self.gapToDriverInFront = gapInLaps .. ' LAP'
                end
            end
        end

        if #self.splits == 0 and newSplit ~= 0 then
            self.gapToDriverInFront = '--.--'
            self.gapToLeader = '--.--'
        end
    end
end

function Driver:updateSectors()
    local car = self.car
    self.speedMS = math.round(car.speedKmh, 1)
    self.carDistance = car.distanceDrivenTotalKm
    self.name = ac.getDriverName(self.index)
    self.country = ac.getDriverNationCode(self.index)

    local newSectorIndex = self.car.currentSector + 1
    if newSectorIndex - 1 == #SIM.lapSplits then
        newSectorIndex = 0
    end
    if newSectorIndex ~= self.currentSectorIndex then
        local fastestLapSectorTime = self.fastestSectors[self.currentSectorIndex]
        local newSectorTime = self.car.previousSectorTime

        -- stupid hack because last sector is always 0
        if newSectorTime == 0 and #self.laps > 1 then
            newSectorTime = self.laps[#self.laps - 1].lapTime
            for i = 1, #self.previousSectors - 1, 1 do
                newSectorTime = newSectorTime - self.previousSectors[i]
            end
        end

        if not fastestLapSectorTime then
            return
        end

        if newSectorTime < fastestLapSectorTime then
            self.prevFastestSectors[self.currentSectorIndex] = self.fastestSectors[self.currentSectorIndex]
            self.fastestSectors[self.currentSectorIndex] = newSectorTime
        end


        if newSectorIndex ~= 1 then
            self.sectorTimeGap = newSectorTime - fastestLapSectorTime
        end


        self.previousSectors[self.currentSectorIndex] = newSectorTime
        self.currentSectorIndex = newSectorIndex
    end
end

function Driver:updateLaps()
    local car = self.car
    local currentLap = 0
    if not SIM.isSessionStarted then
        if SIM.raceSessionType == 4 then
            self.currentLap = 0
        else
            self.currentLap = 1
        end
        self.prevLapTime = 0
        return
    else
        currentLap = self.currentLap
    end


    local adjLaptime = car.lapTimeMs
    if self.currentLap == 0 and car.isRemote then
        adjLaptime = car.lapTimeMs - BASE_SESSION_TIME
    end


    if adjLaptime < 300 and adjLaptime < self.prevLapTime and self.splinePosition > 0 and
        car.speedKmh > 2 then
        currentLap = self.currentLap + 1
    else
        self.lapTime = adjLaptime
    end

    self.prevLapTime = adjLaptime

    if self.fastestLap ~= fastestLapForDriver(self) then
        self.prevFastestLap = self.fastestLap
        if SIM.raceSessionType ~= ac.SessionType.Race then
            if SORTEDDRIVERS == nil or self.fastestLap ~= self.prevFastestLap then
                SORTEDDRIVERS = qualySortedDrivers(DRIVERS)
            end
        end
        self.fastestLap = fastestLapForDriver(self)



        self.normFastestSplits = normalizeSplits(table.clone(self.splits))
    end
    if currentLap ~= self.currentLap and self.currentLap ~= 0 and SIM.isSessionStarted then
        local lap = table.findByProperty(self.laps, 'lap', self.currentLap)
        if lap then
            local lapIndex = table.indexOf(self.laps, lap)

            local lapTime = self.lapTime
            self.laps[lapIndex]:updateLapTime(lapTime, car.isInPitlane)
            local lastValid = car.isLastLapValid
            if not lastValid then
                self.laps[lapIndex]:updateValidity(lastValid)
            end


            if self.currentSectorIndex == #SIM.lapSplits and #self.laps > 1 then
                if fastestDriverInSession() then
                    self.sectorTimeGap = lapTime - fastestDriverInSession().fastestLap
                else
                    self.sectorTimeGap = 0
                end
            end
        else
            ------
        end

        if tonumber(MPTotalLaps) == 0 or self.currentLap + 1 <= tonumber(MPTotalLaps) then
            local newLapInfo = LapInfo(self.currentLap + 1)
            table.insert(self.laps, newLapInfo)
        end
    end

    if adjLaptime > 50 and adjLaptime < 150 and self.currentLap ~= 1 then
        local lap = table.findByProperty(self.laps, 'lap', self.currentLap - 1)
        if lap then
            local lapIndex = table.indexOf(self.laps, lap)
            local lastValid = self.car.isLastLapValid
            if not lastValid then
                self.laps[lapIndex]:updateValidity(lastValid)
            end
        end
    end


    self.currentLap = currentLap
    self.splinePosition = car.splinePosition
end
