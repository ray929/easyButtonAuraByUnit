-- easyButtonAuraByUnit.lua
-- Easy Button Aura by Unit
--
-- 剥离自上游 ActionbarEnhanced/Preset.lua（技能栏光环显示），并按用户需求重设计：
--   · 手动绑定：光环 ID → 技能 ID 由玩家在配置窗口（/babu）绑定，按专精存档。
--     绑定不选追踪单位——每条绑定自动同时挂 player(HELPFUL|PLAYER) 与 target(HARMFUL|PLAYER)
--     两路容器，哪路命中显示哪路（另一路自然无匹配，代价只是每条绑定多一个容器）。
--   · 内置预设：上游 PresetData 全量移植（见 PresetData.lua，按职业过滤），配置窗口「预设」区
--     逐条启用/禁用（专精级覆盖，缺省启用）。含武器临时附魔（火舌/风怒/裁决仪式等，
--     GetWeaponEnchantInfo 战斗安全通道，独立覆盖层 + 1 秒 ticker，不参与合并，两把武器独立计时）。
--   · 光环渲染沿用上游 12.1 官方安全通道【AuraContainer】（暴雪渲染层）：
--     addon 零读取光环数据、零 secret/taint 问题；倒计时 / 层数 / 显隐全部由暴雪驱动。
--   · 合并规则：多条绑定指向同一单位 + 同一技能时，运行时合并成一个 includeSpellIDs 集合、
--     共用一个容器（多光环任一命中即显示，也避免多容器叠在同一按钮上）。
--   · 存在标记 = CDMButtonAuras 同款柔光材质（Textures/Overlay.tga，ADD 混合）：
--     挂在暴雪创建的 AuraButton 上（initializeFrame 回调允许），随按钮显隐 → 不需要读任何
--     光环存在性信号（AuraButton:IsShown() 是 secret，我们根本不读它）；独立纹理层，
--     不碰 icon（与 easyButtonColor 零冲突）、不依赖各 UI 边框结构。
--   · 配色：自身增益 = 绿（数字 / 柔光），敌对目标减益 = 纯红。
--   · 全局开关 = 角色级；绑定 = 专精级。全静默（无 print / 无弹窗）。
--
-- 12.x secret 值红线：一律 issecretvalue 判定，不比较 secret 数值，外部数据 pcall 兜底。

EasyButtonAuraByUnit = EasyButtonAuraByUnit or {}
local B = EasyButtonAuraByUnit
B.ADDON_NAME = ...

-- =========================================================
-- 本地化（自维护纯 Lua 表；三语齐全，缺失回退 enUS）
-- =========================================================
local LOCALES = {
    enUS = {
        SPEC_LABEL        = "Current Specialization",
        SPEC_UNKNOWN      = "Unknown",
        ENABLE            = "Global Enable",
        SECTION_MANUAL    = "Manual Bindings",
        SECTION_LEARNED   = "Auto-Learned (out-of-combat scan)",
        LEARN_ENABLE      = "Enable",
        LEARN_CLEAR       = "Clear",
        LEARNED_TARGET_TAG = " (target)",
        LEARN_SUPERSEDED  = " (taken over by manual binding)",
        LEARN_TIP         = "While out of combat, scans your own timed buffs (and your debuffs on a hostile target) and shows them on matching action bar buttons. Combat is never scanned; can be cleared anytime.",
        COL_AURA          = "Aura",
        COL_SPELL_BIND    = "Bind Spell",
        COL_SPELL         = "Spell",
        ADD               = "Add Binding",
        DEL               = "Delete",
        ERR_INVALID       = "Spell not found",
        ERR_NO_AURA       = "Invalid aura",
        STATUS_NOT_ON_BAR = "not on action bars",
        OPEN_OPTIONS      = "Open Options",
        STUB_HINT         = "Click the button below, or type /babu, to open the configuration window.",
        PRESET_HEADER     = "Built-in Presets",
    },
    zhCN = {
        SPEC_LABEL        = "当前专精",
        SPEC_UNKNOWN      = "未知",
        ENABLE            = "全局启用",
        SECTION_MANUAL    = "手动配置",
        SECTION_LEARNED   = "自动学习（脱战扫描）",
        LEARN_ENABLE      = "启用",
        LEARN_CLEAR       = "清空",
        LEARNED_TARGET_TAG = "（目标）",
        LEARN_SUPERSEDED  = "（已被手动绑定接管）",
        LEARN_TIP         = "脱战时扫描自身增益光环与敌对目标身上的我方减益，自动显示到动作条上的同名技能按钮。战斗中绝不扫描；可随时清空或整体关闭。",
        COL_AURA          = "光环",
        COL_SPELL_BIND    = "绑定技能",
        COL_SPELL         = "技能",
        ADD               = "添加绑定",
        DEL               = "删除",
        ERR_INVALID       = "未找到该法术",
        ERR_NO_AURA       = "光环 ID 无效",
        STATUS_NOT_ON_BAR = "不在动作条上",
        OPEN_OPTIONS      = "打开配置",
        STUB_HINT         = "点击按钮，或者输入 /babu 打开配置窗口。",
        PRESET_HEADER     = "内置预设",
    },
    zhTW = {
        SPEC_LABEL        = "目前專精",
        SPEC_UNKNOWN      = "未知",
        ENABLE            = "全域啟用",
        SECTION_MANUAL    = "手動配置",
        SECTION_LEARNED   = "自動學習（脫戰掃描）",
        LEARN_ENABLE      = "啟用",
        LEARN_CLEAR       = "清空",
        LEARNED_TARGET_TAG = "（目標）",
        LEARN_SUPERSEDED  = "（已被手動綁定接管）",
        LEARN_TIP         = "脫戰時掃描自身增益光環與敵對目標身上的我方減益，自動顯示到快捷列上的同名技能按鈕。戰鬥中絕不掃描；可隨時清空或整體關閉。",
        COL_AURA          = "光環",
        COL_SPELL_BIND    = "綁定技能",
        COL_SPELL         = "技能",
        ADD               = "新增綁定",
        DEL               = "刪除",
        ERR_INVALID       = "找不到該法術",
        ERR_NO_AURA       = "光環 ID 無效",
        STATUS_NOT_ON_BAR = "不在快捷列上",
        OPEN_OPTIONS      = "開啟設定",
        STUB_HINT         = "點擊按鈕，或者輸入 /babu 開啟設定視窗。",
        PRESET_HEADER     = "內建預設",
    },
}

local activeLocale = LOCALES[GetLocale()] or LOCALES.enUS

local function L(key)
    local v = activeLocale[key]
    if v == nil then v = LOCALES.enUS[key] end
    return v
end
B.L = L

-- =========================================================
-- 样式常量（时间 / 层数 / 柔光的字体与配色；画面风格集中在此）
-- =========================================================
B.Style = {
    FONT             = STANDARD_TEXT_FONT,
    FONT_SIZE        = 16,
    OUTLINE          = "THICKOUTLINE",
    TIME_COLOR_SELF  = { 0.20, 1.00, 0.20 },                    -- 倒计时（自身增益 / 武器附魔）：绿
    TIME_COLOR_ENEMY = { 1.00, 0.00, 0.00 },                    -- 倒计时（敌对目标减益）：纯红
    STACK_COLOR      = { 0x3F / 255, 0xC7 / 255, 0xEB / 255 },  -- 层数：#3FC7EB
    GLOW_SELF        = { 0.00, 0.70, 0.00 },                    -- 柔光（自身）：绿（CDMButtonAuras 同款）
    GLOW_ENEMY       = { 1.00, 0.00, 0.00 },                    -- 柔光（敌对目标）：红
    GLOW_ALPHA       = 0.5,
}

B.OVERLAY_TEXTURE = "Interface\\AddOns\\" .. B.ADDON_NAME .. "\\Textures\\Overlay"

