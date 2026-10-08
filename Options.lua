-- Options.lua
-- Easy Button Aura by Unit — 设置界面
--
-- 界面分两块（沿用 easyButtonAuraByCDM 的既定模式）：
--   1. 暴雪插件设置里的【占位页】：只有一句提示 + 一个按钮，点按钮打开自有配置窗口。
--   2. 【自有配置窗口】：承载全部绑定控件；用 /babu 或占位页按钮打开。
--
-- 绑定列表是玩家手动维护的数组（每行 = 一条绑定）：
--   光环 ID 输入框 + 追踪单位下拉（自身/目标）+ 技能 ID 输入框 + 删除按钮；
--   窗口底部「添加绑定」按钮追加空行。同单位+同技能的多条绑定由主文件在运行时合并。
--
-- 战斗行为：战斗中配置窗口直接隐藏，战斗结束若此前是打开状态则自动恢复；
-- 战斗中不响应 /babu 与占位页按钮。
--
-- 布局约定：所有控件的坐标都是【相对 row 的绝对坐标】，不互相链式锚定；
-- 列表区为【固定高度 + 滚动条】，滚动条显式重锚进窗口内右缘。

local B = EasyButtonAuraByUnit
local L = B.L

local PANEL_W = 680
local ROW_W   = PANEL_W - 44
local ROW_H   = 56

local VISIBLE_ROWS = 7
local LIST_H = VISIBLE_ROWS * ROW_H

-- 行内第二行控件的横坐标（相对 row 左侧）与宽度
local X_AURA,  W_AURA  = 48, 140
local X_UNIT,  W_UNIT  = 204, 92
local X_SPELL, W_SPELL = 330, 180
local X_DEL,   W_DEL   = 560, 56

local ADD_ROW_H = 46   -- 底部「添加绑定」按钮区高度

-- 暴雪设置分类名 / 配置窗口标题：不本地化，固定用插件名（工作区约定）
local ADDON_TITLE = "Easy Button Aura by Unit"

local STUB_W = 520

local configFrame
local rows = {}
local refreshing = false

-- =========================================================
-- 小工具
-- =========================================================
local function AddTip(widget, text)
    local prevEnter = widget:GetScript("OnEnter")
    local prevLeave = widget:GetScript("OnLeave")
    widget:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        GameTooltip:Hide()
    end)
end

-- 下拉按钮的显示文字（不同版本方法名可能有差异，优先 SetText）
local function SetDdText(dd, text)
    if dd.SetText then
        dd:SetText(text)
    elseif dd.SetDefaultText then
        dd:SetDefaultText(text)
    end
end

-- 追踪单位下拉：自身 / 目标
local function CurUnit(index)
    local list = B.GetList()
    local cfg = list[index]
    return (cfg and cfg.unit) or "player"
end

local function SetupUnitMenu(dd)
    dd:SetupMenu(function(_, rootDescription)
        local entries = { { key = "player", label = L("UNIT_PLAYER") }, { key = "target", label = L("UNIT_TARGET") } }
        for _, e in ipairs(entries) do
            rootDescription:CreateRadio(e.label, function()
                return CurUnit(dd._index) == e.key
            end, function()
                if dd._index then
                    B.UpdateBinding(dd._index, "unit", e.key)
                end
            end)
        end
    end)
end

-- 提交「光环」输入框：名字 / ID 皆可；空 = 清除；解析失败 = 还原并提示
local function CommitAuraEdit(row)
    if row._committing then return end
    if not row.index then return end
    row._committing = true

    local list = B.GetList()
    local cfg = list[row.index]
    local prev = cfg and cfg.auraID
    local text = strtrim(row.auraEdit:GetText() or "")

    if text == "" then
        if prev then B.UpdateBinding(row.index, "auraID", nil) end
        row.auraEdit:SetText("")
    else
        local id = B.ParseAuraInput(text)
        if id then
            if id ~= prev then B.UpdateBinding(row.index, "auraID", id) end
            row.auraEdit:SetText(B.GetSpellDisplayName(id))
        else
            row.status:SetText(L("ERR_NO_AURA"))
            row.status:SetTextColor(1, 0.35, 0.35)
            row.auraEdit:SetText(prev and B.GetSpellDisplayName(prev) or "")
        end
    end

    row.auraEdit:ClearFocus()
    row._committing = false
