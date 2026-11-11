-- PresetData.lua
-- Easy Button Aura by Unit — 内置预设数据
--
-- 两套表按客户端二选一，绝不混用（法术/光环 ID 体系不同，互相套用必错绑）：
--   · 正式服（Mainline）表 = 上游 ActionbarEnhanced 移植的精选条目（武器附魔 / 毒药 / 误导 /
--     宠物 / 种族 / 嗜血家族……）+ 2026-11-11 从 EllesmereUI_BuffPresets 的 RETAIL_PRESETS
--     整段导入的全量目录（每职业减伤 / 团队冷却 / 外部保命 / 治疗增益 / 爆发 / 移动 / 辅助）。
--   · 永恒（非 Mainline）表 = 玩家存档实测收编的 32 条 + 从 EllesmereUI_BuffPresets 的
--     ForeverCatalogue() 导入的 54 条。
-- 导入块由脚本离线生成（.temp/gen_block.lua），未手工抄写 ID。
-- 运行时按当前职业过滤（class = nil 的条目任何职业都生效，靠 IsPlayerSpell 自动筛选种族技能）；
-- 每条预设可在配置窗口（/babu）的「预设」区逐条启用/禁用（专精级存档）。
--
-- 条目格式：
--   光环预设：{ class = "WARRIOR", auraSpellID = 1160, actionSpellID = 1160,
--               unit = "target", filter = "HARMFUL|PLAYER" }
--     · auraSpellID：要追踪的光环法术 ID（单个 number 或 {id1,id2} 数组，任一命中即显示）
--     · actionSpellID：显示到哪个技能按钮（该技能必须放在动作条上）
--     · class 可选：限定职业（nil = 全职业通用）。不做专精过滤（2026-10-09 用户决策：
--       专精归属多版本变迁容易写错，如爆炸射击现仅生存猎；启停存档按专精保存已够用）
--     · unit/filter 可选：默认 player + HELPFUL；目标减益必须写 unit="target" +
--       filter="HARMFUL|PLAYER"（|PLAYER=只追踪玩家自己施放的，2026-08-19 烈焰震击踩坑）
--     · auraName / actionName 可选（2026-11-08 起）：写名字时按名字展开成同名全部 ID，
--       跨 Rank 生效——永恒表必写，正式服表不写（ID 稳定，按 ID 直查更省一次索引查询）
--     · group 可选（2026-11-11 起）：该条在 Ellesmere 目录里的分区（defensives / coreheals…），
--       只影响配置窗口的分组标题，不参与运行时判断；无 group 的条目归「常用」组
--     · defaultOff 可选（2026-11-11 起）：缺省不勾选（Ellesmere 标 disabled 的条目、
--       结构上大概率失效的导入数据）；用户勾选后显式存 true
--   武器附魔预设：{ class = "SHAMAN", enchantID = 5400, actionSpellID = 318038, enchantName = "Flametongue" }
--     · 走 C_PaperDollInfo.GetTemporaryEnchantmentInfo 战斗安全通道
--       （独立覆盖层 + 1 秒 ticker；旧 API GetWeaponEnchantInfo 已 deprecated）
--   无持续时间光环预设：{ auraSpellID = 378081, actionSpellID = 378081, overlayOnly = true }
--     · 形态/瞬发开关类光环没有持续时间可显示：不挂倒计时框/层数，存在标记与其他
--       光环同款（CDMButtonAuras 柔光，自身=绿），随暴雪按钮显隐。

local B = EasyButtonAuraByUnit
if not B then return end

