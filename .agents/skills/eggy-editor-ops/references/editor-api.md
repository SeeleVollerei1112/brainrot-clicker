# EditorAPI 参考

> 当前启用的 EditorAPI 命令。

## 试玩控制

### EditorAPI.run_game()
- **描述**: 开始试玩
- **参数**: 无
- **返回**: 无

### EditorAPI.stop_game()
- **描述**: 停止试玩
- **参数**: 无
- **返回**: 无

### EditorAPI.game_execute(_content)
- **描述**: 在试玩中执行游戏指令（Lua 代码）
- **参数**: `_content`(Str) 要执行的 Lua 代码字符串
- **返回**: 无
- **注意**: 需要先 `run_game()` 进入试玩状态后才能使用

## 场景单位管理

> **重要**: 所有坐标参数（`Point3` 类型）必须使用 `math.Vector3(x, y, z)` 构造，**不能传 Lua table `{x=0,y=0,z=0}`**，否则会报错：
> ```
> param type mismatch, expected: <type 'framecore.reactphysics3d.Vector3'>, got <type 'dict'>
> ```

### EditorAPI.create_obstacle(_unit_key, _pos)
- **描述**: 在场景中创建组件
- **参数**: `_unit_key`(ObstacleKey) 组件编号, `_pos`(Point3) 坐标，需用 `math.Vector3(x,y,z)` 构造
- **返回**: `UnitID` 组件ID
- **示例**: `EditorAPI.create_obstacle(100051, math.Vector3(0, 0, 10))`

### EditorAPI.create_unit_group(_group_key, _pos)
- **描述**: 在场景中创建组件组
- **参数**: `_group_key`(UnitGroupKey) 组件组编号, `_pos`(Point3) 坐标，需用 `math.Vector3(x,y,z)` 构造
- **返回**: `UnitID` 组件组ID
- **示例**: `EditorAPI.create_unit_group(200001, math.Vector3(5, 0, 5))`

### EditorAPI.destroy_obstacle(_unit_id)
- **描述**: 删除场景中的组件
- **参数**: `_unit_id`(UnitID) 组件ID
- **返回**: 无

### EditorAPI.get_all_unit_ids()
- **描述**: 获取所有单位
- **参数**: 无
- **返回**: `ListUnit` 单位列表

### EditorAPI.get_selected_unit_ids()
- **描述**: 获取当前被选中单位
- **参数**: 无
- **返回**: `ListUnit` 单位列表

### EditorAPI.get_all_scene_unit_data()
- **描述**: 获取场景中所有组件的数据
- **参数**: 无
- **返回**: `Dict` 组件列表

### EditorAPI.get_scene_unit_data(_uid)
- **描述**: 获取场景中指定ID的组件的数据
- **参数**: `_uid`(Int) 组件ID
- **返回**: `Dict` 组件数据

**返回 table 常用字段**（字段为 table 属性，直接用 `.fieldName` 访问）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 单位名称 |
| `position` | `{[1]=x,[2]=y,[3]=z}` | 本地坐标，用数字索引访问 |
| `world_position` | `{[1]=x,[2]=y,[3]=z}` | 世界坐标 |
| `scale` | `{[1]=x,[2]=y,[3]=z}` | 缩放 |
| `model_angle` | `{[1]=x,[2]=y,[3]=z}` | 旋转角度（欧拉角） |
| `physic_enable` | bool | 是否启用物理 |
| `enable_hp` | bool | 是否启用血量 |
| `ob_max_hp` | number | 最大血量 |
| `model_alpha` | number | 透明度 (0~1) |
| `create_probability` | number | 创建概率 (0~1) |
| `fix_destroy_time` | number | 固定销毁时间（-1=不销毁） |
| `material_pattern_color` | `{[1]=r,[2]=g,[3]=b,[4]=a}` | 材质颜色 (0~255) |
| `material_roughness_1` | number | 粗糙度 |
| `material_metalness_1` | number | 金属度 |
| `emissive_intensity_1` | number | 自发光强度 |