end

-- 提交「技能」输入框：名字 / ID 皆可；空 = 清除；解析失败 = 还原并提示
local function CommitSpellEdit(row)
    if row._committing then return end
    if not row.index then return end
    row._committing = true

    local list = B.GetList()
    local cfg = list[row.index]
    local prev = cfg and cfg.bindSpell
    local text = strtrim(row.spellEdit:GetText() or "")

    if text == "" then
        if prev then B.UpdateBinding(row.index, "bindSpell", nil) end
        row.spellEdit:SetText("")
    else
        local target = B.ParseSpellInput(text)
        if target then
            if target ~= prev then B.UpdateBinding(row.index, "bindSpell", target) end
            row.spellEdit:SetText(B.GetSpellDisplayName(target))
        else
            row.status:SetText(L("ERR_INVALID"))
            row.status:SetTextColor(1, 0.35, 0.35)
            row.spellEdit:SetText(prev and B.GetSpellDisplayName(prev) or "")
        end
    end

    row.spellEdit:ClearFocus()
    row._committing = false
end

-- =========================================================
-- 行控件
-- =========================================================
local function CreateRow(index)
    local row = CreateFrame("Frame", nil, configFrame.rows)
    row:SetSize(ROW_W, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)

    -- 第一行：图标 + 光环名 + 状态提示
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("TOPLEFT", 6, -4)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints()
    row.icon:SetScript("OnEnter", function(self)
        local id = self.spellID
        if not id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(id)
        else
            GameTooltip:SetText(B.GetSpellDisplayName(id))
        end
        GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.status:SetJustifyH("LEFT")

    -- 第二行：光环输入框 / 单位下拉 / 技能输入框 / 删除按钮
    -- 统一底边（输入框 y=6、下拉 y=4、按钮 y=4），中心线一致 → 视觉对齐
    row.auraEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.auraEdit:SetSize(W_AURA, 20)
    row.auraEdit:SetPoint("BOTTOMLEFT", X_AURA, 6)
    row.auraEdit:SetAutoFocus(false)
    row.auraEdit:SetMaxLetters(60)
    row.auraEdit:SetScript("OnEnterPressed", function() CommitAuraEdit(row) end)
    row.auraEdit:SetScript("OnEditFocusLost", function() CommitAuraEdit(row) end)
    row.auraEdit:SetScript("OnEscapePressed", function()
        row._committing = true
        local list = B.GetList()
        local cfg = list[row.index]
        local prev = cfg and cfg.auraID
        row.auraEdit:SetText(prev and B.GetSpellDisplayName(prev) or "")
        row.auraEdit:ClearFocus()
        row._committing = false
    end)

    row.auraLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.auraLabel:SetPoint("RIGHT", row.auraEdit, "LEFT", -6, 0)
    row.auraLabel:SetText(L("COL_AURA"))

    row.unitDd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.unitDd:SetSize(W_UNIT, 24)
    row.unitDd:SetPoint("BOTTOMLEFT", X_UNIT, 4)
    SetupUnitMenu(row.unitDd)
    AddTip(row.unitDd, L("COL_UNIT"))

    row.spellEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.spellEdit:SetSize(W_SPELL, 20)
    row.spellEdit:SetPoint("BOTTOMLEFT", X_SPELL, 6)
    row.spellEdit:SetAutoFocus(false)
    row.spellEdit:SetMaxLetters(60)
    row.spellEdit:SetScript("OnEnterPressed", function() CommitSpellEdit(row) end)
    row.spellEdit:SetScript("OnEditFocusLost", function() CommitSpellEdit(row) end)
    row.spellEdit:SetScript("OnEscapePressed", function()
        row._committing = true
        local list = B.GetList()
        local cfg = list[row.index]
        local prev = cfg and cfg.bindSpell
        row.spellEdit:SetText(prev and B.GetSpellDisplayName(prev) or "")
        row.spellEdit:ClearFocus()
        row._committing = false
    end)

    row.spellLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.spellLabel:SetPoint("RIGHT", row.spellEdit, "LEFT", -6, 0)
    row.spellLabel:SetText(L("COL_SPELL"))

    row.delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delBtn:SetSize(W_DEL, 22)
    row.delBtn:SetPoint("BOTTOMLEFT", X_DEL, 4)
    row.delBtn:SetText(L("DEL"))
    row.delBtn:SetScript("OnClick", function()
        if row.index then
            B.DeleteBinding(row.index)
        end
    end)

    return row
end

local function UpdateRow(row, index, buttonMap)
    local list = B.GetList()
    local cfg = list[index] or {}

    local auraName = cfg.auraID and B.GetSpellDisplayName(cfg.auraID) or ""
    row.name:SetText(auraName)
    row.icon.spellID = cfg.auraID
    row.icon.tex:SetTexture(B.GetSpellIcon(cfg.auraID) or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- 输入框显示已解析的名字。⚠️ 必须「先清空再写入」：EditBox:SetText 在文本未变时被
    -- 客户端短路为 no-op，初次 SetText 发生在窗口隐藏时（字体度量未就绪）会导致
    -- 水平滚动偏移算错、文字滚出框外看不见。先清空强制其按当前尺寸重算偏移。
    if not row.auraEdit:HasFocus() then
        row.auraEdit:SetText("")
        row.auraEdit:SetText(auraName)
    end
    local spellName = cfg.bindSpell and B.GetSpellDisplayName(cfg.bindSpell) or ""
    if not row.spellEdit:HasFocus() then
        row.spellEdit:SetText("")
        row.spellEdit:SetText(spellName)
    end

    if cfg.bindSpell and not buttonMap[cfg.bindSpell] then
        row.status:SetText(L("STATUS_NOT_ON_BAR"))
        row.status:SetTextColor(1, 0.4, 0.4)
    else
        row.status:SetText("")
    end

    row.unitDd._index = index
    SetDdText(row.unitDd, (cfg.unit == "target") and L("UNIT_TARGET") or L("UNIT_PLAYER"))
end

-- =========================================================
-- 面板刷新
-- =========================================================
local function DoRefresh()
    if not configFrame then return end

    configFrame.specText:SetText(L("SPEC_LABEL") .. ": " .. B.GetCurrentSpecName())
    if configFrame.enableCheck then
        configFrame.enableCheck:SetChecked(B.IsEnabled())
    end

    local list = B.GetList()
    local count = #list
    local buttonMap = B.BuildSpellButtonMap()

    for i = 1, count do
        local row = rows[i]
        if not row then
            row = CreateRow(i)
            rows[i] = row
        end
        row.index = i
        row.icon.spellID = nil
        row:Show()
        UpdateRow(row, i, buttonMap)
    end
    for i = count + 1, #rows do
        rows[i].index = nil
        rows[i].icon.spellID = nil
        rows[i]:Hide()
    end

    -- 空列表：隐藏滚动区（其自带底板会盖住提示文字），只显示提示
    local empty = (count == 0)
    configFrame.emptyList:SetShown(empty)
    configFrame.scroll:SetShown(not empty)
    configFrame.rows:SetSize(ROW_W, math.max(count, 1) * ROW_H)
    if configFrame.scroll.UpdateScrollChildRect then
        pcall(configFrame.scroll.UpdateScrollChildRect, configFrame.scroll)
    end

    -- 窗口高度 = 顶部实际几何 + 固定列表高度 + 添加按钮区 + 底部留白
    local pTop, rTop = configFrame:GetTop(), configFrame.scroll:GetTop()
    local headerH = (pTop and rTop and pTop > rTop) and (pTop - rTop) or 130
    configFrame:SetSize(PANEL_W, headerH + LIST_H + ADD_ROW_H + 20)
end

-- ⚠️ refreshing 守卫必须无条件复位：刷新中途一旦抛错，若不复位，之后所有刷新都会被挡掉
function B.RefreshPanel()
    if not configFrame or refreshing then return end
    refreshing = true
    pcall(DoRefresh)
    refreshing = false
end

-- =========================================================
-- 自有配置窗口
-- =========================================================
local function BuildConfigFrame()
    configFrame = CreateFrame("Frame", "EasyButtonAuraByUnitConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(PANEL_W, 380)
    configFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:SetClampedToScreen(true)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:Hide()

    local titleText = (configFrame.TitleContainer and configFrame.TitleContainer.TitleText) or configFrame.TitleText
    if titleText then titleText:SetText(ADDON_TITLE) end

    configFrame.specText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.specText:SetPoint("TOPLEFT", 16, -36)

    configFrame.desc = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    configFrame.desc:SetPoint("TOPLEFT", configFrame.specText, "BOTTOMLEFT", 0, -8)
    configFrame.desc:SetWidth(PANEL_W - 40)
    configFrame.desc:SetJustifyH("LEFT")
    configFrame.desc:SetText(L("PAGE_DESC"))

    -- 全局启用开关（角色级、不分专精；窗口右上角，标签锚在复选框左侧防越界）
    configFrame.enableCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    configFrame.enableCheck:SetSize(24, 24)
    configFrame.enableCheck:SetPoint("TOPRIGHT", -16, -34)
    configFrame.enableLabel = configFrame.enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configFrame.enableLabel:SetPoint("RIGHT", configFrame.enableCheck, "LEFT", -4, 0)
    configFrame.enableLabel:SetText(L("ENABLE"))
    configFrame.enableCheck:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(not self:GetChecked())
            return
        end
        B.SetEnabled(self:GetChecked() and true or false)
    end)
    configFrame.enableCheck:SetChecked(B.IsEnabled())

    configFrame.emptyList = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    configFrame.emptyList:SetPoint("TOPLEFT", configFrame.desc, "BOTTOMLEFT", 0, -12)
    configFrame.emptyList:SetWidth(PANEL_W - 40)
    configFrame.emptyList:SetJustifyH("LEFT")
    configFrame.emptyList:SetText(L("EMPTY_HINT"))
    configFrame.emptyList:Hide()

    -- 列表区：固定高度的滚动区（行数超过可见行数时出现滚动条，支持鼠标滚轮）
    configFrame.scroll = CreateFrame("ScrollFrame", "EasyButtonAuraByUnitConfigScroll", configFrame, "UIPanelScrollFrameTemplate")
    configFrame.scroll:SetPoint("TOPLEFT", configFrame.desc, "BOTTOMLEFT", 8, -14)
    configFrame.scroll:SetSize(ROW_W, LIST_H)
    configFrame.scroll:EnableMouseWheel(true)
    configFrame.scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar or _G["EasyButtonAuraByUnitConfigScrollScrollBar"]
        if not bar or not bar:IsShown() then return end
        local lo, hi = bar:GetMinMaxValues()
        local v = (bar:GetValue() or 0) - delta * ROW_H
        if v < lo then v = lo elseif v > hi then v = hi end
        bar:SetValue(v)
    end)

    configFrame.rows = CreateFrame("Frame", nil, configFrame.scroll)
    configFrame.rows:SetPoint("TOPLEFT", configFrame.scroll, "TOPLEFT", 0, 0)
    configFrame.rows:SetSize(ROW_W, LIST_H)
    configFrame.scroll:SetScrollChild(configFrame.rows)

    -- ⚠️ UIPanelScrollFrameTemplate 的滚动条默认锚在滚动区右侧外部，会越过窗口右边界；
    -- 显式重锚到滚动区【内部右缘】（内缩 2px）。模板把滚动条存在 ScrollBar 字段（大写 S）。
    local bar = configFrame.scroll.ScrollBar or _G["EasyButtonAuraByUnitConfigScrollScrollBar"]
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", configFrame.scroll, "TOPRIGHT", -2, -14)
        bar:SetPoint("BOTTOMRIGHT", configFrame.scroll, "BOTTOMRIGHT", -2, 14)
    end

    -- 底部「添加绑定」按钮：追加一条空绑定并刷新
    configFrame.addBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    configFrame.addBtn:SetSize(120, 24)
    configFrame.addBtn:SetPoint("TOPLEFT", configFrame.scroll, "BOTTOMLEFT", 8, -10)
    configFrame.addBtn:SetText(L("ADD"))
    configFrame.addBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        B.AddBinding()
    end)

    configFrame:SetScript("OnShow", function()
        B.RefreshPanel()
    end)