-- 预设分两套客户端，绝不混用（两套客户端法术/光环 ID 体系不一致，互相套用必错绑）：
--   · 正式服（Mainline）→ 本文件末尾的正式服表（ID 跨版本稳定，直接按 ID 查）
--   · 永恒（Forever / Camelot，非 Mainline）→ 下一节的永恒表
--     ⚠️ 永恒里同一技能每级是【不同 spellID + 不同光环 ID，只有名字相同】，
--        所以永恒表的精选条目带 auraName / actionName，由主文件按名字展开成同名全部 ID；
--        导入块走 ID 数组（Ellesmere 已把全部 rank 列全），不依赖名字。
-- =========================================================
-- 永恒（Forever / Camelot）预设
-- =========================================================
-- 精选部分来源（2026-11-08 起，持续收编）：读取玩家永恒客户端存档 WTF/Account/RAY0929/95/
-- */SavedVariables/easyButtonAuraByUnit.lua 里「自动学习 learned」+「手动绑定 list」的真实配对，
-- 外加客户端实测（`/babu weapon`）：圣骑士 7 条（尸-太浓）/ 牧师 8 条（爷爷-泡茶 6 条含手动
-- 暗言术：痛；爸爸-不会泡茶 2 条虚弱之触·buff 与 debuff 两阶段）/ 萨满 1 条（石化武器·武器灌注，
-- 走附魔通道）/ 种族 3 条（血性狂暴·兽人、感知·人类、食尸·亡灵）/ 各职业常驻增益 13 条。
-- 名字均为该客户端给出的本地化名（缺名字的旧条目按客户端物品库交叉核对：圣典：渐隐术 /
-- 圣典：恢复 / 圣典：心灵之火 / 圣典：暗言术：痛 / EllesmereUI 的 Power Word 两条）。
-- ⚠️ 名字驱动：auraName 才是匹配键，auraSpellID / actionSpellID 只是「观察到那一级」的 ID，
--    仅作名字解析失败时的兜底（详见主文件 RebuildGroups 的预设循环）。
-- ⚠️ 新条目只能加在表尾：预设启停按 ipairs 序号存档（specs[specID].presets[key]），
--    中途插入会让后续条目的禁用记录错位。
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    B.PRESET_DATA = {
        -- 圣骑士 PALADIN（自增益；光环 ID 通常等于该等级技能 ID）
        { class = "PALADIN", auraName = "正义圣印",   auraSpellID = 20154,   actionName = "正义圣印",   actionSpellID = 20154 },
        { class = "PALADIN", auraName = "力量祝福",   auraSpellID = 19740,   actionName = "力量祝福",   actionSpellID = 19740 },
        { class = "PALADIN", auraName = "十字军圣印", auraSpellID = 21082,   actionName = "十字军圣印", actionSpellID = 21082 },
        -- 圣佑术：auraSpellID 并入 Ellesmere 永恒表的全部 rank（5573 = 更高一级的光环）
        { class = "PALADIN", auraName = "圣佑术",     auraSpellID = { 498, 5573 }, actionName = "圣佑术", actionSpellID = 498 },
        { class = "PALADIN", auraName = "正义之怒",   auraSpellID = 25780,   actionName = "正义之怒",   actionSpellID = 25780 },
        -- 愤怒圣印：永恒自定义法术（ID 落在 1.3M 段，正式服无此 ID）
        { class = "PALADIN", auraName = "愤怒圣印",   auraSpellID = 1311649, actionName = "愤怒圣印",   actionSpellID = 1311649 },
        -- 保护祝福：并入 Ellesmere 的 5599 / 10278（更高 rank 与群体版）
        { class = "PALADIN", auraName = "保护祝福",   auraSpellID = { 1022, 5599, 10278 }, actionName = "保护祝福", actionSpellID = 1022 },

        -- 牧师 PRIEST
        { class = "PRIEST", auraName = "真言术：韧", auraSpellID = 1243, actionName = "真言术：韧", actionSpellID = 1243 },
        -- 真言术：盾 / 恢复 / 渐隐术：auraSpellID 并入 Ellesmere 永恒表的整条 rank 线
        -- （名字驱动本来就能展开同名 ID，这里写全是为了「名字索引没覆盖到某个 rank」时兜底）
        { class = "PRIEST", auraName = "真言术：盾", auraSpellID = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
          actionName = "真言术：盾", actionSpellID = 17 },
        { class = "PRIEST", auraName = "恢复", auraSpellID = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315,
            425268, 425269, 425270, 425271, 425272, 425273, 425274, 425275, 425276, 425277 },
          actionName = "恢复", actionSpellID = 139 },
        { class = "PRIEST", auraName = "渐隐术", auraSpellID = { 586, 9578, 9579, 9592, 10941, 10942 },
          actionName = "渐隐术", actionSpellID = 586 },
        { class = "PRIEST", auraName = "心灵之火",   auraSpellID = 588,  actionName = "心灵之火",   actionSpellID = 588 },
        -- 暗言术：痛：挂在目标身上的我方减益。存档里这条是「手动绑定」（手动绑定会双路展开
        -- player/target），预设必须显式写 target，否则键到玩家的增益通道上永远不命中。
        { class = "PRIEST", auraName = "暗言术：痛", auraSpellID = 589, actionName = "暗言术：痛", actionSpellID = 589,
          unit = "target", filter = "HARMFUL|PLAYER" },

        -- 种族技能（不设 class：靠施放技能的 IsPlayerSpell 门禁自动筛选，只有对应种族生效）
        { auraName = "血性狂暴", auraSpellID = 20572, actionName = "血性狂暴", actionSpellID = 20572 }, -- 兽人
        { auraName = "感知",     auraSpellID = 20600, actionName = "感知",     actionSpellID = 20600 }, -- 人类
        { auraName = "食尸",     auraSpellID = 20578, actionName = "食尸",     actionSpellID = 20577 }, -- 亡灵（光环 20578 = 进食增益，施放技能 20577）

        -- 虚弱之触（牧师，2026-11-09 收编）：这个技能有【两个阶段、两个单位、两个光环 ID】——
        --   ① 施放 2652 后自身获得同名 buff（buff ID 就是施放 ID 2652），被打一次即消失；
        --   ② 被打那一下把同名 debuff 挂到怪身上，debuff ID 与施放 ID 不同（本 Rank 实测 2943）。
        -- 一条预设只能盯一个单位（容器按 unit+filter 分组），所以拆成两条；两阶段互斥，
        -- 不会在同一按钮上叠两层显示。
        -- ⚠️ ① 自身 buff 走名字展开即可跨 Rank（buff ID = 施放 ID）；
        -- ② 敌方 debuff 的 ID 升 Rank 必变、名字索引（动作条∪法术书）推不出来，只能靠脱战扫描
        --    记一次（B.RecordSeenAura 的 auraSeen 缓存，按名字并入追踪集合），故这里写的是
        --    本 Rank 的观察值 2943 —— 它只作首屏兜底，真身 ID 由扫描补齐。
        -- 条目必须加在表尾（启停按 ipairs 序号存档）。
        { class = "PRIEST", auraName = "虚弱之触", auraSpellID = 2652, actionName = "虚弱之触", actionSpellID = 2652 },
        { class = "PRIEST", auraName = "虚弱之触", auraSpellID = 2943, actionName = "虚弱之触", actionSpellID = 2652,
          unit = "target", filter = "HARMFUL|PLAYER" },

        -- 石化武器（萨满武器灌注，2026-11-11 实测）：它【不是 unit aura】——客户端把灌注做成
        -- item enchant（Enum.ItemEnchantType.Imbue = 3），/babu scan 一条光环都扫不到，
        -- 只能走武器附魔覆盖层通道（1 秒 ticker）。本 Rank（施放 8017）实测：
        -- enchantID = 29、enchantIconID = 136086，tooltip 写作「石化 1（54分钟）」——
        -- 附魔名（石化 1）与法术名（石化武器）不一致，所以按名字认这条路走不通。
        -- 升 Rank 后 enchantID 会变 → 同时按【附魔图标】匹配（同一灌注的图标跨 Rank 不变）；
        -- 若新 Rank 连图标也换，把 /babu weapon 的新值补进 enchantIDs / imbueIcons。
        -- 施放技能按名字解析到条上当前 Rank（actionName 驱动），按钮定位不受 Rank 影响。
        { class = "SHAMAN", imbueName = "石化武器", enchantIDs = { 29 }, imbueIcons = { 136086 },
          actionName = "石化武器", actionSpellID = 8017 },

        -- ===== 各职业常驻增益（2026-11-11；数据来自本客户端自带插件的 Forever 表：
        --       EllesmereUI/EllesmereUI_BuffPresets.lua 的 FOREVER_BUFF_FAMILIES，
        --       与 EllesmereUIAuraBuffReminders 的 EABR.FvClassBuffs）=====
        -- 全部写成【ID 数组】：那些表给的就是「能给该增益的全部法术 ID」（各 Rank + 群体版 +
        -- NPC/物品副本），数组任一命中即显示 → 天然跨 Rank，而且**不需要写中文字名**：
        -- 按钮定位靠 actionSpellID 在运行时反查名字，名字不用进表。
        -- ⚠️ 未在客户端逐条实测：若某条在本客户端根本不产生光环，表现是「勾着不显示」。
        -- ⚠️ 只能加在表尾（启停按 ipairs 序号存档）。
        { class = "DRUID", auraSpellID = { 1126, 5232, 5234, 5286, 5287, 6756, 8907, 8908, 9884, 9885,
            16878, 24752, 364163, 1291335, 1310503, 21849, 21850 }, actionSpellID = 1126 },                 -- 野性印记
        { class = "DRUID", auraSpellID = { 467, 782, 1075, 8914, 9756, 9910, 15438, 16877, 21335, 21337,
            22128, 22351, 22696, 25640, 25777, 438294, 438326, 1213813, 1213816, 1213834, 1236308,
            1291338, 1312955 }, actionSpellID = 467 },                                                      -- 荆棘术
        { class = "MAGE", auraSpellID = { 1459, 1460, 1461, 10156, 10157, 13326, 16876, 364161, 23028 },
          actionSpellID = 1459 },                                                                           -- 奥术智慧
        { class = "MAGE", auraSpellID = { 168, 7300, 7301 }, actionSpellID = 168 },                         -- 冰甲术
        { class = "MAGE", auraSpellID = { 7302, 7320, 10219, 10220 }, actionSpellID = 7302 },               -- 冰霜护甲
        { class = "MAGE", auraSpellID = { 6117, 22782, 22783 }, actionSpellID = 6117 },                     -- 魔甲术
        { class = "PALADIN", auraSpellID = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
          actionSpellID = 19742 },                                                                          -- 智慧祝福
        { class = "PALADIN", auraSpellID = { 20217, 1213408, 25898 }, actionSpellID = 20217 },              -- 王者祝福
        { class = "PALADIN", auraSpellID = { 1038, 1912, 25895 }, actionSpellID = 1038 },                   -- 拯救祝福
        { class = "PRIEST", auraSpellID = { 15473 }, actionSpellID = 15473, overlayOnly = true },           -- 暗影形态（无持续时间，仅遮罩）
        { class = "SHAMAN", auraSpellID = { 324, 325, 905, 945, 8134, 10431, 10432 }, actionSpellID = 324 }, -- 闪电之盾
        { class = "WARLOCK", auraSpellID = { 687, 696, 706, 1086, 11733, 11734, 11735 }, actionSpellID = 687 }, -- 魔甲术
        { class = "WARRIOR", auraSpellID = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 9128, 24438,
            25101, 26043, 26099, 27578 }, actionSpellID = 6673 },                                           -- 战斗怒吼

        -- ===== 以下整段导入自客户端自带插件的永恒目录 =====
        -- 来源：EllesmereUI/EllesmereUI_BuffPresets.lua 的 ForeverCatalogue()（每个 filter 一组，
        -- 每组 primary + alts 都是「能产生该光环的全部法术 ID」，rank 线 + 群体版 + NPC/物品副本）。
        -- 转换规则（脚本离线生成，见 .temp/gen_block.lua，未手工抄写 ID）：
        --   · group = 该条在 Ellesmere 里的 filter 分区（配置窗口按它分组显示）
        --   · auraSpellID = primary + alts（已剔除上面手写条目已覆盖的 ID，避免同一按钮两行）
        --   · actionSpellID = primary；仅当 primary 是纯光环 ID 时改回真实施放 ID（本表无此情况）
        --   · overlayOnly = 形态/开关类无持续时间光环（潜行、旅行形态、幽魂之狼、自然迅捷、救赎之魂）
        -- ⚠️ 未在客户端逐条实测：若某条在本客户端不产生光环，表现是「勾着不显示」，删掉即可。
        -- ⚠️ 只能加在表尾：启停按 ipairs 序号存档（specs[specID].presets[key]）。
        -- ----- defensives -----
        { class = "PALADIN", group = "defensives", auraSpellID = { 642, 1020 }, actionSpellID = 642 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 871 }, actionSpellID = 871 },
        { class = "MAGE", group = "defensives", auraSpellID = { 1463, 8494, 8495, 10191, 10192, 10193 }, actionSpellID = 1463 },
        { class = "ROGUE", group = "defensives", auraSpellID = { 1856, 1857, 11327, 11329 }, actionSpellID = 1856 },
        { class = "ROGUE", group = "defensives", auraSpellID = { 5277 }, actionSpellID = 5277 },
        { class = "WARLOCK", group = "defensives", auraSpellID = { 6229, 11739, 11740, 28610 }, actionSpellID = 6229 },
        { class = "MAGE", group = "defensives", auraSpellID = { 11958 }, actionSpellID = 11958 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 12975, 12976 }, actionSpellID = 12975 },
        { class = "MAGE", group = "defensives", auraSpellID = { 11426, 13031, 13032, 13033 }, actionSpellID = 13031 },
        { class = "HUNTER", group = "defensives", auraSpellID = { 19263 }, actionSpellID = 19263 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 20230 }, actionSpellID = 20230 },
        { class = "DRUID", group = "defensives", auraSpellID = { 22812 }, actionSpellID = 22812 },
        { class = "DRUID", group = "defensives", auraSpellID = { 22842, 22845 }, actionSpellID = 22842 },
        { class = "PRIEST", group = "defensives", overlayOnly = true, auraSpellID = { 27827 }, actionSpellID = 27827 },

        -- ----- raidcds -----
        { class = "DRUID", group = "raidcds", auraSpellID = { 740, 8918, 9862, 9863 }, actionSpellID = 8918 },

        -- ----- externals -----
        { class = "PRIEST", group = "externals", auraSpellID = { 6346 }, actionSpellID = 6346 },
        { class = "PALADIN", group = "externals", auraSpellID = { 6940, 20729 }, actionSpellID = 6940 },
        { class = "PRIEST", group = "externals", auraSpellID = { 10060 }, actionSpellID = 10060 },
        { class = "DRUID", group = "externals", auraSpellID = { 29166 }, actionSpellID = 29166 },

        -- ----- coreheals -----
        { class = "DRUID", group = "coreheals", auraSpellID = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 }, actionSpellID = 1058 },
        { class = "DRUID", group = "coreheals", auraSpellID = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 }, actionSpellID = 8938 },
        { class = "PRIEST", group = "coreheals", auraSpellID = { 401859, 401877, 1240826, 1240827, 1240848, 1240849 }, actionSpellID = 401859 },

        -- ----- offensive -----
        { class = "WARRIOR", group = "offensive", auraSpellID = { 1719 }, actionSpellID = 1719 },
        { class = "HUNTER", group = "offensive", auraSpellID = { 3045 }, actionSpellID = 3045 },
        { class = "DRUID", group = "offensive", auraSpellID = { 5217 }, actionSpellID = 5217 },
        { class = "MAGE", group = "offensive", auraSpellID = { 11129 }, actionSpellID = 11129 },
        { class = "MAGE", group = "offensive", auraSpellID = { 12042 }, actionSpellID = 12042 },
        { class = "MAGE", group = "offensive", auraSpellID = { 12043 }, actionSpellID = 12043 },
        { class = "WARRIOR", group = "offensive", auraSpellID = { 12292 }, actionSpellID = 12292 },
        { class = "WARRIOR", group = "offensive", auraSpellID = { 12328 }, actionSpellID = 12328 },
        { class = "ROGUE", group = "offensive", auraSpellID = { 13750 }, actionSpellID = 13750 },
        { class = "ROGUE", group = "offensive", auraSpellID = { 13877 }, actionSpellID = 13877 },
        { class = "ROGUE", group = "offensive", auraSpellID = { 14177 }, actionSpellID = 14177 },
        { class = "PRIEST", group = "offensive", auraSpellID = { 14751 }, actionSpellID = 14751 },
        { class = "SHAMAN", group = "offensive", overlayOnly = true, auraSpellID = { 16188 }, actionSpellID = 16188 },
        { class = "DRUID", group = "offensive", overlayOnly = true, auraSpellID = { 17116 }, actionSpellID = 17116 },
        { class = "WARRIOR", group = "offensive", auraSpellID = { 18499 }, actionSpellID = 18499 },
        { class = "HUNTER", group = "offensive", auraSpellID = { 19574 }, actionSpellID = 19574 },
        { class = "PALADIN", group = "offensive", auraSpellID = { 20216 }, actionSpellID = 20216 },

        -- ----- movement -----
        { class = "MAGE", group = "movement", auraSpellID = { 130 }, actionSpellID = 130 },
        { class = "DRUID", group = "movement", overlayOnly = true, auraSpellID = { 783 }, actionSpellID = 783 },
        { class = "PALADIN", group = "movement", auraSpellID = { 1044, 299256 }, actionSpellID = 1044 },
        { class = "PRIEST", group = "movement", auraSpellID = { 1706 }, actionSpellID = 1706 },
        { class = "ROGUE", group = "movement", overlayOnly = true, auraSpellID = { 1784, 1785, 1786, 1787 }, actionSpellID = 1784 },
        { class = "DRUID", group = "movement", auraSpellID = { 1850, 9821 }, actionSpellID = 1850 },
        { class = "SHAMAN", group = "movement", overlayOnly = true, auraSpellID = { 2645 }, actionSpellID = 2645 },
        { class = "ROGUE", group = "movement", auraSpellID = { 2983, 8696, 11305 }, actionSpellID = 2983 },
        { class = "DRUID", group = "movement", overlayOnly = true, auraSpellID = { 5215, 6783, 9913 }, actionSpellID = 5215 },
        { class = "HUNTER", group = "movement", auraSpellID = { 5384 }, actionSpellID = 5384 },

        -- ----- utility -----
        { class = "SHAMAN", group = "utility", auraSpellID = { 131 }, actionSpellID = 131 },
        { class = "SHAMAN", group = "utility", auraSpellID = { 546 }, actionSpellID = 546 },
        { class = "MAGE", group = "utility", auraSpellID = { 604, 8450, 8451, 10173, 10174 }, actionSpellID = 604 },
        { class = "MAGE", group = "utility", auraSpellID = { 1008, 8455, 10169, 10170 }, actionSpellID = 1008 },
        { class = "WARLOCK", group = "utility", auraSpellID = { 5697 }, actionSpellID = 5697 },
    }
    return
