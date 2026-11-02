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
print('Pi native Chinese guard: 8 assertions passed')