end

-- 打开配置窗口（战斗中不允许打开）
function B.ShowConfigFrame()
    if InCombatLockdown() then return end
    if not configFrame then BuildConfigFrame() end
    configFrame:Show()
end

-- /babu 与占位页按钮：切换配置窗口显隐（战斗中不响应）
function B.ToggleConfigFrame()
    if InCombatLockdown() then return end
    if not configFrame then BuildConfigFrame() end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

-- 战斗状态切换（主文件 PLAYER_REGEN_DISABLED / ENABLED 调用）：
-- 战斗中直接隐藏配置窗口并记住；战斗结束若此前是打开状态则恢复。
function B.OnCombatChanged(inCombat)
    if not configFrame then return end
    if inCombat then
        if configFrame:IsShown() then
            B._restoreConfig = true
            configFrame:Hide()
        end
    elseif B._restoreConfig then
        B._restoreConfig = nil
        B.ShowConfigFrame()
    end
end

-- =========================================================
-- 暴雪插件设置里的占位页（提示 + 按钮）
-- =========================================================
local function BuildBlizzardStub()
    local stub = CreateFrame("Frame")
    stub:SetSize(STUB_W, 200)

    -- canvas layout 要求的三函数：本页无实际设置，故均为空实现
    stub.OnCommit  = function() end
    stub.OnDefault = function() end
    stub.OnRefresh = function() end

    -- 页面顶部标题（英文插件名，Chattynator 风格）：左侧分类树有名字，页内自身也要有
    local title = stub:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", stub, "TOP", 0, -18)
    title:SetText(ADDON_TITLE)

    local hint = stub:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOP", stub, "TOP", 0, -58)
    hint:SetWidth(STUB_W - 40)
    hint:SetJustifyH("CENTER")
    hint:SetText(L("STUB_HINT"))

    local template = "SharedButtonLargeTemplate"
    local hasTemplate = false
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, template)
        hasTemplate = ok and info ~= nil
    end
    if not hasTemplate then template = "UIPanelDynamicResizeButtonTemplate" end
    local button = CreateFrame("Button", nil, stub, template)
    button:SetText(L("OPEN_OPTIONS"))
    button.padding = 40
    if DynamicResizeButton_Resize then pcall(DynamicResizeButton_Resize, button) end
    button:SetPoint("TOP", hint, "BOTTOM", 0, -30)
    button:SetScript("OnClick", function() B.ToggleConfigFrame() end)

    return stub
end

local function RegisterSettings()
    if B._stubRegistered then return end
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    B._stubRegistered = true
    local stub = BuildBlizzardStub()
    local category = Settings.RegisterCanvasLayoutCategory(stub, ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
end

-- =========================================================
-- 启动
-- =========================================================
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    RegisterSettings()
    BuildConfigFrame()
    B.RefreshPanel()
end)
