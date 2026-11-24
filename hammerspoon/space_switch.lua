-- Fast Desktop Space switching using ONLY Left Option + 1..N.
-- Right Option is completely untouched (safe for Doubao voice input, etc.).
-- Triggers macOS native Ctrl+1..N Mission Control shortcuts for zero-lag switching.

local M = {}

local LALT = hs.eventtap.event.rawFlagMasks.deviceLeftAlternate  -- 0x20
local RALT = hs.eventtap.event.rawFlagMasks.deviceRightAlternate -- 0x40

-- macOS virtual keyCodes for top-row digits 1..9
local DIGIT_KEYCODES = {
  [18] = "1",
  [19] = "2",
  [20] = "3",
  [21] = "4",
  [23] = "5",
  [22] = "6",
  [26] = "7",
  [28] = "8",
  [25] = "9",
}

M._tap = nil

local function sendNativeSpaceSwitch(digitStr)
  local down = hs.eventtap.event.newKeyEvent({ "ctrl" }, digitStr, true)
  local up = hs.eventtap.event.newKeyEvent({ "ctrl" }, digitStr, false)
  down:setFlags({ ctrl = true })
  up:setFlags({ ctrl = true })
  down:post()
  up:post()
end

function M.bind(maxSpaces)
  if M._tap then
    M._tap:stop()
    M._tap = nil
  end

  local limit = tonumber(maxSpaces) or 4

  M._tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local digit = DIGIT_KEYCODES[event:getKeyCode()]
    if not digit or tonumber(digit) > limit then
      return false
    end

    -- Must be ONLY Option (no Cmd / Ctrl / Shift)
    local flags = event:getFlags()
    if not flags:containExactly({ "alt" }) then
      return false
    end

    -- Must be LEFT Option only — never intercept RIGHT Option
    local raw = event:rawFlags()
    if (raw & LALT) == 0 or (raw & RALT) ~= 0 then
      return false
    end

    -- Ignore key auto-repeat while held down
    if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0 then
      return true
    end

    hs.timer.doAfter(0, function()
      sendNativeSpaceSwitch(digit)
    end)
    return true
  end)

  M._tap:start()
end

return M