end

-- 正式服表结构（2026-11-11 重组）：
--   前半 = 上游 ActionbarEnhanced 移植的精选条目 + 手动维护的特殊配对。仍留在表前的，是
--     Ellesmere 零售目录**没有**的东西：武器附魔 / 毒药 / 误导前后 / 治疗宠物 / 种族技能 /
--     嗜血家族 / 团队增益（奥术智慧、野性印记、真言术韧、战斗怒吼）/ 目标减益三怒吼等。
--     其中被 Ellesmere 目录覆盖过同一 ID 的条目已剔除（避免配置窗口里同一按钮出现两行）。
--   后半 = 按 Ellesmere filter 分组的全量导入块（见该块前的说明）。
-- 全职业通用（class = nil，靠 IsPlayerSpell 门禁自动筛选）+ 无持续时间光环，见下方表内注释

-- 嗜血/英勇家族：不同职业的引导技能不同，但施放到全队身上的增益本质是同一个效果
-- （嗜血 2825 / 英勇 32182 / 时间扭曲 80353 / 远古狂暴 90355 / 原始狂怒 264667 /
--   原始暴怒-技能书版 272678 / 化身巨龙之怒 390386）。
-- 任一命中即显示 → 用同一个光环 ID 集合；actionSpellID 指向本职业的施放技能按钮。
-- filter 用缺省 HELPFUL（不加 |PLAYER）：队友施放的英勇同样显示（倒计时参考价值一致）。
-- 注意 264667 与 272678 同名「原始暴怒」但体系不同：264667 是宠物施放版（wowhead 证实
-- buff 本体），272678 是猎人技能书页版（效果为 Dummy，服务端转手触发 264667）；猎人条上
-- 的按钮由「宠物掌控 272651」在召唤狂野系宠物时替换为 272678，故按钮定位用 272678。
local LUST_AURAS = { 2825, 32182, 80353, 90355, 264667, 272678, 390386 }

