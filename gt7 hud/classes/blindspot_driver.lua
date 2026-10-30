BlindspotDriver = class('BlindspotDriver')


function BlindspotDriver:initialize(distance, isLeft, isRight, splinePosition) --constructor
    self.distance = distance
    self.isLeft = isLeft
    self.isRight = isRight
    self.splinePosition = splinePosition
end

function BlindspotDriver:update(distance, isLeft, isRight, splinePosition)
    self.distance = distance
    self.isLeft = isLeft
    self.isRight = isRight
    self.splinePosition = splinePosition
end
