Settings = class('Settings')
function Settings:initialize() -- constructor
    local file = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/GT7HUD/settings/" .. "settings.ini")

    if file == nil then
        file = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/GT7HUD/settings/" .. "default_settings.ini")
    end
    self.ini = file
    self.autoScale = file:get('SCALE', 'AUTOSCALE', true)
    self.scaleValue = file:get('SCALE', 'SCALEVALUE', 0.5)
    self.isImperial = file:get('UNITS', 'IMPERIAL', false)
    self.fixedPos = file:get('EXPERIMENTAL', 'FIXED_POS', false)
    self.beepSound = file:get('SOUND', 'BEEP', true)
    self.beepSoundMulti = file:get('SOUND', 'BEEP_VOLUME_MULTI', 0.2)
    self.countdownSound = file:get('SOUND', 'COUNTDOWN', true)
    self.countdownSoundMulti = file:get('SOUND', 'COUNTDOWN_VOLUME_MULTI', 0.2)
    local modules = file:get('MFD', 'MODULES', nil)
    if modules == nil then
        self.mfdModules = { 'TCS', 'ABS', 'BB', 'FUEL', 'SB', 'RADAR' }
    elseif type(modules[1]) == 'string' then
        self.mfdModules = string.split(modules[1], ',')
    else
        self.mfdModules = modules
    end

    self.countdown = file:get('FEATURES', 'COUNTDOWN', true)
    self.countdownCamera = file:get('FEATURES', 'COUNTDOWN_CAMERA', true)
    self.carName = file:get('FEATURES', 'CARNAME', false)
    self.pitDetails = file:get('FEATURES', 'INPITLANEDETAILS', true)
    self.extendedTyreTemps = file:get('FEATURES', 'EXTENDED_TYRE_TEMPS', true)
    self.analogMode = file:get('FEATURES', 'ANALOG_TACH', false)
    self.analogModeAuto = file:get('FEATURES', 'ANALOG_TACH_AUTO', false)
end

function Settings:reload()
    local file = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/GT7HUD/settings/" .. "settings.ini")
    self.ini = file
    self.autoScale = file:get('SCALE', 'AUTOSCALE', true)
    self.scaleValue = file:get('SCALE', 'SCALEVALUE', 0.5)
    self.isImperial = file:get('UNITS', 'IMPERIAL', false)
    self.fixedPos = file:get('EXPERIMENTAL', 'FIXED_POS', false)
    self.beepSound = file:get('SOUND', 'BEEP', true)
    self.beepSoundMulti = file:get('SOUND', 'BEEP_VOLUME_MULTI', 0.2)
    self.countdownSound = file:get('SOUND', 'COUNTDOWN', true)
    self.countdownSoundMulti = file:get('SOUND', 'COUNTDOWN_VOLUME_MULTI', 0.2)
    local modules = file:get('MFD', 'MODULES', nil)
    if modules == nil then
        self.mfdModules = { 'TCS', 'ABS', 'BB', 'FUEL', 'SB', 'RADAR' }
    elseif type(modules[1]) == 'string' then
        self.mfdModules = string.split(modules[1], ',')
    else
        self.mfdModules = modules
    end
    self.countdown = file:get('FEATURES', 'COUNTDOWN', true)
    self.countdownCamera = file:get('FEATURES', 'COUNTDOWN_CAMERA', true)
    self.carName = file:get('FEATURES', 'CARNAME', false)
    self.pitDetails = file:get('FEATURES', 'INPITLANEDETAILS', true)
    self.extendedTyreTemps = file:get('FEATURES', 'EXTENDED_TYRE_TEMPS', false)
    self.analogMode = file:get('FEATURES', 'ANALOG_TACH', false)
    self.analogModeAuto = file:get('FEATURES', 'ANALOG_TACH_AUTO', false)
end

function Settings:update(section, key, value)
    local test = self.ini:set(section, key, value)
    self.ini:save(ac.getFolder(ac.FolderID.ACApps) .. "/lua/GT7HUD/settings/" .. "settings.ini")
end