B.PRESET_DATA = {
    -- 全职业通用（复原：光环 1231418 → 技能 1231411，所有职业的公用技能）
    { auraSpellID = 1231418, actionSpellID = 1231411 },
    -- 无持续时间光环（overlayOnly）：不显示倒计时/层数，仅绿色遮罩标记
    -- （均为萨满专属：378081 Wowhead Requires Shaman；2645 为萨满形态）
    { class = "SHAMAN", auraSpellID = 378081, actionSpellID = 378081, overlayOnly = true }, -- 自然迅捷（无持续时间）
    -- 嗜血/英勇家族（萨满两个引导技能按阵营二选一：部落嗜血 2825 / 联盟英勇 32182；
    -- 未学的那个被 IsPlayerSpell 门自动停用，条目保留是为了两阵营通用）
    { class = "SHAMAN", auraSpellID = LUST_AURAS, actionSpellID = 2825 },   -- 嗜血（部落）
    { class = "SHAMAN", auraSpellID = LUST_AURAS, actionSpellID = 32182 },  -- 英勇（联盟）
    { class = "MAGE",   auraSpellID = LUST_AURAS, actionSpellID = 80353 },  -- 时间扭曲
    { class = "EVOKER", auraSpellID = LUST_AURAS, actionSpellID = 390386 }, -- 化身巨龙之怒
    { class = "HUNTER", auraSpellID = LUST_AURAS, actionSpellID = 272678 }, -- 原始暴怒（条上按钮 = 技能书版 272678，由宠物掌控 272651 替换而来；264667 为宠物施放版，过不了 IsPlayerSpell 门禁）

    -- 猎人 HUNTER（这里只留 Ellesmere 目录没有的配对：目标减益 / 宠物 / 技能书与按钮不同名）
    { class = "HUNTER", auraSpellID = 212431, actionSpellID = 212431, unit = "target", filter = "HARMFUL|PLAYER" }, -- 爆炸射击
    { class = "HUNTER", auraSpellID = 385540, actionSpellID = 109304 },  -- 意气风发（减伤）
    { class = "HUNTER", auraSpellID = 34477, actionSpellID = 34477 },    -- 误导(生效前)
    { class = "HUNTER", auraSpellID = 35079, actionSpellID = 34477 },    -- 误导(生效后)
    { class = "HUNTER", auraSpellID = 257622, actionSpellID = 257620 },  -- 技巧射击绑多重射击
    { class = "HUNTER", auraSpellID = 6197, actionSpellID = 6197 },      -- 鹰眼术
    { class = "HUNTER", auraSpellID = 321297, actionSpellID = 321297 },  -- 野兽之眼
    -- 武僧 MONK（减伤/爆发）
    { class = "MONK", auraSpellID = 122278, actionSpellID = 122278 },    -- 躯不坏（减伤）
    { class = "MONK", auraSpellID = 115176, actionSpellID = 115176 },    -- 禅悟冥想（引导减伤）
    { class = "MONK", auraSpellID = 116680, actionSpellID = 116680 },    -- 雷光聚神茶（爆发）
    { class = "MONK", auraSpellID = 137639, actionSpellID = 137639 },    -- 风火雷电（爆发）
    -- 萨满 SHAMAN
    { class = "SHAMAN", auraSpellID = 462854, actionSpellID = 462854 },  -- 天怒（光环=技能）
    { class = "SHAMAN", auraSpellID = 192106, actionSpellID = 192106 },  -- 闪电之盾
    { class = "SHAMAN", auraSpellID = 52127, actionSpellID = 52127 },    -- 水之护盾
    { class = "SHAMAN", auraSpellID = 546, actionSpellID = 546 },        -- 水上行走
    { class = "SHAMAN", auraSpellID = 6196, actionSpellID = 6196 },      -- 视界术
    { class = "SHAMAN", enchantID = 5400, actionSpellID = 318038, enchantName = "Flametongue" },       -- 火舌武器
    { class = "SHAMAN", enchantID = 5401, actionSpellID = 33757, enchantName = "Windfury" },           -- 风怒武器
    { class = "SHAMAN", enchantID = 6498, actionSpellID = 382021, enchantName = "Earthliving Weapon" }, -- 大地生命武器
    { class = "SHAMAN", enchantID = 7528, actionSpellID = 457481, enchantName = "Tidecaller's Guard" }, -- 唤潮者护卫
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
    { class = "ROGUE", auraSpellID = 1856, actionSpellID = 1856 },       -- 消失（保命）
    -- 法师 MAGE
    { class = "MAGE", auraSpellID = 1459, actionSpellID = 1459 },        -- 奥术智慧（团队增益）
    { class = "MAGE", auraSpellID = 210126, actionSpellID = 1459 },      -- 奥术魔宠（buff 210126 → 奥术智慧 1459）
    -- 法师 MAGE（减伤/爆发；光环=技能同ID）
    { class = "MAGE", auraSpellID = 12042, actionSpellID = 12042 },      -- 奥术强化（爆发）
    { class = "MAGE", auraSpellID = 12472, actionSpellID = 12472 },      -- 冰冷血脉（爆发）
    -- 术士 WARLOCK
    { class = "WARLOCK", auraSpellID = 196099, actionSpellID = 108503 }, -- 牺牲魔典
    -- 战士 WARRIOR
    { class = "WARRIOR", auraSpellID = 6673, actionSpellID = 6673 },     -- 战斗怒吼（团队增益）
    -- 战士 WARRIOR（减伤/爆发；光环=技能同ID）
    { class = "WARRIOR", auraSpellID = 18499, actionSpellID = 18499 },   -- 狂暴之怒
    { class = "WARRIOR", auraSpellID = 1160, actionSpellID = 1160, unit = "target", filter = "HARMFUL|PLAYER" },    -- 挫志怒吼
    { class = "WARRIOR", auraSpellID = 12323, actionSpellID = 12323, unit = "target", filter = "HARMFUL|PLAYER" },  -- 刺耳怒吼
    { class = "WARRIOR", auraSpellID = 386071, actionSpellID = 386071, unit = "target", filter = "HARMFUL|PLAYER" }, -- 瓦解怒吼
    { class = "WARRIOR", auraSpellID = 12975, actionSpellID = 12975 },   -- 破釜沉舟（防战减伤）
    { class = "WARRIOR", auraSpellID = 23920, actionSpellID = 23920 },   -- 法术反射（减伤）
    { class = "WARRIOR", auraSpellID = 227847, actionSpellID = 227847 }, -- 剑刃风暴（爆发）
    { class = "WARRIOR", auraSpellID = 260708, actionSpellID = 260708 }, -- 横扫攻击（爆发）
    -- 德鲁伊 DRUID
    { class = "DRUID", auraSpellID = 1126, actionSpellID = 1126 },       -- 野性印记（团队增益，432661 为 NPC 版）
    -- 德鲁伊 DRUID（减伤/爆发；光环=技能同ID）
    { class = "DRUID", auraSpellID = 5217, actionSpellID = 5217 },       -- 猛虎之怒（猫爆发）
    { class = "DRUID", auraSpellID = 33891, actionSpellID = 33891 },     -- 化身:生命之树（奶爆发）
    -- 牧师 PRIEST
    { class = "PRIEST", auraSpellID = 21562, actionSpellID = 21562 },    -- 真言术韧（团队增益）
    -- 牧师 PRIEST（减伤/爆发；光环=技能同ID）
    { class = "PRIEST", auraSpellID = 15286, actionSpellID = 15286 },    -- 吸血鬼拥抱（自疗）
    -- 圣骑士 PALADIN（武器仪式）
    { class = "PALADIN", enchantID = 7144, actionSpellID = 433583, enchantName = "Ritual of Judgment" },       -- 裁决仪式
    { class = "PALADIN", enchantID = 7143, actionSpellID = 433568, enchantName = "Ritual of Sanctification" }, -- 圣化仪式
    -- 圣骑士 PALADIN（减伤/爆发；光环=技能同ID）
    { class = "PALADIN", auraSpellID = 105809, actionSpellID = 105809 }, -- 神圣复仇者（防骑爆发）
    -- 唤魔者 EVOKER（增辉协调：黑 403264 / 铜 403265 二选一）
    { class = "EVOKER", auraSpellID = { 403264, 403265 }, actionSpellID = 403208 },
    -- 唤魔者 EVOKER 青铜龙祝福（团队增益，光环为多阶段变体）
    { class = "EVOKER", auraSpellID = { 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 }, actionSpellID = 364342 },
    -- 唤魔者 EVOKER（减伤/爆发；光环=技能同ID）
    { class = "EVOKER", auraSpellID = 357210, actionSpellID = 357210 },  -- 深呼吸（爆发）
    -- 种族技能（与职业无关，不设 class；IsPlayerSpell 自动过滤——只有会该技能的种族才生效）
    { auraSpellID = 65116, actionSpellID = 20594 },                      -- 石像形态（光环 65116 → 技能 20594，矮人）

    -- 先祖迅捷 443454：先知（Farseer）英雄天赋第 5 行节点，习得后【取代】自然迅捷 378081
    --（玩家身上的无持续时间光环与条上按钮都变成 443454）。⚠️ 必须单列条目、不能并进上面
    -- 自然迅捷那条的 auraSpellID 数组：按钮解析按法术名匹配（ResolveButton→FindActionButtonForSpellName），
    -- 「先祖迅捷」与「自然迅捷」名字不同，actionSpellID 只有 378081 时永远找不到按钮。
    -- 未习得该天赋时 IsPlayerSpell(443454)=false → 条目自动失活，无副作用。
    -- ⚠️ 放在表尾：预设启停按 ipairs 序号存档（specs[specID].presets[key]），中途插入会使
    -- 后续条目的禁用记录错位。
    { class = "SHAMAN", auraSpellID = 443454, actionSpellID = 443454, overlayOnly = true }, -- 先祖迅捷（无持续时间，先知天赋取代自然迅捷）

    -- 治疗宠物 136：宠物身上、由【玩家】施放的 Hot（10s）。unit="pet" + filter="HELPFUL|PLAYER"
    -- = 只追踪玩家自己施放到宠物身上的增益（宠物自身/队友施放的不显示）。
    -- ⚠️ 放在表尾：预设启停按 ipairs 序号存档（specs[specID].presets[key]），中途插入会使
    --    后续条目的禁用记录错位。
    -- 按钮注意：Mend Pet 与 Revive Pet 共享动作条按钮——宠物死亡时按钮变为 Revive Pet，
    -- 按法术名解析不到 Mend Pet 的按钮 → 容器停靠；宠物复活后自愈恢复（ResolveButton 既有机制）。
    { class = "HUNTER", auraSpellID = 136, actionSpellID = 136, unit = "pet", filter = "HELPFUL|PLAYER" }, -- 治疗宠物（宠物 Hot）

    -- ===== 以下整段导入自客户端自带插件的正式服目录 =====
    -- 来源：EllesmereUI/EllesmereUI_BuffPresets.lua 的 RETAIL_PRESETS（每个 filter 一组，
    -- 组内 [primary] = { class, alts } 的全部 ID 都写进 auraSpellID，任一命中即显示）。
    -- 转换规则（脚本离线生成，见 .temp/gen_block.lua，未手工抄写 ID）：
    --   · group = 该条在 Ellesmere 里的 filter 分区（配置窗口按它分组显示）
    --   · 已被上面手写条目覆盖的 ID 已剔除；上面那批保留的是 Ellesmere 目录没有的配对
    --     （团队增益、武器附魔、毒药、误导、宠物、种族技能、嗜血家族等）
    --   · actionSpellID 修正为真实施放 ID 的：383648→974 大地之盾、121557→121536 羽毛、
    --     97463→97462 集结呐喊（Ellesmere 的 primary 是光环 ID，这里换成按钮上的技能 ID）
    --   · defaultOff = Ellesmere 标了 disabled 的条目：数据保留但默认不勾，
    --     避免一次性接管几百条（勾选会显式记 true，见 IsPresetEnabled）
    -- ⚠️ 未逐条实测：勾着不显示的对应用户自行取消即可。
    -- ⚠️ 只能加在表尾：启停按 ipairs 序号存档（specs[specID].presets[key]）。
        -- ----- defensives -----
        { class = "PALADIN", group = "defensives", auraSpellID = { 403876 }, actionSpellID = 498 },
        { class = "PRIEST", group = "defensives", auraSpellID = { 27827 }, actionSpellID = 27827 },
        { class = "PRIEST", group = "defensives", defaultOff = true, auraSpellID = { 45242, 426401 }, actionSpellID = 45242 },
        { class = "DEATHKNIGHT", group = "defensives", auraSpellID = { 444741 }, actionSpellID = 48707 },
        { class = "DEATHKNIGHT", group = "defensives", auraSpellID = { 101568 }, actionSpellID = 101568 },
        { class = "PRIEST", group = "defensives", defaultOff = true, auraSpellID = { 114214, 114216 }, actionSpellID = 114216 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 118038 }, actionSpellID = 118038 },
        { class = "MONK", group = "defensives", auraSpellID = { 125174 }, actionSpellID = 125174 },
        { class = "WARLOCK", group = "defensives", auraSpellID = { 132413 }, actionSpellID = 132413 },
        { class = "MONK", group = "defensives", auraSpellID = { 132578 }, actionSpellID = 132578 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 147833 }, actionSpellID = 147833 },
        { class = "PALADIN", group = "defensives", defaultOff = true, auraSpellID = { 184662 }, actionSpellID = 184662 },
        { class = "DEMONHUNTER", group = "defensives", auraSpellID = { 187827 }, actionSpellID = 187827 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 1277297 }, actionSpellID = 190456 },
        { class = "PRIEST", group = "defensives", auraSpellID = { 193065 }, actionSpellID = 193065 },
        { class = "WARRIOR", group = "defensives", defaultOff = true, auraSpellID = { 202147 }, actionSpellID = 202147 },
        { class = "DEMONHUNTER", group = "defensives", auraSpellID = { 207771 }, actionSpellID = 207771 },
        { class = "PALADIN", group = "defensives", auraSpellID = { 212641 }, actionSpellID = 212641 },
        { class = "MAGE", group = "defensives", defaultOff = true, auraSpellID = { 235313 }, actionSpellID = 235313 },
        { class = "MAGE", group = "defensives", defaultOff = true, auraSpellID = { 235450 }, actionSpellID = 235450 },
        { class = "SHAMAN", group = "defensives", auraSpellID = { 260881 }, actionSpellID = 260881 },
        { class = "MONK", group = "defensives", auraSpellID = { 322507 }, actionSpellID = 322507 },
        { class = "MAGE", group = "defensives", auraSpellID = { 342246 }, actionSpellID = 342246 },
        { class = "EVOKER", group = "defensives", auraSpellID = { 374349 }, actionSpellID = 374349 },
        { class = "SHAMAN", group = "defensives", auraSpellID = { 381755 }, actionSpellID = 381755 },
        { class = "WARRIOR", group = "defensives", auraSpellID = { 385391 }, actionSpellID = 385391 },
        { class = "WARLOCK", group = "defensives", auraSpellID = { 387636 }, actionSpellID = 387636 },
        { class = "WARLOCK", group = "defensives", defaultOff = true, auraSpellID = { 389614 }, actionSpellID = 389614 },
        { class = "DRUID", group = "defensives", defaultOff = true, auraSpellID = { 393903 }, actionSpellID = 393903 },
        { class = "EVOKER", group = "defensives", auraSpellID = { 404381 }, actionSpellID = 404381 },
        { class = "MAGE", group = "defensives", auraSpellID = { 414658 }, actionSpellID = 414658 },
        { class = "DEMONHUNTER", group = "defensives", defaultOff = true, auraSpellID = { 258920, 427912 }, actionSpellID = 427912 },
        { class = "MONK", group = "defensives", defaultOff = true, auraSpellID = { 432180 }, actionSpellID = 432180 },
        { class = "DEMONHUNTER", group = "defensives", defaultOff = true, auraSpellID = { 442715 }, actionSpellID = 442715 },
        { class = "MAGE", group = "defensives", auraSpellID = { 449336 }, actionSpellID = 449336 },
        { class = "HUNTER", group = "defensives", defaultOff = true, auraSpellID = { 472708 }, actionSpellID = 472708 },
        { class = "MONK", group = "defensives", auraSpellID = { 1241059 }, actionSpellID = 1241059 },
        { class = "DRUID", group = "defensives", auraSpellID = { 1261872 }, actionSpellID = 1261872 },
        { class = "DEMONHUNTER", group = "defensives", defaultOff = true, auraSpellID = { 394933, 1266616 }, actionSpellID = 1266616 },
        { class = "MAGE", group = "defensives", auraSpellID = { 1309793 }, actionSpellID = 1309793 },

        -- ----- activemitigation -----
        { class = "DEATHKNIGHT", group = "activemitigation", auraSpellID = { 77535 }, actionSpellID = 77535 },
        { class = "PALADIN", group = "activemitigation", auraSpellID = { 132403 }, actionSpellID = 132403 },
        { class = "WARRIOR", group = "activemitigation", auraSpellID = { 132404 }, actionSpellID = 132404 },
        { class = "DEMONHUNTER", group = "activemitigation", auraSpellID = { 203819 }, actionSpellID = 203819 },

        -- ----- raidcds -----
        { class = "DRUID", group = "raidcds", defaultOff = true, auraSpellID = { 740, 157982, 1264623 }, actionSpellID = 740 },
        { class = "PALADIN", group = "raidcds", auraSpellID = { 31821, 317929 }, actionSpellID = 31821 },
        { class = "PRIEST", group = "raidcds", defaultOff = true, auraSpellID = { 64844 }, actionSpellID = 64843 },
        { class = "PRIEST", group = "raidcds", auraSpellID = { 62618, 81782 }, actionSpellID = 81782 },
        { class = "DEATHKNIGHT", group = "raidcds", auraSpellID = { 51052, 145629 }, actionSpellID = 145629 },
        -- 黑暗：Ellesmere 在 defensives 与 raidcds 各列一条（同 ID），并成一条，光环 209426 与 196718 都追踪
        { class = "DEMONHUNTER", group = "raidcds", auraSpellID = { 196718, 209426 }, actionSpellID = 209426 },
        { class = "SHAMAN", group = "raidcds", auraSpellID = { 98008, 325174 }, actionSpellID = 325174 },
        { class = "EVOKER", group = "raidcds", defaultOff = true, auraSpellID = { 359816, 362361 }, actionSpellID = 359816 },
        { class = "EVOKER", group = "raidcds", defaultOff = true, auraSpellID = { 363534 }, actionSpellID = 363534 },
        { class = "EVOKER", group = "raidcds", auraSpellID = { 374227 }, actionSpellID = 374227 },

        -- ----- externals -----
        { class = "PALADIN", group = "externals", auraSpellID = { 1022, 1309794 }, actionSpellID = 1022 },
        { class = "PALADIN", group = "externals", auraSpellID = { 6940 }, actionSpellID = 6940 },
        { class = "HUNTER", group = "externals", auraSpellID = { 53480 }, actionSpellID = 53480 },
        { class = "DRUID", group = "externals", auraSpellID = { 102342 }, actionSpellID = 102342 },
        { class = "MONK", group = "externals", auraSpellID = { 116849 }, actionSpellID = 116849 },
        { class = "PALADIN", group = "externals", auraSpellID = { 204018 }, actionSpellID = 204018 },
        { class = "PALADIN", group = "externals", auraSpellID = { 387804 }, actionSpellID = 387804 },

        -- ----- coreheals -----
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 1246768, 1254306, 1300008 }, actionSpellID = 17 },
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 139 }, actionSpellID = 139 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 774, 419204 }, actionSpellID = 774 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 8936, 419287 }, actionSpellID = 8936 },
        { class = "DRUID", group = "coreheals", auraSpellID = { 33763, 419207, 1227806 }, actionSpellID = 33763 },
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 41635 }, actionSpellID = 41635 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 48438, 419344 }, actionSpellID = 48438 },
        { class = "PALADIN", group = "coreheals", auraSpellID = { 53563 }, actionSpellID = 53563 },
        { class = "SHAMAN", group = "coreheals", defaultOff = true, auraSpellID = { 61295 }, actionSpellID = 61295 },
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 77489 }, actionSpellID = 77489 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 115175, 198533, 1260617 }, actionSpellID = 115175 },
        { class = "MONK", group = "coreheals", auraSpellID = { 119611 }, actionSpellID = 119611 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 124682 }, actionSpellID = 124682 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 155777 }, actionSpellID = 155777 },
        { class = "PALADIN", group = "coreheals", defaultOff = true, auraSpellID = { 461432 }, actionSpellID = 156322 },
        { class = "PALADIN", group = "coreheals", auraSpellID = { 156910 }, actionSpellID = 156910 },
        { class = "PRIEST", group = "coreheals", auraSpellID = { 194384 }, actionSpellID = 194384 },
        { class = "PALADIN", group = "coreheals", auraSpellID = { 200025 }, actionSpellID = 200025 },
        { class = "SHAMAN", group = "coreheals", defaultOff = true, auraSpellID = { 207400 }, actionSpellID = 207400 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 355936, 355941, 382614 }, actionSpellID = 355941 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 363502 }, actionSpellID = 363502 },
        { class = "EVOKER", group = "coreheals", auraSpellID = { 364343 }, actionSpellID = 364343 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 366155 }, actionSpellID = 366155 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 367364 }, actionSpellID = 367364 },
        { class = "EVOKER", group = "coreheals", auraSpellID = { 373267 }, actionSpellID = 373267 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 373862 }, actionSpellID = 373862 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 376788 }, actionSpellID = 376788 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 388513 }, actionSpellID = 388513 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 409678 }, actionSpellID = 409678 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 409895 }, actionSpellID = 409895 },
        { class = "PALADIN", group = "coreheals", defaultOff = true, auraSpellID = { 431381 }, actionSpellID = 431381 },
        { class = "PALADIN", group = "coreheals", defaultOff = true, auraSpellID = { 432502 }, actionSpellID = 432502 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 439530 }, actionSpellID = 439530 },
        { class = "SHAMAN", group = "coreheals", defaultOff = true, auraSpellID = { 444490 }, actionSpellID = 444490 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 445740 }, actionSpellID = 445740 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 450521, 450526, 450531, 450711, 450769 }, actionSpellID = 450769 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 450805 }, actionSpellID = 450805 },
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 453846, 453850 }, actionSpellID = 453846 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 427296, 467281 }, actionSpellID = 467281 },
        { class = "PALADIN", group = "coreheals", defaultOff = true, auraSpellID = { 469703 }, actionSpellID = 469703 },
        { class = "DRUID", group = "coreheals", auraSpellID = { 474750, 474754 }, actionSpellID = 474754 },
        { class = "PALADIN", group = "coreheals", auraSpellID = { 1244893 }, actionSpellID = 1244893 },
        { class = "PRIEST", group = "coreheals", defaultOff = true, auraSpellID = { 1253593, 1300009 }, actionSpellID = 1253593 },
        { class = "DRUID", group = "coreheals", defaultOff = true, auraSpellID = { 1278914 }, actionSpellID = 1278914 },
        { class = "EVOKER", group = "coreheals", defaultOff = true, auraSpellID = { 1291636 }, actionSpellID = 1291636 },
        { class = "MONK", group = "coreheals", defaultOff = true, auraSpellID = { 1292922 }, actionSpellID = 1292922 },

        -- ----- support -----
        { class = "EVOKER", group = "support", auraSpellID = { 360827 }, actionSpellID = 360827 },
        { class = "EVOKER", group = "support", defaultOff = true, auraSpellID = { 361021 }, actionSpellID = 361021 },
        { class = "EVOKER", group = "support", defaultOff = true, auraSpellID = { 361022 }, actionSpellID = 361022 },
        { class = "EVOKER", group = "support", defaultOff = true, auraSpellID = { 369459 }, actionSpellID = 369459 },
        { class = "EVOKER", group = "support", auraSpellID = { 395152, 395296 }, actionSpellID = 395152 },
        { class = "EVOKER", group = "support", auraSpellID = { 410089 }, actionSpellID = 410089 },
        { class = "EVOKER", group = "support", defaultOff = true, auraSpellID = { 410263 }, actionSpellID = 410263 },
        { class = "EVOKER", group = "support", defaultOff = true, auraSpellID = { 413984 }, actionSpellID = 413984 },

        -- ----- offensive -----
        { class = "PALADIN", group = "offensive", auraSpellID = { 216331, 231895, 454351 }, actionSpellID = 31884 },
        { class = "DEATHKNIGHT", group = "offensive", auraSpellID = { 42650 }, actionSpellID = 42650 },
        { class = "DRUID", group = "offensive", defaultOff = true, auraSpellID = { 50334 }, actionSpellID = 50334 },
        { class = "DRUID", group = "offensive", auraSpellID = { 102543 }, actionSpellID = 106951 },
        { class = "SHAMAN", group = "offensive", auraSpellID = { 114051, 114052 }, actionSpellID = 114050 },
        { class = "HUNTER", group = "offensive", auraSpellID = { 186254, 1235388, 1285912 }, actionSpellID = 186254 },
        { class = "DEMONHUNTER", group = "offensive", auraSpellID = { 321067, 321068 }, actionSpellID = 191427 },
        { class = "DRUID", group = "offensive", auraSpellID = { 102560, 194223 }, actionSpellID = 194223 },
        { class = "PRIEST", group = "offensive", auraSpellID = { 194249 }, actionSpellID = 194249 },
        { class = "WARLOCK", group = "offensive", auraSpellID = { 266087 }, actionSpellID = 266087 },
        { class = "MAGE", group = "offensive", auraSpellID = { 365350, 365362 }, actionSpellID = 365350 },
        { class = "EVOKER", group = "offensive", auraSpellID = { 375087 }, actionSpellID = 375087 },
        { class = "EVOKER", group = "offensive", defaultOff = true, auraSpellID = { 403631 }, actionSpellID = 403631 },
        { class = "WARLOCK", group = "offensive", auraSpellID = { 417282 }, actionSpellID = 417282 },
        { class = "WARLOCK", group = "offensive", auraSpellID = { 442726 }, actionSpellID = 442726 },
        { class = "SHAMAN", group = "offensive", auraSpellID = { 466772 }, actionSpellID = 466772 },
        { class = "DEMONHUNTER", group = "offensive", auraSpellID = { 471306, 473671, 1217605, 1217607 }, actionSpellID = 471306 },
        { class = "MAGE", group = "offensive", auraSpellID = { 1247908 }, actionSpellID = 1247908 },
        { class = "MONK", group = "offensive", defaultOff = true, auraSpellID = { 1248992 }, actionSpellID = 1248992 },
        { class = "MONK", group = "offensive", auraSpellID = { 1249625 }, actionSpellID = 1249625 },
        { class = "DEATHKNIGHT", group = "offensive", auraSpellID = { 152279, 1249658 }, actionSpellID = 1249658 },
        { class = "ROGUE", group = "offensive", auraSpellID = { 1249810 }, actionSpellID = 1249810 },
        { class = "HUNTER", group = "offensive", auraSpellID = { 1250646, 1251703 }, actionSpellID = 1250646 },
        { class = "WARLOCK", group = "offensive", auraSpellID = { 1276166 }, actionSpellID = 1276166 },
        { class = "WARLOCK", group = "offensive", defaultOff = true, auraSpellID = { 1276767 }, actionSpellID = 1276767 },

        -- ----- movement -----
        { class = "MAGE", group = "movement", auraSpellID = { 130 }, actionSpellID = 130 },
        { class = "PALADIN", group = "movement", auraSpellID = { 1044, 299256 }, actionSpellID = 1044 },
        { class = "ROGUE", group = "movement", overlayOnly = true, auraSpellID = { 1784 }, actionSpellID = 1784 },
        { class = "DRUID", group = "movement", auraSpellID = { 1850, 61684 }, actionSpellID = 1850 },
        { class = "ROGUE", group = "movement", auraSpellID = { 2983 }, actionSpellID = 2983 },
        { class = "DRUID", group = "movement", auraSpellID = { 5215 }, actionSpellID = 5215 },
        { class = "HUNTER", group = "movement", auraSpellID = { 5384 }, actionSpellID = 5384 },
        { class = "ROGUE", group = "movement", auraSpellID = { 31230 }, actionSpellID = 31230 },
        { class = "ROGUE", group = "movement", auraSpellID = { 36554 }, actionSpellID = 36554 },
        { class = "DEATHKNIGHT", group = "movement", auraSpellID = { 48265 }, actionSpellID = 48265 },
        { class = "MAGE", group = "movement", auraSpellID = { 55342 }, actionSpellID = 55342 },
        { class = "SHAMAN", group = "movement", auraSpellID = { 58875, 90328 }, actionSpellID = 58875 },
        { class = "PRIEST", group = "movement", auraSpellID = { 65081 }, actionSpellID = 65081 },
        { class = "SHAMAN", group = "movement", auraSpellID = { 79206 }, actionSpellID = 79206 },
        { class = "MONK", group = "movement", defaultOff = true, auraSpellID = { 101545 }, actionSpellID = 101545 },
        { class = "DRUID", group = "movement", auraSpellID = { 77761, 77764, 106898 }, actionSpellID = 106898 },
        { class = "MAGE", group = "movement", auraSpellID = { 108843 }, actionSpellID = 108843 },
        { class = "MAGE", group = "movement", auraSpellID = { 110960 }, actionSpellID = 110960 },
        { class = "WARLOCK", group = "movement", auraSpellID = { 111400 }, actionSpellID = 111400 },
        { class = "PRIEST", group = "movement", auraSpellID = { 111759 }, actionSpellID = 111759 },
        { class = "ROGUE", group = "movement", auraSpellID = { 114018 }, actionSpellID = 114018 },
        { class = "MONK", group = "movement", auraSpellID = { 116841 }, actionSpellID = 116841 },
        { class = "HUNTER", group = "movement", auraSpellID = { 118922 }, actionSpellID = 118922 },
        { class = "MONK", group = "movement", auraSpellID = { 119085 }, actionSpellID = 119085 },
        { class = "HUNTER", group = "movement", auraSpellID = { 186258 }, actionSpellID = 186257 },
        { class = "SHAMAN", group = "movement", auraSpellID = { 192082 }, actionSpellID = 192082 },
        { class = "HUNTER", group = "movement", auraSpellID = { 199483 }, actionSpellID = 199483 },
        { class = "WARRIOR", group = "movement", auraSpellID = { 202164 }, actionSpellID = 202164 },
        { class = "DEATHKNIGHT", group = "movement", auraSpellID = { 212552 }, actionSpellID = 212552 },
        { class = "DRUID", group = "movement", auraSpellID = { 252216 }, actionSpellID = 252216 },
        { class = "PALADIN", group = "movement", auraSpellID = { 221883, 221885, 221886, 221887, 254471, 254472, 254473, 254474, 276111, 276112, 294133, 363608, 453804, 1253723, 1253874, 1253881, 1272854,
            }, actionSpellID = 276111 },
        { class = "WARLOCK", group = "movement", auraSpellID = { 333889 }, actionSpellID = 333889 },
        { class = "DRUID", group = "movement", auraSpellID = { 340546 }, actionSpellID = 340546 },
        { class = "EVOKER", group = "movement", auraSpellID = { 358267 }, actionSpellID = 358267 },
        { class = "EVOKER", group = "movement", auraSpellID = { 358733 }, actionSpellID = 358733 },
        { class = "EVOKER", group = "movement", auraSpellID = { 370889 }, actionSpellID = 370889 },
        { class = "EVOKER", group = "movement", auraSpellID = { 375226, 375229, 375230, 375234, 375238, 375240, 375252, 375253, 375254, 375255, 375256, 375257, 375258,
            }, actionSpellID = 375234 },
        { class = "MAGE", group = "movement", auraSpellID = { 382294 }, actionSpellID = 382294 },
        { class = "WARLOCK", group = "movement", auraSpellID = { 387626 }, actionSpellID = 387626 },
        { class = "WARLOCK", group = "movement", auraSpellID = { 387633 }, actionSpellID = 387633 },
        { class = "MONK", group = "movement", auraSpellID = { 394112 }, actionSpellID = 394112 },
        { class = "DRUID", group = "movement", auraSpellID = { 400126 }, actionSpellID = 400126 },
        { class = "MONK", group = "movement", auraSpellID = { 443569 }, actionSpellID = 443569 },
        { class = "DEATHKNIGHT", group = "movement", auraSpellID = { 444347 }, actionSpellID = 444347 },
        { class = "MAGE", group = "movement", auraSpellID = { 444754 }, actionSpellID = 444754 },
        { class = "MONK", group = "movement", auraSpellID = { 449609 }, actionSpellID = 449609 },
        { class = "WARRIOR", group = "movement", auraSpellID = { 1244157 }, actionSpellID = 1244157 },

        -- ----- utility -----
        { class = "DEATHKNIGHT", group = "utility", auraSpellID = { 3714 }, actionSpellID = 3714 },
        { class = "DRUID", group = "utility", auraSpellID = { 29166 }, actionSpellID = 29166 },
        { class = "ROGUE", group = "utility", auraSpellID = { 115834 }, actionSpellID = 115834 },
        { class = "HUNTER", group = "utility", defaultOff = true, auraSpellID = { 357650 }, actionSpellID = 264667 },
        { class = "EVOKER", group = "utility", auraSpellID = { 406732, 406789 }, actionSpellID = 406732 },
        { class = "EVOKER", group = "utility", defaultOff = true, auraSpellID = { 408233 }, actionSpellID = 408233 },
        { class = "HUNTER", group = "utility", defaultOff = true, auraSpellID = { 466904 }, actionSpellID = 466904 },
        { class = "HUNTER", group = "utility", auraSpellID = { 54216, 62305, 1224810 }, actionSpellID = 1224810 },
}
