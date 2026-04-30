# EzWindows.hs

一个基于 Hammerspoon 的 macOS 窗口管理配置，目标是给桌面操作补上一些更接近 Linux WM 的体验：

- 用键盘和鼠标快速拖动、缩放窗口
- 统一窗口最大化、关闭、切换逻辑
- 绑定常用应用启动和系统操作快捷键

## 功能概览与当前按键绑定
你可以通过修改 `init.lua` 来修改/添加按键绑定

- `Super + 鼠标左键` 拖动窗口
- `Super + 鼠标右键` 从右下角缩放窗口
- `Super + t` 最大化 / 恢复为居中的 70% 大小
- `Super + q` 智能关闭窗口或退出应用
- `Super + tab` 在当前 Space 中循环切换窗口
- `Super + c` 打开新的浏览器窗口
- `Super + space` 打开普通大小的 `kitty`
- `Super + return` 打开最大化的 `kitty`
- `Super + e` 打开新的访达窗口并定位到家目录
- `Super + Alt + r` 重载 Hammerspoon 配置
- `Super + Alt + l` 锁屏
- `Super + Shift + up/down` 调整系统音量并弹出提示

这里的 `Super` 指 `ctrl + cmd`。

## 代码结构

- `init.lua`
  配置入口。负责定义修饰键、注册所有快捷键，并组合各个模块。
- `mouseHotkey.lua`
  对 Hammerspoon 原生能力做了一层补充，支持“修饰键 + 鼠标按下”这类绑定，并维护被拦截鼠标键的虚拟按下状态。
- `windowMoveResize.lua`
  负责窗口拖动和缩放。通过定时器持续读取鼠标位置，实现按住鼠标拖动窗口、从右下角缩放窗口。
- `windowUtil.lua`
  放置通用窗口逻辑，包括最大化切换、当前 Space 内窗口轮换、智能关闭窗口。
- `.stylua.toml`
  Lua 格式化配置，使用 `stylua` 时会读这个文件。

## 使用前提

需要先安装：

1. [Hammerspoon](https://www.hammerspoon.org/)
2. 可选：`stylua`，用于格式化 Lua 代码

第一次使用时，还需要在 macOS 中给 Hammerspoon 打开权限：

1. `系统设置 -> 隐私与安全性 -> 辅助功能`
2. 允许 `Hammerspoon`

如果部分快捷键需要控制其他应用，通常还需要允许自动化相关权限。

## 如何安装

1. 将本仓库内容放到 `~/.hammerspoon/`
2. 打开 Hammerspoon
3. 点击菜单栏图标，选择 `Reload Config`
4. 或直接使用快捷键 `ctrl + cmd + alt + r`

配置重载成功后，屏幕会显示“配置已重载”。

## 使用前需要修改的地方

当前 `init.lua` 中有几个应用路径是写死的，直接照搬到另一台机器上前，通常需要先改成你自己的安装路径：

- 浏览器路径：`/Applications/Nix Apps/Firefox.app`
- 终端路径：`/Applications/Nix Apps/kitty.app`

对应位置在 `init.lua`：

- `Super + c` 绑定的是新开一个 Firefox 窗口
- `Super + space` 和 `Super + return` 绑定的是启动 `kitty`

如果你的应用不在这些路径下，可以改成：

- 你自己的 `.app` 路径
- 或直接改成 `hs.application.launchOrFocus(...)` 这类更通用的启动方式

## 特殊行为说明

### 1. 智能关闭白名单

`init.lua` 里有一个 `ONLY_CLOSE_APPS` 表：

- `微信`
- `QQ`
- `访达`
- `Raycast`
- `PixPin`

这些应用触发 `Super + q` 时，只会关闭窗口，不会直接退出应用。你可以按自己的习惯继续增删这个名单。

### 2. 最大化后的拖动行为

如果一个窗口已经接近全屏宽高，再执行 `Super + 鼠标左键` 拖动时，配置会先把它缩到约 70%，再跟随鼠标移动。这是为了模拟更顺手的窗口拖拽体验。

### 3. 当前 Space 内切窗

`Super + tab` 不是按 macOS 默认逻辑切应用，而是按“当前桌面里的标准窗口”进行轮换，更接近窗口管理器风格。

## 适合怎么改

如果你想继续扩展这个配置，通常从 `init.lua` 下手就够了：

- 新增快捷键绑定
- 修改应用启动路径
- 调整 `ONLY_CLOSE_APPS` 白名单

如果要改窗口行为，则看对应模块：

- 拖动 / 缩放：`windowMoveResize.lua`
- 最大化 / 切窗 / 关闭策略：`windowUtil.lua`
- 鼠标组合键底层支持：`mouseHotkey.lua`

## 开发建议

- 修改完配置后，用 `ctrl + cmd + alt + r` 立即重载测试
- 如果 Hammerspoon 没有响应，先检查辅助功能权限是否仍然开启
- 如果应用启动快捷键无效，优先检查 `.app` 路径是否正确
