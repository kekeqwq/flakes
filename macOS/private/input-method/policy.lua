-- Pure state policy. No Hammerspoon/OS calls; also exercised by Lua tests.
local M = {}
M.ABC = 'com.apple.keylayout.ABC'
M.RIME = 'im.rime.inputmethod.Squirrel.Hans'
M.WEZTERM = 'com.github.wez.wezterm'
M.GHOSTTY = 'com.mitchellh.ghostty'
function M.isTerminal(bundle)
  return bundle == M.WEZTERM or bundle == M.GHOSTTY
end
function M.managed(bundle)
  return bundle == 'org.gnu.Emacs' or bundle == 'com.tinycast.app'
    or bundle == 'com.tinycast.app.dictation' or M.isTerminal(bundle)
end
local function socketName(path)
  return (path or ''):gsub('^/private/tmp/', '/tmp/')
end
local function blocked(client)
  return client.pane_in_mode == '1' or client.client_prefix == '1'
    or (client.client_key_table ~= 'root' and client.client_key_table ~= '')
end
-- The terminal title pushed by tmux identifies its socket and client tty.
local function fresh(client, now)
  -- Ignore leftover snapshots from dead tmux sockets.
  return type(client.updated) == 'number' and now - client.updated < 7
    and now >= client.updated - 1
end
local function clientForTitle(title, clients, now)
  if not title or title == '' then return nil end
  for _, client in ipairs(clients) do
    if fresh(client, now) then
      local expected = 'tmux:' .. tostring(client.socket or '') .. ':' .. tostring(client.client_tty or '')
      if title == expected then return client end
    end
  end
  return nil
end
local function walk(first, clients, now)
  local current = first
  local tty, pid, tmuxPane, socket
  for _ = 1, 4 do
    if blocked(current) then return nil end
    tty, pid = current.pane_tty, tonumber(current.foreground_pid)
    tmuxPane, socket = current.pane_id, current.socket
    local nxt
    for _, client in ipairs(clients) do
      if fresh(client, now) and client.client_tty == tty then nxt = client; break end
    end
    if not nxt or nxt == current then break end
    current = nxt
  end
  return tty, pid, tmuxPane, socket
end
local function directIdentity(title)
  local pid, surface = (title or ''):match('^pi%-ime:([1-9]%d*):([%w%-]+)$')
  if pid and #surface <= 64 then return tonumber(pid), surface end
end
local function shellIdentity(title)
  local surface = (title or ''):match('^ghostty%-shell:([%w%-]+)$')
  return surface and #surface <= 64
end
function M.piContext(terminal, clients, contexts, now)
  if not terminal or terminal.blocked then return nil end
  local directPid, surface = directIdentity(terminal.title)
  if directPid then
    for _, ctx in ipairs(contexts) do
      if ctx.pid == directPid and ctx.ghosttySurface == surface and not ctx.tmuxPane
          and ctx.editing == true and fresh(ctx, now) then return ctx end
    end
    return nil
  end
  local tty, pid, tmuxPane, socket
  if terminal.title then
    -- Ghostty: the window title identifies the focused client.
    local seed = clientForTitle(terminal.title, clients, now)
    if not seed then return nil end
    tty, pid, tmuxPane, socket = walk(seed, clients, now)
    if not tty then return nil end
  else
    -- WezTerm: the reported pane tty identifies it; follow nested tmux too.
    tty, pid = terminal.tty, terminal.pid
    local found
    for _, client in ipairs(clients) do
      if fresh(client, now) and client.client_tty == tty then found = client; break end
    end
    if found then
      tty, pid, tmuxPane, socket = walk(found, clients, now)
      if not tty then return nil end
    else
      tmuxPane, socket = nil, nil
    end
  end
  for _, ctx in ipairs(contexts) do
    if ctx.pid == pid and ctx.editing == true and type(ctx.updated) == 'number'
        and now - ctx.updated < 7 and now >= ctx.updated - 1 then
      if tmuxPane then
        if ctx.tmuxPane == tmuxPane and socketName(ctx.socket) == socketName(socket) then return ctx end
      elseif not ctx.tmuxPane and (terminal.native or tostring(ctx.weztermPane) == tostring(terminal.pane)) then return ctx end
    end
  end
  return nil
end
function M.desired(bundle, terminal, clients, contexts, now, memories, prefixHeld)
  -- Prefix is armed for a shortcut, or the user has not cancelled it yet.
  if M.isTerminal(bundle) and prefixHeld then return M.ABC end
  if bundle == M.GHOSTTY and shellIdentity(terminal and terminal.title) then return M.ABC end
  if bundle == M.GHOSTTY and directIdentity(terminal and terminal.title) then
    local ctx = M.piContext(terminal, clients, contexts, now)
    return ctx and M.RIME or M.ABC, ctx
  end
  -- Until a surface is identified, preserve manual source selection rather
  -- than trapping direct shells/Pi in ABC. Identified tmux keeps its policy.
  if bundle == M.GHOSTTY and not (terminal and terminal.native)
      and not clientForTitle(terminal and terminal.title, clients, now) then
    return nil
  end
  if M.isTerminal(bundle) then
    local ctx = M.piContext(terminal, clients, contexts, now)
    return ctx and M.RIME or M.ABC, ctx
  end
  if M.managed(bundle) then return M.ABC end
  return memories[bundle]
end
return M
