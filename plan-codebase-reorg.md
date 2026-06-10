# 开发计划：Brainrot Clicker 代码库组织重构（第二轮）

> 重写时间：2026-06-09 | 范围：系统级 | 粒度：分步重构（每步独立 commit）

## 系统概述

第二轮聚焦两件事:**删冗余防御代码** 与 **统一玩家状态所有权**。仍是纯重构(**不改任何玩法行为**),每一步独立成一次 `git commit`,提交后用 `eggy-playtest` 跑测验证无报错、玩法照常,再进下一步;出问题可精确回滚。

推进顺序:**先工作流 B(机械清理,不改行为)→ 后工作流 A(架构性,状态迁移)**。先把代码面缩小,改架构时面对更干净的代码。

**核心原则**:防御代码只保留在**信任边界**(引擎 API 返回值、反序列化、存档读写、玩家事件载荷);删除**内部不变量**判空(架构已保证的 session/role/state 非空、调用方已判过的二次判空)。

**不动清单(任何步骤都不得改动)**:
- 根目录 `EggyAPI.lua` / `EggyEditorAPI.lua` / `DebugTools.lua`
- `Data/` 引擎自动导出物 `Prefab.lua` / `EquipmentPrefab.lua` / `ArchivesData.lua`(`ArchivesData` 在 A4 中成为存档槽位的**唯一真相**)
- `Data/UINodes.lua`
- `BoothController` 对 DebugTools 暴露的 **role 维度公共方法签名**(`get_state(role)` / `place_item(role,...)` 等)保持不变,仅改内部实现走 session

**通用验收**:每步完成后 `eggy-playtest` 跑测 → 无报错 + 对应玩法功能正常。

---

# 工作流 B —— 浅包装 / 过度判空清理（先做）

**背景**:`is_node(node)` 在 6 个 View 里各抄了一份,实现是 `node ~= nil and node ~= false and node ~= 0 and node ~= ""`——但 `GameAPI.get_eui_child_by_name` 找不到节点返回 `nil`,不会是 `0`/`""`(且二者在 Lua 中为真值),所以那两个判断是死分支。`is_node(x)` 可无损降级为惯用 `if x then`。另有 `get_scene_ui_node` / `head_layer_key` / `child` / `get_canvas` 等薄包装可内联。

**每文件一 commit**,清理范围 = 该文件的 `is_node` 去除 + 薄包装内联 + 冗余字段判空裁剪(保证存在的节点就地写、删判空;可选节点保留)。改完跑测对应功能。

## 模块 B1：Clicker/ClickerView 清理 ✅
**风险**:低
- [x] 删 `is_node` 定义,调用降级为 `if x then`
- [x] 裁剪保证存在节点的冗余判空
- [x] commit：`refactor(B1): ClickerView 去 is_node/冗余判空`（558b2b2）
**验收**:WHEN 点击角色,THEN 飘字 / HUD / 连击条 / 皮肤切换正常。

## 模块 B2：Clicker/UpgradeShop/UpgradeShopView 清理 ✅
**风险**:低(本文件 is_node 调用最密集,~45 处)
- [x] 删 `is_node` 定义,调用降级
- [x] 卡片字段判空属场景导出缺失的合法边界守卫,保留(仅去 is_node)
- [x] commit：`refactor(B2): UpgradeShopView 去 is_node`（2645963）
**验收**:WHEN 打开商店、购买升级,THEN 卡片渲染、扣费、刷新、锁定态显示正常。

## 模块 B3：Mall/MallView 清理（含薄包装内联）✅
**风险**:低
- [x] 删 `is_node` 定义,调用降级
- [x] `child` 用 ~10 处且带 nil-parent 守卫,去 is_node 后收敛为一行(不内联)
- [x] `MallView.get_canvas()` 无调用方,删除(死代码)
- [x] commit：`refactor(B3): MallView 去 is_node、简化 child、删死代码 get_canvas`（f815abc）
**验收**:WHEN 开关商城、切标签、点购买,THEN 渲染与交互正常。

