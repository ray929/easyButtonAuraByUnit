-- Options.lua
-- Easy Button Aura by Unit — 设置界面
--
-- 界面分两块（沿用 easyButtonAuraByCDM 的既定模式）：
--   1. 暴雪插件设置里的【占位页】：标题（金色大字，与插件图标同色系）+ 提示 + 按钮，
--      点按钮打开自有配置窗口。
--   2. 【自有配置窗口】：
--      · 固定头部：当前专精 + 「手动配置」区标题（不再放说明文字）。
--      · 滚动区三段：
--        - 手动绑定：每行 = 图标 + 光环[输入框] + 绑定技能[输入框] + 状态 + 删除
--          （单行紧凑；追踪单位自动识别，主文件对每条绑定同时挂 player/target 两路）。
--        - 自动学习：脱战扫描自身增益自动生成的绑定（角色级通用表），区标题行带
--          总开关复选框 + 清空按钮，每条可单独停用。
--        - 内置预设：PresetData.lua 按当前职业过滤，每条启用复选框（专精级，缺省启用）。
--
-- 战斗行为：战斗中配置窗口直接隐藏，战斗结束若此前是打开状态则自动恢复；
-- 战斗中不响应 /babu 与占位页按钮。
--
-- 布局约定：行内控件用【相对 row 的绝对坐标】，区段标题行内部允许链式锚定
-- （长度随本地化变化，链式更稳）；列表区为【固定高度 + 滚动条】，滚动条显式重锚进窗口内右缘。

local B = EasyButtonAuraByUnit
local L = B.L

local PANEL_W = 680
local ROW_W   = PANEL_W - 44
local ROW_H   = 30        -- 手动绑定行：单行紧凑
local PRESET_ROW_H = 28   -- 预设行
local LEARN_ROW_H  = 28   -- 自动学习行

local VISIBLE_ROWS = 12
local LIST_H = VISIBLE_ROWS * ROW_H

-- 行内控件横坐标（相对 row 左侧；单行布局，输入框前带名称标签）
local X_AURA_LABEL       = 30   -- 「光环」标签
local X_AURA,  W_AURA    = 60, 130
local X_SPELL_LABEL      = 196  -- 「绑定技能」标签
local X_SPELL, W_SPELL   = 252, 130
local X_STATUS           = 390
local X_DEL              = 478  -- 删除按钮（固定横坐标，不再贴窗口右缘）
local ADD_ROW_H = 36    -- 「添加绑定」按钮区高度

-- 暴雪设置分类名 / 配置窗口标题：不本地化，固定用插件名（工作区约定）
local ADDON_TITLE = "Easy Button Aura by Unit"

-- 标题金色：与插件图标（金色 E 圆环）主色一致（直方图采样主峰值 #E8BC75）
local GOLD_R, GOLD_G, GOLD_B = 0.910, 0.737, 0.459

local STUB_W = 520

local configFrame
local rows = {}         -- 手动绑定行
local learnedRows = {}  -- 自动学习行
local presetRows = {}   -- 内置预设行
local refreshing = false

-- =========================================================
-- 小工具
-- =========================================================
local function AddTip(widget, textFn)
    local prevEnter = widget:GetScript("OnEnter")
    local prevLeave = widget:GetScript("OnLeave")
    widget:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        local text = type(textFn) == "function" and textFn() or textFn
        if not text then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
-- 手动绑定行控件（单行：图标 + 光环[ ] + 绑定技能[ ] + 状态 + 删除）
-- =========================================================
local function CreateRow(index)
    local row = CreateFrame("Frame", nil, configFrame.rows)
    row:SetSize(ROW_W, ROW_H)
    -- 与自动学习/预设行同缩进（row x=30 → 图标 x≈34 对齐学习行图标）
    row:SetPoint("TOPLEFT", 30, -(index - 1) * ROW_H)

    -- 图标（悬停显示光环法术提示）
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints()
    AddTip(row.icon, function()
        return row.icon.spellID and B.GetSpellDisplayName(row.icon.spellID) or nil
    end)

    -- 「光环」标签
    row.auraLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.auraLabel:SetPoint("LEFT", X_AURA_LABEL, 0)
    row.auraLabel:SetText(L("COL_AURA"))

    -- 光环输入框
    row.auraEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.auraEdit:SetSize(W_AURA, 20)
    row.auraEdit:SetPoint("LEFT", X_AURA, 0)
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

    -- 「绑定技能」标签
    row.spellLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.spellLabel:SetPoint("LEFT", X_SPELL_LABEL, 0)
    row.spellLabel:SetText(L("COL_SPELL_BIND"))

    -- 技能输入框
    row.spellEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.spellEdit:SetSize(W_SPELL, 20)
    row.spellEdit:SetPoint("LEFT", X_SPELL, 0)
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

    -- 状态提示（技能不在动作条上等）
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", X_STATUS, 0)
    row.status:SetJustifyH("LEFT")

    -- 删除按钮（固定横坐标，不贴右缘）
    row.delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delBtn:SetSize(48, 20)
    row.delBtn:SetPoint("LEFT", X_DEL, 0)
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
end

