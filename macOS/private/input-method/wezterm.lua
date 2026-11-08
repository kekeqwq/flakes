-- No input-source operations or subprocesses here. This file only reports
-- the ACTUAL active terminal pane; Hammerspoon owns all switching.
local wezterm = require 'wezterm'
local M = {}
function M.apply()
  local directory = wezterm.home_dir .. '/.local/state/input-method'
  local last = nil
  local function report(window, pane)
    if not window:is_focused() then return end
    pane = window:active_pane() or pane
    if not pane then return end
    local info = pane:get_foreground_process_info()
    local state = {
      version = 1, window = window:window_id(), pane = pane:pane_id(),
      tty = pane:get_tty_name(), pid = info and info.pid or 0,
      blocked = window:active_key_table() ~= nil or window:leader_is_active(),
    }
    local data = wezterm.json_encode(state)
    if data == last then return end
    local temp = directory .. '/wezterm.' .. tostring(window:window_id()) .. '.tmp'
    local f = io.open(temp, 'w')
    if not f then return end
    f:write(data)
    f:close()
    if os.rename(temp, directory .. '/wezterm.json') then last = data end
  end
  wezterm.on('update-status', report)
  wezterm.on('window-focus-changed', report)
  wezterm.on('window-config-reloaded', report)
end
return M
