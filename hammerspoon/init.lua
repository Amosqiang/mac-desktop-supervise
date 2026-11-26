-- ============================================================================
-- Mac Desktop Supervise Engine (Hammerspoon Entry Point)
-- Customize everything in ~/.hammerspoon/config.lua
-- ============================================================================

local function logInitError(msg)
  local f = io.open(hs.configdir .. "/desk_layout.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S  [init] ") .. tostring(msg) .. "\n")
    f:close()
  end
end

-- Load user config (falls back safely if config.lua is missing)
local cfgOk, cfg = pcall(require, "config")
if not cfgOk or type(cfg) ~= "table" then
  logInitError("config.lua load warning: " .. tostring(cfg))
  cfg = {}
end

hs.window.animationDuration = 0
hs.menuIcon(cfg.showMenuIcon == true)
hs.dockIcon(cfg.showDockIcon == true)
if cfg.autoLaunch ~= nil then
  hs.autoLaunch(cfg.autoLaunch == true)
end
hs.allowAppleScript(true)
hs.urlevent.setDefaultHandler("hammerspoon")

-- 1. Window Snapping (1:1 Rectangle replacement, optional via config.lua)
if cfg.enableWindowSnap ~= false then
  local snapOk, snap = pcall(require, "window_snap")
  if snapOk then
    snap.bind(cfg.snapKeys)
  else
    hs.alert.show("window_snap load error - check ~/.hammerspoon/desk_layout.log")
    logInitError(snap)
  end
end

-- 1b. Fast Desktop Space switching with Left Option + 1..4 (Right Option untouched)
if cfg.enableLeftOptSpaceSwitch ~= false then
  local swOk, sw = pcall(require, "space_switch")
  if swOk then
    sw.bind(cfg.leftOptSpaceCount or 4)
  else
    hs.alert.show("space_switch load error - check ~/.hammerspoon/desk_layout.log")
    logInitError(sw)
  end
end

-- 2. Desk Layout Snapshot Engine
local ok, desk = pcall(require, "desk_layout")
if not ok then
  hs.alert.show("desk_layout load error - check ~/.hammerspoon/desk_layout.log")
  logInitError(desk)
  return
end

desk.configure(cfg)
desk.bindUrl()

-- Built-in workspace hotkeys
if cfg.enableBuiltInHotkeys ~= false then
  desk.bindHotkeys(cfg)
end

-- File trigger fallback (if Hammerspoon was manually quit and relaunched via URL)
local function urlDecode(s)
  if not s then return nil end
  return s:gsub("+", " "):gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
end

local actionFile = hs.configdir .. "/desk_action"
local f = io.open(actionFile, "r")
if f then
  local body = f:read("*a") or ""
  f:close()
  os.remove(actionFile)
  local params = {}
  for k, v in body:gmatch("([^&\r\n=]+)=([^&\r\n]*)") do
    params[k] = urlDecode(v)
  end
  if params.action then
    hs.timer.doAfter(0.4, function() desk.handleURL(params) end)
  end
end

print("Mac Desktop Supervise ready")