-- =========================================================
-- 内置预设区（按当前职业过滤；复选框启停）
-- =========================================================
-- 预设光环名列表（auraSpellID 兼容数组）
local function PresetAuraNames(e)
    local ids = (type(e.auraSpellID) == "table") and e.auraSpellID or { e.auraSpellID }
    local names = {}
    for _, id in ipairs(ids) do
        names[#names + 1] = B.GetSpellDisplayName(id)
    end
    return names
end

-- 预设行显示文本：光环名（数组取首个 + 计数）→ 技能名
local function PresetDisplayText(e)
    local spellName = B.GetSpellDisplayName(e.actionSpellID)
    if e.enchantID then
        -- 上游 enchantName 是英文硬编码；一律显示客户端本地化的技能名
        -- （GetSpellDisplayName 查询失败时返回数字字符串，此时才回退 enchantName）
        if spellName and spellName ~= "" and spellName ~= tostring(e.actionSpellID) then
            return spellName
        end
        return (e.enchantName or tostring(e.enchantID)) .. " → " .. spellName
    end
    local ids = (type(e.auraSpellID) == "table") and e.auraSpellID or { e.auraSpellID }
    local names = {}
    for _, id in ipairs(ids) do
        names[#names + 1] = B.GetSpellDisplayName(id)
    end
    if #names > 1 then
        return (names[1] or "?") .. " (+" .. (#names - 1) .. ") → " .. spellName
    end
    return (names[1] or "?") .. " → " .. spellName
end

local function PresetTooltipText(e)
    local spellName = B.GetSpellDisplayName(e.actionSpellID)
    if e.enchantID then
        return B.GetSpellDisplayName(e.actionSpellID) ..
            (e.enchantID and (" (enchantID: " .. e.enchantID .. ")") or "")
    end
    local names = PresetAuraNames(e)
    return table.concat(names, ", ") .. " → " .. spellName
end

local function CreatePresetRows()
    local list = B.GetClassPresetList()
    for i, item in ipairs(list) do
        local e = item.e
        local row = CreateFrame("Frame", nil, configFrame.rows)
        row:SetSize(ROW_W, PRESET_ROW_H)
        row.key = item.key

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(22, 22)
        row.check:SetPoint("LEFT", 2, 0)
        row.check:SetHitRectInsets(0, 0, 0, 0)
        row.check:SetScript("OnClick", function(self)
            B.SetPresetEnabled(row.key, self:GetChecked() and true or false)
        end)

        row.iconTex = row:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetSize(18, 18)
        row.iconTex:SetPoint("LEFT", 30, 0)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.text:SetPoint("LEFT", row.iconTex, "RIGHT", 8, 0)
        row.text:SetJustifyH("LEFT")

        AddTip(row.check, function() return PresetTooltipText(e) end)
        AddTip(row.iconTex, function() return PresetTooltipText(e) end)

        row.iconTex:SetTexture(B.GetSpellIcon(e.actionSpellID)
            or (not e.enchantID and B.GetSpellIcon(type(e.auraSpellID) == "table" and e.auraSpellID[1] or e.auraSpellID))
            or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(PresetDisplayText(e))

        presetRows[#presetRows + 1] = row
    end
end

-- =========================================================
-- 自动学习区（角色级通用表；区标题行带总开关 + 清空，行带单条停用）
-- =========================================================
local function LearnedDisplayText(e)
    local auraName = B.GetSpellDisplayName(e.auraID)
    local spellName = B.GetSpellDisplayName(e.actionSpellID)
    local text
    if spellName and spellName ~= auraName and spellName ~= tostring(e.actionSpellID) then
        text = auraName .. " → " .. spellName
    else
        text = auraName
    end
    -- 敌对目标减益条目标注「（目标）」，与自身条目区分
    if (e.unit or "player") == "target" then
        text = text .. L("LEARNED_TARGET_TAG")
    end
    -- 该光环已被当前专精手动绑定接管 → 标注（运行时该条目不生效，删掉手动绑定即自动恢复）
    if B.IsAuraManuallyBound and B.IsAuraManuallyBound(e.auraID) then
        text = text .. L("LEARN_SUPERSEDED")
    end
    return text
end

local function CreateLearnedRow(index)
    local row = CreateFrame("Frame", nil, configFrame.rows)
    row:SetSize(ROW_W, LEARN_ROW_H)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(22, 22)
    row.check:SetPoint("LEFT", 2, 0)
    row.check:SetHitRectInsets(0, 0, 0, 0)
    row.check:SetScript("OnClick", function(self)
        if row.index then
            B.SetLearnedDisabled(row.index, not self:GetChecked())
        end
    end)

    row.iconTex = row:CreateTexture(nil, "ARTWORK")
    row.iconTex:SetSize(18, 18)
    row.iconTex:SetPoint("LEFT", 30, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row.iconTex, "RIGHT", 8, 0)
    row.text:SetJustifyH("LEFT")

    AddTip(row.check, function()
        if row.index then
            local e = B.GetLearnedList()[row.index]
            return e and LearnedDisplayText(e) or nil
        end
    end)

    learnedRows[#learnedRows + 1] = row
    return row
end

-- =========================================================
-- 面板刷新 + 滚动区内部布局
-- =========================================================
-- 手动行数 / 学习表变化时，重排滚动区内的动态区段（添加按钮 / 自动学习 / 内置预设）
local function LayoutScrollContent(count)
    local y = count * ROW_H
    configFrame.addBtn:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 30, -(y + 4))

    -- 分割线1 + 自动学习区标题行（控件横向链式锚定，随本地化文字长度自适应）
    local dy1 = y + ADD_ROW_H + 8
    configFrame.divLearn:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 20, -dy1)
    local ly = dy1 + 14
    configFrame.learnedHeader:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 8, -ly)
    configFrame.learnCheck:SetPoint("LEFT", configFrame.learnedHeader, "RIGHT", 14, -1)
    configFrame.learnLabel:SetPoint("LEFT", configFrame.learnCheck, "RIGHT", 2, 0)
    configFrame.learnClear:SetPoint("LEFT", configFrame.learnLabel, "RIGHT", 10, -3)

    local learned = B.GetLearnedList()
    local nLearned = B.IsLearnEnabled() and #learned or 0
    -- 学习条目行：定位在标题行与分割线2之间（此前漏写 SetPoint，行无锚定默认落在
    -- 滚动区中心互相重叠 → 配置界面里「学到了但看不见」）
    for i, lr in ipairs(learnedRows) do
        lr:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 4, -(ly + 26 + (i - 1) * LEARN_ROW_H))
    end

    -- 分割线2 + 内置预设区标题 + 行
    local dy2 = ly + 26 + nLearned * LEARN_ROW_H + 10
    configFrame.divPreset:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 20, -dy2)
    local ph = dy2 + 14
    configFrame.presetHeader:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 8, -ph)
    local py2 = ph + 26
    for i, pr in ipairs(presetRows) do
        pr:SetPoint("TOPLEFT", configFrame.rows, "TOPLEFT", 4, -(py2 + (i - 1) * PRESET_ROW_H))
    end
    return py2 + #presetRows * PRESET_ROW_H + 8
