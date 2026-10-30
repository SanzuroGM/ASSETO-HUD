--[[

  ███╗   ███╗██╗██╗     ██╗     ███████╗███╗   ██╗██╗██╗   ██╗███╗   ███╗
  ████╗ ████║██║██║     ██║     ██╔════╝████╗  ██║██║██║   ██║████╗ ████║
  ██╔████╔██║██║██║     ██║     █████╗  ██╔██╗ ██║██║██║   ██║██╔████╔██║
  ██║╚██╔╝██║██║██║     ██║     ██╔══╝  ██║╚██╗██║██║██║   ██║██║╚██╔╝██║
  ██║ ╚═╝ ██║██║███████╗███████╗███████╗██║ ╚████║██║╚██████╔╝██║ ╚═╝ ██║
  ╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝╚═╝╚═════╝ ╚═╝     ╚═╝

  M I L L E N I U M   H U D  ·  Hello from Spotik

  Полупрозрачный HUD поверх игры:
    • спидометр: цифровой блок или дуговой прибор (переключается), скорость/обороты/передача
    • педали: GAS / BRK / CLT / HB с процентами (CLT показывает нажатие)
    • передача: отдельная плашка (между педалями и шинами), вспышка у красной зоны
    • шины: температура резины по колёсам, цвет состояния (серый/зелёный/жёлтый/красный)

  Отдельный проект семейства Mellenium. Общий конвейер: [UI_CALLBACKS] IN_GAME
  рисует оверлей всегда (LAZY = NONE), окно в панели приложений — только настройки.

--]]

local VERSION = '1.4.3'

----------------------------------------------------------------------
-- Настройки (ac.storage сам сохраняет их между сессиями)
----------------------------------------------------------------------
local cfg = ac.storage({
  hudSpeedo   = true,     -- виджет спидометра
  hudPedals   = true,     -- виджет педалей
  hudGear     = true,     -- виджет передачи (отдельная плашка)
  hudBrand    = true,     -- бренд-блок в левом верхнем углу
  hudTyres    = true,     -- виджет температуры шин
  bgEnabled   = true,     -- фон и рамка виджетов (выкл — чистые цифры поверх игры)
  speedoArc   = false,    -- дуговой прибор вместо цифрового блока
  opacity     = 0.55,     -- прозрачность подложек (0.15–0.95)
  scale       = 1.0,      -- общий масштаб HUD (0.8–1.4)
  shiftFlash  = true,     -- вспышка у красной зоны оборотов
  shiftPoint  = 0.93,     -- доля лимитера для вспышки
  pedalPct    = true,     -- проценты у полос педалей
  dragEnabled = true,     -- перетаскивание HUD мышью
  posX        = 0,        -- смещение от якоря (низ экрана, центр)
  posY        = 0,
})

----------------------------------------------------------------------
-- Палитра (та же, что у Mellenium)
----------------------------------------------------------------------
local ACCENT       = rgbm(0.62, 0.40, 1.00, 1)   -- фирменный фиолетовый
local ACCENT_SOFT  = rgbm(0.85, 0.78, 1.00, 1)
local ACCENT_DARK  = rgbm(0.30, 0.18, 0.55, 0.65)
local DIM          = rgbm(1, 1, 1, 0.40)
local COL_OK       = rgbm(0.35, 1.00, 0.45, 1)
local COL_WARN     = rgbm(1.00, 0.35, 0.30, 1)

local COL_GAS  = rgbm(0.30, 1.00, 0.25, 1)       -- газ
local COL_BRK  = rgbm(1.00, 0.22, 0.18, 1)       -- тормоз
local COL_CLT  = rgbm(0.30, 0.75, 1.00, 1)       -- сцепление
local COL_HB   = rgbm(1.00, 0.62, 0.12, 1)       -- ручник

-- Шрифты Segoe UI (кириллица в комплекте)
local fontMain  = ui.DWriteFont('Segoe UI')
local fontSmall = ui.DWriteFont('Segoe UI'):weight(450)
local fontBold  = ui.DWriteFont('Segoe UI'):weight(650)
local fontTitle = ui.DWriteFont('Segoe UI'):weight(800)
local fontGear  = ui.DWriteFont('Segoe UI'):weight(800)  -- цифра передачи: максимально жирная
local dwriteOk = type(ui.dwriteDrawText) == 'function'   -- есть ли DWrite-отрисовка с размером

