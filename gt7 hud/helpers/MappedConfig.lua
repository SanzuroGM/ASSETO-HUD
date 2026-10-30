---@class MappedConfig
---@field filename string
---@field ini ac.INIConfig
---@field data table
---@field original table
---@field map table
local MappedConfig = class('MappedConfig', function(filename, map)
    local ini = ac.INIConfig.load(filename)
    local data = ini:mapConfig(map)
    local key = 'app.GT7HUD:' .. filename
    local original = nil -- TODO: REMOVE THIS LINE
    if not original then
        ac.store(key, stringify(data))
        original = stringify.parse(stringify(data))
    end
    return { filename = filename, ini = ini, map = map, data = data, original = original }
end, class.NoInitialize)


function MappedConfig:reload()
    self.ini = ac.INIConfig.load(self.filename) or self.ini
    self.data = self.ini:mapConfig(self.map)
end

---@param section string
---@param key string
---@param value number|boolean
---@param triggerControlReload boolean?
function MappedConfig:set(section, key, value, triggerControlReload, hexFormat)
    if not self.data[section] then self.data[section] = {} end
    if type(value) == 'number' and not (value > -1e9 and value < 1e9) then
        error('Sanity check failed: ' ..
            tostring(value))
    end
    if self.data[section][key] == value then return end
    self.data[section][key] = value
    setTimeout(function()
        ac.log('Saving updated value: ' .. tostring(value))
        if onConfigChange then onConfigChange() end
        self.ini:setAndSave(section, key,
            self.data[section][key])
        -- hexFormat and string.format('0x%x', self.data[section][key]) or self.data[section][key])
        if triggerControlReload ~= false then
            setTimeout(function()
                ac.log('Reloading control settings now')
                ac.reloadControlSettings()
            end, 0.02, 'reload')
        end
        ignoreChangesUntil = ui.time() + 4
    end, 0.02, section .. key)
end

-- Actual configs:
local controlsIni = MappedConfig(ac.getFolder(ac.FolderID.Cfg) .. '/controls.ini',
    { HEADER = { INPUT_METHOD = ac.INIConfig.OptionalString }, })


CFGControls = MappedConfig(ac.getFolder(ac.FolderID.ACApps) .. "/lua/GT7HUD/settings/" .. "mfd_controls.ini", {
    HEADER = controlsIni.data.HEADER,
    KEYBOARD = {
        MFD_UP = '',
        MFD_DOWN = '',
        MFD_LEFT = '',
        MFD_RIGHT = '',
    },
    X360 = {
        JOYPAD_INDEX = 0,
        MFD_UP = '',
        MFD_DOWN = '',
        MFD_LEFT = '',
        MFD_RIGHT = '',
    },
    WHEEL = {
        WHEEL_INDEX = '',
        MFD_UP = '',
        MFD_DOWN = '',
        MFD_LEFT = '',
        MFD_RIGHT = '',
    },
})

GamepadNames = {
    ['DPAD_LEFT'] = { ac.GamepadButton.DPadLeft, 'D-Pad Left' },
    ['DPAD_RIGHT'] = { ac.GamepadButton.DPadRight, 'D-Pad Right' },
    ['DPAD_UP'] = { ac.GamepadButton.DPadUp, 'D-Pad Up' },
    ['DPAD_DOWN'] = { ac.GamepadButton.DPadDown, 'D-Pad Down' },
    ['A'] = { ac.GamepadButton.A, 'A' },
    ['B'] = { ac.GamepadButton.B, 'B' },
    ['X'] = { ac.GamepadButton.X, 'X' },
    ['Y'] = { ac.GamepadButton.Y, 'Y' },
    ['LSHOULDER'] = { ac.GamepadButton.LeftShoulder, 'Left Shoulder' },
    ['RSHOULDER'] = { ac.GamepadButton.RightShoulder, 'Right Shoulder' },
    ['LTHUMB_PRESS'] = { ac.GamepadButton.LeftThumb, 'Left Thumb' },
    ['RTHUMB_PRESS'] = { ac.GamepadButton.RightThumb, 'Right Thumb' },
    ['START'] = { ac.GamepadButton.Start, 'Start' },
    ['BACK'] = { ac.GamepadButton.Back, 'Back' },
}

local gamepadButtonsOrdered = {
    { 'X360', 'MFD_UP',    'Change Setting (UP)' },
    { 'X360', 'MFD_DOWN',  'Change Setting (DOWN)' },
    { 'X360', 'MFD_LEFT',  'Change Page (LEFT)' },
    { 'X360', 'MFD_RIGHT', 'Change Page (RIGHT)' },
}
local wheelButtonsOrdered = {
    { 'WHEEL', 'MFD_UP',    'Change Setting (UP)' },
    { 'WHEEL', 'MFD_DOWN',  'Change Setting (DOWN)' },
    { 'WHEEL', 'MFD_LEFT',  'Change Page (LEFT)' },
    { 'WHEEL', 'MFD_RIGHT', 'Change Page (RIGHT)' },
}
local gamepadWaiting

