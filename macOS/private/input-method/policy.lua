-- Pure state policy. No Hammerspoon/OS calls; also exercised by Lua tests.
local M = {}
M.ABC = 'com.apple.keylayout.ABC'
M.RIME = 'im.rime.inputmethod.Squirrel.Hans'
M.WEZTERM = 'com.github.wez.wezterm'
function M.managed(bundle)
  return bundle == 'org.gnu.Emacs' or bundle == 'com.tinycast.app'
    or bundle == 'com.tinycast.app.dictation' or bundle == M.WEZTERM
end
local function socketName(path)
  return (path or ''):gsub('^/private/tmp/', '/tmp/')
end
function M.piContext(terminal, clients, contexts, now)
  if not terminal or terminal.blocked then return nil end
  local tty, pid, tmuxPane, socket = terminal.tty, terminal.pid, nil, nil
  -- Follow nested tmux clients too. Only the active client pane counts.
  for _ = 1, 4 do
    local found
    for _, client in ipairs(clients) do
      -- Ignore leftover snapshots from dead tmux sockets. Their client_tty
      -- can collide with a live pane and steal the nested walk to ABC.
      if type(client.updated) == 'number' and now - client.updated < 7
          and now >= client.updated - 1 and client.client_tty == tty then
        found = client; break
      end
    end
    if not found then break end
    if found.pane_in_mode == '1' or found.client_prefix == '1'
        or (found.client_key_table ~= 'root' and found.client_key_table ~= '') then return nil end
    tty, pid = found.pane_tty, tonumber(found.foreground_pid)
    tmuxPane, socket = found.pane_id, found.socket
  end
  for _, ctx in ipairs(contexts) do
    if ctx.pid == pid and ctx.editing == true and type(ctx.updated) == 'number'
        and now - ctx.updated < 7 and now >= ctx.updated - 1 then
      if tmuxPane then
        if ctx.tmuxPane == tmuxPane and socketName(ctx.socket) == socketName(socket) then return ctx end
      elseif not ctx.tmuxPane and tostring(ctx.weztermPane) == tostring(terminal.pane) then
        return ctx
      end
    end
  end
  return nil
end
function M.desired(bundle, terminal, clients, contexts, now, memories, prefixHeld)
  -- Prefix is armed for a shortcut, or the user has not cancelled it yet.
  if bundle == M.WEZTERM and prefixHeld then return M.ABC end
  if bundle == M.WEZTERM then
    local ctx = M.piContext(terminal, clients, contexts, now)
    return ctx and M.RIME or M.ABC, ctx
  end
  if M.managed(bundle) then return M.ABC end
  return memories[bundle]
end
return M
