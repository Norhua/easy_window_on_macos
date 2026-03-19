local winMR = require("windowMoveResize")
local mouseHotkey = require("mouseHotkey")
local windowUtil = require("windowUtil")


local super = { "ctrl", "cmd" }
local superAlt = {"ctrl", "cmd", "alt"}
local superShift = {"ctrl", "cmd", "shift"}

-- super + alt + r 重载配置
hs.hotkey.bind(superAlt, "r", function()
    hs.reload()
end)

--------------------------------------------------------------------------------
-- 窗口操作
--------------------------------------------------------------------------------
mouseHotkey.hotkeyBindWithMouseDown(super, "left", winMR.MoveWindowUseMouse)
mouseHotkey.hotkeyBindWithMouseDown(super, "right", winMR.ReSizeWindowUseMouse)

hs.hotkey.bind(super, "t", function()
    local win = hs.window.focusedWindow()
    windowUtil.toggleMaximize(win)
end)

hs.hotkey.bind(super, "q", windowUtil.smartCloseWindow)

hs.hotkey.bind(super, "tab", windowUtil.focusNextWindowInCurrentSpace)


--------------------------------------------------------------------------------
-- 应用启动
--------------------------------------------------------------------------------
hs.hotkey.bind(super, "c", function()
    local task = hs.task.new("/usr/bin/open", nil, {
        "-n", "-a", "/Applications/Google Chrome.app",
        "--args",
        "--new-window"
    })
    task:start()
end)

hs.hotkey.bind(super, "space", function()
    local task = hs.task.new("/usr/bin/open", nil, {
        "-n", "-a", "/Applications/Nix Apps/kitty.app",
        "--args",
        "-d", os.getenv("HOME"),
        "-o", "remember_window_size=no",
        "-o", "initial_window_width=1050",
        "-o", "initial_window_height=650"
    })
    task:start()
end)

hs.hotkey.bind(super, "return", function()
    local task = hs.task.new("/usr/bin/open", nil, {
        "-n", "-a", "/Applications/Nix Apps/kitty.app",
        "--args",
        "-d", os.getenv("HOME"),
        "--start-as=maximized"
    })
    task:start()
end)


--------------------------------------------------------------------------------
-- 媒体控制
--------------------------------------------------------------------------------
hs.hotkey.bind(superShift, "up", function()
    local dev = hs.audiodevice.defaultOutputDevice()
    dev:setVolume(dev:volume() + 5)
end)

hs.hotkey.bind(superShift, "down", function()
    local dev = hs.audiodevice.defaultOutputDevice()
    dev:setVolume(dev:volume() - 5)
end)


--------------------------------------------------------------------------------
-- 其他
--------------------------------------------------------------------------------
hs.hotkey.bind(superAlt, "l", hs.caffeinate.lockScreen)


--------------------------------------------------------------------------------
-- End
--------------------------------------------------------------------------------
hs.alert.show("配置已重载")