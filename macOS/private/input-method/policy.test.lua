local P = dofile(arg[1] or 'policy.lua')
local now = 1000
local terminal = { pane = 0, tty = '/dev/ttys001', pid = 42 }
local pi = { pid = 42, editing = true, updated = now, weztermPane = '0' }
local function want(bundle, term, clients, contexts, memory, prefixHeld)
  return P.desired(bundle, term, clients or {}, contexts or {}, now, memory or {}, prefixHeld)
end
assert(want('org.gnu.Emacs', terminal, {}, { pi }) == P.ABC)
assert(want('com.abueammar.tinycast', terminal, {}, { pi }) == P.ABC)
assert(want('com.tinycast.app', terminal, {}, { pi }) == P.ABC)
assert(want('com.tinycast.app.dictation', terminal, {}, { pi }) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, { pi }) == P.RIME)
terminal.blocked = true
assert(want(P.WEZTERM, terminal, {}, { pi }) == P.ABC)
terminal.blocked = false
assert(want(P.WEZTERM, { pane=1, pid=77, tty='/dev/ttys002' }, {}, { pi }) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, {{pid=42, editing=false, updated=now, weztermPane='0'}}) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, {{pid=42, editing=true, updated=now-8, weztermPane='0'}}) == P.ABC)
local memory = { ['com.tencent.xinWeChat'] = P.RIME }
assert(want('com.tencent.xinWeChat', terminal, {}, {}, memory) == P.RIME)
assert(want('com.abueammar.tinycast', terminal, {}, {}, {
  ['com.abueammar.tinycast'] = P.RIME,
}) == P.ABC, 'Tinycast must use ABC even when a Chinese source was remembered')
assert(want('com.tinycast.app', terminal, {}, {}, memory) == P.ABC)
assert(want('com.tencent.xinWeChat', terminal, {}, {}, memory) == P.RIME)
local client = { client_tty='/dev/ttys001', pane_id='%3', pane_tty='/dev/ttys004',
  foreground_pid=88, socket='/private/tmp/tmux-501/default', pane_in_mode='0',
  client_prefix='0', client_key_table='root', updated=now }
local tmuxPi = { pid=88, editing=true, updated=now, tmuxPane='%3', socket='/tmp/tmux-501/default' }
assert(want(P.WEZTERM, terminal, {client}, {pi,tmuxPi}) == P.RIME)
client.pane_id='%4'
assert(want(P.WEZTERM, terminal, {client}, {pi,tmuxPi}) == P.ABC)
client.pane_id='%3'; client.pane_in_mode='1'
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}) == P.ABC)
client.pane_in_mode='0'; client.client_prefix='1'
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}) == P.ABC)
client.client_prefix='0'
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}, nil, true) == P.ABC)
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}) == P.RIME)
local nested = { client_tty='/dev/ttys004', pane_id='%8', pane_tty='/dev/ttys009',
  foreground_pid=99, socket='/tmp/tmux-501/nested', pane_in_mode='0',
  client_prefix='0', client_key_table='root', updated=now }
local stale = { client_tty='/dev/ttys004', pane_id='%9', pane_tty='/dev/ttys010',
  foreground_pid=100, socket='/tmp/tmux-501/imetest', pane_in_mode='0',
  client_prefix='0', client_key_table='root', updated=now-30 }
assert(want(P.WEZTERM, terminal, {client,stale}, {tmuxPi}) == P.RIME)
local nestedPi = {pid=99, editing=true, updated=now, tmuxPane='%8', socket='/tmp/tmux-501/nested'}
assert(want(P.WEZTERM, terminal, {client,nested}, {tmuxPi,nestedPi}) == P.RIME)
-- Ghostty: the window title pushed by tmux identifies the client.
local titled = { client_tty = '/dev/ttys001', pane_id = '%3', pane_tty = '/dev/ttys004',
  foreground_pid = 88, socket = '/private/tmp/tmux-501/default', pane_in_mode = '0',
  client_prefix = '0', client_key_table = 'root', updated = now,
  host = 'deck', session_name = '0', window_name = 'pi' }
local ghterm = { title = 'tmux:/private/tmp/tmux-501/default:/dev/ttys001' }
assert(P.isTerminal(P.GHOSTTY) and P.isTerminal(P.WEZTERM))
assert(P.managed(P.GHOSTTY))
assert(want(P.GHOSTTY, ghterm, {titled}, {tmuxPi}, nil, false) == P.RIME)
titled.pane_unfocused = '1'
assert(want(P.GHOSTTY, ghterm, {titled}, {tmuxPi}) == P.ABC)
titled.pane_unfocused = ''
assert(want(P.GHOSTTY, ghterm, {titled}, {tmuxPi}) == P.RIME)
assert(want(P.GHOSTTY, { title = 'keke@deck ~' }, {titled}, {tmuxPi}, nil, false) == nil,
  'unidentified Ghostty window must allow manual Chinese selection')
