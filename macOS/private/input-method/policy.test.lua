local P = dofile(arg[1] or 'policy.lua')
local now = 1000
local terminal = { pane = 0, tty = '/dev/ttys001', pid = 42 }
local pi = { pid = 42, editing = true, updated = now, weztermPane = '0' }
local function want(bundle, term, clients, contexts, memory)
  return P.desired(bundle, term, clients or {}, contexts or {}, now, memory or {})
end
assert(want('org.gnu.Emacs', terminal, {}, { pi }) == P.ABC)
assert(want('com.tinycast.app', terminal, {}, { pi }) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, { pi }) == P.RIME)
terminal.blocked = true
assert(want(P.WEZTERM, terminal, {}, { pi }) == P.ABC)
terminal.blocked = false
assert(want(P.WEZTERM, { pane=1, pid=77, tty='/dev/ttys002' }, {}, { pi }) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, {{pid=42, editing=false, updated=now, weztermPane='0'}}) == P.ABC)
assert(want(P.WEZTERM, terminal, {}, {{pid=42, editing=true, updated=now-8, weztermPane='0'}}) == P.ABC)
local memory = { ['com.tencent.xinWeChat'] = P.RIME }
assert(want('com.tencent.xinWeChat', terminal, {}, {}, memory) == P.RIME)
assert(want('com.tinycast.app', terminal, {}, {}, memory) == P.ABC)
assert(want('com.tencent.xinWeChat', terminal, {}, {}, memory) == P.RIME)
local client = { client_tty='/dev/ttys001', pane_id='%3', pane_tty='/dev/ttys004',
  foreground_pid=88, socket='/private/tmp/tmux-501/default', pane_in_mode='0',
  client_prefix='0', client_key_table='root' }
local tmuxPi = { pid=88, editing=true, updated=now, tmuxPane='%3', socket='/tmp/tmux-501/default' }
assert(want(P.WEZTERM, terminal, {client}, {pi,tmuxPi}) == P.RIME)
client.pane_id='%4'
assert(want(P.WEZTERM, terminal, {client}, {pi,tmuxPi}) == P.ABC)
client.pane_id='%3'; client.pane_in_mode='1'
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}) == P.ABC)
client.pane_in_mode='0'; client.client_prefix='1'
assert(want(P.WEZTERM, terminal, {client}, {tmuxPi}) == P.ABC)
client.client_prefix='0'
local nested = { client_tty='/dev/ttys004', pane_id='%8', pane_tty='/dev/ttys009',
  foreground_pid=99, socket='/tmp/tmux-501/nested', pane_in_mode='0',
  client_prefix='0', client_key_table='root' }
local nestedPi = {pid=99, editing=true, updated=now, tmuxPane='%8', socket='/tmp/tmux-501/nested'}
assert(want(P.WEZTERM, terminal, {client,nested}, {tmuxPi,nestedPi}) == P.RIME)
print('input-method policy: 15 transition/restore/tmux/lease assertions passed')