## 模块 B4：Inventory/InventoryView 清理 ✅
**风险**:低
- [x] 删 `is_node` 定义,调用降级
- [x] commit：`refactor(B4): InventoryView 去 is_node/冗余判空`（3bfb054）
**验收**:WHEN 切换 装备栏/储物栏 标签,THEN 选中态、文字变色正常。

## 模块 B5：Booth/BoothInteraction 清理 ✅
**风险**:低
- [x] 删 `is_node` 定义,调用降级(place/recycle/synthesis 三按钮)
- [x] commit：`refactor(B5): BoothInteraction 去 is_node`（63fafac）
**验收**:WHEN 站上展台位,THEN 放置/回收/合成按钮显隐与点击正常。

## 模块 B6：Booth/BoothZoneView 清理（含薄包装内联）✅
**风险**:低
- [x] 删 `is_node` 定义,调用降级
- [x] `head_layer_key()` 仅一处调用,内联
- [x] `get_scene_ui_node` 用 4 处且带 UINodes 查找逻辑,保留并简化(不内联)
- [x] commit：`refactor(B6): BoothZoneView 去 is_node、内联 head_layer_key`（5258748）
**验收**:WHEN 解锁展区、有放置物挂机,THEN 头顶 3D 文字(等级/收益/累计)与公告板刷新正常。

---

# 工作流 A —— session 状态所有权统一（后做）

**目标**:把"每个玩家的状态"统一收归 `session`。新增 `SessionStateRegistry` 集中声明各功能的状态**工厂 / 恢复器 / 保存器**(钩子可选子集),session 通过 `get_or_create_state(key)` 惰性取片。消除 Clicker 的特判、Booth 的 `state_by_role_id` 自维护、重复的 `get_role_id`。

**三家差异**(设计前提):
- **Clicker**:纯内存态,有 `create`(`ClickerState.new()` + `UpgradeShopSystem.initialize`),当前不持久化。
- **Booth**:纯内存态,`create = BoothPersistence.load(role)`,`save = BoothPersistence.save`。
- **Inventory**:**无内存态**(状态在角色装备槽,引擎侧),只有 `restore` / `save`,无 `create`。

**声明形态(已与用户确认)**:
```lua
SessionStateRegistry.declare("clicker", {
    create = function() local s = ClickerState.new(); UpgradeShopSystem.initialize(s); return s end,
})
SessionStateRegistry.declare("booth", {
    create = function(sess) return BoothPersistence.load(sess.role) end,
    save   = function(sess) BoothPersistence.save(sess.role, sess:get_or_create_state("booth")) end,
})
SessionStateRegistry.declare("inventory", {            -- 无 create
    restore = function(sess) ItemSynthesisSystem.restore_role_inventory(sess.role) end,
    save    = function(sess) ItemSynthesisSystem.save_role_inventory(sess.role) end,
})
```
访问签名**只传 key**:`session:get_or_create_state("booth")`,工厂集中声明一次,不传模块。

> ⚠️ 隐藏耦合:Booth 与 Inventory **共用存档槽位 1001**,各自 read-merge-write 保留对方字段(`preserve_inventory_blob` / `load_archive_root`)。`save_all` 串行调两家不破坏合并语义,但实现时须确认。

## 模块 A1：SessionStateRegistry + session 对象化
**依赖**:无(B 完成后) **风险**:中(动装配核心)
- [ ] 新建 `App/SessionStateRegistry.lua`:`declare(key, spec)` / `create(key, sess)` / `restore_all(sess)` / `save_all(sess)`
- [ ] `GameApp` 的 session 改为带 `states = {}` 的对象 + 方法 `get_or_create_state(key)`
- [ ] `ControllerRegistry.create_player_state` 的 Clicker 特判改为走注册表声明(或移除,改由惰性 create)
- [ ] commit：`refactor(A1): 引入 SessionStateRegistry，session 对象化`
**验收**:WHEN 玩家进场,THEN 各功能状态按需创建,玩法与重构前一致。

