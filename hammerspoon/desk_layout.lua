-- Desk Layout: save / restore / delete named window layouts for Alfred.
-- Slots 1..N map to Ctrl+Opt+Cmd+1..N. Layout names are human (Base, Work, Study, ...).
--
-- Accessibility (hs.window) only sees windows on the Desktop that is showing,
-- so every cross-Desktop step goes through bin/spacectl, which sees and moves
-- windows on any Space. Restore pulls the layout's windows onto the visible
-- Desktop, sizes them there, closes extras, then sends each to its Desktop.

local M = {}

local SPACECTL = hs.configdir .. "/bin/spacectl"
local STORE = hs.configdir .. "/desk_layouts.json"
local BACKUP_DIR = hs.configdir .. "/backups"
local LOG = hs.configdir .. "/desk_layout.log"
local MAX_SLOTS = 9
local MAX_BACKUPS = 10

local OTHER_APPS_ACTION = "quit" -- "quit" | "hide" | "none"
local CLOSE_FINDER_ON_RESTORE = true

-- Never quit these on restore, even when they are not in the layout.
local KEEP_ALIVE_BUNDLES = {
  ["io.github.clash-verge-ninja.clash-verge-ninja"] = true,
}

-- Never captured, never quit.
local SKIP_BUNDLES = {
  ["org.hammerspoon.Hammerspoon"] = true,
  ["com.runningwithcrayons.Alfred"] = true,
  ["com.runningwithcrayons.Alfred-Preferences"] = true,
  ["com.louivers.spacepigeon"] = true,
}

-- Ignored when capturing snapshots (prevents polluting Base with transient
-- system utilities), but still closed on restore by handleOtherApps().
local IGNORE_CAPTURE_BUNDLES = {
  ["com.apple.ActivityMonitor"] = true,
  ["com.apple.systempreferences"] = true,
  ["com.apple.Preview"] = true,
  ["com.apple.Console"] = true,
  ["com.apple.QuickTimePlayerX"] = true,
  ["com.apple.screencaptureui"] = true,
  ["com.apple.archiveutility"] = true,
}

local function listToSet(list)
  local set = {}
  for _, v in ipairs(list or {}) do
    if type(v) == "string" and v ~= "" then set[v] = true end
  end
  return set
end

function M.configure(cfg)
  if type(cfg) ~= "table" then return end
  if cfg.otherAppsAction == "quit" or cfg.otherAppsAction == "hide" or cfg.otherAppsAction == "none" then
    OTHER_APPS_ACTION = cfg.otherAppsAction
  end
  if cfg.closeFinderOnRestore ~= nil then
    CLOSE_FINDER_ON_RESTORE = cfg.closeFinderOnRestore == true
  end
  if type(cfg.keepAliveApps) == "table" then
    KEEP_ALIVE_BUNDLES = listToSet(cfg.keepAliveApps)
  end
  if type(cfg.ignoreOnCapture) == "table" then
    IGNORE_CAPTURE_BUNDLES = listToSet(cfg.ignoreOnCapture)
  end
  if type(cfg.maxHotkeySlots) == "number" and cfg.maxHotkeySlots >= 1 and cfg.maxHotkeySlots <= 9 then
    MAX_SLOTS = math.floor(cfg.maxHotkeySlots)
  end
end

local FINDER = "com.apple.finder"

local missionControl = nil
do
  local ok, mod = pcall(require, "mission_control")
  if ok then missionControl = mod end
end

local windowSnap = nil
do
  local ok, mod = pcall(require, "window_snap")
  if ok then windowSnap = mod end
end

local busy = false

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------

local function log(fmt, ...)
  local ok, msg = pcall(string.format, fmt, ...)
  if not ok then msg = tostring(fmt) end
  local f = io.open(LOG, "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S  ") .. msg .. "\n")
    f:close()
  end
end

local function trimLog()
  local attr = hs.fs.attributes(LOG)
  if attr and attr.size > 300000 then os.remove(LOG) end
end

local function alert(msg, seconds)
  hs.alert.show(msg, seconds or 2.5)
end

local function sleep(seconds)
  hs.timer.usleep(math.floor(seconds * 1e6))
end

local function setFrameInstant(win, frame)
  if windowSnap and windowSnap.setFrameInstant then
    windowSnap.setFrameInstant(win, frame)
  else
    win:setFrame(frame, 0)
  end