----------------------------------------------------------------------
-- Низкоуровневые помощники отрисовки (все координаты — локальные окна)
----------------------------------------------------------------------
local hudT = 0

-- Центрированный текст: drawTextClipped есть не везде, зондируем один раз
local clippedOk = true
local function ctext(p1, p2, str, color)
  if clippedOk then
    local ok = pcall(ui.drawTextClipped, str, p1, p2, color, 0.5, true)
    if ok then return end
    clippedOk = false
  end
  ui.drawText(str, vec2(p1.x + 8, (p1.y + p2.y) * 0.5 - 8), color)
end

-- контур прямоугольника четырьмя тонкими залитыми (ui.drawRect не везде есть)
local function strokeRect(p1, p2, color, w)
  w = w or 1
  ui.drawRectFilled(vec2(p1.x, p1.y), vec2(p2.x, p1.y + w), color, 0)
  ui.drawRectFilled(vec2(p1.x, p2.y - w), vec2(p2.x, p2.y), color, 0)
  ui.drawRectFilled(vec2(p1.x, p1.y + w), vec2(p1.x + w, p2.y - w), color, 0)
  ui.drawRectFilled(vec2(p2.x - w, p1.y + w), vec2(p2.x, p2.y - w), color, 0)
end

-- дуга из отрезков: углы в градусах по часовой от «3 часов» (экранная ось Y вниз)
local function arcSeg(cx, cy, r, a0, a1, color, th, segs)
  segs = segs or math.max(6, math.floor(math.abs(a1 - a0) / 5))
  local px, py = cx + r * math.cos(math.rad(a0)), cy + r * math.sin(math.rad(a0))
  for i = 1, segs do
    local a = math.rad(a0 + (a1 - a0) * i / segs)
    local qx, qy = cx + r * math.cos(a), cy + r * math.sin(a)
    ui.drawLine(vec2(px, py), vec2(qx, qy), color, th)
    px, py = qx, qy
  end
end

