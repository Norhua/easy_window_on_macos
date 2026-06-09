local M = {}

-- 使用 hs.axuielement 读取 Accessibility 层级。
-- 这里不能只依赖 hs.window.focusedWindow()：Firefox 文件选择窗口、
-- sheet、dialog 这类非标准子窗口经常不会被它当成“当前窗口”，
-- 从而导致快捷键误操作到背后的主窗口。
local axuielement = require 'hs.axuielement'

-- Accessibility 里常见的模态窗口角色。
-- AXSheet 通常是附着在主窗口上的文件选择/保存面板；
-- AXDialog 则是独立的对话框窗口。
local MODAL_WINDOW_ROLES = {
  AXSheet = true,
  AXDialog = true,
}

-- Hammerspoon 的 window:subrole() 常见会返回这些子角色。
-- AXSystemDialog 覆盖系统文件选择、权限确认等系统级弹窗。
local MODAL_WINDOW_SUBROLES = {
  AXDialog = true,
  AXSystemDialog = true,
}

-- 有些应用不会暴露 AXCancelButton 属性，只能从子元素里找按钮。
-- 这里同时支持英文和中文系统/应用环境里的“取消”按钮标题。
local CANCEL_BUTTON_TITLES = {
  Cancel = true,
  ['取消'] = true,
}

-- Accessibility 查询在窗口刚创建/销毁、应用未完整实现 AX 属性时可能抛错。
-- 用 pcall 包起来，避免一次失败让整个 Hammerspoon 快捷键回调中断。
local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

-- 安全读取 AX 属性。
-- 例如 AXRole、AXSubrole、AXChildren、AXCancelButton 等都可能不存在。
local function attr(element, name)
  if not element then return nil end
  return safeCall(function() return element:attributeValue(name) end)
end

-- 判断一个 AX 元素本身是否就是需要优先处理的模态窗口。
-- 只要命中 role 或 subrole，就不能继续走后面的主窗口关闭逻辑。
local function isModalElement(element)
  local role = attr(element, 'AXRole')
  local subrole = attr(element, 'AXSubrole')
  return MODAL_WINDOW_ROLES[role] or MODAL_WINDOW_SUBROLES[subrole] or false
end

-- 对按钮执行 AXPress。
-- 直接按 Cancel/Close 按钮比模拟键盘更准确，也不会误伤背后的主窗口。
local function pressButton(button)
  if not button then return false end

  local result = safeCall(function() return button:performAction('AXPress') end)
  return result ~= nil and result ~= false
end

-- 如果 AX 元素对应一个 Hammerspoon window，就转成 hs.window。
-- 不是所有 AX 元素都能转换，所以这里仍然必须安全调用。
local function asWindow(element)
  if not element then return nil end
  return safeCall(function() return element:asHSWindow() end)
end

-- 不同应用暴露按钮名称的属性不完全一致。
-- Firefox 文件选择框里常见是 AXTitle，但保留 AXDescription/AXValue 作为兼容。
local function buttonTitle(button)
  return attr(button, 'AXTitle') or attr(button, 'AXDescription') or attr(button, 'AXValue')
end

-- 递归寻找“取消”按钮。
-- 某些 sheet/dialog 不提供 AXCancelButton，只能遍历 AXChildren。
-- depth 限制是为了避免在复杂应用的 Accessibility 树里递归太深，影响快捷键响应。
local function findCancelButton(element, depth)
  if not element or depth > 8 then return nil end

  if attr(element, 'AXRole') == 'AXButton' and CANCEL_BUTTON_TITLES[buttonTitle(element)] then
    return element
  end

  for _, child in ipairs(attr(element, 'AXChildren') or {}) do
    local button = findCancelButton(child, depth + 1)
    if button then return button end
  end

  return nil
end

-- 判断 AX 元素是否是“非标准窗口”。
-- 文件选择框这类没有红绿灯按钮的子窗口，通常不是 standard window；
-- 识别到它们后应该优先处理，而不是让 smartCloseWindow 去关闭/退出主应用。
local function isNonStandardWindowElement(element)
  local win = asWindow(element)
  if not win then return false end

  return safeCall(function() return not win:isStandard() end) or false
end

-- 找到当前真正获得焦点的模态/非标准子窗口。
-- 流程：
-- 1. 从 systemWideElement 读取 AXFocusedUIElement，这是当前键盘焦点所在的真实 AX 元素。
-- 2. 如果系统级读取失败，再从前台应用的 AXFocusedUIElement 兜底。
-- 3. 从焦点元素向父级追溯，查找最近的 sheet/dialog/非标准窗口。
-- 4. 如果父级路径没有命中，再检查焦点元素所属的 AXWindow。
local function findFocusedModalElement()
  local focusedElement = attr(axuielement.systemWideElement(), 'AXFocusedUIElement')

  if not focusedElement then
    local app = hs.application.frontmostApplication()
    local appElement = app and axuielement.applicationElement(app)
    focusedElement = attr(appElement, 'AXFocusedUIElement')
  end

  if not focusedElement then return nil, nil end

  local path = safeCall(function() return focusedElement:path() end) or {}
  for index = #path, 1, -1 do
    if isModalElement(path[index]) or isNonStandardWindowElement(path[index]) then
      return path[index], focusedElement
    end
  end

  local focusedWindow = attr(focusedElement, 'AXWindow')
  if isModalElement(focusedWindow) or isNonStandardWindowElement(focusedWindow) then
    return focusedWindow, focusedElement
  end

  return nil, focusedElement