-- =========================================================
-- Secret Value 安全工具（12.x 红线）
-- =========================================================
local function IsSecret(v)
    local ok, res = pcall(function() return issecretvalue and issecretvalue(v) end)
    return ok and res
end
B.IsSecret = IsSecret

-- =========================================================
-- 技能名 / ID 解析与显示
-- =========================================================
-- 名字 / ID 皆可，返回解析后的 spellID（解析失败返回 nil）
function B.ParseSpellInput(text)
    text = strtrim(tostring(text or ""))
    if text == "" then return nil end
    local num = tonumber(text)
    if num then
        local ok, info = pcall(C_Spell.GetSpellInfo, num)
        if ok and info and info.name then return num end
        return nil
    end
    local okID, id = pcall(function() return C_Spell.GetSpellID(text) end)
    if okID and id and id > 0 then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and info and info.name then return id end
    end
    local ok2, info2 = pcall(C_Spell.GetSpellInfo, text)
    if ok2 and info2 and info2.name then
        return info2.spellID or info2.id
    end
    return nil
end

-- 光环 ID 解析：纯数字直接接受（光环 ID 客户端可能解析不出名字，交给玩家自己把握）；
-- 文本则按名字解析成 ID。
function B.ParseAuraInput(text)
    text = strtrim(tostring(text or ""))
    if text == "" then return nil end
    local num = tonumber(text)
    if num and num > 0 and num == math.floor(num) then return num end
    return B.ParseSpellInput(text)
end

function B.GetSpellDisplayName(spellID)
    if not spellID then return "" end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and info and info.name then return info.name end
    return tostring(spellID)
end

function B.GetSpellIcon(spellID)
    if not spellID then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and info and info.iconID then return info.iconID end
    return nil
end

-- =========================================================
-- 存档：全局开关（角色级）+ 绑定列表 / 预设启停 / 自动学习表（按专精）
-- easyButtonAuraByUnitDB.enabled = true|false          （角色级，所有专精共用）
-- easyButtonAuraByUnitDB.specs[specID] = { list = { cfg... }, presets = { [key]=false... },
--                                          learned = { entry... } }
--   cfg = { auraID = <光环 spellID>, bindSpell = <目标技能 spellID> }
--     （不存 unit：运行时自动同时挂 player / target 两路，见 RebuildGroups）
--   presets：预设禁用覆盖表——只记被关掉的条目（key = PresetData.lua 中的序号），缺省 = 启用
-- easyButtonAuraByUnitDB.learnEnabled = true|false     （角色级；自动学习总开关）
-- specs[specID].learned = { { auraID=..., actionSpellID=..., unit=..., disabled=bool }... }
--   自动学习表：脱战扫描当前形态下的光环 → 匹配动作条同名技能 自动生成的绑定（专精级——
--   扫描的就是当前专精的 buff/debuff，各专精各学各的，共享 buff 玩到该专精时自然补学）。
--   unit = "player"（自身增益）或 "target"（敌对目标身上我方减益），缺省 player。
--   每条自带 disabled 标记，可单独停用。旧版角色级根表在 InitStorage 迁入当前专精。
-- specID 取自 GetSpecializationInfo(GetSpecialization())，拿不到时用 0（通用槽）。
-- =========================================================
local function GetCurrentSpecID()
    local ok, specID = pcall(function()
        local idx = GetSpecialization()
        if not idx or idx == 0 then return nil end
        return (select(1, GetSpecializationInfo(idx)))
    end)
    if ok and specID then return specID end
    return 0
end

function B.InitStorage()
    easyButtonAuraByUnitDB = easyButtonAuraByUnitDB or {}
    if easyButtonAuraByUnitDB.enabled == nil then
        easyButtonAuraByUnitDB.enabled = true
    end
    if easyButtonAuraByUnitDB.learnEnabled == nil then
        easyButtonAuraByUnitDB.learnEnabled = true
    end
    if not easyButtonAuraByUnitDB.specs then
        easyButtonAuraByUnitDB.specs = { [0] = { list = {} } }
    end
end
-- 全局开关（角色级；关闭 = 撤下全部容器与覆盖层）
function B.IsEnabled()
    return easyButtonAuraByUnitDB and easyButtonAuraByUnitDB.enabled ~= false
end

-- 切换到「当前专精」配置槽：B.db 指向 specs[specID] 子表
function B.SelectSpec(specID)
    B.InitStorage()
    specID = specID or GetCurrentSpecID()
    local specs = easyButtonAuraByUnitDB.specs
    if not specs[specID] then
        specs[specID] = { list = {}, presets = {}, learned = {} }
    end
    specs[specID].list = specs[specID].list or {}
    specs[specID].presets = specs[specID].presets or {}
    specs[specID].learned = specs[specID].learned or {}
    -- 旧版迁移：learned 曾是角色级根表 → 整体搬进当前专精（条目按光环 ID 精确匹配，
    -- 混入其他专精的条目不会误触发，无需逐条甄别；该专精日后扫到会覆盖式补齐）
    if easyButtonAuraByUnitDB.learned then
        if #easyButtonAuraByUnitDB.learned > 0 and #specs[specID].learned == 0 then
            specs[specID].learned = easyButtonAuraByUnitDB.learned
        end
        easyButtonAuraByUnitDB.learned = nil
    end
    B.db = specs[specID]
    B.currentSpecID = specID
end

function B.GetList()
    if B.db and B.db.list then return B.db.list end
    return {}
end

-- 该光环 ID 是否已被当前专精的手动绑定覆盖（手动 > 学习 优先级判据）
function B.IsAuraManuallyBound(auraID)
    for _, cfg in ipairs(B.GetList()) do
        if cfg.auraID == auraID then return true end
    end
    return false
end

