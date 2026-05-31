## CLI 配置

`editor-cli.exe` 默认位于 `.codemaker` 根目录下，直接使用即可：

```powershell
$CLI = '.codemaker\editor-cli.exe'
```

> 若 `.codemaker\editor-cli.exe` 不存在，提示用户提供 `editor-cli.exe` 的完整路径。

## 核心原则

1. **状态先行**：执行操作前检查 `editor-cli status`
2. **idle 状态**：场景搭建、EUI 编辑、启动试玩
3. **playing 状态**：game_execute、玩家操控、读日志
4. **exec 无返回值**：用 `EditorAPI.log()` 写日志，再读 `log.txt`

## 编码规范

### 方法调用用 `.` 而非 `:`
```lua
role.get_ctrl_unit()  -- 正确
role:get_ctrl_unit()  -- 错误
```

### Vector3 分量直接访问
```lua
local pos = unit.get_position()
local x = pos.x  -- 正确
```

### 延迟调用
```lua
LuaAPI.call_delay_time(1.0, function() end)  -- 正确
```

### Fixed 类型传浮点数
```lua
role.set_camera_property(Enums.CameraPropertyType.DIST, 30.0)  -- 正确
```

### Quaternion 用弧度
```lua
local PI = 3.14159265
local rot = math.Quaternion(0, PI, 0)  -- 180度
```

### game_execute 引号规则
```powershell
# 正确：外层双引号，Lua内全单引号
exec "EditorAPI.game_execute('local x = ''hello''; print(''MCP|'' .. x)')"
```

## 组件类型

| 类型 | 创建 API | 说明 |
|------|---------|------|
| Obstacle | `GameAPI.create_obstacle(key, pos, rot, scale)` | 场景装饰 |
| Equipment | `GameAPI.create_equipment(key, pos)` | 可拾取物品 |
| Creature | `GameAPI.create_creature_fixed_scale(key, pos, rot, scale)` | 生物单位 |

## 常用 API

```lua
-- 玩家与单位
GameAPI.get_all_valid_roles()
role.get_ctrl_unit()
unit.get_position()
unit.set_position(pos)

-- 创建与销毁
GameAPI.create_obstacle(key, pos, rot, scale)
GameAPI.destroy_unit(unit)

-- 事件
LuaAPI.global_register_trigger_event({EVENT.REPEAT_TIMEOUT, 0.1}, callback)
LuaAPI.unit_register_trigger_event(unit, {EVENT.SPEC_OBSTACLE_CONTACT_BEGIN}, callback)

-- UI
LuaAPI.global_register_trigger_event({EVENT.UI_CUSTOM_EVENT, "EVENT_NAME"}, callback)
role.send_ui_custom_event("EVENT_NAME", {})
```

## 文档查询

| 用途 | docset_code |
|------|-------------|
| 工坊手册 | docset_1755051906953 |
| 组件信息 | docset_1765444462000 |
| API 文档 | docset_1770738267956 |

## 技能索引

| 需求 | 使用技能 |
|------|---------|
| 试玩控制、场景搭建、EUI 编辑、执行编辑器命令 | `eggy-editor-ops` |
| 编写 Lua 玩法逻辑、查 API、开发自定义地图 | `eggy-party-dev` |
| 自动跑测（循环修复） | `eggy-auto-test` |
| 报错排查 | `editor-log-triage` |
| 游戏创意设计、玩法拆解、生成系统设计文档 | `eggy-game-design` |
| 制定开发计划、生成 TODO / Plan 文件、跟踪进度 | `eggy-dev-planner` |
