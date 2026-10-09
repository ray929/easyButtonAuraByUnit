-- PresetData.lua
-- Easy Button Aura by Unit — 内置预设数据
--
-- 全量移植自上游 ActionbarEnhanced/PresetData.lua（SELF_BUFFS + PRESETS + 武器附魔）。
-- 运行时按当前职业过滤（class = nil 的条目任何职业都生效，靠 IsPlayerSpell 自动筛选种族技能）；
-- 每条预设可在配置窗口（/babu）的「预设」区逐条启用/禁用（专精级存档）。
--
-- 条目格式：
--   光环预设：{ class = "WARRIOR", specID = 254, auraSpellID = 1160, actionSpellID = 1160,
--               unit = "target", filter = "HARMFUL|PLAYER" }
--     · auraSpellID：要追踪的光环法术 ID（单个 number 或 {id1,id2} 数组，任一命中即显示）
--     · actionSpellID：显示到哪个技能按钮（该技能必须放在动作条上）
--     · class 可选：限定职业（nil = 全职业通用）；specID 可选：限定专精（如 254 = 射击猎）
--     · unit/filter 可选：默认 player + HELPFUL；目标减益必须写 unit="target" +
--       filter="HARMFUL|PLAYER"（|PLAYER=只追踪玩家自己施放的，2026-08-19 烈焰震击踩坑）
--   武器附魔预设：{ class = "SHAMAN", enchantID = 5400, actionSpellID = 318038, enchantName = "Flametongue" }
--     · 走 GetWeaponEnchantInfo 战斗安全通道（独立覆盖层 + 1 秒 ticker）
--   无持续时间光环预设：{ auraSpellID = 378081, actionSpellID = 378081, overlayOnly = true }
--     · 形态/瞬发开关类光环没有持续时间可显示：不挂倒计时框/层数，存在标记与其他
--       光环同款（CDMButtonAuras 柔光，自身=绿），随暴雪按钮显隐。

local B = EasyButtonAuraByUnit
if not B then return end

-- 预设仅限正式服（Retail）：永恒（Camelot）等客户端的法术/光环 ID 体系与正式服不一致，
-- 直接套用会错绑（用户 2026-10-09 指定：所有预设含复原都只在正式服启用，永恒的 ID 后续再挖掘）。
-- 非正式服时清空预设表 → 配置界面「预设」区为空、学习扫描的 preset 覆盖检查自然失效。
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    B.PRESET_DATA = {}
    return
end

-- 全职业通用（class = nil，靠 IsPlayerSpell 门禁自动筛选）+ 无持续时间光环，见下方表内注释

-- 嗜血/英勇家族：不同职业的引导技能不同，但施放到全队身上的增益本质是同一个效果
-- （嗜血 2825 / 英勇 32182 / 时间扭曲 80353 / 远古狂暴 90355 / 原始狂怒 264667 / 化身巨龙之怒 390386）。
-- 任一命中即显示 → 用同一个光环 ID 集合；actionSpellID 指向本职业的施放技能按钮。
-- filter 用缺省 HELPFUL（不加 |PLAYER）：队友施放的英勇同样显示（倒计时参考价值一致）。
local LUST_AURAS = { 2825, 32182, 80353, 90355, 264667, 390386 }

