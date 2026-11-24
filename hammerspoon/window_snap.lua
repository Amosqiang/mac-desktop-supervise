-- Window Snapping module for Hammerspoon (1:1 replacement for Rectangle).
-- Mirrors the exact Rectangle keybindings with zero animation delay:
--   Opt+Cmd+Left    Left Half   (repeat on multi-monitor -> Right Half of west screen)
--   Opt+Cmd+Right   Right Half  (repeat on multi-monitor -> Left Half of east screen)
--   Opt+Cmd+Up      Top Half
--   Opt+Cmd+Down    Bottom Half
--   Opt+Cmd+Return  Maximize
--   Ctrl+Cmd+T      First Third (toggle Left 1/3 <-> Right 1/3)
--   Ctrl+Cmd+Y      First Two Thirds (toggle Left 2/3 <-> Right 2/3)

local M = {}

local TOLERANCE = 12
local lastToggle = {} -- [winId] = { kind = "...", side = "left"|"right" }

-- Temporarily disables AXEnhancedUserInterface on Chromium/Electron apps
-- (Chrome, Cursor, Antigravity, TRAE) so resizing is instantaneous and exact.
function M.setFrameInstant(win, frame)
  if not win then return end
  local app = win:application()
  local axApp = app and hs.axuielement.applicationElement(app)
  local wasEnhanced = false
  if axApp then
    local ok, val = pcall(function() return axApp.AXEnhancedUserInterface end)
    if ok and val then
      wasEnhanced = true
      pcall(function() axApp.AXEnhancedUserInterface = false end)
    end
  end
  win:setFrame(frame, 0)
  if wasEnhanced then
    pcall(function() axApp.AXEnhancedUserInterface = true end)
  end
end

local function near(a, b)
  return math.abs(a - b) <= TOLERANCE
end

local function framesMatch(a, b)
  return near(a.x, b.x) and near(a.y, b.y) and near(a.w, b.w) and near(a.h, b.h)
end

local function rectFor(kind, sf)
  local halfW = math.floor(sf.w / 2)
  local halfH = math.floor(sf.h / 2)
  local thirdW = math.floor(sf.w / 3)
  local twoThirdsW = sf.w - thirdW
  if kind == "left" then
    return { x = sf.x, y = sf.y, w = halfW, h = sf.h }
  elseif kind == "right" then
    return { x = sf.x + halfW, y = sf.y, w = sf.w - halfW, h = sf.h }
  elseif kind == "top" then
    return { x = sf.x, y = sf.y, w = sf.w, h = halfH }
  elseif kind == "bottom" then
    return { x = sf.x, y = sf.y + halfH, w = sf.w, h = sf.h - halfH }
  elseif kind == "max" then
    return { x = sf.x, y = sf.y, w = sf.w, h = sf.h }
  elseif kind == "leftThird" then
    return { x = sf.x, y = sf.y, w = thirdW, h = sf.h }
  elseif kind == "rightThird" then
    return { x = sf.x + sf.w - thirdW, y = sf.y, w = thirdW, h = sf.h }
  elseif kind == "leftTwoThirds" then
    return { x = sf.x, y = sf.y, w = twoThirdsW, h = sf.h }
  elseif kind == "rightTwoThirds" then
    return { x = sf.x + sf.w - twoThirdsW, y = sf.y, w = twoThirdsW, h = sf.h }
  end
end

local function toggleLeftRight(kind, leftKind, rightKind)
  local win = hs.window.focusedWindow()
  if not win or not win:isStandard() then return end
  if win:isFullScreen() then return end

  local screen = win:screen()
  if not screen then return end

  local sf = screen:frame()
  local cur = win:frame()
  local leftRect = rectFor(leftKind, sf)
  local rightRect = rectFor(rightKind, sf)

  local wid = win:id()
  local prev = wid and lastToggle[wid]
  local isAtLeft = framesMatch(cur, leftRect)
    or (prev and prev.kind == kind and prev.side == "left" and near(cur.x, leftRect.x))

  local nextSide = isAtLeft and "right" or "left"
  local target = nextSide == "right" and rightRect or leftRect
  if wid then
    lastToggle[wid] = { kind = kind, side = nextSide }
  end
  M.setFrameInstant(win, target)
end

local function snap(kind)
  local win = hs.window.focusedWindow()
  if not win or not win:isStandard() then return end
  if win:isFullScreen() then return end

  local screen = win:screen()
  if not screen then return end

  local sf = screen:frame()
  local target = rectFor(kind, sf)
  if not target then return end

  -- Match Rectangle's subsequentExecutionMode = 1 (across displays):
  -- Pressing Left/Right again when already snapped moves across displays.
  if #hs.screen.allScreens() > 1 and framesMatch(win:frame(), target) then
    if kind == "left" then
      local west = screen:toWest()
      if west then
        target = rectFor("right", west:frame())
      end
    elseif kind == "right" then
      local east = screen:toEast()
      if east then
        target = rectFor("left", east:frame())
      end
    end
  end

  if win:id() then lastToggle[win:id()] = nil end
  M.setFrameInstant(win, target)
end

function M.bind(snapKeys)
  local k = snapKeys or {}
  local function bindKey(spec, fallbackMods, fallbackKey, fn)
    local mods = (spec and spec[1]) or fallbackMods
    local key = (spec and spec[2]) or fallbackKey
    if mods and key and key ~= "" then
      hs.hotkey.bind(mods, key, fn)
    end
  end

  bindKey(k.leftHalf,        { "alt", "cmd" },  "left",   function() snap("left") end)
  bindKey(k.rightHalf,       { "alt", "cmd" },  "right",  function() snap("right") end)
  bindKey(k.topHalf,         { "alt", "cmd" },  "up",     function() snap("top") end)
  bindKey(k.bottomHalf,      { "alt", "cmd" },  "down",   function() snap("bottom") end)
  bindKey(k.maximize,        { "alt", "cmd" },  "return", function() snap("max") end)
  bindKey(k.toggleThird,     { "ctrl", "cmd" }, "t",      function() toggleLeftRight("third", "leftThird", "rightThird") end)
  bindKey(k.toggleTwoThirds, { "ctrl", "cmd" }, "y",      function() toggleLeftRight("twoThirds", "leftTwoThirds", "rightTwoThirds") end)
end

return M
