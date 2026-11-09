# Easy Button Aura by Unit

## English

> Bind aura IDs to action bar buttons to track their remaining time and stacks.

- Built-in presets with per-entry toggles: about 120 entries plus the class-agnostic Renewal on Retail, and a 17-entry set on WoW Forever (paladin seals and blessings, priest self-buffs, Shadow Word: Pain and Touch of Weakness, plus orc / human / undead racials) collected from the author's own saved bindings. The two clients never share aura IDs — each gets its own table; Forever entries match by spell name, so they keep working as you learn higher ranks.
- No unit dropdown: every binding automatically covers both channels — your own buffs and your debuffs on a hostile target — whichever matches, shows. Buffs you cast on your pet (e.g. Mend Pet) are covered by the pet preset and auto-learn instead of manual bindings.
- Bindings match by spell name: on clients where every rank of a spell has its own spell and aura ID (e.g. WoW Forever), bind once and it keeps working as you level up and learn higher ranks — no need to bind the same spell again.
- Auto-learn: while out of combat, your own timed buffs (on you and on your pet) and your debuffs on a hostile target matching action bar spells are bound automatically (per specialization).
- One aura ID is never tracked on both you and your pet at the same time — learn dedups by aura ID and presets declare their unit explicitly — so an aura that sits on both units (e.g. Primal Rage) shows only once.
- Duration-less auras (forms / instant toggles, e.g. Nature's Swiftness, Ancestral Swiftness, Ghost Wolf) show a translucent green mask instead of a countdown.
- Bindings are saved per specialization; a character-level master switch toggles everything.
- Multiple auras bound to the same button share one display; any match shows.
- Some spells (e.g. Barbed Shot) produce both a buff on you and a debuff on your target at the same time, so they show up as two separate entries on the same button — this is expected. Uncheck the entry you don't want to track in the configuration window.
- Weapon enchants (Flametongue, Windfury, Rites, etc.) are built in and need no setup.
- Soft edge glow and countdown color distinguish self-buffs (green) from enemy debuffs (red).
- Configuration window opens with `/babu`; shared minimap button for all Easy add-ons.

## 简体中文

> 把光环 ID 绑定到动作条按钮，追踪其剩余时间与层数。

- 内置预设可逐条启停：正式服约 120 条 + 全职业通用的复原；《魔兽世界：永恒》另有一套 17 条（圣骑士圣印与祝福、牧师自身增益、暗言术：痛与虚弱之触、兽人/人类/亡灵种族技能），由作者自己的存档配对整理而来。两套客户端的法术/光环 ID 互不通用，各用各的表；永恒的条目按技能名匹配，升等级学新 Rank 后依然生效。其余光环全手动绑定，完全自主可控。
- 不选追踪单位：每条绑定自动同时挂「自身增益」与「施放到敌对目标的减益」两路，哪路命中显示哪路。你施放到宠物身上的增益（如治疗宠物）由宠物预设与自动学习覆盖，不走手动绑定。
- 绑定按技能名匹配：在同一技能的每个等级都各自拥有独立法术 / 光环 ID 的客户端（如《魔兽世界：永恒》）里，绑定一次即可随等级提升自动跟随新等级，不必每升一级重绑一遍。
- 自动学习：脱战时扫描自身与宠物身上由你施放的限时增益、以及敌对目标身上的我方减益，匹配动作条上的技能自动绑定（按专精保存）。
- 同一个光环 ID 不会同时挂在「你」和「宠物」两路上——学习表按光环 ID 全局去重、预设逐条显式声明单位——因此玩家与宠物身上各有一份的光环（如原始暴怒）只会显示一次。
- 无持续时间的光环（形态/瞬发开关，如自然迅捷、先祖迅捷、幽魂之狼）不显示倒计时，仅以绿色半透明遮罩标记。
- 绑定按专精分别保存；全局开关为角色级，一键控制全部显示。
- 多条光环绑定同一按钮时自动合并显示，任一命中即显示。
- 某些技能（如倒刺射击）会同时产生「自身增益」与「敌对目标减益」两个条目，同一技能出现两个条目属正常现象；不需要监控的条目可在配置窗口中取消勾选。
- 武器附魔（火舌/风怒/裁决仪式等）内置预设，无需配置。
- 柔光标记与倒计时配色区分：自身增益为绿色，敌对减益为纯红。
- 输入 `/babu` 打开配置窗口；Easy 系列插件共享一个小地图按钮。

## 繁體中文

> 把光環 ID 綁定到快捷列按鈕，追蹤其剩餘時間與堆疊數量。

- 內建預設可逐條啟停：正式服約 120 條 + 全職業通用的復原；《魔獸世界：永恆》另有一套 17 條（聖騎士聖印與祝福、牧師自身增益、暗言術：痛與虛弱之觸、獸人／人類／不死族種族技能），由作者自己的存檔配對整理而來。兩套用戶端的法術／光環 ID 互不通用，各用各的表；永恆的條目按技能名稱比對，升等級學新 Rank 後依然生效。其餘光環全手動綁定，完全自主可控。
- 不選追蹤單位：每條綁定自動同時掛「自身增益」與「施放到敵對目標的減益」兩路，哪路命中顯示哪路。你施放到寵物身上的增益（如治療寵物）由寵物預設與自動學習覆蓋，不走手動綁定。
- 綁定按技能名稱比對：在同一技能每個等級都各自擁有獨立法術／光環 ID 的用戶端（如《魔獸世界：永恆》）裡，綁定一次即可隨等級提升自動跟隨新等級，不必每升一級重綁一遍。
- 自動學習：脫戰時掃描自身與寵物身上由你施放的限時增益、以及敵對目標身上的我方減益，符合快捷列上技能的自動綁定（按專精保存）。
- 同一個光環 ID 不會同時掛在「你」和「寵物」兩路上——學習表按光環 ID 全域去重、預設逐條顯式宣告單位——因此玩家與寵物身上各有一份的光環（如原始暴怒）只會顯示一次。
- 無持續時間的光環（形態／瞬發開關，如自然迅捷、先祖迅捷、幽魂之狼）不顯示倒計時，僅以綠色半透明遮罩標記。
- 綁定按專精分別保存；全域開關為角色級，一鍵控制全部顯示。
- 多條光環綁定同一按鈕時自動合併顯示，任一命中即顯示。
- 某些技能（如倒刺射擊）會同時產生「自身增益」與「敵對目標減益」兩個條目，同一技能出現兩個條目屬正常現象；不需要監控的條目可在設定視窗中取消勾選。
- 武器附魔（火舌／風怒／裁決儀式等）內建預設，無需設定。
- 柔光標記與倒計時配色區分：自身增益為綠色，敵對減益為純紅。
- 輸入 `/babu` 開啟設定視窗；Easy 系列插件共用一個小地圖按鈕。

## Related / 相关插件 / 相關插件

[Easy Button Simplify](https://www.curseforge.com/wow/addons/easybuttonsimplify) pairs well with this add-on: it hides the native button borders, enlarges icons with a clean 1px outline and styles button text — a neater canvas for the aura display.
[Easy Button Simplify](https://www.curseforge.com/wow/addons/easybuttonsimplify) 与本插件是绝配：隐藏原生按钮边框、图标放大并加 1px 黑描边、统一按钮文字样式——给光环显示一个更干净的按钮底面。
[Easy Button Simplify](https://www.curseforge.com/wow/addons/easybuttonsimplify) 與本插件是絕配：隱藏原生按鈕邊框、圖示放大並加 1px 黑描邊、統一按鈕文字樣式——給光環顯示一個更乾淨的按鈕底面。

## Credits / 致谢 / 致謝

- Thanks to all addon developers. / 感谢所有插件开发者。/ 感謝所有插件開發者。