end

-- 优先关闭当前模态/非标准子窗口。
-- 返回 true 表示已经接管本次 Super+Q，不再执行主窗口关闭/退出逻辑；
-- 返回 false 表示没有发现需要特殊处理的子窗口，可以继续走原来的 smartCloseWindow。
local function closeFocusedModalElement()
  local modalElement, focusedElement = findFocusedModalElement()
  if not modalElement then return false end

  -- 最理想情况：应用直接暴露了取消/关闭按钮属性。
  if pressButton(attr(modalElement, 'AXCancelButton')) then return true end
  if pressButton(attr(modalElement, 'AXCloseButton')) then return true end

  -- 次优情况：没有 AXCancelButton，就在子元素树里找标题为 Cancel/取消 的按钮。
  if pressButton(findCancelButton(modalElement, 0)) then return true end

  -- 再兜底尝试 hs.window:close()。
  -- 对非标准窗口来说它不一定生效，所以这里不直接 return，而是继续走 Cmd+.。
  local modalWindow = asWindow(modalElement)
  if modalWindow then safeCall(function() if not modalWindow:isStandard() then modalWindow:close() end end) end

  -- 最后兜底：Cmd+. 是 macOS 取消当前模态操作的通用快捷键。
  -- 延迟 0.05 秒是为了等 Super+Q 的 ctrl/cmd 修饰键释放，
  -- 避免 Hammerspoon 刚处理完热键时，模拟按键被旧修饰键状态干扰。
  local app = hs.application.frontmostApplication()
  if app then
    hs.timer.doAfter(0.05, function() hs.eventtap.keyStroke({ 'cmd' }, '.', 0, app) end)
  end

  return true
end

local function getCurrentSpaceWindows()
  local windows = {}

  for _, win in ipairs(hs.window.orderedWindows()) do
    if win:isStandard() and not win:isMinimized() then table.insert(windows, win) end
  end

  -- 按照 app 名字和 window id 排序，以保证顺序固定，从而可以循环遍历所有窗口
  table.sort(windows, function(a, b)
    local appA = a:application()
    local appB = b:application()
    local nameA = appA and appA:name() or ''
    local nameB = appB and appB:name() or ''
    if nameA == nameB then
      local idA = a:id() or 0
      local idB = b:id() or 0
      return idA < idB
    end
    return nameA < nameB
  end)

  return windows
end

function M.toggleMaximize(win)
  if not win then return end

  local f = win:frame()
  local max = win:screen():frame()

  -- 容差判断是否已最大化（处理部分应用如终端存在微小的像素差异）
  local isMaximized = (math.abs(f.w - max.w) < 20) and (math.abs(f.h - max.h) < 20)

  if isMaximized then
    -- 如果已经最大化，缩小至 70% 并在屏幕中居中
    f.w = max.w * 0.7
    f.h = max.h * 0.7
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 2
    win:setFrame(f, 0)
  else
    -- 如果不是最大化，则最大化
    win:maximize(0)
  end
end

-- 用于循环切换当前空间的窗口
function M.focusNextWindowInCurrentSpace()
  local windows = getCurrentSpaceWindows()
  if #windows == 0 then return end

  local focused = hs.window.focusedWindow()
  if not focused then
    windows[1]:focus()
    return
  end

  for index, win in ipairs(windows) do
    if win:id() == focused:id() then
      local nextIndex = (index % #windows) + 1
      windows[nextIndex]:focus()
      return
    end
  end

  windows[1]:focus()
end

-- 智能关闭窗口：如果是名单内的应用，或者有多个窗口，只关闭当前窗口；否则直接退出应用。
function M.smartCloseWindow(ONLY_CLOSE_APPS)
  -- 必须先处理模态/非标准子窗口，再读取 hs.window.focusedWindow()。
  -- 否则 Firefox 文件选择框这类子窗口获得焦点时，focusedWindow() 仍可能返回主窗口，
  -- 后续逻辑就会误关主窗口或退出应用。
  if closeFocusedModalElement() then return end

  local win = hs.window.focusedWindow()
  if not win then return end

  local app = win:application()
  if not app then
    win:close()
    return
  end

  local appName = app:name()

  -- 1. 检查是否在“仅关闭窗口”名单内
  if ONLY_CLOSE_APPS[appName] then
    win:close()
    return
  end

  -- 2. 统计应用当前开启的所有“标准窗口”数量
  local standardWindowsCount = 0
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then standardWindowsCount = standardWindowsCount + 1 end
  end

  -- 3. 核心判断：如果标准窗口 <= 1，直接 kill 整个应用；否则仅关闭当前窗口
  if standardWindowsCount <= 1 then
    app:kill()
  else
    win:close()
  end
end

return M