end

local function spacectl(args)
  local cmd = string.format("%q", SPACECTL)
  for _, a in ipairs(args) do
    cmd = cmd .. " " .. string.format("%q", tostring(a))
  end
  local out, _, _, rc = hs.execute(cmd)
  if rc ~= 0 then return nil, out end
  if not out or out:match("^%s*$") then return true end
  local ok, decoded = pcall(hs.json.decode, out)
  if ok and decoded ~= nil then return decoded end
  return true
end

local function waitUntil(pred, timeout, step)
  local deadline = hs.timer.secondsSinceEpoch() + (timeout or 2)
  while hs.timer.secondsSinceEpoch() < deadline do
    local v = pred()
    if v then return v end
    sleep(step or 0.05)
  end
  return pred()
end

---------------------------------------------------------------------------
-- Store & Backups
---------------------------------------------------------------------------

local function loadStore()
  local f = io.open(STORE, "r")
  if not f then return { version = 1, layouts = {} } end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(hs.json.decode, raw)
  if not ok or type(data) ~= "table" then return { version = 1, layouts = {} } end
  data.layouts = data.layouts or {}
  return data
end

local function backupStore()
  local f = io.open(STORE, "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return end

  hs.fs.mkdir(BACKUP_DIR)
  local stamp = os.date("%Y%m%d_%H%M%S")
  local dst = string.format("%s/desk_layouts_%s.json", BACKUP_DIR, stamp)
  local out = io.open(dst, "w")
  if out then
    out:write(raw)
    out:close()
  end

  local files = {}
  local iter, dirObj = hs.fs.dir(BACKUP_DIR)
  if iter then
    for entry in iter, dirObj do
      if entry:match("^desk_layouts_%d+_%d+%.json$") then
        table.insert(files, entry)
      end
    end
  end
  table.sort(files)
  while #files > MAX_BACKUPS do
    local oldest = table.remove(files, 1)
    os.remove(BACKUP_DIR .. "/" .. oldest)
  end
end

local function saveStore(data)
  backupStore()
  data.version = 1
  data.updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local json = hs.json.encode(data, true)
  local tmp = STORE .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(json)
  f:close()
  os.rename(tmp, STORE)
  return true
end

local function nextFreeSlot(store)
  local used = {}
  for _, layout in pairs(store.layouts) do
    if layout.slot then used[layout.slot] = true end
  end
  for i = 1, MAX_SLOTS do
    if not used[i] then return i end
  end
end

local function findByName(store, name)
  if not name or name == "" then return nil end
  for key, layout in pairs(store.layouts) do
    if layout.name == name or key == name then return key, layout end
  end
  local lower = name:lower()
  for key, layout in pairs(store.layouts) do
    if (layout.name and layout.name:lower() == lower) or key:lower() == lower then
      return key, layout
    end
  end
end

local function findBySlot(store, slot)
  for key, layout in pairs(store.layouts) do
    if layout.slot == slot then return key, layout end
  end
end

---------------------------------------------------------------------------
-- Screens, Spaces, Windows
---------------------------------------------------------------------------

local function orderedScreens()
  local screens = hs.screen.allScreens()
  table.sort(screens, function(a, b)
    local af, bf = a:frame(), b:frame()
    if af.x ~= bf.x then return af.x < bf.x end
    return af.y < bf.y
  end)
  return screens
end

local function readSpaces()
  local data = spacectl({ "spaces" })
  local byDisplay, displayOfSpace = {}, {}
  if type(data) == "table" then
    for _, d in ipairs(data) do
      local ids = {}
      for _, sp in ipairs(d.spaces or {}) do
        table.insert(ids, sp.id)
        displayOfSpace[sp.id] = d.display
      end
      byDisplay[d.display] = { ids = ids, current = d.current }
    end
  end
  return byDisplay, displayOfSpace
end

local function isRealWindow(w)
  return w.id and w.w and w.h and w.w > 50 and w.h > 50
end

local function listWindows()
  local list = spacectl({ "windows" })
  local out = {}
  if type(list) == "table" then
    for _, w in ipairs(list) do
      if isRealWindow(w) then table.insert(out, w) end
    end
  end
  return out
end

local function windowsOfPid(all, pid)
  local out = {}
  for _, w in ipairs(all) do
    if w.pid == pid then table.insert(out, w) end
  end
  return out
end

local function relativeFrame(abs, sf)
  return {
    x = (abs.x - sf.x) / sf.w,
    y = (abs.y - sf.y) / sf.h,
    w = abs.w / sf.w,
    h = abs.h / sf.h,
  }
end

local function absoluteFrame(rel, sf)
  return {
    x = sf.x + rel.x * sf.w,
    y = sf.y + rel.y * sf.h,
    w = rel.w * sf.w,
    h = rel.h * sf.h,
  }
end

local function displayIndexForPoint(x, y, screens)
  for i, s in ipairs(screens) do
    local f = s:fullFrame()
    if x >= f.x and x < f.x + f.w and y >= f.y and y < f.y + f.h then return i end
  end
  return 1
end

local function appForCapture(pid)
  local app = hs.application.applicationForPID(pid)
  if not app then return nil end
  local bid = app:bundleID() or ""
  if SKIP_BUNDLES[bid] or IGNORE_CAPTURE_BUNDLES[bid] or bid == FINDER then return nil end
  if app:kind() ~= 1 then return nil end
  return app
end

local function moveWindowToSpace(id, spaceId)
  local ok = spacectl({ "move", tostring(id), tostring(spaceId), "2000" })
  return ok ~= nil
end

---------------------------------------------------------------------------
-- Mission Control / landing on a Desktop
---------------------------------------------------------------------------

local function closeMissionControl()
  if hs.spaces.closeMissionControl then pcall(hs.spaces.closeMissionControl) end
end

local function switchToSpace(spaceId, screen)
  local function arrived()
    return hs.spaces.activeSpaceOnScreen(screen) == spaceId
  end
  if arrived() then return true end

  spacectl({ "focus", tostring(spaceId), "800" })
  if waitUntil(arrived, 0.5) then return true end

  local switched = false
  if missionControl and missionControl.inWindowManager then
    pcall(hs.spaces.openMissionControl)
    local kids = waitUntil(function()
      local list = missionControl.spacesList(screen)
      local k = list and list.AXChildren
      return (k and #k > 0) and k or nil
    end, 2)
    if kids then
      local all = hs.spaces.spacesForScreen(screen) or {}
      for i, sid in ipairs(all) do
        if sid == spaceId and kids[i] then
          pcall(function() kids[i]:performAction("AXPress") end)
          switched = waitUntil(arrived, 3, 0.08) and true or false
          break
        end
      end
    end
    if not switched then
      closeMissionControl()
      hs.eventtap.keyStroke({}, "escape")
    end
  elseif hs.spaces.gotoSpace then
    pcall(hs.spaces.gotoSpace, spaceId)
    switched = waitUntil(arrived, 3, 0.08) and true or false
    closeMissionControl()
  end
  return switched or arrived()
end

---------------------------------------------------------------------------
-- Capture & Summary
---------------------------------------------------------------------------

local function capture()
  local screens = orderedScreens()
  local spaces = readSpaces()
  if next(spaces) == nil then return nil, "spacectl spaces failed" end

  local displays, place = {}, {}
  for i, screen in ipairs(screens) do
    local uuid = screen:getUUID()
    local ids = (spaces[uuid] and spaces[uuid].ids) or hs.spaces.spacesForScreen(screen) or {}
    local sf = screen:frame()
    displays[i] = {
      index = i,
      uuid = uuid,
      frame = { x = sf.x, y = sf.y, w = sf.w, h = sf.h },
      spaceIds = ids,
      spaceCount = #ids,
    }
    for si, sid in ipairs(ids) do
      place[sid] = { displayIndex = i, spaceIndex = si, screen = screen }
    end
  end

  local entries = {}
  for _, w in ipairs(listWindows()) do
    local app = appForCapture(w.pid)
    if app then
      local p = place[w.spaces and w.spaces[1]]
      local di = p and p.displayIndex or displayIndexForPoint(w.x, w.y, screens)
      local screen = p and p.screen or screens[di]
      local win = hs.window.get(w.id)
      local path = app:path()
      table.insert(entries, {
        name = (path and path:match("([^/]+)%.app/?$")) or app:name(),
        appName = app:name(),
        bundleID = app:bundleID(),
        path = path,
        title = win and win:title() or "",
        displayIndex = di,
        spaceIndex = p and p.spaceIndex or 1,
        fullscreen = w.fullscreen == true,
        frame = relativeFrame({ x = w.x, y = w.y, w = w.w, h = w.h }, screen:frame()),
        _x = w.x,
        _y = w.y,
      })
    end
  end

  table.sort(entries, function(a, b)
    if a.displayIndex ~= b.displayIndex then return a.displayIndex < b.displayIndex end
    if a.spaceIndex ~= b.spaceIndex then return a.spaceIndex < b.spaceIndex end
    if a._x ~= b._x then return a._x < b._x end
    return a._y < b._y
  end)
  for _, e in ipairs(entries) do
    e._x, e._y = nil, nil
  end

  local activeSpace = { displayIndex = 1, spaceIndex = 1 }
  local p = place[hs.spaces.focusedSpace()]
  if p then activeSpace = { displayIndex = p.displayIndex, spaceIndex = p.spaceIndex } end

  return {
    monitorCount = #screens,
    displays = displays,
    windows = entries,
    activeSpace = activeSpace,
    savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
end

local function summarizeSnap(snap)
  local multiMonitor = (snap.monitorCount or 1) > 1
  local groups, keys = {}, {}
  for _, e in ipairs(snap.windows or {}) do
    local di = e.displayIndex or 1
    local si = e.spaceIndex or 1
    local k = string.format("%02d:%02d", di, si)
    if not groups[k] then
      groups[k] = { di = di, si = si, order = {}, counts = {} }
      table.insert(keys, k)
    end
    local g = groups[k]
    local label = e.appName or e.name or "?"
    if not g.counts[label] then
      g.counts[label] = 0
      table.insert(g.order, label)
    end
    g.counts[label] = g.counts[label] + 1
  end
  table.sort(keys)
  local lines = {}
  for _, k in ipairs(keys) do
    local g = groups[k]
    local parts = {}
    for _, label in ipairs(g.order) do
      local c = g.counts[label]
      table.insert(parts, c > 1 and string.format("%s x%d", label, c) or label)
    end
    local prefix = multiMonitor
      and string.format("屏%d 桌面%d: ", g.di, g.si)
      or string.format("桌面 %d: ", g.si)
    table.insert(lines, prefix .. table.concat(parts, ", "))
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Restore
---------------------------------------------------------------------------

local function prepareApp(bid, path, name)
  local app = hs.application.get(bid)
  if not app then
    log("launch %s", name)
    app = hs.application.open(bid, 10, true)
      or (path and hs.application.open(path, 10, true))
      or hs.application.get(bid)
  end
  if not app then
    log("  could not launch %s", name)
    return nil
  end
  if app:isHidden() then app:unhide() end
  if #windowsOfPid(listWindows(), app:pid()) == 0 then
    hs.application.open(bid)
    waitUntil(function() return #windowsOfPid(listWindows(), app:pid()) > 0 end, 4, 0.2)
  end
  return app
end

local function pullVisible(wins, spaces, displayOfSpace)
  for _, w in ipairs(wins) do
    local sid = w.spaces and w.spaces[1]
    local disp = sid and displayOfSpace[sid]
    local cur = disp and spaces[disp] and spaces[disp].current
    if cur and sid ~= cur then
      local ok = moveWindowToSpace(w.id, cur)
      log("  pull window %d from space %d to %d: %s", w.id, sid, cur, ok and "ok" or "FAILED")
    end
  end
end

local function sizeScore(win, entry, screen)
  local f = win:frame()
  local t = absoluteFrame(entry.frame, screen:frame())
  return math.abs(f.w - t.w) + math.abs(f.h - t.h)
end

local function assignWindows(rows, wins, screenFor)
  local used, result = {}, {}
  for i, row in ipairs(rows) do
    local title = row.entry.title
    if title and title ~= "" then
      for _, w in ipairs(wins) do
        if not used[w:id()] and (w:title() or "") == title then
          used[w:id()], result[i] = true, w
          break
        end
      end
    end
  end
  for i, row in ipairs(rows) do
    if not result[i] then
      local best, bestScore
      for _, w in ipairs(wins) do
        if not used[w:id()] then
          local s = sizeScore(w, row.entry, screenFor(row.entry))
          if not bestScore or s < bestScore then best, bestScore = w, s end
        end
      end
      if best then used[best:id()], result[i] = true, best end
    end
  end
  return result, used
end

local function closeFinderWindows()
  local ok = hs.osascript.applescript('tell application "Finder" to close every window')
  log("close Finder windows: %s", ok and "ok" or "FAILED (Automation permission for Finder?)")
end

local function handleOtherApps(keepBundles)
  if OTHER_APPS_ACTION == "none" then return end
  local withWindows = {}
  for _, w in ipairs(listWindows()) do withWindows[w.pid] = true end
  for _, app in ipairs(hs.application.runningApplications()) do
    local bid = app:bundleID() or ""
    if app:kind() == 1 and withWindows[app:pid()]
      and not keepBundles[bid] and not KEEP_ALIVE_BUNDLES[bid]
      and not SKIP_BUNDLES[bid] and bid ~= FINDER then
      if OTHER_APPS_ACTION == "hide" then
        log("hide %s (%s)", app:name() or "?", bid)
        app:hide()
      else
        log("quit %s (%s)", app:name() or "?", bid)
        app:kill()
      end
    end
  end
end

local function restoreLayout(layout)
  local screens = orderedScreens()
  local spaces, displayOfSpace = readSpaces()

  local targets = {}
  for i, disp in ipairs(layout.displays or {}) do
    local screen
    for _, s in ipairs(screens) do
      if disp.uuid and s:getUUID() == disp.uuid then screen = s end
    end
    screen = screen or screens[i] or screens[1]
    local ids = (spaces[screen:getUUID()] and spaces[screen:getUUID()].ids) or {}
    if #ids < (disp.spaceCount or 0) then
      log("WARNING display %d has %d Desktops, layout expects %d", i, #ids, disp.spaceCount)
    end
    targets[i] = { screen = screen, ids = ids }
  end
  for i, screen in ipairs(screens) do
    if not targets[i] then
      targets[i] = { screen = screen, ids = (spaces[screen:getUUID()] or {}).ids or {} }
    end
  end
  local function targetFor(entry)
    local t = targets[entry.displayIndex or 1] or targets[1]
    return t, t.ids[entry.spaceIndex or 1] or t.ids[1]
  end
  local function screenFor(entry) return (targetFor(entry)).screen end

  local groups, order, keepBundles = {}, {}, {}
  for _, e in ipairs(layout.windows or {}) do
    local key = e.bundleID or e.name
    if not groups[key] then
      groups[key] = { bid = e.bundleID, path = e.path, name = e.appName or e.name, rows = {} }
      table.insert(order, key)
    end
    table.insert(groups[key].rows, { entry = e })
    if e.bundleID then keepBundles[e.bundleID] = true end
  end

  local placed = {}
  for _, key in ipairs(order) do
    local g = groups[key]
    log("app %s: %d window(s) in layout", g.name, #g.rows)
    local app = prepareApp(g.bid, g.path, g.name)
    if app then
      local pid = app:pid()
      local wins = windowsOfPid(listWindows(), pid)
      log("  found %d window(s) across all Desktops", #wins)

      local missing = #g.rows - #wins
      for _ = 1, math.max(missing, 0) do
        log("  create window with Cmd+N")
        app:activate()
        sleep(0.2)
        hs.eventtap.keyStroke({ "cmd" }, "n", 0, app)
        sleep(0.6)
      end
      if missing > 0 then wins = windowsOfPid(listWindows(), pid) end

      pullVisible(wins, spaces, displayOfSpace)
      local wanted = {}
      for _, w in ipairs(wins) do wanted[w.id] = true end
      local axWins = waitUntil(function()
        local list, found = {}, 0
        for _, w in ipairs(app:allWindows()) do
          if wanted[w:id()] then
            if w:isMinimized() then w:unminimize() end
            table.insert(list, w)
            found = found + 1
          end
        end
        return found >= #wins and list or nil
      end, 1.5) or (function()
        local list = {}
        for _, w in ipairs(app:allWindows()) do
          if wanted[w:id()] then table.insert(list, w) end
        end
        return list
      end)()
      if #axWins < #wins then
        log("  WARNING only %d of %d window(s) reachable after pulling", #axWins, #wins)
      end

      local assigned, used = assignWindows(g.rows, axWins, screenFor)
      for i, row in ipairs(g.rows) do
        local win = assigned[i]
        local t, spaceId = targetFor(row.entry)
        if not win then
          log("  row %d: no window to place", i)
        elseif row.entry.fullscreen then
          moveWindowToSpace(win:id(), spaceId)
          pcall(function() win:setFullScreen(true) end)
          table.insert(placed, { win = win, spaceId = spaceId })
        else
          if win:isFullScreen() then
            win:setFullScreen(false)
            sleep(0.6)
          end
          setFrameInstant(win, absoluteFrame(row.entry.frame, t.screen:frame()))
          local ok = moveWindowToSpace(win:id(), spaceId)
          log("  row %d: window %d -> Desktop %d %s", i, win:id(), row.entry.spaceIndex or 1, ok and "" or "(move FAILED)")
          table.insert(placed, { win = win, spaceId = spaceId })
        end
      end

      for _, w in ipairs(axWins) do
        if not used[w:id()] then
          log("  close extra window %d %q", w:id(), w:title() or "")
          w:close()
        end
      end
    end
  end

  if CLOSE_FINDER_ON_RESTORE and not keepBundles[FINDER] then closeFinderWindows() end
  handleOtherApps(keepBundles)

  local as = layout.activeSpace or { displayIndex = 1, spaceIndex = 1 }
  local t = targets[as.displayIndex or 1] or targets[1]
  local landing = t.ids[as.spaceIndex or 1] or t.ids[1]
  for _, p in ipairs(placed) do
    if p.spaceId == landing then
      pcall(function() p.win:focus() end)
      break
    end
  end
  local ok = switchToSpace(landing, t.screen)
  log("land on Desktop %d: %s", as.spaceIndex or 1, ok and "ok" or "FAILED")
end

---------------------------------------------------------------------------
-- Persist helper
---------------------------------------------------------------------------

local function commitSnap(name, snap)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    alert("请输入布局名称（例如 Base / Study）")
    return false
  end

  local store = loadStore()
  local existingKey, existing = findByName(store, name)
  local slot
  local isOverwrite = false
  if existing then
    slot = existing.slot
    isOverwrite = true
    if existingKey ~= name then store.layouts[existingKey] = nil end
  else
    slot = nextFreeSlot(store)
  end

  snap.name, snap.slot = name, slot
  store.layouts[name] = snap
  if not saveStore(store) then
    alert("写入 desk_layouts.json 失败")
    return false
  end

  for _, e in ipairs(snap.windows) do
    log("  saved %s -> display %d Desktop %d", e.appName, e.displayIndex, e.spaceIndex)
  end
  log("saved %q in slot %s (%d windows)", name, tostring(slot or "none"), #snap.windows)

  local slotHint = slot and string.format("Ctrl+Opt+Cmd+%d", slot) or "ws 面板"
  local verb = isOverwrite and "已覆盖" or "已保存"
  alert(string.format("%s「%s」-> %s（%d 个窗口）", verb, name, slotHint, #snap.windows), 3)
  return true
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

function M.saveInteractive()
  trimLog()
  log("=== save (interactive)")

  local snap, err = capture()
  if not snap then
    log("save failed: %s", tostring(err))
    alert("捕获窗口失败: " .. tostring(err))
    return
  end

  local summary = summarizeSnap(snap)
  local body = string.format(
    "已捕获 %d 个窗口（%d 台显示器）：\n%s\n\n输入布局名称（同名将覆盖原槽位；新名称自动分配下一个快捷键槽位）：",
    #snap.windows, snap.monitorCount, summary ~= "" and summary or "（无窗口）"
  )

  hs.focus()
  local button, name = hs.dialog.textPrompt(
    "保存桌面布局 (Desk Layout)",
    body,
    "", "保存", "取消"
  )
  if button ~= "保存" then
    alert("已取消保存", 1.2)
    return
  end

  commitSnap(name, snap)
end

function M.saveByName(name)
  trimLog()
  log("=== save (direct: %s)", tostring(name))

  local snap, err = capture()
  if not snap then
    log("save failed: %s", tostring(err))
    alert("捕获窗口失败: " .. tostring(err))
    return
  end

  commitSnap(name, snap)
end

local function runRestore(layout, label)
  if busy then
    alert("正在恢复布局中，请稍候…", 1.5)
    return
  end
  busy = true
  log("=== restore %q (%s)", layout.name or "?", label)
  alert(string.format("正在恢复「%s」…", layout.name or "?"), 1.5)
  hs.timer.doAfter(0.05, function()
    local ok, err = xpcall(function() restoreLayout(layout) end, debug.traceback)
    busy = false
    if ok then
      log("restore done")
      alert(string.format("已恢复「%s」", layout.name or "?"), 1.5)
    else
      log("restore ERROR: %s", tostring(err))
      alert("恢复失败 - 请查看 ~/.hammerspoon/desk_layout.log", 3)
    end
  end)
end

function M.restoreSlot(slot)
  trimLog()
  slot = tonumber(slot)
  local _, layout = findBySlot(loadStore(), slot)
  if not layout then
    log("=== restore slot %s: no layout", tostring(slot))
    alert(string.format("槽位 %s 还没有保存布局，可按 Ctrl+Opt+Cmd+S 或输入 ws save 保存。", tostring(slot)), 3)
    return
  end
  runRestore(layout, "slot " .. tostring(slot))
end

function M.restoreByName(name)
  trimLog()
  local _, layout = findByName(loadStore(), name)
  if not layout then
    log("=== restore name %q: no layout", tostring(name))
    alert(string.format("未找到名为「%s」的布局", tostring(name)), 2.5)
    return
  end
  runRestore(layout, "name " .. tostring(name))
end

function M.deleteByName(name)
  trimLog()
  local store = loadStore()
  local key, layout = findByName(store, name)
  if not layout then
    alert(string.format("未找到名为「%s」的布局", tostring(name)), 2)
    return
  end
  local freedSlot = layout.slot
  store.layouts[key] = nil
  if not saveStore(store) then
    alert("写入 desk_layouts.json 失败")
    return
  end
  log("=== deleted %q (slot %s)", key, tostring(freedSlot or "none"))
  local slotHint = freedSlot and string.format("，已释放槽位 %d", freedSlot) or ""
  alert(string.format("已删除「%s」%s", key, slotHint), 2.5)
end

-- Read-only: what a restore would touch. For debugging from the console.
function M.plan(slot)
  local _, layout = findBySlot(loadStore(), tonumber(slot))
  if not layout then return "no layout in slot " .. tostring(slot) end
  local all = listWindows()
  local lines, keep = {}, {}
  local counts = {}
  for _, e in ipairs(layout.windows or {}) do
    keep[e.bundleID or ""] = true
    counts[e.bundleID] = (counts[e.bundleID] or 0) + 1
  end
  for bid, n in pairs(counts) do
    local app = hs.application.get(bid)
    local have = app and #windowsOfPid(all, app:pid()) or 0
    table.insert(lines, string.format("%s: layout %d, open %d%s", bid, n, have, app and "" or " (not running)"))
  end
  for _, app in ipairs(hs.application.runningApplications()) do
    local bid = app:bundleID() or ""
    if app:kind() == 1 and #windowsOfPid(all, app:pid()) > 0 and not keep[bid]
      and not KEEP_ALIVE_BUNDLES[bid] and not SKIP_BUNDLES[bid] then
      table.insert(lines, (bid == FINDER and "close windows: " or "quit: ") .. (app:name() or bid))
    end
  end
  table.sort(lines)
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Built-in Native Workspace Palette (hs.chooser) — Works WITHOUT Alfred!
---------------------------------------------------------------------------

local function sortedLayoutsList(store)
  local items = {}
  for key, layout in pairs(store.layouts or {}) do
    if type(layout) == "table" then
      table.insert(items, {
        name = layout.name or key,
        slot = layout.slot,
        layout = layout,
      })
    end
  end
  table.sort(items, function(a, b)
    local sa, sb = a.slot or 999, b.slot or 999
    if sa ~= sb then return sa < sb end
    return a.name:lower() < b.name:lower()
  end)
  return items
end

local function oneLineSummary(layout)
  local s = summarizeSnap(layout)
  if s == "" then return "空布局" end
  return s:gsub("\n", " · ")
end

local activeChooser = nil

function M.openDeletePalette()
  local store = loadStore()
  local list = sortedLayoutsList(store)
  if #list == 0 then
    alert("当前还没有可删除的布局", 2)
    return
  end

  local choices = {}
  for _, item in ipairs(list) do
    local slotTag = item.slot and string.format("  [释放槽位 %d]", item.slot) or ""
    table.insert(choices, {
      text = "删除「" .. item.name .. "」" .. slotTag,
      subText = oneLineSummary(item.layout),
      action = "delete",
      name = item.name,
    })
  end

  activeChooser = hs.chooser.new(function(choice)
    if not choice then return end
    if choice.action == "delete" then
      M.deleteByName(choice.name)
    end
  end)
  activeChooser:placeholderText("选择要删除的布局…")
  activeChooser:choices(choices)
  activeChooser:show()
end

function M.openPalette()
  local store = loadStore()
  local list = sortedLayoutsList(store)
  local choices = {}

  for _, item in ipairs(list) do
    local slotTag = item.slot and string.format("  [Ctrl+Opt+Cmd+%d]", item.slot) or ""
    local count = #(item.layout.windows or {})
    table.insert(choices, {
      text = item.name .. slotTag,
      subText = string.format("%d 窗口 · %s", count, oneLineSummary(item.layout)),
      action = "restore",
      name = item.name,
    })
  end

  table.insert(choices, {
    text = "+ 保存 / 覆盖当前桌面为布局…",
    subText = "等同于 Ctrl+Opt+Cmd+S（会先预览窗口清单，同名自动备份后覆盖）",
    action = "save",
  })

  if #list > 0 then
    table.insert(choices, {
      text = "- 删除某个已有布局…",
      subText = "删除后自动释放对应的数字快捷键槽位",
      action = "delete_menu",
    })
  end

  activeChooser = hs.chooser.new(function(choice)
    if not choice then return end
    if choice.action == "restore" then
      M.restoreByName(choice.name)
    elseif choice.action == "save" then
      hs.timer.doAfter(0.1, function() M.saveInteractive() end)
    elseif choice.action == "delete_menu" then
      hs.timer.doAfter(0.1, function() M.openDeletePalette() end)
    end
  end)
  activeChooser:placeholderText("搜索并切换工作区布局（回车立即切换）…")
  activeChooser:searchSubText(true)
  activeChooser:choices(choices)
  activeChooser:show()
end

function M.bindHotkeys(cfg)
  cfg = cfg or {}
  local mods = cfg.layoutMods or { "ctrl", "alt", "cmd" }
  local saveKey = cfg.saveKey or "s"
  local paletteKey = cfg.paletteKey or "w"
  local reloadKey = cfg.reloadKey or "r"
  local maxSlots = cfg.maxHotkeySlots or MAX_SLOTS

  if saveKey ~= "" then
    hs.hotkey.bind(mods, saveKey, function() M.saveInteractive() end)
  end
  if paletteKey ~= "" then
    hs.hotkey.bind(mods, paletteKey, function() M.openPalette() end)
  end
  if reloadKey ~= "" then
    hs.hotkey.bind(mods, reloadKey, function()
      alert("正在重载配置…", 1)
      hs.timer.doAfter(0.15, function() hs.reload() end)
    end)
  end
  for i = 1, math.min(maxSlots, 9) do
    local slotNum = i
    hs.hotkey.bind(mods, tostring(slotNum), function() M.restoreSlot(slotNum) end)
  end
end

function M.handleURL(params)
  params = params or {}
  local action = params.action
  if action == "save" then
    if params.name and params.name ~= "" then
      M.saveByName(params.name)
    else
      M.saveInteractive()
    end
  elseif action == "restore" then
    if params.name and params.name ~= "" then
      M.restoreByName(params.name)
    else
      M.restoreSlot(params.slot)
    end
  elseif action == "delete" then
    M.deleteByName(params.name)
  elseif action == "palette" then
    M.openPalette()
  elseif action == "reload" then
    alert("正在重载 Hammerspoon…", 1)
    hs.timer.doAfter(0.2, function() hs.reload() end)
  elseif action == "console" then
    hs.openConsole(true)
  else
    alert("Unknown deskLayout action: " .. tostring(action))
  end
end

function M.bindUrl()
  hs.urlevent.bind("deskLayout", function(_, params) M.handleURL(params) end)
  hs.urlevent.bind("desklayout", function(_, params) M.handleURL(params) end)
end

return M
