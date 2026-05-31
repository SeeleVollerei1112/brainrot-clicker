---
name: eggy-editor-ops
description: 蛋仔派对编辑器操作技能。通过 editor-cli.exe 操控编辑器，执行 EditorAPI 命令。使用场景：试玩/停止试玩、执行游戏指令、检查编辑器状态、场景搭建。
disable-model-invocation: true
allowed-tools: Bash Read
---

# 编辑器操作指南

## CLI 配置

`editor-cli.exe` 默认位于 `.codemaker` 根目录：

```powershell
$CLI = '.codemaker\editor-cli.exe'
```

> 若 `.codemaker\editor-cli.exe` 不存在，提示用户提供 `editor-cli.exe` 的绝对路径。

## 状态检查

| 状态 | 含义 | 可用操作 |
|------|------|---------|
| `idle` | 编辑时 | 场景搭建、EUI 编辑、启动试玩 |
| `entering` | 启动中 | 等待 |
| `map-loading` | 加载中 | 等待 |
| `playing` | 调试时 | game_execute、玩家操控 |
| `exiting` | 退出中 | 等待 |

## 命令格式

```cmd
# 检查状态
%CLI% --port 19836 status

# 执行 EditorAPI
%CLI% --port 19836 exec "EditorAPI.run_game()"

# 执行游戏指令
%CLI% --port 19836 exec "EditorAPI.game_execute('Lua代码')"
```

## 核心操作

| 操作 | 命令 |
|------|------|
| 开始试玩 | `EditorAPI.run_game()` |
| 停止试玩 | `EditorAPI.stop_game()` |
| 创建组件 | `EditorAPI.create_obstacle(key, pos)` |
| 删除组件 | `EditorAPI.destroy_obstacle(uid)` |
| 查询单位 | `EditorAPI.query_scene_units(pattern, false)` |
| 获取属性 | `EditorAPI.get_unit_attr(uid, attr)` |
| 设置属性 | `EditorAPI.set_unit_attr(uid, attr, value)` |
| EUI 查询 | `EditorAPI.get_all_eui_node_ids()` |
| EUI 创建 | `EditorAPI.create_eui_label_node(parent, x, y, w, h, name, text)` |
| 截图 | `EditorAPI.take_screenshot()` |
| 日志输出 | `EditorAPI.log(content)` |

## 引号规则

```powershell
# 直接 exec：外层双引号，Lua 内单引号
exec "local d = EditorAPI.get_scene_unit_data(123); print(d.position)"

# game_execute：外层双引号，中层单引号，Lua 字符串用 [[ ]]
exec "EditorAPI.game_execute('local u = LuaAPI.query_unit([[名称]]); print(u.get_position())')"
```

## 日志读取

```powershell
# 增量读取（推荐）
$offset = (Get-Item "log.txt").Length
# ... 执行 game_execute ...
$bytes = [System.IO.File]::ReadAllBytes("log.txt")
$newContent = [System.Text.Encoding]::UTF8.GetString($bytes[$offset..($bytes.Length-1)])
```

## 注意事项

1. `game_execute` 内用 `print()`，直接 exec 用 `EditorAPI.log()`
2. `idle` 状态用 `EditorAPI.query_scene_units`，`playing` 状态用 `LuaAPI.query_unit`
3. 批量创建每批 ≤ 10 个，批次间延迟 200ms
