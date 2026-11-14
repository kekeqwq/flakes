local guard = dofile(arg[1])
local callbacks = {}
local ctx = { options = {ascii_mode=true} }
function ctx:get_option(name) return self.options[name] == true end
function ctx:set_option(name, value)
  self.options[name] = value
  for _, cb in pairs(callbacks) do cb(self, name) end
end
ctx.option_update_notifier = {}
function ctx.option_update_notifier:connect(cb)
  callbacks[1] = cb
  return {disconnect=function() callbacks[1]=nil end}
end
local env = {engine={context=ctx}}
guard.init(env)
assert(ctx:get_option('ascii_mode'), 'other apps keep ASCII mode')
assert(guard.func({}, env) == 2)
assert(ctx:get_option('ascii_mode'), 'other apps are not locked')
ctx:set_option('_pi_chinese_lock', true)
assert(not ctx:get_option('ascii_mode'), 'WezTerm session enters Chinese immediately')
ctx:set_option('ascii_mode', true)
assert(not ctx:get_option('ascii_mode'), 'Shift cannot leave a Pi session in ASCII mode')
ctx:set_option('ascii_mode', true)
assert(not ctx:get_option('ascii_mode'), 'enforcement is idempotent, not toggle')
ctx:set_option('_pi_chinese_lock', false)
ctx:set_option('ascii_mode', true)
assert(ctx:get_option('ascii_mode'), 'disabling guard restores ordinary behavior')
guard.fini(env)
assert(next(callbacks)==nil, 'disconnect on schema destruction')

-- tmux prefix passthrough: no candidate window before tmux gets the key.
local function key(name)
  return { repr = function() return name end, release = function() return false end }
end
guard.fini(env)
local env2 = {engine={context=ctx}}
guard.init(env2)
ctx:set_option('_pi_chinese_lock', true)
-- librime Processor::ProcessResult: rejected=0, accepted=1, noop=2.
-- Engine::ProcessKey returns false on rejected (OS receives the key),
-- true on accepted (consumed), and continues processors on noop.
local function reachesTerminal(name)
  local result = guard.func(key(name), env2)
  assert(result ~= 1, 'shortcut must never be consumed by this processor')
  return result == 0
end
assert(reachesTerminal('Control+b'), 'prefix itself reaches the terminal')
assert(guard.func(key('Release+Control+b'), env2) == 2, 'release preserves pending passthrough')
assert(reachesTerminal('c'), 'next key is forwarded, not composed')
assert(guard.func(key('c'), env2) == 2, 'hold is single-shot')
assert(reachesTerminal('Control+space'))
assert(reachesTerminal('v'))
assert(reachesTerminal('Control+b'))
env2.pi_prefix_until = os.time() - 1
assert(guard.func(key('x'), env2) == 2, 'expired hold permits ordinary composition')
ctx:set_option('_pi_chinese_lock', false)
assert(guard.func(key('Control+b'), env2) == 2, 'other apps retain their processors')
assert(env2.pi_prefix_until == nil)
print('Pi native Chinese guard: passthrough/scope/release/expiry assertions passed')