local function gamepadButton(section, key, label)
    ui.alignTextToFramePadding()
    ui.text(label .. ':')
    ui.sameLine(180, 0)
    local current = CFGControls.data[section][key]
    local id = section .. '/' .. key
    if ui.button(string.format('%s###%s', GamepadNames[current] and GamepadNames[current][2] or 'None', id), vec2(ui.availableSpaceX() - 24, 0), gamepadWaiting == id and ui.ButtonFlags.Active or 0) then
        gamepadWaiting = gamepadWaiting ~= id and id or nil
    end

    ui.sameLine(0, 4)
    if ui.button('##r' .. id, vec2(20, 20), ui.ButtonFlags.None) then
        CFGControls:set(section, key, '', true)
        gamepadWaiting = nil
    end
    ui.addIcon(ui.Icons.Delete, 10, 0.5, nil, 0)
    if gamepadWaiting == id then
        if ac.blockEscapeButton then ac.blockEscapeButton() end
        if ui.keyboardButtonDown(ui.KeyIndex.Escape) or ui.keyboardButtonDown(ui.KeyIndex.Back) then
            gamepadWaiting = nil
        elseif ui.keyboardButtonDown(ui.KeyIndex.Delete) then
            CFGControls:set(section, key, '', true)
            gamepadWaiting = nil
        else
            for k, _ in pairs(GamepadNames) do
                if ac.isGamepadButtonPressed(CFGControls.data.X360.JOYPAD_INDEX, _[1]) then
                    CFGControls:set(section, key, k, true)
                    gamepadWaiting = nil
                end
            end
        end
    end
end

function wheelButton(section, key, label, tooltip, listenMode)
    ui.alignTextToFramePadding()
    ui.text(label .. ':')
    ui.sameLine(200, 0)
    local current = CFGControls.data[section][key]
    local id = section .. '/' .. key
    local name = 'None'

    if current ~= nil then
        if GamepadNames[tonumber(current)] then
            name = GamepadNames[tonumber(current)][2]
        else
            name = 'Button ' .. current
        end
    end
    if ui.button(string.format('%s###%s', name
            , id),
            vec2(ui.availableSpaceX() - 24, 0), gamepadWaiting == id and ui.ButtonFlags.Active or 0) then
        gamepadWaiting = gamepadWaiting ~= id and id or nil
    end
    if tooltip and ui.itemHovered() then
        (type(tooltip) == 'function' and ui.tooltip or ui.setTooltip)(tooltip)
    end
    ui.sameLine(0, 4)
    local changed = CFGControls.original[section][key] ~= current
    if ui.button('##r' .. id, vec2(20, 20), ui.ButtonFlags.None) then
        CFGControls:set(section, key, '', true)
        gamepadWaiting = nil
    end

    if gamepadWaiting == id then
        if ui.keyboardButtonDown(ui.KeyIndex.Escape) or ui.keyboardButtonDown(ui.KeyIndex.Back) then
            gamepadWaiting = nil
        elseif ui.keyboardButtonDown(ui.KeyIndex.Delete) then
            CFGControls:set(section, key, '', true)
            gamepadWaiting = nil
        else
            for currentJoyStick = 0, ac.getJoystickCount(), 1 do
                for currentButton = 1, 100, 1 do
                    if ac.isJoystickButtonPressed(currentJoyStick, currentButton) then
                        CFGControls:set(section, key, currentButton, true)
                        CFGControls:set('WHEEL', 'WHEEL_INDEX', currentJoyStick, true)
                        gamepadWaiting = nil
                    end
                    if ac.getJoystickDpadsCount(currentJoyStick) ~= 0 and
                        ac.getJoystickDpadValue(currentJoyStick, 0) ~= -1 then
                        CFGControls:set(section, key, ac.getJoystickDpadValue(currentJoyStick, 0), true)
                        CFGControls:set('WHEEL', 'WHEEL_INDEX', currentJoyStick, true)
                        gamepadWaiting = nil
                    end
                end
            end
        end
    end
end