B.PRESET_DATA = {
    -- 全职业通用（复原：光环 1231418 → 技能 1231411，所有职业的公用技能）
    { auraSpellID = 1231418, actionSpellID = 1231411 },
    -- 无持续时间光环（overlayOnly）：不显示倒计时/层数，仅绿色遮罩标记
    -- （均为萨满专属：378081 Wowhead Requires Shaman；2645 为萨满形态）
    { class = "SHAMAN", auraSpellID = 378081, actionSpellID = 378081, overlayOnly = true }, -- 自然迅捷（无持续时间）
    { class = "SHAMAN", auraSpellID = 2645,  actionSpellID = 2645,  overlayOnly = true },  -- 幽魂之狼（形态）
    -- 嗜血/英勇家族（萨满两个引导技能按阵营二选一：部落嗜血 2825 / 联盟英勇 32182；
    -- 未学的那个被 IsPlayerSpell 门自动停用，条目保留是为了两阵营通用）
    { class = "SHAMAN", auraSpellID = LUST_AURAS, actionSpellID = 2825 },   -- 嗜血（部落）
    { class = "SHAMAN", auraSpellID = LUST_AURAS, actionSpellID = 32182 },  -- 英勇（联盟）
    { class = "MAGE",   auraSpellID = LUST_AURAS, actionSpellID = 80353 },  -- 时间扭曲
    { class = "EVOKER", auraSpellID = LUST_AURAS, actionSpellID = 390386 }, -- 化身巨龙之怒
    { class = "HUNTER", auraSpellID = LUST_AURAS, actionSpellID = 264667 }, -- 原始狂怒（宠物施放；按钮不在玩家动作条上则自动不显示）

    -- 死亡骑士 DEATHKNIGHT（减伤/爆发；光环=技能同ID）
    { class = "DEATHKNIGHT", auraSpellID = 48792, actionSpellID = 48792 },  -- 冰封之韧（减伤）
    { class = "DEATHKNIGHT", auraSpellID = 48707, actionSpellID = 48707 },  -- 反魔法护罩（减伤）
    { class = "DEATHKNIGHT", auraSpellID = 55233, actionSpellID = 55233 },  -- 吸血鬼之血（自保）
    { class = "DEATHKNIGHT", auraSpellID = 51271, actionSpellID = 51271 },  -- 冰霜之柱（爆发）
    { class = "DEATHKNIGHT", auraSpellID = 49039, actionSpellID = 49039 },  -- 巫妖之躯
    -- 恶魔猎手 DEMONHUNTER（减伤/爆发）
    { class = "DEMONHUNTER", auraSpellID = 212800, actionSpellID = 212800 }, -- 疾影（减伤）
    { class = "DEMONHUNTER", auraSpellID = 162264, actionSpellID = 191427 }, -- 恶魔变形（光环 162264 → 技能 191427，爆发/减伤）
    -- 猎人 HUNTER（减伤/爆发）
    { class = "HUNTER", auraSpellID = 212431, actionSpellID = 212431, unit = "target", filter = "HARMFUL|PLAYER" }, -- 爆炸射击
    { class = "HUNTER", auraSpellID = 186265, actionSpellID = 186265 },  -- 灵龟守护（减伤）
    { class = "HUNTER", auraSpellID = 264735, actionSpellID = 264735 },  -- 优胜劣汰（减伤）
    { class = "HUNTER", auraSpellID = 385540, actionSpellID = 109304 },  -- 意气风发（减伤）
    { class = "HUNTER", auraSpellID = 19574, actionSpellID = 19574 },    -- 狂野怒火（爆发）
    { class = "HUNTER", auraSpellID = 288613, actionSpellID = 288613 },  -- 百发百中（爆发）
    { class = "HUNTER", auraSpellID = 34477, actionSpellID = 34477 },    -- 误导(生效前)
    { class = "HUNTER", auraSpellID = 35079, actionSpellID = 34477 },    -- 误导(生效后)
    { class = "HUNTER", auraSpellID = 257622, actionSpellID = 257620 },  -- 技巧射击绑多重射击
    { class = "HUNTER", specID = 254, auraSpellID = 6197, actionSpellID = 6197 }, -- 鹰眼术（12.x 射击专精限定）
    { class = "HUNTER", auraSpellID = 321297, actionSpellID = 321297 },  -- 野兽之眼
    -- 武僧 MONK（减伤/爆发）
    { class = "MONK", auraSpellID = 122278, actionSpellID = 122278 },    -- 躯不坏（减伤）
    { class = "MONK", auraSpellID = 122783, actionSpellID = 122783 },    -- 散魔功（减伤）
    { class = "MONK", auraSpellID = 115176, actionSpellID = 115176 },    -- 禅悟冥想（引导减伤）
    { class = "MONK", auraSpellID = 116680, actionSpellID = 116680 },    -- 雷光聚神茶（爆发）
    { class = "MONK", auraSpellID = 137639, actionSpellID = 137639 },    -- 风火雷电（爆发）
    { class = "MONK", auraSpellID = 120954, actionSpellID = 115203 },    -- 壮胆酒
    -- 萨满 SHAMAN
    { class = "SHAMAN", auraSpellID = 1219480, actionSpellID = 114050 }, -- 升腾
    { class = "SHAMAN", auraSpellID = 383648, actionSpellID = 974 },     -- 大地之盾（光环 383648 → 技能 974）
    { class = "SHAMAN", auraSpellID = 462854, actionSpellID = 462854 },  -- 天怒（光环=技能）
    { class = "SHAMAN", auraSpellID = 192106, actionSpellID = 192106 },  -- 闪电之盾
    { class = "SHAMAN", auraSpellID = 52127, actionSpellID = 52127 },    -- 水之护盾
    { class = "SHAMAN", auraSpellID = 546, actionSpellID = 546 },        -- 水上行走
    { class = "SHAMAN", auraSpellID = 6196, actionSpellID = 6196 },      -- 视界术
    { class = "SHAMAN", enchantID = 5400, actionSpellID = 318038, enchantName = "Flametongue" },       -- 火舌武器
    { class = "SHAMAN", enchantID = 5401, actionSpellID = 33757, enchantName = "Windfury" },           -- 风怒武器
    { class = "SHAMAN", enchantID = 6498, actionSpellID = 382021, enchantName = "Earthliving Weapon" }, -- 大地生命武器
    { class = "SHAMAN", enchantID = 7528, actionSpellID = 457481, enchantName = "Tidecaller's Guard" }, -- 唤潮者护卫
    { class = "SHAMAN", auraSpellID = 108271, actionSpellID = 108271 },  -- 星界转移（减伤）
    { class = "SHAMAN", auraSpellID = 191634, actionSpellID = 191634 },  -- 风暴守护者（爆发）
    -- 盗贼 ROGUE（武器涂毒：光环 = 技能 同 ID）
    { class = "ROGUE", auraSpellID = 381664, actionSpellID = 381664 },   -- 增效毒药 Amplifying
    { class = "ROGUE", auraSpellID = 2823, actionSpellID = 2823 },       -- 致命毒药 Deadly
    { class = "ROGUE", auraSpellID = 315584, actionSpellID = 315584 },   -- 即时毒药 Instant
    { class = "ROGUE", auraSpellID = 8679, actionSpellID = 8679 },       -- 致伤毒药 Wound
    { class = "ROGUE", auraSpellID = 381637, actionSpellID = 381637 },   -- 萎缩毒药 Atrophic
    { class = "ROGUE", auraSpellID = 5761, actionSpellID = 5761 },       -- 麻痹毒药 Numbing
    { class = "ROGUE", auraSpellID = 3408, actionSpellID = 3408 },       -- 减速毒药 Crippling
    -- 盗贼 ROGUE（减伤/爆发；光环=技能同ID）
    { class = "ROGUE", auraSpellID = 31224, actionSpellID = 31224 },     -- 斗篷（减伤）
    { class = "ROGUE", auraSpellID = 5277, actionSpellID = 5277 },       -- 闪避（减伤）
    { class = "ROGUE", auraSpellID = 1966, actionSpellID = 1966 },       -- 佯攻（AoE减伤）
    { class = "ROGUE", auraSpellID = 185311, actionSpellID = 185311 },   -- 猩红之瓶（自疗）
    { class = "ROGUE", auraSpellID = 1856, actionSpellID = 1856 },       -- 消失（保命）
    { class = "ROGUE", auraSpellID = 13750, actionSpellID = 13750 },     -- 冲动（爆发）
    { class = "ROGUE", auraSpellID = 185422, actionSpellID = 185422 },   -- 影舞步（敏锐爆发）
    { class = "ROGUE", auraSpellID = 121471, actionSpellID = 121471 },   -- 暗影之刃（爆发）
    -- 法师 MAGE
    { class = "MAGE", auraSpellID = 1459, actionSpellID = 1459 },        -- 奥术智慧（团队增益）
    { class = "MAGE", auraSpellID = 210126, actionSpellID = 1459 },      -- 奥术魔宠（buff 210126 → 奥术智慧 1459）
    -- 法师 MAGE（减伤/爆发；光环=技能同ID）
    { class = "MAGE", auraSpellID = 45438, actionSpellID = 45438 },      -- 寒冰屏障（减伤）
    { class = "MAGE", auraSpellID = 11426, actionSpellID = 11426 },      -- 寒冰护体（减伤）
    { class = "MAGE", auraSpellID = 12042, actionSpellID = 12042 },      -- 奥术强化（爆发）
    { class = "MAGE", auraSpellID = 12472, actionSpellID = 12472 },      -- 冰冷血脉（爆发）
    { class = "MAGE", auraSpellID = 190319, actionSpellID = 190319 },    -- 燃烧（火法爆发）
    -- 术士 WARLOCK
    { class = "WARLOCK", auraSpellID = 196099, actionSpellID = 108503 }, -- 牺牲魔典
    { class = "WARLOCK", auraSpellID = 104773, actionSpellID = 104773 }, -- 不灭决心（减伤）
    { class = "WARLOCK", auraSpellID = 108416, actionSpellID = 108416 }, -- 黑暗契约（减伤）
    -- 战士 WARRIOR
    { class = "WARRIOR", auraSpellID = 6673, actionSpellID = 6673 },     -- 战斗怒吼（团队增益）
    -- 战士 WARRIOR（减伤/爆发；光环=技能同ID）
    { class = "WARRIOR", auraSpellID = 871, actionSpellID = 871 },       -- 盾墙（防战减伤）
    { class = "WARRIOR", auraSpellID = 18499, actionSpellID = 18499 },   -- 狂暴之怒
    { class = "WARRIOR", auraSpellID = 97463, actionSpellID = 97462 },   -- 集结呐喊
    { class = "WARRIOR", auraSpellID = 1160, actionSpellID = 1160, unit = "target", filter = "HARMFUL|PLAYER" },    -- 挫志怒吼
    { class = "WARRIOR", auraSpellID = 12323, actionSpellID = 12323, unit = "target", filter = "HARMFUL|PLAYER" },  -- 刺耳怒吼
    { class = "WARRIOR", auraSpellID = 386071, actionSpellID = 386071, unit = "target", filter = "HARMFUL|PLAYER" }, -- 瓦解怒吼
    { class = "WARRIOR", auraSpellID = 12975, actionSpellID = 12975 },   -- 破釜沉舟（防战减伤）
    { class = "WARRIOR", auraSpellID = 23920, actionSpellID = 23920 },   -- 法术反射（减伤）
    { class = "WARRIOR", auraSpellID = 184364, actionSpellID = 184364 }, -- 狂怒回复（自疗）
    { class = "WARRIOR", auraSpellID = 190456, actionSpellID = 190456 }, -- 无视苦痛（防战吸收）
    { class = "WARRIOR", auraSpellID = 1719, actionSpellID = 1719 },     -- 鲁莽（爆发）
    { class = "WARRIOR", auraSpellID = 107574, actionSpellID = 107574 }, -- 天神下凡（爆发）
    { class = "WARRIOR", auraSpellID = 227847, actionSpellID = 227847 }, -- 剑刃风暴（爆发）
    { class = "WARRIOR", auraSpellID = 260708, actionSpellID = 260708 }, -- 横扫攻击（爆发）
    -- 德鲁伊 DRUID
    { class = "DRUID", auraSpellID = 1126, actionSpellID = 1126 },       -- 野性印记（团队增益，432661 为 NPC 版）
    -- 德鲁伊 DRUID（减伤/爆发；光环=技能同ID）
    { class = "DRUID", auraSpellID = 22812, actionSpellID = 22812 },     -- 树皮术（减伤）
    { class = "DRUID", auraSpellID = 61336, actionSpellID = 61336 },     -- 生存本能（减伤）
    { class = "DRUID", auraSpellID = 192081, actionSpellID = 192081 },   -- 铁鬃（熊减伤）
    { class = "DRUID", auraSpellID = 22842, actionSpellID = 22842 },     -- 狂暴回复（自疗）
    { class = "DRUID", auraSpellID = 106951, actionSpellID = 106951 },   -- 狂暴（爆发）
    { class = "DRUID", auraSpellID = 102558, actionSpellID = 102558 },   -- 化身:丛林之王（熊爆发）
    { class = "DRUID", auraSpellID = 5217, actionSpellID = 5217 },       -- 猛虎之怒（猫爆发）
    { class = "DRUID", auraSpellID = 33891, actionSpellID = 33891 },     -- 化身:生命之树（奶爆发）
    -- 牧师 PRIEST
    { class = "PRIEST", auraSpellID = 21562, actionSpellID = 21562 },    -- 真言术韧（团队增益）
    { class = "PRIEST", auraSpellID = 586, actionSpellID = 586 },        -- 渐隐术
    { class = "PRIEST", auraSpellID = 10060, actionSpellID = 10060 },    -- 能量灌注
    { class = "PRIEST", auraSpellID = 19236, actionSpellID = 19236 },    -- 绝望祷言
    { class = "PRIEST", auraSpellID = 17, actionSpellID = 17 },          -- 真言术盾
    { class = "PRIEST", auraSpellID = 121557, actionSpellID = 121536 },  -- 羽毛
    -- 牧师 PRIEST（减伤/爆发；光环=技能同ID）
    { class = "PRIEST", auraSpellID = 33206, actionSpellID = 33206 },    -- 痛苦压制（减伤）
    { class = "PRIEST", auraSpellID = 47788, actionSpellID = 47788 },    -- 守护之魂（减伤/保命）
    { class = "PRIEST", auraSpellID = 47585, actionSpellID = 47585 },    -- 消散（暗牧减伤）
    { class = "PRIEST", auraSpellID = 15286, actionSpellID = 15286 },    -- 吸血鬼拥抱（自疗）
    { class = "PRIEST", auraSpellID = 64843, actionSpellID = 64843 },    -- 神圣赞美诗（团队治疗）
    -- 圣骑士 PALADIN（武器仪式）
    { class = "PALADIN", enchantID = 7144, actionSpellID = 433583, enchantName = "Ritual of Judgment" },       -- 裁决仪式
    { class = "PALADIN", enchantID = 7143, actionSpellID = 433568, enchantName = "Ritual of Sanctification" }, -- 圣化仪式
    -- 圣骑士 PALADIN（减伤/爆发；光环=技能同ID）
    { class = "PALADIN", auraSpellID = 642, actionSpellID = 642 },       -- 圣盾术（减伤）
    { class = "PALADIN", auraSpellID = 498, actionSpellID = 498 },       -- 圣佑术（减伤）
    { class = "PALADIN", auraSpellID = 31850, actionSpellID = 31850 },   -- 炽热防御者（防骑减伤）
    { class = "PALADIN", auraSpellID = 86659, actionSpellID = 86659 },   -- 远古列王守卫（减伤）
    { class = "PALADIN", auraSpellID = 31884, actionSpellID = 31884 },   -- 复仇之怒（爆发）
    { class = "PALADIN", auraSpellID = 105809, actionSpellID = 105809 }, -- 神圣复仇者（防骑爆发）
    { class = "PALADIN", auraSpellID = 156322, actionSpellID = 156322 }, -- 神圣之火
    -- 唤魔者 EVOKER（增辉协调：黑 403264 / 铜 403265 二选一）
    { class = "EVOKER", auraSpellID = { 403264, 403265 }, actionSpellID = 403208 },
    -- 唤魔者 EVOKER 青铜龙祝福（团队增益，光环为多阶段变体）
    { class = "EVOKER", auraSpellID = { 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 }, actionSpellID = 364342 },
    -- 唤魔者 EVOKER（减伤/爆发；光环=技能同ID）
    { class = "EVOKER", auraSpellID = 363916, actionSpellID = 363916 },  -- 黑曜石鳞片（减伤）
    { class = "EVOKER", auraSpellID = 357170, actionSpellID = 357170 },  -- 时间膨胀（团队减伤）
    { class = "EVOKER", auraSpellID = 357210, actionSpellID = 357210 },  -- 深呼吸（爆发）
    -- 种族技能（与职业无关，不设 class；IsPlayerSpell 自动过滤——只有会该技能的种族才生效）
    { auraSpellID = 65116, actionSpellID = 20594 },                      -- 石像形态（光环 65116 → 技能 20594，矮人）
}
