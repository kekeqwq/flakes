-- Nix-managed. Edit common/input-method/* in flakes, not this generated link.
require('hs.ipc')
local policy = require('ime_policy')
local log = hs.logger.new('input-method', 'info')
local root = os.getenv('HOME') .. '/.local/state/input-method'
local memories = hs.settings.get('input-method.memories') or {}
local active, generation = nil, 0
local pending, verify
local nativeTask, nativeKey, nativeApplied, nativeExit
local nativeAttempts = 0
local actuator = '@INPUT_SOURCE_SELECT@'
local M = { events = {} }
local function note(kind, detail)
  table.insert(M.events, {time=hs.timer.secondsSinceEpoch(), kind=kind, detail=detail})
  if #M.events > 60 then table.remove(M.events, 1) end
end

local function readJSON(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local data = file:read(65536); file:close()
  local ok, value = pcall(hs.json.decode, data)
  if ok and type(value) == 'table' then return value end
end
local function records(directory, key)
  local result = {}
  for name in hs.fs.dir(directory) do
    if name:match('^[^%.].*%.json$') then
      local value = readJSON(directory .. '/' .. name)
      if value then
        if key then
          for _, entry in ipairs(value[key] or {}) do table.insert(result, entry) end
        else table.insert(result, value) end
      end
    end
  end
  return result
end
local function frontBundle()
  local app = hs.application.frontmostApplication()
  -- Tinycast is a nonactivating AXSystemDialog: macOS still reports WeChat
  -- as frontmost. Prefer the owner of the actual focused AX text field.
  local ok, pid = pcall(function()
    local element = hs.axuielement.systemWideElement():attributeValue('AXFocusedUIElement')
    return element and element:pid()
  end)
  local owner = ok and pid and hs.application.applicationForPID(pid)
  if not owner then
    local window = hs.window.focusedWindow()
    owner = window and window:application()
  end
  if owner and (owner:bundleID() or ''):find('tinycast', 1, true) then app = owner end
  return app and app:bundleID()
end
local function desired()
  local bundle = frontBundle()
  if not bundle then return nil end
  return policy.desired(bundle, readJSON(root .. '/wezterm.json'),
                        records(root .. '/tmux', 'clients'), records(root .. '/pi'),
                        hs.timer.secondsSinceEpoch(), memories)
end
local function cancel(timer) if timer then timer:stop() end end

local function cancelNative()
  local task = nativeTask
  nativeTask = nil
  if task then note('cancel', nativeKey); task:terminate() end
end
local function selectTerminal(want, context)
  local terminal = readJSON(root .. '/wezterm.json') or {}
  local key = want .. ':' .. tostring(context and context.pid) .. ':' .. tostring(terminal.window) .. ':' .. tostring(terminal.pane)
  if nativeKey ~= key then
    cancelNative(); nativeKey = key; nativeApplied = nil; nativeAttempts = 0
  end
  if nativeTask or (nativeApplied == key and hs.keycodes.currentSourceID() == want)
      or nativeAttempts >= 3 then return end
  local app = hs.application.get(policy.WEZTERM)
  if not app then return end
  nativeAttempts = nativeAttempts + 1
  note('request', key)
  local task
  task = hs.task.new(actuator, function(code, _, stderr)
    if nativeTask ~= task then return end
    nativeTask = nil
    nativeExit = code
    note('complete', tostring(code) .. ':' .. key)
    if code == 0 then nativeApplied = key; nativeAttempts = 0
    elseif code ~= 75 then log.w('Focused-app IME selection failed: ' .. tostring(code) .. ' ' .. stderr) end
  end, {want, tostring(app:pid())})
  if task then
    task:setEnvironment({HOME=os.getenv('HOME'), USER=os.getenv('USER'),
      TMPDIR=os.getenv('TMPDIR'), PATH='/usr/bin:/bin:/usr/sbin:/sbin'})
  end
  nativeTask = task
  if not task or not task:start() then nativeTask = nil; log.w('Cannot launch focused-app IME selector') end
end

local function apply(attempt)
  attempt = attempt or 0
  local bundle = frontBundle()
  if not bundle then return end
  if bundle ~= active then
    note('app', bundle)
    active = bundle
    generation = generation + 1
    if not policy.managed(bundle) and not memories[bundle] then
      memories[bundle] = hs.keycodes.currentSourceID()
      hs.settings.set('input-method.memories', memories)
    end
  end
  local want, context = desired()
  if bundle == policy.WEZTERM and want then
    selectTerminal(want, context)
    return
  end
  cancelNative(); nativeKey = nil; nativeApplied = nil; nativeAttempts = 0
  if not want then return end
  local token = generation
  if hs.keycodes.currentSourceID() ~= want then
    note('TIS', bundle .. ':' .. want)
    if not hs.keycodes.currentSourceID(want) then
      log.w('Cannot select input source ' .. want)
    end
    cancel(verify)
    if attempt < 2 then
      verify = hs.timer.doAfter(0.15, function()
        if generation == token and frontBundle() == bundle then apply(attempt + 1) end
      end)
    end
  end
end
local function schedule()
  generation = generation + 1
  cancel(pending)
  cancel(verify)
  pending = hs.timer.doAfter(0.02, function() apply() end)
end

M.appWatcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.activated then schedule() end
end):start()
M.windowWatcher = hs.window.filter.new(true):setDefaultFilter({allowRoles='*'}):subscribe({
  hs.window.filter.windowFocused, hs.window.filter.windowUnfocused,
  hs.window.filter.windowVisible, hs.window.filter.windowNotVisible,
  hs.window.filter.windowDestroyed,
}, schedule)
M.fileWatcher = hs.pathwatcher.new(root, schedule):start()
-- Expire a crashed Pi's lease; stable policy does not cause any IME switches.
M.leaseTimer = hs.timer.doEvery(0.2, function()
  local bundle = frontBundle()
  -- Also detect nonactivating panels closing; no application activation is
  -- emitted then. An unchanged app/policy never makes a native source switch.
  if bundle ~= active or bundle == policy.WEZTERM then apply() end
end)
hs.keycodes.inputSourceChanged(function()
  local bundle = frontBundle()
  note('source', tostring(bundle) .. ':' .. tostring(hs.keycodes.currentSourceID()))
  if bundle and bundle == active and not policy.managed(bundle) then
    memories[bundle] = hs.keycodes.currentSourceID()
    hs.settings.set('input-method.memories', memories)
  end
  if bundle and policy.managed(bundle) then schedule() end
end)
-- Native Squirrel sessions enforce Chinese via pi_chinese_lock.lua.
-- No synthetic keystrokes: WezTerm may consume control/function keys before IME.

function M.status()
  local want, context = desired()
  return { front = frontBundle(), source = hs.keycodes.currentSourceID(),
           desired = want, pi = context and context.pid, trusted = hs.accessibilityState(),
           nativePending = nativeTask ~= nil, nativeContext = nativeApplied,
           nativeExit = nativeExit, nativeAttempts = nativeAttempts }
end
function M.stop()
  cancel(pending); cancel(verify); cancelNative()
  M.appWatcher:stop(); M.windowWatcher:unsubscribeAll(); M.fileWatcher:stop()
  M.leaseTimer:stop()
  hs.keycodes.inputSourceChanged(nil)
end
_G.inputMethodManager = M
hs.shutdownCallback = M.stop
schedule()
log.i('Input method manager loaded; macOS Accessibility permission is required.')