> ⚠️ `position`/`scale`/`model_angle` 等向量字段是数组格式 `{[1]=x,[2]=y,[3]=z}`，**不是 `.x/.y/.z`**，访问用 `pos[1]`、`pos[2]`、`pos[3]`。
> ⚠️ **不能用 `[[fieldName]]` 访问字段**，会被解析为函数调用报错。必须用 `.fieldName` 或 `['fieldName']`。

```powershell
# ✅ 正确：用 .fieldName 访问，用 [N] 访问向量分量
exec "local d = EditorAPI.get_scene_unit_data(123); local pos = d.position; print(pos[1] .. ',' .. pos[2] .. ',' .. pos[3])"

# ❌ 错误：用 [[]] 访问字段
exec "local d = EditorAPI.get_scene_unit_data(123); print(d[[position]])"
```

### EditorAPI.query_scene_units(_pattern, _reg_math)
- **描述**: 查询场景中的单位
- **参数**: `_pattern`(Str) 名称, `_reg_math`(Bool) 启用正则匹配
- **返回**: `List` 单位信息列表

### EditorAPI.query_unit_ids(_pattern, _reg_math)
- **描述**: 查询场景中的单位
- **参数**: `_pattern`(Str) 名称, `_reg_math`(Bool) 启用正则匹配
- **返回**: `List` 单位信息列表

### EditorAPI.get_unit_attr(_unit_id, _attr_key)
- **描述**: 获取单位属性
- **参数**: `_unit_id`(UnitID) 单位ID, `_attr_key`(Str) 属性名
- **返回**: `ETypeMeta` 属性值

### EditorAPI.set_unit_attr(_unit_id, _attr_key, _attr_value)
- **描述**: 设置单位属性
- **参数**: `_unit_id`(UnitID) 单位ID, `_attr_key`(Str) 属性名, `_attr_value`(ETypeMeta) 属性值
- **返回**: 无

## 环境设置

### EditorAPI.get_camera_properties()
- **描述**: 获取相机属性
- **参数**: 无
- **返回**: `Dict` 属性列表

### EditorAPI.set_camera_properties(_kv_data)
- **描述**: 设置相机属性
- **参数**: `_kv_data`(Dict) 属性列表
- **返回**: 无

### EditorAPI.get_cur_skybox()
- **描述**: 获取当前天空背景ID
- **参数**: 无
- **返回**: `Int` 天空背景ID

### EditorAPI.set_skybox(_skybox_id)
- **描述**: 设置天空背景
- **参数**: `_skybox_id`(Int) 天空背景ID
- **返回**: 无

### EditorAPI.get_fog_properties()
- **描述**: 获取雾效属性
- **参数**: 无
- **返回**: `Dict` 属性列表

### EditorAPI.set_fog_properties(_kv_data)
- **描述**: 设置雾效属性
- **参数**: `_kv_data`(Dict) 属性列表
- **返回**: 无

### EditorAPI.get_skylight_properties()
- **描述**: 获取环境光属性
- **参数**: 无
- **返回**: `Dict` 属性列表

### EditorAPI.set_skylight_properties(_kv_data)
- **描述**: 设置环境光属性
- **参数**: `_kv_data`(Dict) 属性列表
- **返回**: 无

## 工具

### EditorAPI.log(_content)
- **描述**: 输出日志
- **参数**: `_content`(Str) 日志内容
- **返回**: 无

### EditorAPI.random(_a, _b)
- **描述**: 生成随机数
- **参数**: `_a`(Fixed) 随机范围开始, `_b`(Fixed) 随机范围结束
- **返回**: `Fixed` 随机结果

### EditorAPI.require(_name)
- **描述**: 加载脚本模块
- **参数**: `_name`(Str) 模块名
- **返回**: 无

### EditorAPI.set_menu_dialog(_name, _config)
- **描述**: 设置菜单对话框
- **参数**: `_name`(Str) 入口名称, `_config`(Dict) 配置描述表
- **返回**: 无

## 日志

游戏日志通过直接读取项目根目录的 `log.txt` 文件获取，不通过 EditorAPI。
