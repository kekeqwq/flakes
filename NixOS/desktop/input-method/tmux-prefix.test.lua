local clock, lease, app = 1000, 'tmux 1000', 'ghostty'
local oldTime, oldOpen, oldEnv = os.time, io.open, os.getenv
os.time = function() return clock end
os.getenv = function(name) if name == 'HOME' then return '/test' end; return oldEnv(name) end
io.open = function(path)
  assert(path == '/test/.local/state/input-method/tmux-prefix-context')
  if not lease then return nil end
  return {read=function() return lease end, close=function() end}
end
local guard = dofile(arg[1])
local env = {engine={context={get_property=function(_, name)
  assert(name == 'client_app'); return app
end}}}
local function key(name) return guard.func({repr=function() return name end}, env) end
assert(key('a') == 2)
assert(key('Control+b') == 0)
assert(key('Release+Control+b') == 2)
assert(key('Release+Control_L') == 2)
assert(key('c') == 0, 'next press goes to tmux, not Rime')
assert(key('c') == 2, 'single-shot, ordinary composition resumes')
assert(key('Control+space') == 0)
assert(key('Escape') == 0)
assert(key('a') == 2)
assert(key('Control+b') == 0)
app = 'emacs'
assert(key('c') == 2)
app = 'ghostty'
assert(key('c') == 2, 'pending state cannot leak across apps')
lease = 'other 1000'
assert(key('Control+b') == 2, 'direct Pi/shell is not tmux')
lease = 'tmux 990'
assert(key('Control+b') == 2, 'expired watcher state is not authority')
lease = 'tmux 1010'
assert(key('Control+b') == 2, 'future state is rejected')
lease = nil
assert(key('Control+b') == 2)
lease = 'tmux 1000'
assert(key('Control+b') == 0)
clock = 1004
assert(key('c') == 2)
app = 'com.mitchellh.ghostty'; clock = 1000
assert(key('Control+b') == 0)
assert(key('c') == 0)
app = '' -- Native Wayland frontend: focus is identified by Niri instead.
assert(key('Control+b') == 0)
assert(key('c') == 0)
lease = 'other 1000'
assert(key('Control+b') == 2, 'empty app does not grant a lease to other windows')
local reset, disconnected
lease = 'tmux 1000'
env.engine.context.update_notifier = {connect=function(_, callback)
  reset = callback
  return {disconnect=function() disconnected = true end}
end}
guard.init(env)
assert(key('Control+b') == 0)
reset()
assert(key('c') == 2, 'deactivation/reset must clear pending passthrough')
guard.fini(env)
assert(disconnected, 'schema teardown disconnects notifier')
os.time, io.open, os.getenv = oldTime, oldOpen, oldEnv
print('Linux Rime prefix: passthrough/release/scope/lease/expiry PASS')