local held = { client_tty = '/dev/ttys001', pane_id = '%3', pane_tty = '/dev/ttys004',
  foreground_pid = 88, socket = '/private/tmp/tmux-501/default', pane_in_mode = '0',
  client_prefix = '1', client_key_table = 'prefix', updated = now,
  host = 'deck', session_name = '0', window_name = 'pi' }
assert(want(P.GHOSTTY, ghterm, {held}, {tmuxPi}, nil, false) == P.ABC)
assert(want(P.GHOSTTY, ghterm, {titled}, {tmuxPi}, nil, true) == P.ABC)
-- Two clients on the same session/window still have distinct focus tokens.
local other = { client_tty = '/dev/ttys005', pane_id = '%9', pane_tty = '/dev/ttys006',
  foreground_pid = 77, socket = '/private/tmp/tmux-501/default', pane_in_mode = '0',
  client_prefix = '0', client_key_table = 'root', updated = now,
  host = 'deck', session_name = '0', window_name = 'pi' }
local otherPi = { pid = 77, editing = true, updated = now, tmuxPane = '%9',
  socket = '/private/tmp/tmux-501/default' }
assert(want(P.GHOSTTY, { title = 'tmux:/private/tmp/tmux-501/default:/dev/ttys005' }, {titled, other}, {tmuxPi}, nil, false) == P.ABC)
assert(want(P.GHOSTTY, { title = 'tmux:/private/tmp/tmux-501/default:/dev/ttys005' }, {titled, other}, {tmuxPi, otherPi}, nil, false) == P.RIME)

-- Ghostty's native AppleScript API supplies foreground PID + TTY, no tmux.
local direct = {native=true, pane='surface-1', pid=42, tty='/dev/ttys020'}
local directPi = {pid=42, editing=true, updated=now}
assert(want(P.GHOSTTY, direct, {}, {directPi}) == P.RIME)
assert(want(P.GHOSTTY, direct, {}, {}) == P.ABC)
assert(want(P.GHOSTTY, direct, {}, {{pid=42, editing=false, updated=now}}) == P.ABC)
assert(want(P.GHOSTTY, direct, {}, {{pid=43, editing=true, updated=now}}) == P.ABC)
assert(want(P.GHOSTTY, direct, {}, {{pid=42, editing=true, updated=now-8}}) == P.ABC)
local token = {title='pi-ime:42:surface-a'}
local tokenPi = {pid=42, ghosttySurface='surface-a', editing=true, updated=now}
assert(want(P.GHOSTTY, token, {}, {tokenPi}) == P.RIME)
assert(want(P.GHOSTTY, token, {}, {{pid=42, ghosttySurface='surface-b', editing=true, updated=now}}) == P.ABC)
assert(want(P.GHOSTTY, token, {}, {{pid=42, ghosttySurface='surface-a', editing=false, updated=now}}) == P.ABC)
assert(want(P.GHOSTTY, token, {}, {{pid=42, ghosttySurface='surface-a', editing=true, updated=now-8}}) == P.ABC)
assert(want(P.GHOSTTY, {title='ghostty-shell:surface-a'}, {}, {tokenPi}) == P.ABC)
-- Startup/job layout must not matter: PID is preference only. Container
-- identity + editing + freshness remain required, so fish -c pi job groups
-- and restarted Pis stay Chinese while other panes/surfaces stay isolated.
local drifted = {pid=777, editing=true, updated=now, tmuxPane='%3', socket='/tmp/tmux-501/default'}
assert(want(P.WEZTERM, terminal, {client}, {drifted}) == P.RIME)
assert(want(P.WEZTERM, terminal, {client}, {{pid=777, editing=true, updated=now-8,
  tmuxPane='%3', socket='/tmp/tmux-501/default'}}) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, {{pid=777, editing=true, updated=now, weztermPane='0'}}) == P.RIME)
local fallback = {pid=43, ghosttySurface='surface-a', editing=true, updated=now}
assert(want(P.GHOSTTY, token, {}, {fallback}) == P.RIME)
assert(want(P.GHOSTTY, token, {}, {{pid=43, ghosttySurface='surface-a', editing=true, updated=now-8}}) == P.ABC)
assert(P.piContext(token, {}, {fallback, tokenPi}, now) == tokenPi, 'exact PID preferred over fallback')
print('input-method policy: tmux/native/direct Ghostty/context/lease assertions passed')