-- радиальная засечка
local function tick(cx, cy, r0, r1, angDeg, color, th)
  local a = math.rad(angDeg)
  ui.drawLine(vec2(cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
    vec2(cx + r1 * math.cos(a), cy + r1 * math.sin(a)), color, th)
end

----------------------------------------------------------------------
-- Данные машины
----------------------------------------------------------------------
---Передача: ac.StateCar.gear → -1 = R, 0 = N, 1..n (по коду из CSP)
local function gearLabel(g)
  g = g or 0
  return g == 0 and 'N' or (g < 0 and 'R' or tostring(g))
end

-- лимитер из engine.ini установленной модели (кэш по ID машины)
local limitCache, limitFor = 8000, nil
local function refreshLimit(car)
  local id = ac.getCarID(car.index)
  if id == limitFor then return end
  limitFor = id
  limitCache = 8000
  local ok, ini = pcall(ac.INIConfig.carData, car.index, 'engine.ini')
  if ok and ini then
    local v = ini:get('ENGINE_DATA', 'LIMITER', 0)
    if type(v) == 'number' and v > 1500 then limitCache = v end
  end
end

local function rpmFrac(car)
  return math.saturate((car.rpm or 0) / limitCache)
end

----------------------------------------------------------------------
-- Виджет: спидометр (два режима — переключаются в настройках)
----------------------------------------------------------------------
local ARC_A0, ARC_A1 = 135, 405 -- дуга 270°: низ-лево → верх → низ-право

local function speedoFlashState(frac)
  return cfg.shiftFlash and frac >= cfg.shiftPoint
end

local function drawSpeedoAnalog(x0, y0, w, h, car, spd, frac)
  local cx, cy = x0 + w * 0.5, y0 + h * 0.60
  local R = math.min(w, h) * 0.52
  local flash = speedoFlashState(frac)

  -- фоновая дуга + красная зона
  arcSeg(cx, cy, R, ARC_A0, ARC_A1, rgbm(1, 1, 1, 0.10), 7)
  local redA0 = ARC_A0 + (ARC_A1 - ARC_A0) * 0.85
  arcSeg(cx, cy, R, redA0, ARC_A1, rgbm(1, 0.20, 0.16, 0.45), 7)

  -- засечки каждую 1000 об/мин + подписи каждые 2000
  local top = limitCache
  for k = 0, math.floor(top / 1000) do
    local a = ARC_A0 + (ARC_A1 - ARC_A0) * k * 1000 / top
    tick(cx, cy, R - 5, R + 4, a, rgbm(1, 1, 1, 0.30), 1.5)
    if k % 2 == 0 then
      local ar = math.rad(a)
      local lx, ly = cx + (R - 17) * math.cos(ar), cy + (R - 17) * math.sin(ar)
      ui.pushFont(fontSmall)
      ctext(vec2(lx - 12, ly - 7), vec2(lx + 12, ly + 7), tostring(k), DIM)
      ui.popFont()
    end
  end

  -- активная дуга (фиолетовая, у лимита — красная)
  if frac > 0.01 then
    local col = frac >= 0.85 and COL_WARN or ACCENT
    arcSeg(cx, cy, R, ARC_A0, ARC_A0 + (ARC_A1 - ARC_A0) * frac, col, 7)
  end

  -- стрелка
  local na = math.rad(ARC_A0 + (ARC_A1 - ARC_A0) * frac)
  ui.drawLine(vec2(cx + 10 * math.cos(na), cy + 10 * math.sin(na)),
    vec2(cx + (R - 10) * math.cos(na), cy + (R - 10) * math.sin(na)),
    flash and rgbm(1, 0.35, 0.3, 1) or rgbm(0.9, 0.85, 1, 0.95), 3)
  ui.drawCircleFilled(vec2(cx, cy), 4, ACCENT_DARK)

  -- центр: скорость крупно, передача под ней, «км/ч» сверху
  ui.pushFont(ui.Font ~= nil and ui.Font.Title or fontTitle)
  ctext(vec2(cx - 60, cy - 16), vec2(cx + 60, cy + 14), string.format('%.0f', spd),
    flash and rgbm(1, 0.45 + 0.3 * math.sin(hudT * 12), 0.4, 1) or rgbm(1, 1, 1, 0.95))
  ui.popFont()
  ui.pushFont(fontBold)
  ctext(vec2(cx - 30, cy - 32), vec2(cx + 30, cy - 16), 'км/ч', DIM)
  ui.popFont()
end

local function drawSpeedoDigital(x0, y0, w, h, car, spd, frac)

  -- Шрифты CSP фиксированы и НЕ масштабируются вместе с панелью, поэтому
  -- вёрстка строится по реальной высоте строк (measureText) — иначе при
  -- уменьшении масштаба цифры налезают друг на друга.
  local barH = 12
  local by0 = y0 + h - 12 - barH
  local by1 = by0 + barH

  local spdStr = string.format('%.0f', spd)

  ui.pushFont(fontSmall)
  local unitH = ui.measureText('км/ч').y
  local unitW = ui.measureText('км/ч').x
  ui.popFont()

  if dwriteOk then
    -- «км/ч» жёстко пришита между цифрой и шкалой RPM (раньше при крупном
    -- кегле она уезжала под шкалу), а цифра подгоняется в оставшееся место
    local labelY = by0 - 6 - unitH
    local digitH = (labelY - 4) - (y0 + 6)
    local size = math.clamp(math.floor(digitH * 0.98 + 0.5), 26, 120)
    ui.pushDWriteFont(fontGear)
    local ts = ui.measureDWriteText(spdStr, size)
    while (ts.x > w - 12 or ts.y > digitH) and size > 26 do
      size = size - 2
      ts = ui.measureDWriteText(spdStr, size)
    end
    local ty = y0 + 6 + math.max(0, (digitH - ts.y) * 0.5)
    ui.dwriteDrawText(spdStr, size, vec2(x0 + (w - ts.x) * 0.5, ty), rgbm(1, 1, 1, 0.95))
    ui.popDWriteFont()
    ui.pushFont(fontSmall)
    ui.drawText('км/ч', vec2(x0 + (w - unitW) * 0.5, labelY), DIM)
    ui.popFont()
  else
    -- запасной путь без DWrite: стек по замеренной высоте встроенных кеглей
    local speedFont = (ui.Font ~= nil and ui.Font.Huge ~= nil) and ui.Font.Huge or fontTitle
    if cfg.scale < 0.95 and ui.Font ~= nil and ui.Font.Title ~= nil then speedFont = ui.Font.Title end
    ui.pushFont(speedFont)
    local spdH = ui.measureText(spdStr).y
    ui.popFont()
    local totalH = spdH + 2 + unitH
    local avail = (by0 - 6) - (y0 + 6)
    local ty = y0 + 6 + math.max(0, (avail - totalH) * 0.5)
    ui.pushFont(speedFont)
    ctext(vec2(x0, ty), vec2(x0 + w, ty + spdH + 4), spdStr, rgbm(1, 1, 1, 0.95))
    ui.popFont()
    ty = ty + spdH + 2
    ui.pushFont(fontSmall)
    ctext(vec2(x0, ty), vec2(x0 + w, ty + unitH + 4), 'км/ч', DIM)
    ui.popFont()
  end

  -- полоса RPM с красной зоной (всегда внизу виджета)
  local bx0, bx1 = x0 + 12, x0 + w - 12
  ui.drawRectFilled(vec2(bx0, by0), vec2(bx1, by1), rgbm(1, 1, 1, 0.09), 3)
  local redX = bx0 + (bx1 - bx0) * 0.85
  ui.drawRectFilled(vec2(redX, by0), vec2(bx1, by1), rgbm(1, 0.22, 0.18, 0.30), 3)
  if frac > 0.005 then
    local fx = bx0 + (bx1 - bx0) * frac
    ui.drawRectFilled(vec2(bx0, by0), vec2(fx, by1), frac >= 0.85 and COL_WARN or ACCENT, 3)
  end
end

local function drawSpeedo(x0, y0, w, h, car)
  local frac = rpmFrac(car)
  local spd = car.speedKmh or 0

  if cfg.speedoArc then
    drawSpeedoAnalog(x0, y0, w, h, car, spd, frac)
  else
    drawSpeedoDigital(x0, y0, w, h, car, spd, frac)
  end

  -- вспышка рамкой у красной зоны
  if speedoFlashState(frac) then
    local p = 0.5 + 0.5 * math.sin(hudT * 12)
    strokeRect(vec2(x0 + 1, y0 + 1), vec2(x0 + w - 1, y0 + h - 1),
      rgbm(1, 0.25 + 0.25 * p, 0.25, 0.35 + 0.45 * p), 2)
  end
end

----------------------------------------------------------------------
-- Виджет: педали
----------------------------------------------------------------------
local PEDALS = {
  { 'GAS', COL_GAS, function(car) return car.gas end },
  { 'BRK', COL_BRK, function(car) return car.brake end },
  -- AC-хранилище: clutch = 1 — педаль ОТПУЩЕНА (диски сомкнуты), 0 — выжата в пол;
  -- показываем НАЖАТИЕ педали (как в Mellenium), иначе шкала стоит на 100 % в покое
  { 'CLT', COL_CLT, function(car) return car.clutch ~= nil and 1 - car.clutch or 0 end },
  { 'HB',  COL_HB,  function(car) return car.handbrake end },
}

local function drawPedals(x0, y0, w, h, car)
  local pad = 10
  local rowH = (h - pad * 2 - 4) / 4
  local labelW = 34
  local pctW = cfg.pedalPct and 30 or 0

  for i, row in ipairs(PEDALS) do
    local ry = y0 + pad + (i - 1) * (rowH + 1)
    local raw = row[3](car)
    local v = math.saturate(type(raw) == 'number' and raw or 0)

    ui.pushFont(fontSmall)
    ui.setCursor(vec2(x0 + pad, ry + rowH * 0.5 - 8))
    ui.pushStyleColor(ui.StyleColor.Text, DIM)
    ui.text(row[1])
    ui.popStyleColor()
    ui.popFont()

    local bx0 = x0 + pad + labelW
    local bx1 = x0 + w - pad - pctW
    local by0 = ry + rowH * 0.5 - 5
    ui.drawRectFilled(vec2(bx0, by0), vec2(bx1, by0 + 10), rgbm(1, 1, 1, 0.09), 3)
    if v > 0.005 then
      local c = row[2]
      ui.drawRectFilled(vec2(bx0, by0), vec2(bx0 + (bx1 - bx0) * v, by0 + 10),
        rgbm(c.r, c.g, c.b, 0.35 + 0.65 * v), 3)
    end

    if cfg.pedalPct then
      ui.pushFont(fontSmall)
      ctext(vec2(bx1 + 2, ry), vec2(bx1 + pctW, ry + rowH),
        string.format('%d', math.floor(v * 100 + 0.5)), v > 0.02 and rgbm(1, 1, 1, 0.85) or DIM)
      ui.popFont()
    end
  end
end

----------------------------------------------------------------------
-- Виджет: передача (отдельная плашка)
----------------------------------------------------------------------
local function drawGear(x0, y0, w, h, car)
  local flash = speedoFlashState(rpmFrac(car))
  local gear = gearLabel(car.gear)
  local col = gear == 'N' and DIM or (flash and rgbm(1, 0.45 + 0.3 * math.sin(hudT * 12), 0.4, 1)
    or rgbm(ACCENT_SOFT.r, ACCENT_SOFT.g, ACCENT_SOFT.b, 1))

  if dwriteOk then
    -- огромная жирная цифра: DWrite позволяет задать произвольный пиксельный размер
    local size = math.clamp(math.floor(h * 0.58 + 0.5), 26, 110)
    ui.pushDWriteFont(fontGear)
    local ts = ui.measureDWriteText(gear, size)
    ui.dwriteDrawText(gear, size,
      vec2(x0 + (w - ts.x) * 0.5, y0 + (h - ts.y) * 0.5 - size * 0.05), col)
    ui.popDWriteFont()
    return
  end

  -- запасной путь для старых сборок CSP: встроенный кегль Huge (Title при масштабе <95%)
  local gFont = (ui.Font ~= nil and ui.Font.Huge ~= nil) and ui.Font.Huge or fontTitle
  if cfg.scale < 0.95 and ui.Font ~= nil and ui.Font.Title ~= nil then gFont = ui.Font.Title end
  ui.pushFont(gFont)
  ctext(vec2(x0, y0), vec2(x0 + w, y0 + h), gear, col)
  ui.popFont()
end

----------------------------------------------------------------------
-- Виджет: температура шин (состояние цветом)
----------------------------------------------------------------------
local TYRE_LABELS = { 'LF', 'RF', 'LR', 'RR' } -- порядок car.wheels: 0..3

-- пороги температуры стержня (ядра) шины, °C:
-- обычное < 75 · отличное 75–100 · хуже 100–115 · совсем горячие 115+
local function tyreStateColor(t)
  if t == nil then return rgbm(1, 1, 1, 0.18) end
  if t >= 115 then return COL_WARN end           -- совсем горячие — красные
  if t >= 100 then return rgbm(1, 0.80, 0.10, 1) end -- хуже — жёлтые
  if t >= 75  then return COL_OK end              -- отличное — зелёные
  return rgbm(1, 1, 1, 0.30)                      -- обычное — серое
end

local function drawTyres(x0, y0, w, h, car)
  local pad = 10
  local gapC = 6
  local cw = (w - pad * 2 - gapC) / 2
  local ch = (h - pad * 2 - gapC) / 2
  for row = 0, 1 do
    for col = 0, 1 do
      local wi = row * 2 + col -- 0=LF 1=RF 2=LR 3=RR
      -- живая температура из car.wheels (зондируем pcall — поля зависят от сборки CSP)
      local ok, t = pcall(function()
        local wh = car.wheels[wi]
        return wh ~= nil and wh.tyreCoreTemperature or nil
      end)
      local temp = (ok and type(t) == 'number') and t or nil
      local c = tyreStateColor(temp)

      local x1 = x0 + pad + col * (cw + gapC)
      local y1 = y0 + pad + row * (ch + gapC)
      if cfg.bgEnabled then
        ui.drawRectFilled(vec2(x1, y1), vec2(x1 + cw, y1 + ch), rgbm(1, 1, 1, 0.05), 5)
      end
      -- цветная кромка слева (она же индикатор состояния)
      ui.drawRectFilled(vec2(x1, y1 + 3), vec2(x1 + 3, y1 + ch - 3), rgbm(c.r, c.g, c.b, 0.9), 2)

      ui.pushFont(fontSmall)
      ui.drawText(TYRE_LABELS[wi + 1], vec2(x1 + 9, y1 + 5), DIM)
      ui.popFont()
      ui.pushFont(fontBold)
      ui.drawText(temp ~= nil and string.format('%.0f°', temp + 0.5) or '—',
        vec2(x1 + 9, y1 + ch * 0.5 - 2), rgbm(c.r, c.g, c.b, 0.95))
      ui.popFont()
    end
  end
end

----------------------------------------------------------------------
-- Оверлей целиком
----------------------------------------------------------------------
local dragState = nil

-- бренд-блок: название + версия + авторская строка (без фона, с тенью под буквами)
local function drawBrand()
  if not cfg.hudBrand then return end
  ui.pushFont(fontSmall)
  ui.drawText('millenium HUD v' .. VERSION, vec2(21, 15), rgbm(0, 0, 0, 0.55))
  ui.drawText('Made by Spot1k for assetto corsa', vec2(21, 31), rgbm(0, 0, 0, 0.55))
  ui.drawText('millenium HUD v' .. VERSION, vec2(20, 14), rgbm(0.95, 0.92, 1, 0.95))
  ui.drawText('Made by Spot1k for assetto corsa', vec2(20, 30), rgbm(1, 1, 1, 0.55))
  ui.popFont()
end

function script.drawHud(dt)
  hudT = hudT + dt
  drawBrand()
  local car = ac.getCar(0)
  if car == nil then return end
  refreshLimit(car)

  local s = cfg.scale
  local gap = 10 * s
  local hPod = 150 * s
  local wSpeedo = 200 * s
  local wPedals = 170 * s
  local wGear  = 90 * s
  local wTyres = 170 * s

  -- виджеты собираются списком: включённые друг за другом, без следов выключенных
  local pods = {}
  if cfg.hudSpeedo then pods[#pods + 1] = { wSpeedo, drawSpeedo } end
  if cfg.hudPedals then pods[#pods + 1] = { wPedals, drawPedals } end
  if cfg.hudGear   then pods[#pods + 1] = { wGear,   drawGear   } end
  if cfg.hudTyres  then pods[#pods + 1] = { wTyres,  drawTyres  } end
  if #pods == 0 then return end -- всё выключено
  local tw = gap * (#pods - 1)
  for i = 1, #pods do tw = tw + pods[i][1] end

  local ws = ui.windowSize()
  local x = (ws.x - tw) * 0.5 + cfg.posX
  local y = ws.y - hPod - 30 + cfg.posY

  ui.transparentWindow('##millenium_hud', vec2(x, y), vec2(tw, hPod), true, cfg.dragEnabled, function()
    local cur = 0
    local function pod(pw, drawer)
      local p1, p2 = vec2(cur, 0), vec2(cur + pw, hPod)
      if cfg.bgEnabled then
        ui.drawRectFilled(p1, p2, rgbm(0.014, 0.018, 0.034, cfg.opacity), 9)
        strokeRect(p1, p2, rgbm(ACCENT_DARK.r, ACCENT_DARK.g, ACCENT_DARK.b, 0.5 * cfg.opacity), 1)
      end
      drawer(cur, 0, pw, hPod, car)
      cur = cur + pw + gap
    end

    for i = 1, #pods do pod(pods[i][1], pods[i][2]) end

    -- перетаскивание всей панели мышью (координаты мыши — локальные окна)
    if cfg.dragEnabled then
      local m = ui.mousePos()
      local absM = vec2(x + m.x, y + m.y)
      local down = ui.mouseDown(ui.MouseButton.Left)
      if dragState ~= nil then
        if down then
          cfg.posX = math.clamp(dragState.px + absM.x - dragState.ax, -ws.x * 0.5, ws.x * 0.5)
          cfg.posY = math.clamp(dragState.py + absM.y - dragState.ay, -ws.y, 0)
        else
          dragState = nil
        end
      elseif down and ui.rectHovered(vec2(0, 0), vec2(tw, hPod)) then
        dragState = { px = cfg.posX, py = cfg.posY, ax = absM.x, ay = absM.y }
      end
    end
  end)
end

----------------------------------------------------------------------
-- Окно настроек (иконка в панели приложений)
----------------------------------------------------------------------
local function section(title)
  ui.offsetCursorY(8)
  ui.pushFont(fontBold)
  ui.pushStyleColor(ui.StyleColor.Text, ACCENT_SOFT)
  ui.text(title)
  ui.popStyleColor()
  ui.popFont()
  ui.separator()
end

local function hint(text)
  ui.pushFont(fontSmall)
  ui.pushStyleColor(ui.StyleColor.Text, DIM)
  ui.text(text)
  ui.popStyleColor()
  ui.popFont()
end

local function toggle(title, hintText, key)
  if ui.checkbox(title .. '##' .. key, cfg[key]) then cfg[key] = not cfg[key] end
  if hintText then hint(hintText) end
end

function script.windowMain(dt)
  ui.pushFont(fontMain)

  -- заголовок
  ui.pushFont(fontTitle)
  ui.pushStyleColor(ui.StyleColor.Text, ACCENT)
  ui.text('MILLENIUM HUD')
  ui.popStyleColor()
  ui.popFont()
  ui.sameLine(0, 8)
  ui.pushFont(fontSmall)
  ui.pushStyleColor(ui.StyleColor.Text, DIM)
  ui.text('Hello from Spotik · v' .. VERSION)
  ui.popStyleColor()
  ui.popFont()
  ui.separator()

  hint('HUD рисуется поверх игры всегда. Виджеты полупрозрачные.')
  hint('Перетаскивание мышью — за любое место панели (включается ниже).')

  section('Виджеты')
  toggle('Спидометр', 'Скорость, обороты и текущая передача.', 'hudSpeedo')
  if cfg.hudSpeedo then
    toggle('Дуговой прибор', 'Круговой спидометр со стрелкой вместо цифрового блока.', 'speedoArc')
    toggle('Вспышка у красной зоны', 'Рамка и передача мигают, пора переключаться.', 'shiftFlash')
    if cfg.shiftFlash then
      cfg.shiftPoint = ui.slider('##shiftp', cfg.shiftPoint * 100, 80, 99, 'Вспышка с: %.0f%%') / 100
    end
  end
  toggle('Педали', 'Шкалы GAS / BRK / CLT / HB. CLT показывает нажатие (кик сцепления — всплеск).', 'hudPedals')
  if cfg.hudPedals then
    toggle('Проценты у шкал', nil, 'pedalPct')
  end
  toggle('Передача', 'Текущая передача отдельной плашкой между педалями и шинами; огромная жирная цифра, у красной зоны мигает красным.', 'hudGear')
  toggle('Температура шин', 'По каждому колесу: серая <75°, зелёная 75–100° (отличное), жёлтая 100–115° (хуже), красная 115°+ (совсем горячие).', 'hudTyres')
  section('Внешний вид')
  toggle('Бренд-блок в углу', '«millenium HUD» + версия и «Made by Spot1k for assetto corsa» в левом верхнем углу экрана.', 'hudBrand')
  toggle('Фон виджетов', 'Тёмная полупрозрачная подложка с рамкой. Выкл — чистые цифры поверх игры.', 'bgEnabled')
  cfg.opacity = ui.slider('##opacity', cfg.opacity * 100, 15, 95, 'Прозрачность: %.0f%%') / 100
  cfg.scale = ui.slider('##scale', cfg.scale * 100, 80, 140, 'Масштаб: %.0f%%') / 100

  section('Положение')
  toggle('Перетаскивание мышью', 'Когда включено, панель блокирует клики мыши под собой.', 'dragEnabled')
  cfg.posX = ui.slider('##posx', cfg.posX, -1200, 1200, 'Сдвиг X: %.0f')
  cfg.posY = ui.slider('##posy', cfg.posY, -1000, 0, 'Сдвиг Y: %.0f')
  if ui.button('Вернуть в центр##reset', vec2(-1, 24)) then
    cfg.posX, cfg.posY = 0, 0
  end

  ui.popFont()
end
