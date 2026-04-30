local winMR = require 'windowMoveResize'
local mouseHotkey = require 'mouseHotkey'
local windowUtil = require 'windowUtil'

local super = { 'ctrl', 'cmd' }
local superAlt = { 'ctrl', 'cmd', 'alt' }
local superShift = { 'ctrl', 'cmd', 'shift' }

-- super + alt + r 重载配置
hs.hotkey.bind(superAlt, 'r', function() hs.reload() end)

-- 需要“仅关闭窗口”绝不退出的应用名单
local ONLY_CLOSE_APPS = {
  ['微信'] = true,
  ['QQ'] = true,
  ['访达'] = true,
  ['Raycast'] = true,
  ['PixPin'] = true,
}
--------------------------------------------------------------------------------
-- 窗口操作
--------------------------------------------------------------------------------
mouseHotkey.hotkeyBindWithMouseDown(super, 'left', winMR.MoveWindowUseMouse)
mouseHotkey.hotkeyBindWithMouseDown(super, 'right', winMR.ReSizeWindowUseMouse)

hs.hotkey.bind(super, 't', function()
  local win = hs.window.focusedWindow()
  windowUtil.toggleMaximize(win)
end)

hs.hotkey.bind(super, 'q', function() windowUtil.smartCloseWindow(ONLY_CLOSE_APPS) end)

hs.hotkey.bind(super, 'tab', windowUtil.focusNextWindowInCurrentSpace)

--------------------------------------------------------------------------------
-- 应用启动
--------------------------------------------------------------------------------
-- hs.hotkey.bind(super, 'c', function()
--   local task = hs.task.new('/usr/bin/open', nil, {
--     '-n',
--     '-a',
--     '/Applications/Google Chrome.app',
--     '--args',
--     '--new-window',
--   })
--   task:start()
-- end)

hs.hotkey.bind(super, 'c', function()
  local task = hs.task.new('/usr/bin/open', nil, {
    '-n',
    '-a',
    '/Applications/Nix Apps/Firefox.app',
    '--args',
    '-new-window',
  })
  task:start()
end)

hs.hotkey.bind(super, 'space', function()
  local task = hs.task.new('/usr/bin/open', nil, {
    '-n',
    '-a',
    '/Applications/Nix Apps/kitty.app',
    '--args',
    '-d',
    os.getenv 'HOME',
    '-o',
    'remember_window_size=no',
    '-o',
    'initial_window_width=1050',
    '-o',
    'initial_window_height=650',
  })
  task:start()
end)

hs.hotkey.bind(super, 'return', function()
  local task = hs.task.new('/usr/bin/open', nil, {
    '-n',
    '-a',
    '/Applications/Nix Apps/kitty.app',
    '--args',
    '-d',
    os.getenv 'HOME',
    '--start-as=maximized',
  })
  task:start()
end)

-- hs.hotkey.bind(super, 'p', function() hs.application.launchOrFocus 'Raycast' end)

-- 绑定 Cmd + Opt(Alt) + E 打开新的访达窗口，并默认跳转到家目录
hs.hotkey.bind(super, 'e', function()
  local script = [[
        tell application "Finder"
            make new Finder window to home
            activate
        end tell
    ]]
  hs.osascript.applescript(script)
end)

-- 使用 raycast 绑定的快捷键(不受 hs 管理)

--------------------------------------------------------------------------------
-- 媒体控制
--------------------------------------------------------------------------------
local function postSystemKey(key)
  hs.eventtap.event.newSystemKeyEvent(key, true):post()
  hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

local function showVolumeAlert()
  hs.timer.doAfter(0.02, function()
    local dev = hs.audiodevice.defaultOutputDevice()
    local volume = math.floor(dev:volume() + 0.5)
    hs.alert.closeAll()
    hs.alert.show('音量: ' .. volume .. '%', { atScreenEdge = 2 })
  end)
end

hs.hotkey.bind(superShift, 'up', function()
  postSystemKey 'SOUND_UP'
  showVolumeAlert()
end)

hs.hotkey.bind(superShift, 'down', function()
  postSystemKey 'SOUND_DOWN'
  showVolumeAlert()
end)

--------------------------------------------------------------------------------
-- 其他
--------------------------------------------------------------------------------
hs.hotkey.bind(superAlt, 'l', hs.caffeinate.lockScreen)

--------------------------------------------------------------------------------
-- End
--------------------------------------------------------------------------------
hs.alert.show '配置已重载'