end

local function DoRefresh()
    if not configFrame then return end

    configFrame.specText:SetText(L("SPEC_LABEL") .. ": " .. B.GetCurrentSpecName())
    if configFrame.enableCheck then
        configFrame.enableCheck:SetChecked(B.IsEnabled())
    end

    -- 手动绑定行
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

    -- 自动学习行（总开关关闭时整段隐藏，标题行保留以便重新开启）
    local learned = B.GetLearnedList()
    configFrame.learnCheck:SetChecked(B.IsLearnEnabled())
    local nVisible = B.IsLearnEnabled() and #learned or 0
    for i = 1, nVisible do
        local row = learnedRows[i] or CreateLearnedRow(i)
        local e = learned[i]
        row.index = i
        row.check:SetChecked(not e.disabled)
        row.iconTex:SetTexture(B.GetSpellIcon(e.auraID)
            or B.GetSpellIcon(e.actionSpellID)
            or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(LearnedDisplayText(e))
        row:Show()
    end
    for i = nVisible + 1, #learnedRows do
        learnedRows[i].index = nil
        learnedRows[i]:Hide()
    end

    -- 内置预设复选框状态（随专精切换刷新）
    for _, pr in ipairs(presetRows) do
        pr.check:SetChecked(B.IsPresetEnabled(pr.key))
    end

    local totalH = LayoutScrollContent(count)
    configFrame.rows:SetSize(ROW_W, math.max(totalH, LIST_H))
    if configFrame.scroll.UpdateScrollChildRect then
        pcall(configFrame.scroll.UpdateScrollChildRect, configFrame.scroll)
    end

    -- 窗口高度 = 顶部实际几何 + 固定列表高度 + 底部留白
    local pTop, rTop = configFrame:GetTop(), configFrame.scroll:GetTop()
    local headerH = (pTop and rTop and pTop > rTop) and (pTop - rTop) or 90
    configFrame:SetSize(PANEL_W, headerH + LIST_H + 20)
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
    configFrame:SetSize(PANEL_W, 520)
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

    -- 「手动配置」区标题（固定头部；不再放说明文字——用户指定去掉）
    configFrame.manualHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.manualHeader:SetPoint("TOPLEFT", configFrame.specText, "BOTTOMLEFT", 0, -8)
    configFrame.manualHeader:SetText(L("SECTION_MANUAL"))

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

    -- 列表区：固定高度的滚动区（行数超过可见行数时出现滚动条，支持鼠标滚轮）
    configFrame.scroll = CreateFrame("ScrollFrame", "EasyButtonAuraByUnitConfigScroll", configFrame, "UIPanelScrollFrameTemplate")
    configFrame.scroll:SetPoint("TOPLEFT", configFrame.manualHeader, "BOTTOMLEFT", 8, -10)
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

    -- 底部「添加绑定」按钮：追加一条空绑定并刷新（Y 位置由 LayoutScrollContent 动态排）
    configFrame.addBtn = CreateFrame("Button", nil, configFrame.rows, "UIPanelButtonTemplate")
    configFrame.addBtn:SetSize(120, 24)
    configFrame.addBtn:SetText(L("ADD"))
    configFrame.addBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        B.AddBinding()
    end)

    -- 自动学习区：标题 + 总开关复选框 + 清空按钮（横向链式锚定，随本地化自适应）
    configFrame.learnedHeader = configFrame.rows:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.learnedHeader:SetText(L("SECTION_LEARNED"))

    configFrame.learnCheck = CreateFrame("CheckButton", nil, configFrame.rows, "UICheckButtonTemplate")
    configFrame.learnCheck:SetSize(22, 22)
    configFrame.learnCheck:SetHitRectInsets(0, 0, 0, 0)
    AddTip(configFrame.learnCheck, L("LEARN_TIP"))
    configFrame.learnCheck:SetScript("OnClick", function(self)
        B.SetLearnEnabled(self:GetChecked() and true or false)
    end)

    configFrame.learnLabel = configFrame.learnCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configFrame.learnLabel:SetText(L("LEARN_ENABLE"))

    configFrame.learnClear = CreateFrame("Button", nil, configFrame.rows, "UIPanelButtonTemplate")
    configFrame.learnClear:SetSize(64, 20)
    configFrame.learnClear:SetText(L("LEARN_CLEAR"))
    configFrame.learnClear:SetScript("OnClick", function()
        B.ClearLearned()
    end)

    -- 内置预设区标题 + 行（按当前职业一次性构建；职业不会随会话变化）
    configFrame.presetHeader = configFrame.rows:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.presetHeader:SetText(L("PRESET_HEADER"))

    -- 分割线：手动绑定 | 自动学习 | 内置预设 三段之间（1px 半透明，绝对定位在 LayoutScrollContent）
    for _, key in ipairs({ "divLearn", "divPreset" }) do
        local div = configFrame.rows:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.7, 0.7, 0.7, 0.35)
        div:SetSize(ROW_W - 40, 1)
        configFrame[key] = div
    end

    CreatePresetRows()

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
-- 暴雪插件设置里的占位页（标题 + 提示 + 按钮）
-- =========================================================
local function BuildBlizzardStub()
    local stub = CreateFrame("Frame")
    stub:SetSize(STUB_W, 200)

    -- canvas layout 要求的三函数：本页无实际设置，故均为空实现
    stub.OnCommit  = function() end
    stub.OnDefault = function() end
    stub.OnRefresh = function() end

    -- 页面顶部标题（英文插件名，金色大字——与插件图标同色系）
    local title = stub:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", stub, "TOP", 0, -18)
    title:SetFont(STANDARD_TEXT_FONT, 22, "")
    title:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
    title:SetText(ADDON_TITLE)

    local hint = stub:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOP", stub, "TOP", 0, -64)
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