KeyNames = {
    [8] = 'Backspace',
    [9] = 'Tab',
    [13] = 'Enter',
    [32] = 'Space',
    [35] = 'End',
    [36] = 'Home',
    [37] = 'Left Arrow',
    [38] = 'Up Arrow',
    [39] = 'Right Arrow',
    [40] = 'Down Arrow',
    [45] = 'Insert',
    [46] = 'Delete',
    [91] = 'Win (Left)',
    [92] = 'Win (Right)',
    [96] = 'Numpad 0',
    [97] = 'Numpad 1',
    [98] = 'Numpad 2',
    [99] = 'Numpad 3',
    [100] = 'Numpad 4',
    [101] = 'Numpad 5',
    [102] = 'Numpad 6',
    [103] = 'Numpad 7',
    [104] = 'Numpad 8',
    [105] = 'Numpad 9',
    [106] = 'Numpad Multiply',
    [107] = 'Numpad Add',
    [108] = 'Numpad Separator',
    [109] = 'Numpad Subtract',
    [110] = 'Numpad Decimal',
    [111] = 'Numpad Divide',
    [112] = 'F1',
    [113] = 'F2',
    [114] = 'F3',
    [115] = 'F4',
    [116] = 'F5',
    [117] = 'F6',
    [118] = 'F7',
    [119] = 'F8',
    [120] = 'F9',
    [121] = 'F10',
    [122] = 'F11',
    [123] = 'F12',
    [124] = 'F13',
    [125] = 'F14',
    [126] = 'F15',
    [127] = 'F16',
    [128] = 'F17',
    [129] = 'F18',
    [130] = 'F19',
    [131] = 'F20',
    [132] = 'F21',
    [133] = 'F22',
    [134] = 'F23',
    [135] = 'F24',
    [144] = 'NumLock',
    [145] = 'Scroll',
    [160] = 'Shift (Left)',
    [161] = 'Shift (Right)',
    [162] = 'Control (Left)',
    [163] = 'Control (Right)',
    [164] = 'Alt (Left)',
    [165] = 'Alt (Right)',
    [48] = '0',
    [49] = '1',
    [50] = '2',
    [51] = '3',
    [52] = '4',
    [53] = '5',
    [54] = '6',
    [55] = '7',
    [56] = '8',
    [57] = '9',
    [65] = 'A',
    [66] = 'B',
    [67] = 'C',
    [68] = 'D',
    [69] = 'E',
    [70] = 'F',
    [71] = 'G',
    [72] = 'H',
    [73] = 'I',
    [74] = 'J',
    [75] = 'K',
    [76] = 'L',
    [77] = 'M',
    [78] = 'N',
    [79] = 'O',
    [80] = 'P',
    [81] = 'Q',
    [82] = 'R',
    [83] = 'S',
    [84] = 'T',
    [85] = 'U',
    [86] = 'V',
    [87] = 'W',
    [88] = 'X',
    [89] = 'Y',
    [90] = 'Z',
}

local keyWaiting

local function keyboardButton(section, key, label, tooltip)
    ui.alignTextToFramePadding()
    ui.text(label .. ':')
    ui.sameLine(180, 0)
    local current = CFGControls.data['KEYBOARD'][key]

    local id = section .. '/' .. key
    local name = 'None'
    if current ~= nil and current ~= '' then
        name = KeyNames[tonumber(current)]
    end


    if ui.button(string.format('%s###%s', name, id), vec2(ui.availableSpaceX() - 24, 0), keyWaiting == id and ui.ButtonFlags.Active or 0) then
        keyWaiting = keyWaiting ~= id and id or nil
    end
    if tooltip and ui.itemHovered() then
        (type(tooltip) == 'function' and ui.tooltip or ui.setTooltip)(tooltip)
    end
    ui.sameLine(0, 4)
    if ui.button('##r' .. id, vec2(20, 20), ui.ButtonFlags.None) then
        CFGControls:set(section, key, '', true, true)
        keyWaiting = nil
    end
    ui.addIcon(ui.Icons.Delete, 10, 0.5, nil, 0)

    if keyWaiting == id then
        if ui.keyboardButtonDown(ui.KeyIndex.Escape) or ui.keyboardButtonDown(ui.KeyIndex.Back) then
            keyWaiting = nil
        else
            for k, _ in pairs(KeyNames) do
                if ui.keyboardButtonDown(k) then
                    CFGControls:set(section, key, k, true)
                    keyWaiting = nil
                end
            end
        end
    end
end


local configurators = {}

function configurators.X360()
    for i = 1, #gamepadButtonsOrdered do
        local v = gamepadButtonsOrdered[i]
        gamepadButton(v[1], v[2], v[3])
    end
    -- gamepadButton('X360', 'ACTIVE_GAMEPAD_INDEX', 'Active Gamepad Index', true)
end

function configurators.WHEEL()
    for i = 1, #wheelButtonsOrdered do
        local v = wheelButtonsOrdered[i]
        wheelButton(v[1], v[2], v[3], false)
    end
    -- gamepadButton('X360', 'ACTIVE_GAMEPAD_INDEX', 'Active Gamepad Index', true)
end

function configurators.KEYBOARD()
    keyboardButton('KEYBOARD', 'MFD_UP', 'Change Setting (UP)')
    keyboardButton('KEYBOARD', 'MFD_DOWN', 'Change Setting (DOWN)')
    keyboardButton('KEYBOARD', 'MFD_LEFT', 'Change Page (LEFT)')
    keyboardButton('KEYBOARD', 'MFD_RIGHT', 'Change Page (RIGHT)')
end

function DrawInputSettings()
    ui.text('KEY CONFLICTS NEED TO BE HANDLED BY THE USER')
    ui.newLine(10)
    configurators[CFGControls.data.HEADER.INPUT_METHOD]()
end