-- 新增一条空绑定（返回新条目索引）
function B.AddBinding()
    B.InitStorage()
    local list = B.GetList()
    list[#list + 1] = {}
    B.NotifyBindingsChanged()
    return #list
end

function B.DeleteBinding(index)
    local list = B.GetList()
    if list[index] then
        table.remove(list, index)
        B.NotifyBindingsChanged()
    end
end

-- 更新某条绑定的字段（auraID / bindSpell）
function B.UpdateBinding(index, key, value)
    local list = B.GetList()
    local cfg = list[index]
    if cfg then
        cfg[key] = value
        B.NotifyBindingsChanged()
    end
end

-- =========================================================
-- 预设启停（专精级覆盖；只记禁用条目，缺省 = 启用）
-- =========================================================
function B.IsPresetEnabled(key)
    B.InitStorage()
    local db = easyButtonAuraByUnitDB.specs[B.currentSpecID or 0]
    return not (db and db.presets and db.presets[key] == false)
end

function B.SetPresetEnabled(key, enabled)
    B.InitStorage()
    local db = easyButtonAuraByUnitDB.specs[B.currentSpecID or 0]
    if not db then return end
    db.presets = db.presets or {}
    -- 启用 = 清除覆盖（回到缺省启用）；禁用 = 记 false。
    -- 不写 true 值：预设表日后扩充/调整顺序时，旧的覆盖记录不会错位生效。
    -- ⚠️ 不能写 `enabled and nil or false`：Lua 里 (true and nil) = nil，nil or false = false，
    -- 勾选也会存成 false → 取消后永远无法重新勾上（2026-10-09 用户实测踩坑）。
    if enabled then
        db.presets[key] = nil
    else
        db.presets[key] = false
    end
    B.NotifyBindingsChanged()
end

-- 当前职业可用的预设列表（含 class=nil 的种族预设）：{ { key = 序号, e = 条目 } }
function B.GetClassPresetList()
    local _, classToken = UnitClass("player")
    local out = {}
    for i, e in ipairs(B.PRESET_DATA or {}) do
        if not e.class or e.class == classToken then
            out[#out + 1] = { key = i, e = e }
        end
    end
    return out
end

-- =========================================================
-- 自动学习表（专精级；总开关 learnEnabled 为角色级）
-- =========================================================
function B.IsLearnEnabled()
    B.InitStorage()
    return easyButtonAuraByUnitDB.learnEnabled ~= false
end

function B.SetLearnEnabled(v)
    B.InitStorage()
    easyButtonAuraByUnitDB.learnEnabled = v and true or false
    B.NotifyBindingsChanged()
end

function B.GetLearnedList()
    B.InitStorage()
    return B.db.learned
end

-- 单条停用/启用（entry.disabled）
function B.SetLearnedDisabled(index, disabled)
    local list = B.GetLearnedList()
    local e = list[index]
    if e then
        e.disabled = disabled and true or nil
        B.NotifyBindingsChanged()
    end
end

function B.ClearLearned()
    B.InitStorage()
    wipe(B.db.learned)
    B.NotifyBindingsChanged()
end

function B.GetCurrentSpecName()
    local ok, name = pcall(function()
        local idx = GetSpecialization()
        if not idx or idx == 0 then return nil end
        return (select(2, GetSpecializationInfo(idx)))
    end)
    if ok and name then return name end
    return L("SPEC_UNKNOWN")
end

-- =========================================================
-- 动作条按钮前缀全集：暴雪 ActionButtonUtil.ActionBarButtonNames 可能不覆盖全部栏位
-- （11.0 起的 MultiBar5/6/7 等新栏），扫描期漏栏的直接后果是「技能明明在条上却学不到」
-- （复原放动作条5踩过：ID/名字双双落空，挪到动作条3就能学会）。这里取并集：暴雪列表在前
-- （官方语义优先），已知栏位兜底；_G 中不存在的名字查不到按钮，无害。学习扫描与渲染定位
-- 两处消费方必须共用同一份列表，否则扫描期和显示期会对不上。
local KNOWN_BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
    "MultiBar8Button",
}

local function GetBarPrefixList()
    local list, seen = {}, {}
    local blizz = (ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames) or {}
    for _, p in ipairs(blizz) do
        if type(p) == "string" and not seen[p] then
            seen[p] = true
            list[#list + 1] = p
        end
    end
    for _, p in ipairs(KNOWN_BAR_PREFIXES) do
        if not seen[p] then
            seen[p] = true
            list[#list + 1] = p
        end
    end
    return list
end

-- 原生动作条按钮解析（照搬上游 Preset.lua：按法术名找按钮，缓存 + 自愈验证）
-- =========================================================
local function FindActionButtonForSpellName(name)
    if not name then return end
    for _, actionBar in ipairs(GetBarPrefixList()) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[actionBar .. i]
            -- 只匹配【可见】的按钮：左右动作条共享 action 槽位，同一技能会同时命中两个按钮，
            -- 不跳过隐藏按钮会错误匹配到隐藏栏（"拖到右栏却显示在左栏/不显示"）。
            if btn and btn:IsShown() then
                local atype, actionSpellID = GetActionInfo(btn.action)
                if atype == "macro" and GetMacroSpell and type(actionSpellID) == "number" then
                    -- 宏按钮：GetActionInfo 第二返回值是宏槽位号，解析宏实际施放的法术
                    actionSpellID = GetMacroSpell(actionSpellID)
                end
                if actionSpellID then
                    -- 直接 GetSpellName，不要 GetBaseSpell 重定向（上游 AutoCDM 踩过名字错位坑）
                    local actionSpellName = C_Spell.GetSpellName(actionSpellID)
                    if name == actionSpellName then
                        return btn
                    end
                end
            end
        end
    end
    for i = 1, (NUM_SPECIAL_BUTTONS or 10) do
        local stanceBtn = StanceBar and StanceBar.actionButtons and StanceBar.actionButtons[i]
        if stanceBtn then
            local stanceSpellID = select(4, GetShapeshiftFormInfo(stanceBtn:GetID()))
            if stanceSpellID then
                local stanceSpellName = C_Spell.GetSpellName(stanceSpellID)
                if name == stanceSpellName then
                    return stanceBtn
                end
            end
        end
    end
end

-- 从按钮取「实际施放的法术 ID」：直接法术返回 GetActionInfo 的 ID，宏按钮解析 GetMacroSpell。
-- 技能 ID 与光环 ID 是两套常见不同的值（复原：技能 1231411 / 光环 1231418）——学习条目
-- 两者分开存：auraID 用于光环匹配，actionSpellID 用于按钮定位与 IsPlayerSpell 门禁。
local function ResolveActionSpellID(btn)
    if not (btn and btn.action ~= nil) then return end
    local ok, atype, id = pcall(GetActionInfo, btn.action)
    if not ok then return end
    if atype == "spell" and type(id) == "number" and id > 0 and not IsSecret(id) then
        return id
    end
    if atype == "macro" and GetMacroSpell and type(id) == "number" then
        local okM, mSpell = pcall(GetMacroSpell, id)
        if okM and type(mSpell) == "number" and mSpell > 0 and not IsSecret(mSpell) then
            return mSpell
        end
    end
end

-- 按钮缓存解析（含自愈验证）：切专精/翻页后按钮可能已换成别的技能，用 GetActionInfo +
-- 名字比对验证缓存，失效即作废重找（上游 2026-08-21 修「切专精后剩余时间滞留」）。
local function ResolveButton(p, actionSpellID)
    local actionName = C_Spell.GetSpellName(actionSpellID)
    if p.button and p.button.action ~= nil then
        local okA, _, curSpellID = pcall(GetActionInfo, p.button.action)
        local curName = (okA and curSpellID) and C_Spell.GetSpellName(curSpellID) or nil
        if curName ~= actionName then
            p.button = nil
        end
    end
    if not p.button then
        p.button = FindActionButtonForSpellName(actionName)
    end
    return p.button
end

-- 失活清理：隐藏容器/覆盖层并清按钮缓存，防残留显示滞留在旧按钮上
local function DeactivateGroup(p)
    if p.container then p.container:Hide() end
    if p.overlay then p.overlay:Hide() end
    p.button = nil
    p._rectL, p._rectB, p._rectW, p._rectH = nil, nil, nil, nil
end

-- 供配置窗口检查「绑定目标技能是否在动作条上」
function B.BuildSpellButtonMap()
    local map = {}
    local barNames = GetBarPrefixList()
    local maxBtns = NUM_ACTIONBAR_BUTTONS or 12
    for _, prefix in ipairs(barNames) do
        if type(prefix) == "string" then
            for i = 1, maxBtns do
                local btn = _G[prefix .. i]
                if btn and btn.action then
                local ok, atype, id = pcall(GetActionInfo, btn.action)
                if ok and atype == "spell" and id and id > 0 and not IsSecret(id) and not map[id] then
                    map[id] = prefix .. i
                elseif ok and atype == "macro" and GetMacroSpell then
                    -- 宏按钮：GetActionInfo 只给宏槽位号，解析宏指向的法术（灵魂行者的恩赐这类
                    -- 常被拖成宏/#showtooltip，按 ID/名字都匹配不到就是漏学了）
                    local mok, mSpell = pcall(GetMacroSpell, id)
                    if mok and mSpell and mSpell > 0 and not IsSecret(mSpell) and not map[mSpell] then
                        map[mSpell] = prefix .. i
                    end
                end
                end
            end
        end
    end
    return map
end

-- 诊断（/babu scan 专用）：全栏位逐按钮查找与光环名字或光环 ID 对应的按钮，
-- 不要求按钮可见、不要求 atype，把找到的第一处原样报告——用于定位「技能在条上
-- 却学不到」卡在哪一环（栏位缺失/按钮隐藏/宏没解析出法术/atype 异常）。
function B.ProbeActionBarForName(name, auraSpellID)
    for _, prefix in ipairs(GetBarPrefixList()) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn.action then
                local ok, atype, id = pcall(GetActionInfo, btn.action)
                if ok then
                    local spellID = id
                    if atype == "macro" and GetMacroSpell and type(id) == "number" then
                        local okM, m = pcall(GetMacroSpell, id)
                        spellID = (okM and type(m) == "number") and m or nil
                    end
                    local spellName = (spellID and C_Spell.GetSpellName(spellID)) or nil
                    if (spellName and spellName == name)
                        or (auraSpellID and (id == auraSpellID or spellID == auraSpellID)) then
                        local shown = true
                        if btn.IsShown then
                            local okS, s = pcall(btn.IsShown, btn)
                            shown = okS and s and true or false
                        end
                        return {
                            button = prefix .. i,
                            shown = shown,
                            atype = atype,
                            id = id,
                            spellID = spellID,
                            spellName = spellName,
                        }
                    end
                end
            end
        end
    end
end

-- =========================================================
-- 自动学习：脱战扫描光环 → 匹配动作条技能 → 存入当前专精的 learned 表
--   · 战斗红线：入口先查 InCombatLockdown()，战斗中绝不扫描；再查插件限制状态
--     （IsAuraRestricted：combat/encounter/challenge mode/PvP match 任一生效即跳过）。
--     脱战也不等于可读——大秘境整场期间光环都是 secret（见 IsAuraRestricted 注释）。
--     扫到的 spellID / 字段再过一道 issecretvalue 双保险（个别法术可被标记 always-secret）。
--   · 扫描源：自身增益 + 敌对目标身上的我方减益
--     （目标 debuff 多在战斗中挂上，脱战后残留时间窗正好可扫——用户确认纳入）。
--     自身减益不扫（2026-10-09 用户确认）：自伤类 debuff 没有同 ID 技能按钮。
--   · 学习条件：有时限（expirationTime>0，滤形态/常驻）+ 我自己施放的（sourceUnit=player）
--     + 动作条上存在同名/同ID技能 + 与手动/预设/已学去重（同一光环 ID 只活在一张表里，
--     手动 > 预设 > 学习，所以三者不会冲突重复显示）。上限 64 条 / 专精。
--   · 扫描时机：登录+5s、脱战+1s、脱战期间光环变化（UNIT_AURA 防抖 2s——覆盖补 buff）。
-- =========================================================
local LEARN_MAX = 64

-- 当前是否处于任一「会让光环数据变 secret」的插件限制状态（脱战也可能生效！）。
-- 依据 wiki Secret_Values（核实 2026-10-09）：SecretWhenUnitAuraRestricted 谓词 =
-- combat / encounter / challenge mode / PvP match 限制任一生效。
--   · Combat = 玩家正在影响战斗（≈ InCombatLockdown）
--   · Encounter = 正在参与副本 BOSS 战
--   · ChallengeMode = 「进行中且未完成」的大秘境/挑战模式 —— 整场秘境期间都生效，
--     包括拉怪间隙的脱战窗口！大秘境里本插件的自动学习扫描全程无效（软门禁拦下，不报错）。
--   · PvPMatch = 进行中且未完成的 PvP 比赛
-- 另有 Map 类型（副本地图）但不在光环谓词里——团本/普通副本脱战间隙光环是明文，可扫描。
-- 探测 API：C_RestrictedActions.IsAddOnRestrictionActive（12.0.0+，缺省退回战斗判定）。
local function IsAuraRestricted()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        local E = Enum and Enum.AddOnRestrictionType
        local types = E and { E.Combat, E.Encounter, E.ChallengeMode, E.PvPMatch } or { 0, 1, 2, 3 }
        for _, t in ipairs(types) do
            local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, t)
            if ok and active then return true end
        end
        return false
    end
    return InCombatLockdown()
end

-- 学习源：needHostileTarget = 只在当前存在敌对目标时扫（target 通道）。
-- 不扫 player-HARMFUL（2026-10-09 用户确认）：自伤类 debuff（筋疲力尽/自律这类）
-- 在动作条上没有同 ID 技能，学进去只是死条目——只扫自身增益 + 敌对目标身上的我方减益。
local LEARN_SOURCES = {
    { unit = "player", filter = "HELPFUL" },
    { unit = "target", filter = "HARMFUL", needHostileTarget = true },
}

local function HasHostileTarget()
    local okE, exists = pcall(UnitExists, "target")
    if not (okE and exists and exists ~= false) then return false end
    local okF, friendly = pcall(UnitIsFriend, "player", "target")
    return not (okF and friendly and friendly ~= false)
end

-- 内置预设是否覆盖某光环 ID（学习条目被预设收编时：运行时让位 + 扫描时清理旧条目）
local function PresetCoversAura(auraID)
    for _, e in ipairs(B.PRESET_DATA or {}) do
        if type(e.auraSpellID) == "table" then
            for _, id in ipairs(e.auraSpellID) do
                if id == auraID then return true end
            end
        elseif e.auraSpellID == auraID then
            return true
        end
    end
    return false
end

local function LearnAlreadyCovered(auraID, seen)
    if seen[auraID] then return true end
    for _, cfg in ipairs(B.GetList()) do
        if cfg.auraID == auraID then return true end
    end
    for _, e in ipairs(B.PRESET_DATA or {}) do
        if type(e.auraSpellID) == "table" then
            for _, id in ipairs(e.auraSpellID) do
                if id == auraID then return true end
            end
        elseif e.auraSpellID == auraID then
            return true
        end
    end
    return false
end

-- 诊断模式：verbose=true 时收集每条光环过门禁的明细（/babu scan 用），返回 { 行... }
-- 静默模式（定时器触发）行为与旧版一致，不打印任何东西（全静默约定）。
local function ScanLearnableAuras(verbose)
    local report = verbose and {} or nil
    local function log(fmt, ...)
        if not report then return end
        if select("#", ...) > 0 then
            report[#report + 1] = fmt:format(...)
        else
            report[#report + 1] = fmt
        end
    end

    if not B.IsEnabled() then
        log("skip: addon disabled")
        return 0, report
    end
    if not B.IsLearnEnabled() then
        log("skip: auto-learn toggle off")
        return 0, report
    end
    if InCombatLockdown() then
        log("skip: in combat")                 -- 战斗红线：绝不扫描
        return 0, report
    end
    if IsAuraRestricted() then
        log("skip: addon restriction active (combat/encounter/challenge mode/pvp)")
        return 0, report                       -- 脱战但限制仍生效（大秘境全程/BOSS战/PvP）：光环是 secret，扫了也白扫
    end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        log("skip: C_UnitAuras.GetAuraDataByIndex unavailable")
        return 0, report
    end

    local learned = B.GetLearnedList()
    -- 预设收编清理：某光环家族转为内置预设后（如英勇/嗜血家族），删除学习表中被
    -- 预设覆盖的旧条目——预设语义更合适（家族共享 + 队友施放也显示），学习条目纯冗余
    local pruned = 0
    for i = #learned, 1, -1 do
        local e = learned[i]
        if e and e.auraID and PresetCoversAura(e.auraID) then
            table.remove(learned, i)
            pruned = pruned + 1
        end
    end
    local seen = {}
    for _, e in ipairs(learned) do
        seen[e.auraID] = true
    end
    if pruned > 0 and report then
        log("pruned %d learned entries now covered by presets", pruned)
    end

    local buttonMap = B.BuildSpellButtonMap()
    if report then
        local hasBarList = (ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames) and true or false
        local mapSize = 0
        for _ in pairs(buttonMap) do mapSize = mapSize + 1 end
        log("env: ActionBarButtonNames=%s, action-bar spell buttons=%d, learned=%d/%d",
            tostring(hasBarList), mapSize, #learned, LEARN_MAX)
    end

    local added = 0

    for _, src in ipairs(LEARN_SOURCES) do
        if #learned >= LEARN_MAX then break end
        if src.needHostileTarget and not HasHostileTarget() then
            log("channel %s/%s: no hostile target, skipped", src.unit, src.filter)
        else
            local index = 1
            while #learned < LEARN_MAX do
                local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, src.unit, index, src.filter)
                index = index + 1
                if not ok or not data then break end

                -- 字段级 secret 防护：即使整体门禁漏了（个别法术可被标记 always-secret，
                -- 见 Secret_Values 谓词注），也不对 secret 值做比较。
                -- 注意：此处局部变量一律用 srcUnit 等新名，避免遮蔽外层循环的 src（曾因此丢失 unit 字段）
                local spellID = data.spellId
                local exp = data.expirationTime
                local srcUnit = data.sourceUnit

                if not spellID or IsSecret(spellID) then
                    log("aura @%d: spellId missing/secret, skipped", index - 1)
                elseif not exp or IsSecret(exp) or exp <= 0 then
                    log("%s (%s): no expiration (passive/form), skipped", tostring(data.name), tostring(spellID))
                elseif srcUnit ~= "player" or IsSecret(srcUnit) then
                    log("%s (%s): sourceUnit=%s, not self-cast, skipped",
                        tostring(data.name), tostring(spellID), tostring(srcUnit))
                elseif B.IsAuraManuallyBound(spellID) then
                    log("%s (%d): already manually bound (manual takes precedence), skipped", data.name, spellID)
                elseif LearnAlreadyCovered(spellID, seen) then
                    log("%s (%d): already covered by preset/learned, skipped", data.name, spellID)
                else
                    -- 匹配动作条技能：优先同 ID——buttonMap 的值是按钮名，键命中即说明该法术 ID 在条上，
                    -- 动作法术 ID 就是光环 ID 本身；退而求其次按名字找按钮，再取按钮上的法术 ID
                    -- （注意 GetActionInfo 第二个返回值才是 ID；曾把按钮名/atype 误当 spellID 传给
                    -- IsPlayerSpell → 12.x 弃用包装内部 C_SpellBook.IsSpellKnown 收到非数字直接报错，
                    -- 整轮扫描被 pcall 吞掉静默失败——自动学习从未工作过的根因）
                    local actionSpellID
                    local matchPath
                    if buttonMap[spellID] then
                        actionSpellID = spellID
                        matchPath = "id"
                    elseif data.name and not IsSecret(data.name) then
                        local aid = ResolveActionSpellID(FindActionButtonForSpellName(data.name))
                        if aid then
                            actionSpellID = aid
                            matchPath = "name"
                        end
                    end
                    if not actionSpellID then
                        log("%s (%d): no matching action bar spell (buttonMap/name both miss), skipped",
                            data.name, spellID)
                        -- 深度探测（仅 /babu scan 报告模式）：全栏位逐按钮找同名/同ID，
                        -- 找到即报告按钮名与按钮状态，下一步排查才有抓手
                        if report and data.name then
                            local probe = B.ProbeActionBarForName(data.name, spellID)
                            if probe then
                                log("probe: %s found on %s (shown=%s, type=%s, id=%s, spell=%s/%s)",
                                    data.name, probe.button, tostring(probe.shown),
                                    tostring(probe.atype), tostring(probe.id),
                                    tostring(probe.spellID), tostring(probe.spellName))
                            end
                        end
                    elseif type(actionSpellID) ~= "number" or not IsPlayerSpell(actionSpellID) then
                        log("%s (%d): button spell %s is not a player spell, skipped",
                            data.name, spellID, tostring(actionSpellID))
                    else
                        learned[#learned + 1] = {
                            auraID = spellID,
                            actionSpellID = actionSpellID,
                            unit = src.unit,
                        }
                        seen[spellID] = true
                        added = added + 1
                        log("%s (%d) -> spell %d [%s, %s] LEARNED", data.name, spellID, actionSpellID, matchPath, src.unit)
                    end
                end
            end
        end
    end

    if added > 0 or pruned > 0 then
        B.NotifyBindingsChanged()   -- 刷新面板 + 重建容器（战斗外才可能走到这）
    end
    if report then
        table.insert(report, 1, ("scan done: %d learned this run, %d total"):format(added, #learned))
    end
    return added, report
end
B.ScanLearnableAuras = ScanLearnableAuras

-- 诊断入口（/babu scan）：返回报告行数组
function B.RunLearnScanVerbose()
    local _, report = ScanLearnableAuras(true)
    return report or {}
end

-- 自动学习防抖：脱战期间光环变化（补 buff、目标减益残留）都是学习窗口；
-- 战斗中本事件高频触发也无妨——timer 到点后 ScanLearnableAuras 的战斗门禁直接返回。
local learnScanTimer
local function ScheduleLearnScan(delay)
    if learnScanTimer then learnScanTimer:Cancel() end
    learnScanTimer = C_Timer.NewTimer(delay or 2, function()
        learnScanTimer = nil
        pcall(ScanLearnableAuras)
    end)
end

-- =========================================================
-- 类型 A：unit aura —— 12.1 AuraContainer 暴雪渲染层（照搬上游，数据源换成手动绑定）
-- =========================================================
-- 重设 AuraButton 内倒计时框锚点（固定几何：左下时间、左上层数，用户确认）。
-- ⚠️ 传坐标时用【绝对屏幕坐标】锚到 UIParent——AuraContainer 的 flow layout 会在光环变化/
--    切目标时异步把容器尺寸覆盖成空布局值(≈1x1)，若 cd 相对 btn/容器锚定会跟着错位。
local function LayoutAuraChildren(p, left, bottom, width, height, r)
    local cd = p.cd
    if not cd then return end
    if left then
        r = r or 1
        local rx, ry = left * r, bottom * r
        local rw, rh = width * r, height * r
        cd:ClearAllPoints()
        cd:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rx + 1, ry - 6)
        cd:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rx + rw * 0.62, ry + rh * 0.62 - 7)
    else
        local btn = p.auraButton
        if not btn then return end
        local w, h = btn:GetSize()
        if not w or w <= 0 then w, h = 36, 36 end
        cd:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, -6)
        cd:SetPoint("TOPRIGHT", btn, "BOTTOMLEFT", w * 0.62, h * 0.62 - 7)
    end
end

-- 把容器定位到动作按钮之上（屏幕坐标，绝不锚到按钮；含缩放换算）。
-- ⚠️ 位置(SetPoint)可缓存；尺寸(SetSize)与子控件布局每次都要重做——对抗暴雪 flow layout
--    的异步尺寸覆盖（OnLayoutComplete→SetSize），否则尺寸被覆盖后倒计时框错位。
local function PositionContainer(container, btn, p)
    if not container or not btn then return false end
    local left, bottom, width, height = btn:GetRect()
    if not left then return false end
    local r = 1
    local bs, ps = btn:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if bs and ps and ps > 0 then r = bs / ps end
    if p._rectL ~= left or p._rectB ~= bottom or p._rectW ~= width or p._rectH ~= height then
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * r, (bottom + height) * r)
        p._rectL, p._rectB, p._rectW, p._rectH = left, bottom, width, height
    end
    container:SetSize(width * r, height * r)
    LayoutAuraChildren(p, left, bottom, width, height, r)
    return true
end

-- initializeFrame 回调：暴雪创建 AuraButton 后，addon 注册子控件。
-- ⚠️ 子控件必须 parent 到 btn（ValidateInboundScriptObject 强制 descendant）：
--   cd  → SetDurationCooldown（倒计时数字自带，暴雪驱动）
--   fs  → SetApplicationCount（层数，>1 才显示）
--   glow → CDMButtonAuras 同款柔光纹理（ADD 混合），挂在 AuraButton 上随按钮显隐，
--          不读任何存在性信号。
local function SetupAuraButton(p, btn)
    btn:SetAllPoints(p.container)
    local cd = CreateFrame("Cooldown", nil, btn)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(false)
    btn:SetDurationCooldown(cd)
    p.cd = cd
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -5)
    fs:SetFont(B.Style.FONT, B.Style.FONT_SIZE, B.Style.OUTLINE)
    local sc = B.Style.STACK_COLOR
    fs:SetTextColor(sc[1], sc[2], sc[3])
    btn:SetApplicationCount(fs)
    p.stacksFS = fs

    local glow = btn:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(btn)
    glow:SetTexture(B.OVERLAY_TEXTURE)
    glow:SetBlendMode("ADD")
    local c = (p.unit == "target") and B.Style.GLOW_ENEMY or B.Style.GLOW_SELF
    glow:SetVertexColor(c[1], c[2], c[3], B.Style.GLOW_ALPHA)
    p.glow = glow

    p.auraButton = btn
    LayoutAuraChildren(p)
end

-- 为合并组创建 AuraContainer（每组一个容器，独立定位到各自按钮）。
-- 光环过滤用 includeSpellIDs（按 auraData.spellId 精确匹配光环 ID）。
-- 过滤串 p.filter 由 RebuildGroups 决定：
--   手动绑定 player 路 → HELPFUL|PLAYER（只看自己施放的增益）；
--   手动绑定 target 路 → HARMFUL|PLAYER（只看自己施放到敌对目标身上的减益，上游烈焰震击同款）；
--   预设 → 沿用上游语义（缺省 HELPFUL，条目可显式覆盖）。
local function InitAuraGroup(p)
    if p.container then return true end
    if p._initFailed then return false end  -- 上次战斗中创建失败 → 等脱战重试
    local filter = p.filter or ((p.unit == "target") and "HARMFUL|PLAYER" or "HELPFUL|PLAYER")

    local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(1000)
    container:SetSize(36, 36)
    container:SetUnit(p.unit)
    container:SetEnabled(true)
    -- ⚠️ 先挂引用：AddAuraSlot 的 initializeFrame 回调【同步】执行，
    --   SetupAuraButton 里要用 p.container 做 SetAllPoints
    p.container = container

    local includeSpellIDs = {}
    for auraID in pairs(p.auraIDs) do
        includeSpellIDs[auraID] = true
    end

    local auraFrame
    local ok = pcall(function()
        auraFrame = container:AddAuraSlot("byunit", filter, {
            candidateFilters = { includeSpellIDs = includeSpellIDs },
            initializeFrame = function(btn) SetupAuraButton(p, btn) end,
        })
    end)
    if not ok then
        p._initFailed = true
        p.container = nil
        container:Hide()
        return false
    end
    p.auraFrame = auraFrame
    container:Show()
    return true
end

-- Cooldown 倒计时数字 FontString 要等暴雪首次 SetCooldownFromDurationObject 后才存在，
-- 用低频 ticker 轮询，设置一次字体/颜色后标记完成（幂等、廉价）。
-- ⚠️ 数字 FontString 带 secret aspect，SetFont/SetTextColor 包 pcall 防御。
local function ApplyCountdownFont(p)
    local cd = p.cd
    if not cd or p.cdStyled then return end
    local cds = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if not cds then return end
    local c = (p.unit == "target") and B.Style.TIME_COLOR_ENEMY or B.Style.TIME_COLOR_SELF
    pcall(function()
        cds:SetFont(B.Style.FONT, B.Style.FONT_SIZE, B.Style.OUTLINE)
        cds:SetTextColor(c[1], c[2], c[3])
    end)
    p.cdStyled = true
end

local function UpdateAuraGroup(p)
    if not p.actionSpellID or not next(p.auraIDs) then return end
    -- 玩家没学该施放技能（切专精后技能不可用）→ 清理残留并跳过
    if not IsPlayerSpell(p.actionSpellID) then
        DeactivateGroup(p)
        return
    end
    -- 目标类绑定只在敌对目标身上生效：友方目标（或无目标）时停用，
    -- 防止 includeSpellIDs 被暴雪在 HARMFUL 通道忽略后误匹配任意减益。
    if p.unit == "target" then
        local exists, friendly
        local ok1, e = pcall(UnitExists, "target")
        if ok1 then exists = e and e ~= false end
        local ok2, f = pcall(UnitIsFriend, "player", "target")
        if ok2 then friendly = f and f ~= false end
        if not exists or friendly then
            if p.container then p.container:Hide() end
            return
        end
    end
    if not InitAuraGroup(p) then return end
    local container = p.container

    -- 解析显示目标按钮（缓存+自愈验证，找不到时 ticker 定期重试；该技能必须放在动作条上）
    local btn = ResolveButton(p, p.actionSpellID)
    if not btn then
        container:Hide()
        return
    end
    if not PositionContainer(container, btn, p) then
        container:Hide()
        return
    end
    -- 容器保持可见以接收 UNIT_AURA（ShouldRegisterForDynamicEvents = IsVisible and IsEnabled）；
    -- AuraButton 的显隐由暴雪 ApplyVisibility 控制（有光环显示、无光环隐藏），柔光随按钮显隐
    container:Show()
    ApplyCountdownFont(p)
end

-- =========================================================
-- 类型 B：武器临时附魔（预设数据见 PresetData.lua，走 enchantID 通道）
--   走 item enchant 通道（非 unit aura），12.1 战斗中也能检测（GetWeaponEnchantInfo 战斗安全）。
--   主路径 GetWeaponEnchantInfo()（返回 enchantID + 剩余毫秒），兜底
--   C_PaperDollInfo.GetTemporaryEnchantmentInfo（12.1 官方替代 API）。
-- =========================================================
local function GetWeaponEnchantExpiration(enchantID)
    -- 主路径：旧 API（上游实测 12.1 仍可用）
    local ok, hasMain, mainExp, _, mainID, hasOff, offExp, _, offID = pcall(GetWeaponEnchantInfo)
    if ok then
        if mainID == enchantID and mainExp then return mainExp / 1000 end
        if offID == enchantID and offExp then return offExp / 1000 end
    end
    -- 兜底：12.1 新 API。返回结构 TemporaryItemEnchantInfo{enchantID, remainingTimeMs, ...}
    local function trySlot(slot)
        local fok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
        if fok and info and info.enchantID == enchantID and info.remainingTimeMs then
            return info.remainingTimeMs / 1000
        end
    end
    for _, slot in ipairs({ 16, 17 }) do  -- INVSLOT_MAINHAND, INVSLOT_OFFHAND
        local sec = trySlot(slot)
        if sec and sec > 0 then return sec end
    end
    return nil
end

-- 武器附魔倒计时【每秒】驱动：非 aura 通道战斗安全，1 秒精度足够（不挂每帧 OnUpdate）
local function EnchantTick(p)
    local ov = p.overlay
    local cd = p.cd
    local expSec = GetWeaponEnchantExpiration(p.enchantID)
    if not expSec or expSec <= 0 then
        ov:Hide()
        p._active = false
        return
    end
    local w, h = ov:GetSize()
    cd:SetParent(ov)
    cd:ClearAllPoints()
    cd:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 1, -6)
    cd:SetPoint("TOPRIGHT", ov, "BOTTOMLEFT", w * 0.62, h * 0.62 - 7)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(false)
    pcall(function() cd:SetCooldown(GetTime(), expSec) end)
    local cds = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if cds then
        cds:SetFont(B.Style.FONT, B.Style.FONT_SIZE, B.Style.OUTLINE)
        local c = B.Style.TIME_COLOR_SELF  -- 自身附魔：绿
        cds:SetTextColor(c[1], c[2], c[3])
    end
    if p.stacksFS then p.stacksFS:Hide() end
    cd:Show()
    ov:Show()
    p._active = true
