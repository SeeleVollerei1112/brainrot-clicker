# 开发计划：Brainrot Clicker 代码库组织重构

> 创建时间：2026-06-07 | 范围：系统级 | 粒度：模块拆解（分步重构）

## 系统概述

纯重构（**不改任何玩法行为**），统一全库"复合功能"的组织范式。每一步独立成一次 `git commit`，提交后用 `eggy-playtest` 跑测验证无报错、玩法照常，再进下一步；出问题可精确回滚到上一步。

**统一范式**：顶层功能 = 一个文件夹一个 `Controller`（门面 + 生命周期 + 自注册定时器 + 状态所有权）；其余皆角色文件（`Config / State / System / View / Persistence / Interaction`）；依赖永远 **Controller 往下注入**，子模块绝不反向 `require` Controller。

**不动清单（任何步骤都不得改动）**：
- 根目录 `EggyAPI.lua` / `EggyEditorAPI.lua` / `DebugTools.lua`
- `Data/` 下引擎自动导出物 `Prefab.lua` / `EquipmentPrefab.lua` / `ArchivesData.lua`
- `Data/` 下手写的 `UINodes.lua` / `ArchiveKeys.lua`（保持在 Data/ 不挪）

**通用验收**：每步完成后 `eggy-playtest` 跑测 → 无报错 + 对应玩法功能正常。

---

## 模块 1：删除死代码 dkjson

**功能**：移除全库无人 `require`、且在帧同步沙箱中 table-as-key 必崩的 `Util/dkjson.lua`（序列化已统一走 `Util/Json.lua`）。
**依赖**：无
**风险**：极低

**子任务**：
- [x] 再次确认全库无 `require("Util.dkjson")` / `require("dkjson")` 引用
- [x] 删除 `Util/dkjson.lua`
- [x] commit：`refactor: 删除未使用且不兼容沙箱的 dkjson`（884a955）

**验收**：WHEN 跑测启动，THEN 无 `dkjson` 相关报错，序列化（展台存档）正常。

---

## 模块 2：AppConfig 功能事件归位

**功能**：把功能专属自定义事件从 `AppConfig.APP.events` 收回各自功能，`AppConfig` 只留应用级内容（`TOUCH` 常量 + 画布名）。
**依赖**：无
**风险**：低（改事件常量引用点）

**子任务**：
- [x] `open_lottery / close_lottery` → `LotteryConfig.EVENTS` / `BUTTONS`
- [x] `open_mall / close_mall` → `MallConfig.EVENTS` / `BUTTONS`
- [x] `open_click_canvas / close_click_canvas` → `ClickerConfig.EVENTS` / `BUTTONS` / `BUTTON_TEXT`
- [x] 更新所有 `AppConfig.APP.events/buttons/text` 引用点指向新位置
- [x] `AppConfig` 仅保留 `TOUCH` 与 `APP.canvases`（buttons/text 也随功能迁移）
- [x] commit：`refactor: 自定义事件/按钮/文案归位到各功能 Config`（67a0efe）

**验收**：WHEN 依次开关 点击/抽奖/商城 画布，THEN 三者均正常打开与关闭，无缺失事件报错。

---

## 模块 3：定时器自注册 + ControllerRegistry 退化为列表

**功能**：消除 `ControllerRegistry` 中 `initialize_clicker / initialize_booth` 的手搓 `REPEAT_TIMEOUT + for_each` 特例 glue。让每个 Controller 通过统一入口 `initialize(application)`（`application` 带 `register_trigger` + `sessions`）自注册自己的定时器；间隔常量、tick 函数、定时器注册、会话遍历四样东西收归各 Controller 内部一处。
**依赖**：无（建议在 4、5 之前做，先把装配核心理顺）
**风险**：中（动装配核心）

**子任务**：
- [x] 统一 Controller 接口：`initialize(application)`；可选钩子 `setup_session / cleanup_session / shutdown`
- [x] `ClickerController.initialize` 内自注册 被动收益 tick + 连击衰减 tick（用 `application.sessions.for_each`）
- [x] `BoothController.initialize` 内自注册 收益结算 tick + 自动存档 tick
- [x] `ControllerRegistry` 改为 `controllers = { Clicker, Lottery, Mall, Inventory, Booth }` 列表 + 循环调用各生命周期钩子（钩子缺省时安全跳过；init/setup 正序，cleanup/shutdown 逆序）
- [x] 保留 `create_player_state`（委托给 Clicker 构建 `session.state`）
- [x] 删除 `initialize_clicker / initialize_booth` 特例函数
- [x] commit：`refactor: 各控制器自注册定时器，ControllerRegistry 退化为列表`

**验收**：
- WHEN 挂机一段时间，THEN 被动收益、连击衰减按原节奏发生
- WHEN 展台有放置物挂机，THEN 收益结算 + 自动存档照常
- WHEN 玩家进出，THEN 会话 setup/cleanup 正常

---

## 模块 4：Booth 去循环依赖（改注入）

