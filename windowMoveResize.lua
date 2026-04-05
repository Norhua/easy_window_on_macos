local M = {}

local mouseHotkey = require 'mouseHotkey'

local function getWindow(mousePos)
  -- orderedWindows() 通常按前到后排序，先命中的一般就是鼠标下最上层窗口
  for _, win in ipairs(hs.window.orderedWindows()) do
    local frame = win:frame()
    if hs.geometry(mousePos):inside(frame) then return win end
  end

  return nil
end

function M.MoveWindowUseMouse()
  local mousePos = hs.mouse.absolutePosition()
  local win = getWindow(mousePos)
  if not win then return end
  local winFrame = win:frame()

  win:focus()

  -- 因为 Macos 混乱的窗口管理，我似乎没有办法找到这个窗口是否处于最大化状态，所以
  -- 如果窗口已经最大化，缩小至 70% 并在光标位置居中
  local isMaximized = (math.abs(winFrame.w - win:screen():frame().w) < 20) and (math.abs(winFrame.h - win:screen():frame().h) < 20)
  if isMaximized then
    local newW = winFrame.w * 0.7
    local newH = winFrame.h * 0.7
    winFrame.x = mousePos.x - newW / 2
    winFrame.y = mousePos.y - newH / 2
    winFrame.w = newW
    winFrame.h = newH
    win:setFrame(winFrame, 0)
  end

  -- 用初始位置作为固定基准点，不在 tick 中重新读取
  local mouseStartX = mousePos.x
  local mouseStartY = mousePos.y
  local winStartX = winFrame.x
  local winStartY = winFrame.y

  local moveTimer = nil

  local function MWUM_MouseWatcher()
    local buttons = mouseHotkey.getButtons()
    if not buttons.left then
      if moveTimer then moveTimer:stop() end
      return
    end

    local cur = hs.mouse.absolutePosition()

    -- 目标位置 = 窗口初始位置 + 鼠标位移量（不依赖异步的窗口当前位置）
    win:setTopLeft {
      x = winStartX + (cur.x - mouseStartX),
      y = winStartY + (cur.y - mouseStartY),
    }
  end

  moveTimer = hs.timer.doEvery(0.01, MWUM_MouseWatcher)
end

function M.ReSizeWindowUseMouse()
  local mousePos = hs.mouse.absolutePosition()
  local win = getWindow(mousePos)
  if not win then return end

  local winFrame = win:frame()

  local winStartX = winFrame.x
  local winStartY = winFrame.y
  local winStartW = winFrame.w
  local winStartH = winFrame.h

  -- 目标传送位置：窗口右下角附近
  local mouseStartX = winStartX + winStartW - 5
  local mouseStartY = winStartY + winStartH - 5

  win:focus()

  -- 用合成 mouseMoved 事件传送光标，绕过 CGWarpMouseCursorPosition
  -- （CGWarpMouseCursorPosition 会触发 macOS ~0.25s 的输入抑制，导致光标卡住）
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, { x = mouseStartX, y = mouseStartY }):post()

  local resizeTimer = nil

  local function RWUM_MouseWatcher()
    local buttons = mouseHotkey.getButtons()
    if not buttons.right then
      if resizeTimer then resizeTimer:stop() end
      return
    end

    local cur = hs.mouse.absolutePosition()

    local targetW = math.max(100, winStartW + (cur.x - mouseStartX))
    local targetH = math.max(50, winStartH + (cur.y - mouseStartY))

    win:setFrame({
      x = winStartX,
      y = winStartY,
      w = targetW,
      h = targetH,
    }, 0)
  end

  resizeTimer = hs.timer.doEvery(0.01, RWUM_MouseWatcher)
end

return M
