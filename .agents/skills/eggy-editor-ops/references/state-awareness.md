# 编辑器状态感知指南

## 状态枚举

通过 `editor-cli status` 返回的 `editor_status` 字段判断当前阶段：

| 状态 | 含义 | 阶段 |
|------|------|------|
| `idle` | 编辑器空闲，地图未运行 | **编辑时** |
| `entering` | 试玩启动指令已发，正在初始化 | 过渡态 |
| `map-loading` | 游戏已启动，地图正在加载 | 过渡态 |
| `playing` | 地图加载完成，游戏运行中 | **调试时** |
| `exiting` | 退出试玩指令已发，正在清理 | 过渡态 |
| `unknown` | 接口不可用或返回无法识别的值 | 异常 |

## 查询命令

```bash
.codemaker\editor-cli.exe --port 19836 status
```

## 状态轮询逻辑

等待游戏进入 `playing` 状态（启动试玩后使用）：

```
maxWait = 60秒
interval = 3秒
elapsed = 0

loop:
    result = editor-cli status
    status = result.editor_status

    if status == "playing":
        → 就绪，继续执行
    if status == "unknown":
        → 报错：「编辑器状态异常，请检查连接」，退出
    if elapsed >= maxWait:
        → 报错：「等待游戏就绪超时（60s）」，退出
    
    sleep(interval)
    elapsed += interval
```

等待回到 `idle` 状态（停止试玩后使用）：

```
同上逻辑，目标状态改为 "idle"
超时后报：「等待编辑器退出试玩超时」
```

## 各状态可用操作矩阵

| 操作类型 | idle | entering | map-loading | playing | exiting |
|---------|:----:|:--------:|:-----------:|:-------:|:-------:|
| 启动试玩 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 停止试玩 | ❌ | ❌ | ❌ | ✅ | ❌ |
| 场景单位管理 | ✅ | ❌ | ❌ | ❌ | ❌ |
| EUI 节点编辑（写） | ✅ | ❌ | ❌ | ❌ | ❌ |
| EUI 节点查询（读） | ✅ | ✅ | ✅ | ✅ | ✅ |
| game_execute | ❌ | ❌ | ❌ | ✅ | ❌ |
| 玩家操控 | ❌ | ❌ | ❌ | ✅ | ❌ |
| 读取日志 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 截图（需前置检查） | ✅ | ❌ | ❌ | ✅ | ❌ |
| 环境设置（相机/天空盒）| ✅ | ❌ | ❌ | ❌ | ❌ |

> 过渡态（entering/map-loading/exiting）下除读操作外，所有写操作均应等待状态转换后再执行。

## 运行时快照（详细信息）

需要编辑器更详细的运行状态时，使用：

```bash
.codemaker\editor-cli.exe --port 19836 exec "EditorAPIRuntimeStates.get_runtime_states_snapshot()"
```

返回包含地图信息、模块状态等完整快照的 Dict。

判断是否处于 UI 编辑模式：

```bash
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.is_in_eui_edit_mode()"
```

## 使用示例

**场景：启动试玩并等待就绪**

```bash
# 1. 确认当前是 idle
.codemaker\editor-cli.exe --port 19836 status

# 2. 启动试玩
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.run_game()"

# 3. 轮询等待 playing（每3秒查一次，最多60秒）
.codemaker\editor-cli.exe --port 19836 status
# ... 重复直到 editor_status == "playing"

# 4. 执行游戏内操作
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.game_execute('...')"
```
