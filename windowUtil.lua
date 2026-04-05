local M = {}

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