**功能**：消除 `BoothController ↔ BoothPlacement` / `BoothController ↔ BoothZoneView` 的循环 `require`，与 Clicker 的"往下注入"范式对齐。
**依赖**：模块 3（统一 `initialize` 接口后再注入更顺）
**风险**：中

**子任务**：
- [x] 设计注入面：`BoothController` 暴露被子模块调用的状态访问/变更（`get_state / get_placement / place_item / remove_item`），加载期通过 `.bind` 注入 `BoothPlacement` / `BoothZoneView`
- [x] `BoothPlacement` / `BoothZoneView` 删除顶层 `require("Booth.BoothController")`，改用注入的 `controller`
- [x] 删除 `BoothController` 中 `submodules()` 延迟 require + 缓存特例
- [x] Booth 仍为 7 文件，结构不变
- [x] commit：`refactor: Booth 子模块改依赖注入，消除循环依赖`
- [x] **附带 bug 修复**：解锁展台区后展台无碰撞体积。运行时探针定位真因——展台是组件组(UnitGroup)，`set_physics_active(false)` 不可逆 + `set_model_visible(false)` 不屏蔽碰撞。改用「位置」可逆杠杆：锁定下沉移走静态组件组、解锁移回原位，物理不动。已跑测通过。commit：`fix: 修复解锁展台区后展台无碰撞体积`

**验收**：WHEN 放置 / 回收 / 解锁展区 / 触发离线收益，THEN 行为与重构前一致，无半初始化模块报错。

---

## 模块 5：Clicker 合并消肿（14 → 7 文件）

**功能**：按"点击展示 / 点击商店"的心智模型收敛过细的拆分。
**依赖**：模块 2（事件归位）、模块 3（统一接口）
**风险**：中（多文件合并 + require 路径变更）

**子任务**：
- [ ] 新建 `Clicker/ClickerState.lua`：合并 `PlayerState + CurrencySystem + ComboSystem + SkinSystem`（状态树 + 纯逻辑；`PlayerGameState` 等 luadoc 类名**保持不变**以免改散落注解）
- [ ] 新建 `Clicker/ClickerView.lua`：合并 `CharacterView + FloatTextView + HeadsUpDisplay + ComboBar`（"点击展示"）
- [ ] `ComboConfig` 并入 `ClickerConfig.COMBO`；删除顶层 `Combo/` 文件夹
- [ ] `UpgradeShop/` 下沉为 `Clicker/UpgradeShop/`（`UpgradeShopConfig / UpgradeShopSystem / UpgradeShopView`，`UpgradeShopPanel → UpgradeShopView`）；删除顶层 `UpgradeShop/`
- [ ] 改写 `ClickerController`：改用合并后模块，简化 wiring（初始化 5 个 view → 1 个）
- [ ] 更新所有相关 `require` 路径
- [ ] 删除被合并的旧文件
- [ ] commit：`refactor: Clicker 模块合并消肿，Combo/UpgradeShop 下沉`

**风险点**：`ClickerView` 约 700 行；跑测后若过胖，二次切分为 `CharacterView` 单独留 + 小 `ClickerHudView`（HUD + 连击条）。决策记录于本步。

**验收**：
- WHEN 点击角色，THEN 飘字 / HUD 数值 / 连击条 / 皮肤切换 全部正常
- WHEN 打开商店并购买升级，THEN 扣费、数值刷新、商店刷新正常
- WHEN 挂机，THEN 被动收益与皮肤刷新正常

---

## 模块 6：命名收尾 + 全库一致性核查

**功能**：统一剩余命名，核查 require 路径一致。
**依赖**：模块 1~5
**风险**：低

**子任务**：
- [ ] 核查命名符合范式：顶层功能 `<Feature>Controller / <Feature>Config`，其余 `<概念><角色>`
- [ ] 全库 grep 核查无失效 `require` 路径、无悬挂引用
- [ ] 更新 / 校对入口与 README 级注释（如有）
- [ ] commit：`refactor: 命名与 require 路径一致性收尾`

**验收**：WHEN 完整跑测一轮（点击 / 商店 / 抽奖 / 商城 / 背包 / 展台 / 离线收益），THEN 全功能正常、零报错。

---

## 📊 模块依赖图与进度

```
模块1(删dkjson) ─┐
模块2(事件归位) ─┤
模块3(定时器自注册) ──→ 模块4(Booth去环)
                  └──→ 模块5(Clicker合并) ──→ 模块6(命名收尾)
```

| 模块 | 名称 | 状态 | 依赖 |
|------|------|------|------|
| 1 | 删除 dkjson | ✅ 已完成 (884a955) | 无 |
| 2 | AppConfig 事件归位 | ✅ 已完成 (67a0efe) | 无 |
| 3 | 定时器自注册 + Registry 退化 | ✅ 已完成 | 无 |
| 4 | Booth 去循环依赖 + 物理 bug | ✅ 已完成（去环 + 碰撞修复均跑测通过） | 模块 3 |
| 5 | Clicker 合并消肿 | ⬜ 未开始 | 模块 2、3 |
| 6 | 命名收尾 + 一致性核查 | ⬜ 未开始 | 模块 1~5 |
