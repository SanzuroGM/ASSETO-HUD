-------------------------------- Main Methods --------------------------------
function getGapBetweenDrivers(driver, driverAhead)
    local sim = ac.getSim()
    local driverAheadSplit = driverAhead.splits[driver.currentSplit]
    if driverAheadSplit == nil then
        driverAheadSplit = 0;
    end
    if driverAheadSplit == -1 or driverAheadSplit == 0 then
        return 0
    end
    if (sim.time - driverAheadSplit) / 1000 > 99 then
        return '99.999'
    end
    return string.format('%03.3f', (sim.time - driverAheadSplit) / 1000)
end

function gapBetweenTimes(time1, time2)
    if time2 == -1 or time2 == 0 then
        return 0
    end
    if (time1 - time2) / 1000 > 99 then
        return '99.999'
    end
    return string.format('%03.3f', (time1 - time2) / 1000)
end

function isValidFastestLap(time)
    if time <= 0 or time == -1 then
        return false
    else
        return true
    end
end

function isLastLap()
    return (#MY_DRIVER.laps) == tonumber(MPTotalLaps)
end

function lapTimeToString(time)
    if time == nil or time == -1 then
        return "-:--.---"
    end
    return string.format("%01d:%02d.%03d", math.floor(time / 60000), math.floor((time % 60000) / 1000), time % 1000)
end

function secondsTimeToString(time)
    if time == nil or time == -1 then
        return "-:--.--"
    end
    return string.format("%01d:%02d.%03d", math.floor(time % 3600000) / 60000,
        math.floor((time % 60000) / 1000), time % 1000)
end

function timeToString(time)
    if time == nil or time == -1 then
        return "-:--.--"
    end
    return string.format("%01d:%02d:%02d", math.floor(time / 3600000), math.floor(time % 3600000) / 60000,
        math.floor((time % 60000) / 1000))
end

function gapToString(time)
    if time == nil or time == -1 then
        return "-.---"
    end
    if time < 0 then
        prefix = '-'
    else
        prefix = '+'
    end
    time = math.abs(time)
    return prefix .. string.format(" %01d.%03d", math.floor((time % 60000) / 1000), time % 1000)
end

function fastestDriverInSession()
    local sorted = table.clone(DRIVERS)
    sorted = table.filter(sorted, function(dr)
        return dr.fastestLap ~= -1
    end)
    table.sort(sorted, function(driver1, driver2)
        return driver1.fastestLap < driver2.fastestLap
    end)
    return sorted[1]
end

function normalizeSplits(splits)
    local newTable = {}

    local baseValue = splits[1]
    table.forEach(splits, function(item, key, callbackData)
        if key == 0 or key == 1 then
            table.insert(newTable, 0)
        else
            table.insert(newTable, item - baseValue)
        end
    end)
    return newTable
end

function combo(index, mfdOptions, previewCallback, contentCallback, deleteCallback, addCallback)
    ui.alignTextToFramePadding()
    local current = INI.mfdModules[index] or '---'
    ui.text(index .. ':')
    ui.sameLine(68, 0)
    local id = current
    ui.setNextItemWidth(ui.availableSpaceX() - 50)
    ui.combo('##r' .. id, previewCallback(index), ui.ComboFlags.None, contentCallback)
    ui.sameLine(0, 0)
    ui.moveCursor(10, 0)
    if #INI.mfdModules > 1 then
        if ui.iconButton(ui.Icons.Delete, vec2(20, 20)) then
            deleteCallback(index)
        end
    end
    if index == #INI.mfdModules and index < #mfdOptions - 1 then
        ui.newLine(5)
        if ui.button('+ Add MFD Page') then
            addCallback(index)
        end
    end
    ui.newLine(5)
end

function fastestLapForDriver(driver)
    local filtered = table.filter(driver.laps, function(item, index, callbackData)
        return item.lapTime ~= -1 and item.isValid
    end)
    if #filtered == 0 then
        return -1
    end
    table.sort(filtered, function(a, b)
        return a.lapTime < b.lapTime
    end)

    return filtered[1].lapTime
end

-------------------------------- UI Methods --------------------------------
function scale(value)
    return LBS * value
end

log = ac.debug

function scaledVec2(valueX, valueY)
    return vec2(LBS * valueX, LBS * valueY)
end

-------------------------------- Debugging Methods --------------------------------
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '"' .. k .. '" : ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function getAngle(deg)
    return (deg / 360 * 2 * math.pi) - math.pi / 2
end

function inSine(t, b, c, d)
    return -c * math.cos(t / d * (math.pi / 2)) + c + b
end

function outSine(t, b, c, d)
    return c * math.sin(t / d * (math.pi / 2)) + b
end

function outInSine(t, b, c, d)
    if t < d / 2 then
        return outSine(t * 2, b, c / 2, d)
    else
        return inSine((t * 2) - d, b + c / 2, c / 2, d)
    end
end

function scaleDamageValue(dmg)
    if dmg < 0.5 and dmg > 0.1 then
        return dmg + (1 - dmg) / 2
    else
        return dmg
    end
end

-- Yokai utilities

-- Shifts cursor from current position
ui.moveCursor = function(x, y)
    ui.setCursorX(ui.getCursorX() + x)
    ui.setCursorY(ui.getCursorY() + y)
end

-- modified: draws at cursor position, without moving cursor
ui.image_cursor = function(file, size, color, thing)
    local cursor = ui.getCursor()
    ui.image(file, size, color, thing)
    ui.setCursor(cursor)
end

-- draws at cursor position
ui.drawCircleFilled_cursor = function(size, color, edges)
    ui.drawCircleFilled(
        vec2(ui.getCursorX() + size, ui.getCursorY() + size),
        size, color, edges
    )
end

-- draws at cursor position
ui.drawRectFilled_cursor = function(w, h, color, rounding, roundingFlags)
    ui.drawRectFilled(
        vec2(ui.getCursorX(), ui.getCursorY()),
        vec2(w, h),
        color, rounding, roundingFlags
    )
end

-- Thin border for position testing
ui.drawBorder = function(x, y, w, h)
    local border_size = 1
    ui.drawRect(
        vec2(0, 0), vec2(w, h),
        rgbm.colors.yellow, 1, ui.CornerFlags.All, border_size
    )
end

-- (aka range) converts an input between x1 and x2, to an output between y1 and y2
function interpolate(x1, x2, input, y1, y2)
    input = math.clamp(input, x1, x2)
    return y1 + ((input - x1) / (x2 - x1)) * (y2 - y1)
end

-- just shortening the name
--

function percentage_to_hsl(percentage, hue0, hue1)
    local hue = (percentage * (hue1 - hue0)) + hue0
    return hue, 100, 50
end

function hslToRgb(h, s, l)
    h = h / 360
    s = s / 100
    l = l / 100

    local r, g, b;

    if s == 0 then
        r, g, b = l, l, l; -- achromatic
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1 / 6 then return p + (q - p) * 6 * t end
            if t < 1 / 2 then return q end
            if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
            return p;
        end

        local q = l < 0.5 and l * (1 + s) or l + s - l * s;
        local p = 2 * l - q;
        r = hue2rgb(p, q, h + 1 / 3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1 / 3);
    end

    if not a then a = 1 end
    return r, g, b, a
end

LAST_DEBOUNCE = 0
function debounceValues(func, wait, newValue)
    local now = SIM.time
    if now - LAST_DEBOUNCE < wait then return end
    LAST_DEBOUNCE = now
    return func(newValue)
end

TyreColorMap = {
    C1 = rgbm(1, 1, 1, 1),
    C2 = rgbm(1, 1, 1, 1),
    C3 = rgbm(0.917, 0.933, 0, 1),
    C4 = rgbm(0.90, 0.14, 0.059, 1),
    C5 = rgbm(0.90, 0.14, 0.059, 1),
    SS = rgbm(0.90, 0.14, 0.059, 1),
    S = rgbm(0.90, 0.14, 0.059, 1),
    M = rgbm(0.917, 0.933, 0, 1),
    H = rgbm(1, 1, 1, 1),
    WE = rgbm(0.25, 0.52, 0.97, 1),
    IN = rgbm(0.49, 0.77, 0.47, 1),
}


-- Function to convert a table to a string
function tableToString(tbl, indent)
    indent = indent or 0
    local str = ""

    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        local valueStr = type(v) == "table" and tableToString(v, indent + 1) or tostring(v)
        str = str .. string.rep("  ", indent) .. keyStr .. ": " .. valueStr .. "\n"
    end

    return str
end