end

-- 类型 B 覆盖层容器：UIParent 中立容器（与动作按钮【零锚依赖】，绝不 SetPoint 到按钮）。
local function GetEnchantOverlay(p)
    if p.overlay then return p.overlay end
    local ov = CreateFrame("Frame", nil, UIParent)
    ov:SetFrameStrata("HIGH")
    ov:SetFrameLevel(1000)
    ov:SetSize(36, 36)
    ov:Hide()
    local cd = CreateFrame("Cooldown", nil, ov)
    cd:SetHideCountdownNumbers(false)
    cd:Hide()
    local fs = ov:CreateFontString(nil, "OVERLAY")
    fs:Hide()
    -- 柔光纹理（ADD 混合）：附魔 = 自身 = 绿
    local glow = ov:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(ov)
    glow:SetTexture(B.OVERLAY_TEXTURE)
    glow:SetBlendMode("ADD")
    local c = B.Style.GLOW_SELF
    glow:SetVertexColor(c[1], c[2], c[3], B.Style.GLOW_ALPHA)
    p.overlay = ov
    p.cd = cd
    p.stacksFS = fs
    p.glow = glow
    return ov
end

-- 覆盖层定位。overlay 是 addon 自建的普通 Frame，无暴雪异步覆盖 →
-- 坐标未变即可完整跳过 SetPoint/SetSize（每秒 ticker 省去无谓锚点操作）。
local function PositionOverlay(ov, btn, p)
    if not ov or not btn then return false end
    local left, bottom, width, height = btn:GetRect()
    if not left then return false end
    if p._rectL == left and p._rectB == bottom and p._rectW == width and p._rectH == height then
        return true
    end
    local r = 1
    local bs, ps = btn:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if bs and ps and ps > 0 then r = bs / ps end
    ov:ClearAllPoints()
    ov:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * r, (bottom + height) * r)
    ov:SetSize(width * r, height * r)
    p._rectL, p._rectB, p._rectW, p._rectH = left, bottom, width, height
    return true
