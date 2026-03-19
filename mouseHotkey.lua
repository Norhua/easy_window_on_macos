local M = {}

-- =========================
-- Mouse Hotkey Manager
-- =========================
local MouseHotkey = {
    _bindings = {},
    _tap = nil,
}

local MOD_ALIASES = {
    command = "cmd",
    ["⌘"] = "cmd",
    control = "ctrl",
    ["⌃"] = "ctrl",
    option = "alt",
    ["⌥"] = "alt",
    ["⇧"] = "shift",
}

local MOD_ORDER = { "ctrl", "alt", "shift", "cmd", "fn" }
local VALID_MODS = {
    cmd = true,
    ctrl = true,
    alt = true,
    shift = true,
    fn = true,
}

-- 鼠标按键 → eventtap 事件类型
local BUTTON_EVENT_MAP = {
    left = hs.eventtap.event.types.leftMouseDown,
    right = hs.eventtap.event.types.rightMouseDown,
    middle = hs.eventtap.event.types.otherMouseDown,
}

-- 按键抬起对应的事件类型（用于清除虚拟状态）
local BUTTON_UP_EVENT_MAP = {
    left = hs.eventtap.event.types.leftMouseUp,
    right = hs.eventtap.event.types.rightMouseUp,
    middle = hs.eventtap.event.types.otherMouseUp,
}

-- otherMouseDown 不区分按键编号，需额外检查
local BUTTON_NUMBER_MAP = {
    middle = 2,
}

-- 虚拟按键状态：记录被我们拦截的按键（系统感知不到这些按键状态）
local _pressedButtons = {}

local function canonicalMod(mod)
    mod = tostring(mod):lower()
    return MOD_ALIASES[mod] or mod
end

local function normalizeMods(mods)
    assert(type(mods) == "table", "mods must be a table")

    local seen = {}
    for _, mod in ipairs(mods) do
        local m = canonicalMod(mod)
        assert(VALID_MODS[m], "unsupported modifier: " .. tostring(mod))
        seen[m] = true
    end

    local normalized = {}
    for _, m in ipairs(MOD_ORDER) do
        if seen[m] then
            table.insert(normalized, m)
        end
    end

    return normalized, table.concat(normalized, "+")
end

local function normalizeButton(button)
    assert(type(button) == "string", "button must be a string")
    button = button:lower()
    assert(
        BUTTON_EVENT_MAP[button],
        "unsupported button: " .. button .. " (supported: left, right, middle)"
    )
    return button
end

local function bindingCount()
    local n = 0
    for _ in pairs(MouseHotkey._bindings) do
        n = n + 1
    end
    return n
end

--- 收集当前所有绑定所需的事件类型（去重），同时包含对应的 mouseUp 事件（用于清除虚拟状态）
local function collectEventTypes()
    local seen = {}
    local types = {}
    for _, binding in pairs(MouseHotkey._bindings) do
        local et = BUTTON_EVENT_MAP[binding.button]
        if not seen[et] then
            seen[et] = true
            types[#types + 1] = et
        end
        local up = BUTTON_UP_EVENT_MAP[binding.button]
        if up and not seen[up] then
            seen[up] = true
            types[#types + 1] = up
        end
    end
    return types
end

--- 判断一个 binding 是否匹配当前事件
local function matchesBinding(binding, eventType, flags, event)
    if not binding.enabled then return false end
    if BUTTON_EVENT_MAP[binding.button] ~= eventType then return false end
    if not flags:containExactly(binding.mods) then return false end

    -- otherMouseDown 需要校验具体的按键编号
    local expectedBtn = BUTTON_NUMBER_MAP[binding.button]
    if expectedBtn then
        local prop = hs.eventtap.event.properties.mouseEventButtonNumber
        if event:getProperty(prop) ~= expectedBtn then return false end
    end

    return true
end

--- 根据当前 bindings 重建 eventtap
--- bind / delete 时都需要调用，因为 tap 的事件类型列表在创建后不可变
local function rebuildTap()
    if MouseHotkey._tap then
        MouseHotkey._tap:stop()
        MouseHotkey._tap = nil
    end

    if bindingCount() == 0 then
        return
    end

    MouseHotkey._tap = hs.eventtap.new(
        collectEventTypes(),
        function(event)
            local eventType = event:getType()
            local flags = event:getFlags()

            -- 检查是否是"抬起"事件：清除虚拟按键状态后透传
            for buttonName, upType in pairs(BUTTON_UP_EVENT_MAP) do
                if eventType == upType then
                    _pressedButtons[buttonName] = nil
                    return false
                end
            end

            for _, binding in pairs(MouseHotkey._bindings) do
                if matchesBinding(binding, eventType, flags, event) then
                    -- 记录虚拟按键状态（事件被拦截后系统不会更新按键状态）
                    _pressedButtons[binding.button] = true
                    local ok, err = pcall(binding.fn, event)
                    if not ok then
                        hs.showError(err)
                    end
                    -- 拦截事件，不传给下游应用
                    return true
                end
            end

            -- 无匹配绑定，透传事件
            return false
        end
    )

    MouseHotkey._tap:start()
end

--- 绑定 修饰键 + 鼠标按键 → 回调函数
--- @param mods table 修饰键列表，如 {"ctrl", "cmd"}
--- @param button string 鼠标按键名称："left" | "right" | "middle"
--- @param fn function 回调函数，接收 event 参数
--- @return table 绑定对象，支持 :enable() / :disable() / :delete()
function M.hotkeyBindWithMouseDown(mods, button, fn)
    assert(type(fn) == "function", "fn must be a function")

    local normalizedMods, modsKey = normalizeMods(mods)
    button = normalizeButton(button)
    local bindingKey = button .. ":" .. modsKey

    assert(
        MouseHotkey._bindings[bindingKey] == nil,
        "mouse hotkey already exists for: " .. bindingKey
    )

    local obj = {
        mods = normalizedMods,
        button = button,
        key = bindingKey,
        fn = fn,
        enabled = true,
    }

    function obj:enable()
        self.enabled = true
        return self
    end

    function obj:disable()
        self.enabled = false
        return self
    end

    function obj:delete()
        if MouseHotkey._bindings[self.key] then
            MouseHotkey._bindings[self.key] = nil
            self.enabled = false
            rebuildTap()
        end
    end

    MouseHotkey._bindings[bindingKey] = obj
    rebuildTap()

    return obj
end

--- 向后兼容的便捷接口
function M.hotkeyBindWithLeftMouseDown(mods, fn)
    return M.hotkeyBindWithMouseDown(mods, "left", fn)
end

--- 清除所有鼠标热键绑定（适用于 hs.reload 等场景）
function M.unbindAll()
    MouseHotkey._bindings = {}
    _pressedButtons = {}
    rebuildTap()
end

--- 获取当前鼠标按键状态，合并系统真实状态与被我们拦截的虚拟状态
--- 用来替代 hs.mouse.getButtons()：即使事件被拦截，也能正确反映按键状态
--- @return table 与 hs.mouse.getButtons() 格式相同：{ left=bool, right=bool, middle=bool, ... }
function M.getButtons()
    local btns = hs.mouse.getButtons()
    for buttonName, pressed in pairs(_pressedButtons) do
        if pressed then
            btns[buttonName] = true
        end
    end
    return btns
end

return M