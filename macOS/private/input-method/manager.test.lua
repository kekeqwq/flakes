-- Hammerspoon API-shape/lifecycle smoke test; real GUI tests are separate.
local queue, requests = {}, {}
local source, bundle = 'com.apple.keylayout.ABC', 'com.github.wez.wezterm'
local want = 'im.rime.inputmethod.Squirrel.Hans'
local tick
local windowTitle = 'tmux:/tmp/default:/dev/ttys001'
local focusReads = 0
local function object()
  return setmetatable({}, {__index=function(_, name)
    return function(self) return self end
  end})
end
local function later(fn)
  local t = {stopped=false}
  function t:stop() self.stopped=true end
  queue[#queue+1]=function() if not t.stopped then fn() end end
  return t
end
local app = {bundleID=function() return bundle end, pid=function() return 4242 end}
package.preload['hs.ipc'] = function() return {} end
package.preload['ime_policy'] = function() return {
  ABC='com.apple.keylayout.ABC', RIME='im.rime.inputmethod.Squirrel.Hans', WEZTERM='com.github.wez.wezterm',
  GHOSTTY='com.mitchellh.ghostty',
  isTerminal=function(b) return b=='com.github.wez.wezterm' or b=='com.mitchellh.ghostty' end,
  managed=function() return true end,
  desired=function(b, terminal)
    if b=='com.mitchellh.ghostty' and windowTitle == 'direct Pi' then
      if not terminal then return nil end
      assert(terminal.native and terminal.pid==42 and terminal.tty=='/dev/ttys020')
    end
    if b=='com.github.wez.wezterm' or b=='com.mitchellh.ghostty' then return want, want:find('Squirrel') and {pid=123} or nil end
    return 'com.apple.keylayout.ABC'
  end,
} end
hs = {
  logger={new=function() return {w=function() end,i=function() end} end},
  settings={get=function() end,set=function() end},
  fs={dir=function() return function() end end},
  json={decode=function() return {} end},
  application={frontmostApplication=function() return app end, get=function() return app end,
    watcher={activated=1,new=function() return object() end}},
  axuielement={systemWideElement=function() return {attributeValue=function() end} end},
  window={focusedWindow=function() return {title=function() return windowTitle end, id=function() return 1 end,
    application=function() return app end} end,
    filter={new=function() return object() end}},
  pathwatcher={new=function() return object() end},
  accessibilityState=function() return true end,
  timer={secondsSinceEpoch=function() return 1000 end,
    doAfter=function(_,fn) return later(fn) end,
    doEvery=function(_,fn) tick=fn;return object() end},
  keycodes={currentSourceID=function(value) if value then source=value;return true end; return source end,
    inputSourceChanged=function() end},
  task={new=function(path, callback, args, ...)
    if path=='/usr/bin/osascript' then
      focusReads=focusReads+1
      local task=object()
      function task:start()
        later(function() callback(0, 'surface-1\t42\t/dev/ttys020\n', '') end)
        return self
      end
      return task
    end
    assert(select('#',...)==0, 'hs.task.new: args must be argument 3, not nil + argument 4')
    assert(type(args)=='table' and args[2]=='4242')
    requests[#requests+1]=args
    local task = object()
    function task:setEnvironment(env)
      assert(env.__CFBundleIdentifier==nil, 'do not inherit Hammerspoon Cocoa identity')
      return self
    end
    function task:start() later(function() source=args[1];callback(0,'','') end);return self end
    return task
  end},
}
local function drain()
  local count=0
  while #queue>0 do
    count=count+1;assert(count<30)
    table.remove(queue,1)()
  end
end
dofile(arg[1]);drain()
assert(#requests==1 and source==want)
assert(inputMethodManager.status().nativeExit==0)
for _=1,10 do tick();drain() end
assert(#requests==1, 'stable editor must not respawn selectors')
want='com.apple.keylayout.ABC';tick();drain()
assert(#requests==2 and source==want, 'ordinary tab uses focused-app ABC request')
want='im.rime.inputmethod.Squirrel.Hans';tick();drain()
assert(#requests==3 and source==want, 'returning to Pi reactivates actual IME')
bundle='org.gnu.Emacs';tick();drain()
assert(#requests==3 and source=='com.apple.keylayout.ABC', 'preserve existing Emacs rule')
bundle='com.mitchellh.ghostty';tick();drain()
assert(#requests==4 and source==want, 'Ghostty uses the focused terminal actuator')
for _=1,10 do tick();drain() end
assert(#requests==4, 'stable Ghostty editor must not respawn selectors')
windowTitle='direct Pi';want='com.apple.keylayout.ABC';tick();drain()
assert(focusReads==1 and #requests==5 and source==want, 'native focus query resolves direct shell')
want='im.rime.inputmethod.Squirrel.Hans';tick();drain()
assert(#requests==6 and source==want, 'direct Pi editor can activate Chinese')
inputMethodManager.stop()
print('Hammerspoon actuator/native Ghostty API/lifecycle: PASS')
