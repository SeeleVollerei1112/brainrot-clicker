---
name: eggy-party-dev
description: 蛋仔派对玩法编辑器 Lua 开发技能。提供 API 探索、代码模式参考。使用场景：开发自定义玩法/地图、了解 EggyAPI、编写游戏逻辑。
when_to_use: 用户开发 Lua 玩法逻辑、查询 EggyAPI、编写自定义地图游戏代码时
---

# 玩法开发指南

## API 探索

1. grep 搜索 `EggyAPI.lua` 查找相关 API
2. 阅读 LuaDoc 注解理解参数和返回值
3. 参考 demos 中的实际使用样例

## 核心代码模式

### 游戏初始化
```lua
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        local character = role.get_ctrl_unit()
    end
end)
```

### 事件注册
```lua
-- 全局定时器
LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1.0 }, callback)

-- 单位事件
LuaAPI.unit_register_trigger_event(unit, { EVENT.ON_DEAD }, callback)
```

### 创建单位
```lua
local equipment = GameAPI.create_equipment(prefabID, position)
local creature = GameAPI.create_creature(creatureKey, position, rotation)
```

### UI 操作
```lua
role.set_label_text(nodeId, "文本")
role.set_node_visible(nodeId, true)
role.send_ui_custom_event("EVENT_NAME", {})
```

### 位置和移动
```lua
local pos = unit.get_position()
unit.set_position(math.Vector3(x, y, z))
local dir = unit.get_direction()
```

## 参考文档

| 需求 | 文档 |
|-----|------|
| 游戏概念、单位类型、坐标系、物理系统 | references/concepts.md |
| Lua 环境限制、沙盒约束 | references/lua-env.md |
| 性能优化技巧、编码规范 | references/dev-tips.md |
| 类定义模式、OOP写法 | references/patterns/class-utils.md |
| 事件注册/取消/模式 | references/patterns/event-patterns.md |
| Manager 管理器模式 | references/patterns/manager-patterns.md |
| 战斗/怪物AI/波次刷怪/英雄等级 | references/demos/fight-demo.md |
| 物品系统/背包/商店 | references/demos/items-demo.md |
| 建造/射线检测/物理关节/相机控制 | references/demos/build-demo.md |
| 脚本扩展/单位创建监听/碰撞事件 | references/demos/gameplay-demo.md |
| 存档系统/称号/3D场景UI | references/demos/label-demo.md |
| 开放世界/动态地块加载/对象池 | references/demos/openworld-demo.md |
| 模型切换/角色装扮/区域触发变换 | references/demos/textures-demo.md |
| 无尽跳跃/成就系统/游戏结束存档 | references/demos/unlimitjump-demo.md |

## 注意事项

1. 坐标：左手坐标系，Y 轴向上
2. 逻辑帧：30 帧/秒
3. 数值：使用定点数(Fixed)
4. 沙盒限制：无 io/os/debug 库
5. 性能：优先事件而非 Tick 轮询
