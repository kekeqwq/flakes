-- Native Squirrel session guard, not an input-source switcher.
-- Hammerspoon chooses Squirrel only for Pi text input; ordinary tabs use ABC.
-- Squirrel app_options sets this private flag ONLY on its WezTerm sessions.
local M = {}
local function enforce(ctx)
  if ctx:get_option('_pi_chinese_lock') and ctx:get_option('ascii_mode') then
    ctx:set_option('ascii_mode', false)
  end
end
function M.init(env)
  local ctx = env.engine.context
  env.pi_chinese_connection = ctx.option_update_notifier:connect(function(context, name)
    if name == 'ascii_mode' or name == '_pi_chinese_lock' then enforce(context) end
  end)
  enforce(ctx)
end
function M.func(_, env)
  enforce(env.engine.context)
  return 2 -- kNoop: preserve key handling, uppercase/chords and composition.
end
function M.fini(env)
  if env.pi_chinese_connection then env.pi_chinese_connection:disconnect() end
end
return M