end

local function UpdateEnchant(p)
    if not p.enchantID or not p.actionSpellID then return end
    -- 玩家没学该施放技能 → 清理残留并跳过
    -- （武器附魔在武器上、跨专精持续存在：切专精后不清覆盖层，倒计时会冻结滞留直到 reload）
    if not IsPlayerSpell(p.actionSpellID) then
        DeactivateGroup(p)
        return
    end
    local btn = ResolveButton(p, p.actionSpellID)
    if not btn then return end
    local ov = GetEnchantOverlay(p)
    if not PositionOverlay(ov, btn, p) then
        ov:Hide()
        return
    end
    EnchantTick(p)   -- 立即填充一次（之后由 Tick → RefreshEnchants 每秒刷新）
end

local function RefreshEnchants()
    for _, p in ipairs(B.enchants) do
        pcall(UpdateEnchant, p)
    end
end

-- =========================================================
-- 合并构建：手动绑定 + 自动学习 + 内置预设 → 运行时组
--   · 手动绑定：不选单位 → 每条自动展开成 player(HELPFUL|PLAYER) 与 target(HARMFUL|PLAYER)
--     两个组；哪路命中显示哪路（另一路自然无匹配，代价只是每条绑定多一个容器）。
--   · 自动学习（专精级表）：脱战扫描当前形态光环的产物，player 条目走增益通道、
--     target 条目走减益通道，总开关 + 单条停用可控。
--   · 预设（PresetData.lua，按职业过滤 + 专精级启停）：沿用上游过滤语义
--     （缺省 unit="player" + HELPFUL；目标减益条目自带 HARMFUL|PLAYER）。
--   · 合并规则：unit + filter + 技能 相同的多条来源共用一个容器
--     （多光环任一命中即显示，也避免多容器叠在同一按钮上）。
-- =========================================================
B.groups = {}    -- 类型 A：{ unit, filter, actionSpellID, auraIDs = {[id]=true}, container, ... }
B.enchants = {}  -- 类型 B：{ enchantID, actionSpellID, overlay, cd, ... }

