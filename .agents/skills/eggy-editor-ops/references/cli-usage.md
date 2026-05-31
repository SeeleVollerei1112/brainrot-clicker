# editor-cli.exe 命令行使用手册

## 概述

`editor-cli.exe` 是蛋仔编辑器的命令行代理工具，通过 WebSocket 与编辑器通信，可以执行 EditorAPI 命令和检查编辑器状态。

- **位置**: `.codemaker\editor-cli.exe`（默认位于 `.codemaker` 根目录，无需额外配置）
- **固定端口**: `19836`

## 命令一览

| 命令 | 说明 |
|------|------|
| `status` | 查看编辑器连接状态 |
| `exec <lua代码>` | 执行 Lua 代码 |

## 全局选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--port PORT` | WebSocket 端口 | **固定用 19836** |
| `--timeout TIMEOUT` | 请求超时（秒） | 默认值 |

## 使用示例

### 检查编辑器状态

```bash
.codemaker\editor-cli.exe --port 19836 status
```

### 试玩控制

```bash
# 开始试玩
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.run_game()"

# 停止试玩
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.stop_game()"
```

### 执行游戏指令

```bash
# 在试玩中执行 Lua 代码（字符串参数用单引号）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.game_execute('print(1)')"
```

### 日志读取

游戏日志通过直接读取项目根目录的 `log.txt` 文件获取，不通过 CLI 命令。

## ⚠️ exec 无法获取返回值 — 必须用日志读取

**`editor-cli.exe exec` 命令不会在终端输出任何 Lua 返回值**，即使代码里写了 `return` 或 `print()`，终端也只会显示 `Executed successfully.`，不会显示实际内容。

### 正确做法：把结果写入日志，然后读 log.txt

所有需要读取的数据（节点 ID、单位属性、查询结果等）必须用以下方式输出：

| 场景 | 写日志方式 |
|------|-----------|
| **编辑器侧（idle）** | `EditorAPI.log("内容")` — 写入编辑器日志，**会追加到项目根目录 `log.txt`** |
| **游戏运行时（playing）** | `print("内容")` 或 `EditorAPI.log("内容")` — 同样写入 `log.txt` |

### 标准查询流程（以查询 EUI 节点 ID 为例）

```bash
# 第一步：执行查询，把结果写进日志
.codemaker\editor-cli.exe --port 19836 exec "local ids = EditorAPI.get_all_eui_node_ids(); for i=1,#ids do EditorAPI.log(tostring(i) .. ': id=' .. tostring(ids[i]) .. ' type=' .. tostring(EditorAPI.get_eui_node_type(ids[i]))) end"

# 第二步：读取 log.txt 获取结果（PowerShell，读最后若干行）
powershell -Command "Get-Content 'log.txt' -Tail 30"
```

### 读取日志的方式

```powershell
# 读取最后 N 行（适合查询结果不多时）
powershell -Command "Get-Content 'log.txt' -Tail 30"

# 增量读取（适合多次操作后只看本次新增，避免日志太长）
$offset = (Get-Item 'log.txt').Length
# ... 执行 exec 命令 ...
$bytes = [System.IO.File]::ReadAllBytes('log.txt')
if ($bytes.Length -gt $offset) {
    [System.Text.Encoding]::UTF8.GetString($bytes[$offset..($bytes.Length-1)])
} else { "(no new output)" }
```

> ❌ **绝对不要用 `return` 期望终端输出**：`exec "return EditorAPI.get_all_eui_node_ids()"` 终端只会打印 `Executed successfully.`，返回值完全丢失。
> ✅ **永远用 `EditorAPI.log(...)` 把需要的值写入日志，再从 `log.txt` 读取。**

---

## 参数传递规则

### 字符串参数
外层用双引号包裹整个 Lua 表达式，内层字符串用单引号：
```bash
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.game_execute('print(1)')"
```

## 错误排查

1. **连接失败**: 确认编辑器已启动，端口 19836 可用
2. **命令超时**: 使用 `--timeout` 增加超时时间
3. **game_execute 无效**: 确认已先执行 `run_game()` 进入试玩状态
4. **查看报错日志**: 直接读取项目根目录 `log.txt` 文件