-- Native Squirrel session guard, not an input-source switcher.
-- Hammerspoon chooses Squirrel only for Pi text input; ordinary tabs use ABC.
-- Squirrel app_options sets this private flag ONLY on its WezTerm sessions.
local M = {}
local HOLD_SECONDS = 2

local function enforce(ctx)
  if ctx:get_option('_pi_chinese_lock') and ctx:get_option('ascii_mode') then
    ctx:set_option('ascii_mode', false)
  end
end

local function repr(key)
  if not key then return nil end
  local ok, value = pcall(function() return key:repr() end)
  if ok and type(value) == 'string' then return value end
  return nil
end

function M.init(env)
  local ctx = env.engine.context
  env.pi_chinese_connection = ctx.option_update_notifier:connect(function(context, name)
    if name == 'ascii_mode' or name == '_pi_chinese_lock' then enforce(context) end
  end)
  enforce(ctx)
end

function M.func(key, env)
  enforce(env.engine.context)
  local name = repr(key)
  -- tmux prefix: the next key belongs to tmux. Forwarding it untouched avoids
  -- opening a candidate window that delays the shortcut by a whole compose.
  -- WezTerm normally handles the prefix itself, so this is a safety net.
  if name == 'Control+b' or name == 'Control+space' then
    env.pi_prefix_until = os.time() + HOLD_SECONDS
    return 2 -- kNoop: let the terminal see the prefix key
  end
  if env.pi_prefix_until then
    local active = os.time() <= env.pi_prefix_until
    env.pi_prefix_until = nil
    if active then return 1 end -- kAccept: hand the key straight to tmux
  end
  return 2 -- kNoop: preserve key handling, uppercase/chords and composition.
end

function M.fini(env)
  if env.pi_chinese_connection then env.pi_chinese_connection:disconnect() end
end
return M
