-- Wayland can leave client_app empty. The fresh Niri focus lease is always
-- required; if a frontend supplies an app name, verify that too. Direct Pi,
-- Emacs and other applications have no focused-tmux lease.
local M = {}
local REJECTED, NOOP = 0, 2 -- Rime: rejected passes to app; accepted=1 eats it.

local function capture(now)
  local home = os.getenv('HOME')
  if not home then return false end
  local file = io.open(home .. '/.local/state/input-method/tmux-prefix-context', 'r')
  if not file then return false end
  local line = file:read('*l') or ''
  file:close()
  local updated = tonumber(line:match('^tmux%s+(%d+%.?%d*)$'))
  return updated and now - updated <= 3 and now >= updated - 1
end

function M.init(env)
  -- fcitx clears composition when deactivating/resetting Rime. A prefix whose
  -- next key went through the English path must not eat a later Chinese key.
  env.prefix_connection = env.engine.context.update_notifier:connect(function()
    env.prefix_until = nil
  end)
end

function M.fini(env)
  if env.prefix_connection then env.prefix_connection:disconnect() end
end

function M.func(key, env)
  local app = env.engine.context:get_property('client_app')
  if app and app ~= '' and app ~= 'ghostty' and app ~= 'com.mitchellh.ghostty' then
    env.prefix_until = nil
    return NOOP
  end
  local name = key:repr()
  if name:find('Release+', 1, true) then return NOOP end
  local now = os.time()
  if env.prefix_until then
    local active = now <= env.prefix_until and capture(now)
    env.prefix_until = nil
    if active then return REJECTED end
  end
  if (name == 'Control+b' or name == 'Control+space') and capture(now) then
    env.prefix_until = now + 3
    return REJECTED
  end
  return NOOP
end
return M