local function RebuildGroups()
    if InCombatLockdown() then
        B._pendingRebuild = true   -- 战斗中不建/不拆容器，脱战后重试
        return
    end
    B._pendingRebuild = false
    -- 撤下旧的（容器 / 覆盖层），避免重建后残留
    for _, p in ipairs(B.groups) do
        if p.container then p.container:Hide() end
    end
    for _, p in ipairs(B.enchants) do
        if p.overlay then p.overlay:Hide() end
    end
    wipe(B.groups)
    wipe(B.enchants)
    if not B.IsEnabled() then return end

    local merged, order = {}, {}
    local function addGroup(unit, filter, actionSpellID, auraID)
        local key = tostring(unit) .. ":" .. tostring(filter) .. ":" .. tostring(actionSpellID)
        local g = merged[key]
        if not g then
            g = { unit = unit, filter = filter, actionSpellID = actionSpellID, auraIDs = {} }
            merged[key] = g
            order[#order + 1] = g
        end
        g.auraIDs[auraID] = true
    end

    -- 手动绑定：双通道自动展开
    for _, cfg in ipairs(B.GetList()) do
        if cfg.auraID and cfg.bindSpell then
            addGroup("player", "HELPFUL|PLAYER", cfg.bindSpell, cfg.auraID)
            addGroup("target", "HARMFUL|PLAYER", cfg.bindSpell, cfg.auraID)
        end
    end

    -- 自动学习表（专精级；总开关 + 单条停用）：player 条目走增益通道，
    -- target 条目（敌对目标身上我方减益）走减益通道。
    -- 优先级：手动绑定 > 内置预设 > 学习条目——光环 ID 已被手动绑定或预设覆盖的
    -- 学习条目跳过（不删除；手动绑定删掉后自动恢复，预设收编的在下次扫描时清理）
    if B.IsLearnEnabled() then
        for _, e in ipairs(B.GetLearnedList()) do
            if not e.disabled and e.auraID and e.actionSpellID
                and not B.IsAuraManuallyBound(e.auraID)
                and not PresetCoversAura(e.auraID) then
                local unit = e.unit or "player"
                local filter = (unit == "target") and "HARMFUL|PLAYER" or "HELPFUL|PLAYER"
                addGroup(unit, filter, e.actionSpellID, e.auraID)
            end
        end
    end

    -- 内置预设：按当前职业过滤 + 逐条启停（key = PresetData.lua 中的序号）
    local _, classToken = UnitClass("player")
    for key, e in ipairs(B.PRESET_DATA or {}) do
        if (not e.class or e.class == classToken) and B.IsPresetEnabled(key) then
            if e.enchantID then
                B.enchants[#B.enchants + 1] = {
                    enchantID = e.enchantID,
                    actionSpellID = e.actionSpellID,
                    enchantName = e.enchantName,
                }
            else
                local ids = (type(e.auraSpellID) == "table") and e.auraSpellID or { e.auraSpellID }
                local unit = e.unit or "player"
                local filter = e.filter or (unit == "target" and "HARMFUL|PLAYER" or "HELPFUL")
                for _, id in ipairs(ids) do
                    addGroup(unit, filter, e.actionSpellID, id)
                end
            end
        end
    end

    for _, g in ipairs(order) do
        B.groups[#B.groups + 1] = g
    end
end

-- =========================================================
-- 全量刷新 / 低频 ticker
-- =========================================================
local function RefreshAll()
    for _, p in ipairs(B.groups) do
        pcall(UpdateAuraGroup, p)
    end
    RefreshEnchants()
end

local function Tick()
    -- 类型 A：重定位容器 + 轮询倒计时字体（内容更新由暴雪 AuraContainer 自行驱动）
    for _, p in ipairs(B.groups) do
        pcall(UpdateAuraGroup, p)
    end
    -- 类型 B：清理到期 / 重附魔 / 重定位
    RefreshEnchants()
end

-- =========================================================
-- 变更通知（Options 实现对应入口）
-- =========================================================
local rebuildTimer
local function ScheduleRebuild(delay)
    if rebuildTimer then rebuildTimer:Cancel() end
    rebuildTimer = C_Timer.NewTimer(delay or 0.2, function()
        rebuildTimer = nil
        RebuildGroups()
        RefreshAll()
    end)
end

function B.NotifyBindingsChanged()
    if B.RefreshPanel then B.RefreshPanel() end
    ScheduleRebuild(0.2)
end

-- 全局开关（Options 复选框调用）
function B.SetEnabled(v)
    B.InitStorage()
    easyButtonAuraByUnitDB.enabled = v and true or false
    RebuildGroups()
    RefreshAll()
    if B.RefreshPanel then B.RefreshPanel() end
end

-- 防抖全量刷新（UNIT_AURA 等高频事件）
local refreshTimer
function B.ScheduleRefresh(delay)
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(delay or 0.2, function()
        refreshTimer = nil
        RefreshAll()
    end)
end

-- =========================================================
-- 事件驱动（事件集合与防抖策略照搬上游 Preset.lua）
-- =========================================================
-- 动作条/页面/形态/载具/御龙术/专精切换：缓存失效 + 延迟重匹配。
-- ⚠️ 绝不【立即】刷新：ACTIONBAR_PAGE_CHANGED 等事件在 SetActionBarPage 的保护上下文
--    同步触发，立即操作容器会被 taint/block，导致倒计时框错位。
local actionbarEvents = {
    ACTIONBAR_SLOT_CHANGED       = true,
    ACTIONBAR_PAGE_CHANGED       = true,
    ACTIVE_TALENT_GROUP_CHANGED  = true,
    UPDATE_BONUS_ACTIONBAR       = true,
    UPDATE_OVERRIDE_ACTIONBAR    = true,
    UPDATE_SHAPESHIFT_FORM       = true,
    UPDATE_POSSESS_BAR           = true,
    UPDATE_MULTI_CAST_ACTIONBAR  = true,
}

local function InvalidateButtons()
    for _, p in ipairs(B.groups) do
        p.button = nil
        p._rectL, p._rectB, p._rectW, p._rectH = nil, nil, nil, nil
    end
    for _, p in ipairs(B.enchants) do
        p.button = nil
        p._rectL, p._rectB, p._rectW, p._rectH = nil, nil, nil, nil
    end
end

local evFrame = CreateFrame("Frame")
local auraRefreshTimer = nil
evFrame:RegisterEvent("PLAYER_LOGIN")
for ev in pairs(actionbarEvents) do evFrame:RegisterEvent(ev) end
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")       -- 脱战：重试战斗中建失败的容器 + 恢复配置窗口
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")      -- 进战：隐藏配置窗口
evFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")   -- 武器附魔（重附/替换/卸下）立即刷新
evFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")     -- 同上兜底
evFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
evFrame:RegisterEvent("PLAYER_TARGET_CHANGED")      -- 切目标：target 容器需手动重新解析
evFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")  -- 切专精：换绑定槽 + 重建

evFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        B.SelectSpec()
        RebuildGroups()
        -- 登录后稍候再刷新，确保动作条按钮已就绪（ticker 兜底）
        C_Timer.After(0, RefreshAll)
        C_Timer.After(0.5, RefreshAll)
        -- 首次自动学习扫描：等动作条按钮全部就位
        C_Timer.After(5, function() pcall(ScanLearnableAuras) end)
        -- 低频 ticker：类型 A 重定位/字体 + 类型 B 清理（容器内容由暴雪自行驱动）
        C_Timer.NewTicker(1, Tick)
    elseif actionbarEvents[event] then
        InvalidateButtons()
        C_Timer.After(0.1, function() InvalidateButtons(); RefreshAll() end)
        C_Timer.After(0.5, function() InvalidateButtons(); RefreshAll() end)
    elseif event == "UNIT_AURA" then
        -- 光环增删 → 防抖刷新（只补重定位；AuraButton 显隐由暴雪实时驱动，防抖 0.2s 无感）
        if auraRefreshTimer then auraRefreshTimer:Cancel() end
        auraRefreshTimer = C_Timer.NewTimer(0.2, function()
            auraRefreshTimer = nil
            RefreshAll()
        end)
        -- 自动学习：脱战期间光环变化 = 学习窗口（补 buff、目标减益残留）；
        -- 防抖 2s；战斗中触发时 timer 到点后被 ScanLearnableAuras 的战斗门禁拦下
        ScheduleLearnScan(2)
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- AuraContainer 不监听目标切换，unit="target" 的容器需显式触发重新解析光环
        for _, p in ipairs(B.groups) do
            if p.unit == "target" and p.container then
                pcall(function() p.container:UpdateAllAuras() end)
            end
        end
        -- UpdateAllAuras 触发 FullAuraRebuild，flow layout 下一帧会把容器尺寸覆盖成空布局值，
        -- 延迟重新定位，避免倒计时框短暂错位（否则要等 1 秒 ticker 才纠正）
        C_Timer.After(0.05, function()
            for _, p in ipairs(B.groups) do
                if p.unit == "target" then pcall(UpdateAuraGroup, p) end
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脱战：解除战斗中建容器失败的限制；战斗中被搁置的重建在此补做
        for _, p in ipairs(B.groups) do p._initFailed = nil end
        if B._pendingRebuild then
            RebuildGroups()
        end
        RefreshAll()
        if B.OnCombatChanged then B.OnCombatChanged(false) end
        -- 脱战窗口正是自动学习的扫描窗（战斗中数据是 secret，绝不扫）；稍等动作条/光环稳定
        ScheduleLearnScan(1)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if B.OnCombatChanged then B.OnCombatChanged(true) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        -- 武器附魔变化：非 aura 通道，战斗中也安全
        RefreshEnchants()
    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        B.SelectSpec()
        ScheduleRebuild(0.2)
        if B.RefreshPanel then B.RefreshPanel() end
    end
end)

-- =========================================================
-- slash 命令：/babu 打开配置窗口（实现在 Options.lua）
-- =========================================================
-- 诊断：转储运行时组状态（容器是否创建/可见、按钮解析到没有）——排查「学了/预设了但按钮上没数字」
function B.DumpGroupsVerbose()
    local out = {}
    out[#out + 1] = ("groups=%d enchants=%d enabled=%s combat=%s"):format(
        #B.groups, #B.enchants, tostring(B.IsEnabled()), tostring(InCombatLockdown()))
    for i, p in ipairs(B.groups) do
        local auras = {}
        for id in pairs(p.auraIDs or {}) do auras[#auras + 1] = tostring(id) end
        table.sort(auras)
        out[#out + 1] = ("group %d: unit=%s filter=%s spell=%s auras=[%s] container=%s btn=%s initFailed=%s"):format(
            i, tostring(p.unit), tostring(p.filter), tostring(p.actionSpellID),
            table.concat(auras, ","),
            p.container and (p.container:IsShown() and "shown" or "hidden") or "nil",
            p.button and p.button:GetName() or "nil",
            tostring(p._initFailed))
    end
    for i, p in ipairs(B.enchants) do
        out[#out + 1] = ("enchant %d: id=%s spell=%s overlay=%s"):format(
            i, tostring(p.enchantID), tostring(p.actionSpellID),
            p.overlay and (p.overlay:IsShown() and "shown" or "hidden") or "nil")
    end
    return out
end

SLASH_EASYBUTTONAURABYUNIT1 = "/babu"
SlashCmdList["EASYBUTTONAURABYUNIT"] = function(msg)
    msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "scan" then
        -- 诊断模式：只在本命令显式触发时输出（全静默约定不含用户主动调用的调试命令）
        if B.RunLearnScanVerbose then
            for _, line in ipairs(B.RunLearnScanVerbose()) do
                print("|cffE8BC75[babu]|r " .. line)
            end
        end
        return
    end
    if msg == "debug" then
        if InCombatLockdown() then return end
        RebuildGroups()   -- 先重建一遍，转储的就是当前真实状态
        for _, line in ipairs(B.DumpGroupsVerbose()) do
            print("|cffE8BC75[babu]|r " .. line)
        end
        return
    end
    if B.ToggleConfigFrame then B.ToggleConfigFrame() end
end