## 模块 A2：三家状态迁移到 session
**依赖**:A1 **风险**:中
- [ ] `SessionStateRegistry.declare` 三家(clicker / booth / inventory)
- [ ] 各 `Controller.setup_session/cleanup_session` 改用 `session:get_or_create_state(...)` 与 `SessionStateRegistry.save_all/restore_all`
- [ ] 删 `BoothController.state_by_role_id` + 本文件内重复的 `get_role_id`;Booth 收益/自动存档定时器与 DebugTools 入口改走 session(给 Booth 注入 `find_session`,公共方法签名不变)
- [ ] 确认 Booth/Inventory 共用槽位的 read-merge-write 在新 save 路径下不破
- [ ] commit：`refactor(A2): Clicker/Booth/Inventory 状态收归 session`
**验收**:WHEN 进出场、放置/回收/解锁、离线收益、背包存取,THEN 全部与重构前一致。

## 模块 A3：删死包装 + 架构性判空
**依赖**:A2(状态非空由架构保证后才能删守卫) **风险**:低
- [ ] 删 8 个无调用点的 `*Controller.initialize_role` / `cleanup_role`(Clicker/Lottery/Mall/Inventory/Booth)
- [ ] 删各 `setup/cleanup_session` 里 `local role = session and session.role` / `if not role then return` 这类架构已保证的判空
- [ ] 删 `ClickerController.handle_*` 内层 `if not session then return`(调用处已 `if session then`,双重判空)
- [ ] commit：`refactor(A3): 删除死包装与内部不变量判空`
**验收**:WHEN 完整玩法跑测一轮,THEN 零报错、行为不变。

## 模块 A4：删 ArchiveKeys，槽位源自 ArchivesData
**依赖**:无(可与 A 其余并行) **风险**:低
- [ ] 删 `Data/ArchiveKeys.lua`
- [ ] `BoothPersistence` / `ItemSynthesisSystem` 顶部改 `local BOOTH = require("Data.ArchivesData")["展台状态"]`,引用 `BOOTH.id` / `BOOTH.vType`
- [ ] 更新"不动清单":`ArchivesData` 成为存档槽位唯一真相
- [ ] commit：`refactor(A4): 删 ArchiveKeys，存档槽位源自自动导出的 ArchivesData`
**验收**:WHEN 存/读档(展台 + 背包),THEN 数据正确、无槽位报错。

---

## 📊 模块依赖图与进度

```
工作流 B（先，机械清理，各文件独立）
  B1 ClickerView ─ B2 UpgradeShopView ─ B3 MallView ─ B4 InventoryView ─ B5 BoothInteraction ─ B6 BoothZoneView
        └────────────────────────────────────────────────────────────┐
工作流 A（后，架构性）                                                  ▼
  A1 SessionStateRegistry ──→ A2 三家迁移 ──→ A3 删死包装/判空
  A4 删 ArchiveKeys（可并行）
```

| 模块 | 名称 | 状态 | 依赖 |
|------|------|------|------|
| B1 | ClickerView 清理 | ✅ 已完成 (558b2b2) | 无 |
| B2 | UpgradeShopView 清理 | ✅ 已完成 (2645963) | 无 |
| B3 | MallView 清理 + 内联 | ✅ 已完成 (f815abc) | 无 |
| B4 | InventoryView 清理 | ✅ 已完成 (3bfb054) | 无 |
| B5 | BoothInteraction 清理 | ✅ 已完成 (63fafac) | 无 |
| B6 | BoothZoneView 清理 + 内联 | ✅ 已完成 (5258748) | 无 |
| A1 | SessionStateRegistry + 对象化 | ⬜ 未开始 | B |
| A2 | 三家状态迁移 | ⬜ 未开始 | A1 |
| A3 | 删死包装/判空 | ⬜ 未开始 | A2 |
| A4 | 删 ArchiveKeys | ⬜ 未开始 | 无(可并行) |

---

## 第一轮（已完成，归档）

模块 1 删 dkjson(884a955)· 模块 2 AppConfig 事件归位(67a0efe)· 模块 3 定时器自注册 + Registry 退化 · 模块 4 Booth 去循环依赖 + 碰撞 bug 修复 · 模块 5 Clicker 合并消肿(14→7)· 模块 6 命名收尾。全部跑测通过。
