# 场景批量生成参考

> 本文档适用于在**编辑时（`idle` 状态）**通过 `EditorAPI` 批量搭建场景的场景。
> 所有操作必须在编辑器 `idle` 状态下执行，不支持运行时动态生成场景。

---

## 1. 场景搭建思维准则

搭建蛋仔场景时，必须遵循**游戏关卡设计师**思维，而非 Minecraft 方块堆砌思维。

**核心原则：优先大组件 + 缩放/旋转，不堆砌小方块**

| 场景需求 | ❌ 错误做法（堆砌） | ✅ 正确做法（拉伸） |
|---------|-----------------|-----------------|
| 一堵长墙 | 放 10 个小墙组件排成一排 | 放 1 个墙组件，`scale[1]` 拉伸到目标宽度 |
| 一块大平地 | 铺满小地板块 | 用 1~2 块大地板组件，调整 scale 覆盖目标面积 |
| 一条跑道 | 密集排列小平台 | 用长条状地板组件 + `scale[3]` 拉伸长度 |
| 对称装饰 | 手动计算每个位置 | 左右镜像坐标（`x` 取反）+ 旋转 180° |
| 一片草地 | 铺满草丛组件 | 用 1 个大草地组件 + 缩放覆盖，边缘添加少量点缀 |

**目标：辅助用户搭建出 80% 效果，剩余细节由用户在编辑器中自行微调。**

---

## 2. 需求分析流程

收到模糊场景描述时，AI 按以下 6 步内部拆解（**不需要每步都问用户**，直接决策后告知）：

```
Step 1: 识别场景类型
  开放区域（岛屿/广场）/ 线性跑道 / 竞技场 / 探索地图

Step 2: 拆解构成元素（三层结构）
  地基层：大型地板/地面组件，决定场景的水平范围
  主体层：墙体/柱子/平台等主要结构
  装饰层：树木、植被、小道具等点缀

Step 3: 估算规模
  每个元素需要几个组件（尽量少）、大概尺寸范围

Step 4: 查询组件（见第3节）
  按元素关键词查 docset_1765444462000

Step 5: 规划布局
  计算坐标、高度对齐、旋转方向（见第4节）

Step 6: 告知用户 + 分批执行
  执行前简述："我将创建 N 个组件：地基×2、树×3、装饰×2..."
  分批执行，完成后提示用户可在编辑器中微调
```

### 示例：用户说"帮我搭一个有几棵树的小岛"

```
Step 1: 开放区域（小岛）
Step 2:
  地基层 → 大地板/草地组件 × 1~2（拉伸覆盖整个岛屿）
  装饰层 → 树木组件 × 3、小装饰物 × 2
Step 3: 总共 ~7 个组件，≤20 个，直接创建
Step 4: 查 docset_1765444462000，搜"草地"/"地板"/"树"
Step 5: 地基放在 y=0，树木均匀分布在地基上
Step 6: 告知用户后执行
```

---

## 3. 组件查询流程

> ⚠️ **严禁编造 key 或依赖记忆中的 key 值**，必须通过文档查询。

### 查询步骤

```
1. 提取关键词
   用户说"树" → 搜索词："树木"或"植物"
   用户说"墙" → 搜索词："墙体"或"围墙"
   用户说"地板" → 搜索词："地板"或"地面"

2. 查询 docset_1765444462000
   retrieve_knowledge docset_1765444462000 "<关键词>"

3. 从结果中选择
   优先选：语义吻合 + 尺寸适中 + 非机关类
   避免选：陷阱/弹射/传送等功能性机关（除非用户明确要求）

4. 提取必要字段
   - 组件编号（key）
   - 模型包围盒(半长)：(halfX, halfY, halfZ)
   - 模型中心点：(cx, cy, cz)
```

### 回退策略

| 情形 | 处理方式 |
|------|---------|
| 查到多个候选 | 选语义最匹配的，在告知用户时注明所用组件名称 |
| 查到但尺寸不合适 | 用 scale 调整到合适尺寸 |
| 完全查不到 | 向用户说明，请用户提供具体 key，不得猜测 |

---

## 4. 坐标计算规范

### 4.1 包围盒与间距

```
完整尺寸 = 包围盒半长 × 2
相邻组件间距（无缝）= halfX × 2 × scale[1]  （X 方向）
                     = halfZ × 2 × scale[3]  （Z 方向）
```

### 4.2 底面对齐公式（必读，高度计算最容易出错）

`create_obstacle` 的 `_pos` 对应**模型中心点**，不是底面或顶面。  
**用户提供的尺寸 `(X, Y, Z)` 中，Y 即为模型中心点高度（centerY）= 半高。**

#### 基本公式

```
地板类（让顶面齐平 groundY）：
  pos_y = groundY - centerY
  → 地板顶面 = pos_y + centerY = groundY  ✅

地上物体（让底面站在 groundY 上）：
  pos_y = groundY + centerY
  → 物体底面 = pos_y - centerY = groundY  ✅

缩放后修正（scaleY ≠ 1 时）：
  实际 centerY = 原始 centerY × scaleY
  pos_y = groundY + 实际 centerY
```

#### ⚠️ 多层叠放（地板 + 地上物体）的完整推导链

**这是最常见的错误场景**：先铺地板、再在地板上摆树/花，必须先算出地板顶面的实际 Y，再以该 Y 作为树/花的 groundY。

```
已知：
  地板 centerY = floorHalfY（用户给的尺寸里 Y 分量）
  地板创建位置 floorPosY = placedY（传给 create_obstacle 的 y）
  
则：
  地板顶面 Y（= 树/花的 groundY）= floorPosY + floorHalfY
  
树/花的创建 Y：
  treePosY = 地板顶面Y + treeCenterY
           = (floorPosY + floorHalfY) + treeHalfY
```

#### 实际示例（用户给的组件）

```
平地：key=1204006，尺寸(25, 10, 25) → halfY=10，地板放在 y=0
  地板顶面 Y = 0 + 10 = 10

树：key=103379，尺寸(3, 4, 3) → halfY=4（centerY=4）
  树的 pos_y = 地板顶面Y + treeCenterY = 10 + 4 = 14  ✅

花：key=1840226048，尺寸(1, 1.5, 1) → halfY=1.5（centerY=1.5）
  花的 pos_y = 地板顶面Y + flowerCenterY = 10 + 1.5 = 11.5  ✅
```

❌ **错误做法（直接用 y=0 放树）**：
```
树 pos_y=0 → 树中心在 Y=0，底面在 Y=-4，树整体陷入地板以下！
```

✅ **正确做法**：
```powershell
# 地板放在 y=0（顶面=10）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(1204006, math.Vector3(0, 0, 0))"

# 树放在 y=14（底面对齐地板顶面）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(103379, math.Vector3(10, 14, 10))"

# 花放在 y=11.5（底面对齐地板顶面）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(1840226048, math.Vector3(-5, 11.5, 5))"
```

### 4.3 坐标系约定

| 轴 | 方向 | 用途 |
|----|------|------|
| X | 左右 | 横向排列、镜像 |
| Y | 上下（垂直） | 高度、堆叠 |
| Z | 前后 | 跑道延伸方向、纵深 |

### 4.4 防穿模规范（必读，连接组件最常见错误）

**穿模**指两个组件在空间上相互重叠，视觉上一个插入另一个内部，是关卡搭建中最影响品质的问题。

#### 根本原因：忽略组件自身的"占位半长"

每个组件以 `pos` 为中心向四周延伸半长距离。放置连接组件（桥、路、云朵等）时，**必须同时考虑连接组件和目标组件各自的边界**，不能只用目标组件的中心坐标来定位连接组件。

#### 通用防穿模公式

**两组件无缝相接（不重叠、不留缝）**：
```
组件A中心坐标 + 组件A半长 + 组件B半长 = 组件B中心坐标（沿某轴方向）
```

**连接组件放置在两端组件之间**：
```
端A边缘（朝B方向）= 端A中心Z + 端A半长Z
端B边缘（朝A方向）= 端B中心Z - 端B半长Z
空隙长度 = 端B边缘 - 端A边缘
中间空隙中点 = (端A边缘 + 端B边缘) / 2

若空隙长度 < 连接组件全长（halfZ×2），则连接组件会与端A或端B穿模！
此时必须加大端A与端B之间的距离，或缩短连接组件的尺寸（scale）。
```

#### 典型错误案例：桥挤进地块

```
地块A 中心Z=0，半长Z=12.5 → 右边缘 Z = 0 + 12.5 = 12.5
地块B 中心Z=50，半长Z=12.5 → 左边缘 Z = 50 - 12.5 = 37.5
桥   半长Z=5，中心放在 Z=40 → 桥占据范围 [35, 45]

地块B左边缘=37.5，桥范围[35,45] → 桥与地块B重叠区域 [37.5, 45] ← ❌ 穿模！

✅ 正确：桥中心应在两边缘中点
  桥中心Z = (12.5 + 37.5) / 2 = 25.0
  桥占据范围 = [25-5, 25+5] = [20, 30] → 与地块A边缘(12.5)和地块B边缘(37.5)均有安全间距 ✅
```

#### 高度穿模：连接组件底面低于地块顶面

连接组件的底面应 ≥ 起点地块顶面高度，否则会嵌入地面。

```
地块A顶面Y = floorA_posY + floorA_halfY
连接组件 pos_y = 地块A顶面Y + 连接组件halfY（底面紧贴地块顶面）
```

#### 防穿模检查清单（放置连接组件前必须核对）

```
□ 计算起点组件的边缘坐标（中心 ± 半长）
□ 计算终点组件的边缘坐标（中心 ± 半长）
□ 计算两边缘之间的空隙长度
□ 确认空隙长度 ≥ 连接组件全长（半长×2×scale）
□ 连接组件中心 = 空隙中点（(端A边缘 + 端B边缘) / 2）
□ 连接组件的底面高度 ≥ 起点地块顶面高度
```

#### 示例：正确放置连接两个地块的桥

```
已知：
  地块A：中心(0, 0, 0)，尺寸(25, 10, 25) → halfZ=12.5，右边缘Z=12.5
  地块B：中心(0, 5, 50)，尺寸(25, 10, 25) → halfZ=12.5，左边缘Z=37.5
  桥：尺寸(5, 3, 10) → halfZ=5，全长=10

空隙长度 = 37.5 - 12.5 = 25 ≥ 10 ✅（可以放桥）
桥中心Z = (12.5 + 37.5) / 2 = 25.0
桥底面Y = 地块A顶面Y = 0 + 10 = 10
桥 pos_y = 10 + 3 = 13

→ 桥放在 math.Vector3(0, 13, 25)，完全处于两地块之间，无穿模 ✅
```

---

### 4.5 旋转约定

`model_angle` 使用**角度制**（0~360），格式为 `{pitch, yaw, roll}`：
- `{0, 90, 0}` = 绕 Y 轴旋转 90°（常用于跑道方向切换）
- `{0, 180, 0}` = 绕 Y 轴旋转 180°（对称镜像）
- `{0, 0, 0}` = 无旋转（默认朝向）

---

## 5. EditorAPI 属性设置规范

### 5.1 字段格式

| 属性 | EditorAPI 格式 | 说明 |
|------|--------------|------|
| `scale` | `math.Vector3(sx, sy, sz)`，**不是** `{sx, sy, sz}` 数组 | `math.Vector3(1.0, 1.0, 1.0)` = 原始大小 |
| `model_angle` | `{rx, ry, rz}` 数组，**角度制** | `{0, 90, 0}` = Y 轴旋转 90° |
| `position` | 通过 `create_obstacle` 的 `_pos` 传入 | 使用 `math.Vector3(x, y, z)` |

> ⚠️ **`scale` 必须传 `math.Vector3`，不能传 `{sx, sy, sz}` 数组！**
> 引擎内部会对 scale 值调用 `.x`、`.y`、`.z` 属性，传 list 会报 `AttributeError: 'list' object has no attribute 'x'`。
> `model_angle` 仍使用数组格式 `{rx, ry, rz}`（角度制）。

```lua
-- ❌ 错误写法（传 list，报 AttributeError）
EditorAPI.set_unit_attr(uid, 'scale', {1, 1, 1})

-- ✅ 正确写法（传 math.Vector3）
EditorAPI.set_unit_attr(uid, 'scale', math.Vector3(1.0, 1.0, 1.0))
```

### 5.2 标准三步 CLI 模板

```powershell
# 创建组件 → 设置缩放 → 设置旋转（单条命令完成）
.codemaker\editor-cli.exe --port 19836 exec "local uid = EditorAPI.create_obstacle(KEY, math.Vector3(X, Y, Z)); EditorAPI.set_unit_attr(uid, 'scale', math.Vector3(SX, SY, SZ)); EditorAPI.set_unit_attr(uid, 'model_angle', {RX, RY, RZ})"
```

### 5.3 仅创建（无缩放/旋转需求时，默认缩放为 1:1:1，无需单独设置）

```powershell
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(KEY, math.Vector3(X, Y, Z))"
```

---

## 6. 分批创建策略

编辑器每帧创建组件数有上限，**必须分批执行**。

### 策略规则

- 每批最多 **10 个组件**
- 批次间间隔 **`Start-Sleep -Milliseconds 200`**

### 数量指导

| 组件总数 | 处理方式 | 预计耗时 |
|---------|---------|---------|
| ≤ 20 个 | 直接分批创建，无需特别提示 | ~4 秒 |
| 21~50 个 | 分批创建，执行前告知用户预计等待时间 | ~10 秒 |
| > 50 个 | 考虑合并为更大组件减少数量；若仍需大量创建，告知用户较长等待 | 较长 |

### PowerShell 分批模板

```powershell
# 第一批（最多10个组件）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(KEY1, math.Vector3(X1,Y1,Z1))"
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(KEY2, math.Vector3(X2,Y2,Z2))"
# ... 最多10条

Start-Sleep -Milliseconds 200

# 第二批
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(KEY11, math.Vector3(X11,Y11,Z11))"
# ...
```

---

## 7. 布局模式示例

### 7.1 小岛场景

**结构**：大地基（拉伸地板）+ 树木（均匀分布）+ 小装饰物（边缘点缀）

```
俯视图（示意）：
     Z
     ↑
  [树][  ][装]
  [  ][地基][  ]
  [装][  ][树]  → X
```

**组件规划**（以地基尺寸 20×20 为例）：
```
查询: docset_1765444462000 "草地地板"
  → 假设得到 key=FLOOR_KEY, 半长=(7.5,1.0,7.5), 中心=(0,1.0,0)
  → 拉伸 scale={1.4, 1.0, 1.4} 使覆盖范围 ≈ 21×21

查询: docset_1765444462000 "树"
  → 假设得到 key=TREE_KEY, 半长=(1.5,4.0,1.5), 中心=(0,4.0,0)
  → 底面对齐: pos_y = 0 + 4.0 = 4.0（地面 groundY=0）

查询: docset_1765444462000 "装饰石头"
  → 假设得到 key=DECO_KEY, 半长=(1.0,0.8,1.0), 中心=(0,0.8,0)
  → 底面对齐: pos_y = 0 + 0.8 = 0.8
```

**CLI 调用序列**（共 6 个组件，一批完成）：

```powershell
# 地基 × 1（拉伸覆盖岛屿范围）
.codemaker\editor-cli.exe --port 19836 exec "local uid = EditorAPI.create_obstacle(FLOOR_KEY, math.Vector3(0, -1.0, 0)); EditorAPI.set_unit_attr(uid, 'scale', {1.4, 1.0, 1.4})"

# 树 × 3（岛屿三角形分布，底面 y=4.0）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(TREE_KEY, math.Vector3(-6, 4.0, -6))"
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(TREE_KEY, math.Vector3(6, 4.0, -4))"
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(TREE_KEY, math.Vector3(0, 4.0, 7))"

# 装饰 × 2（边缘点缀）
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(DECO_KEY, math.Vector3(-8, 0.8, 3))"
.codemaker\editor-cli.exe --port 19836 exec "EditorAPI.create_obstacle(DECO_KEY, math.Vector3(7, 0.8, -7))"
```

---

### 7.2 线性跑道

**结构**：沿 Z 轴延伸的地板段（`scale[3]` 拉伸）+ 可选两侧栅栏

```
俯视图（示意）：
[栅][地板 ×N 沿Z延伸...][栅]
     ←───────────────→
          跑道方向 Z+
```

**无缝拼接间距计算**：
```
地板半长 halfZ, 当前 scale[3] = SZ
单块地板沿 Z 方向占用宽度 = halfZ × 2 × SZ
第 i 块地板中心 Z 坐标 = startZ + i × (halfZ × 2 × SZ)
```

**CLI 调用序列**（3 段地板 + 两侧栅栏，共 5 个组件）：

```powershell
# 查询得：地板 key=FLOOR_KEY, 半长=(5,0.5,10), 中心=(0,0.5,0)
# 每块沿Z拉伸2倍 scale={1,1,2}，实际Z长度=10×2=20，中心间距=20
# 地板底面: pos_y = 0 - 0.5 = -0.5

# 地板 × 3（Z方向无缝排列）
.codemaker\editor-cli.exe --port 19836 exec "local u1 = EditorAPI.create_obstacle(FLOOR_KEY, math.Vector3(0, -0.5, 0)); EditorAPI.set_unit_attr(u1, 'scale', {1,1,2})"
.codemaker\editor-cli.exe --port 19836 exec "local u2 = EditorAPI.create_obstacle(FLOOR_KEY, math.Vector3(0, -0.5, 20)); EditorAPI.set_unit_attr(u2, 'scale', {1,1,2})"
.codemaker\editor-cli.exe --port 19836 exec "local u3 = EditorAPI.create_obstacle(FLOOR_KEY, math.Vector3(0, -0.5, 40)); EditorAPI.set_unit_attr(u3, 'scale', {1,1,2})"

Start-Sleep -Milliseconds 200

# 查询得：栅栏 key=FENCE_KEY, 半长=(0.2,1.5,30), 中心=(0,1.5,0)
# 拉伸 scale[3] 使栅栏总长 = 跑道总长60, scale={1,1,1}（已足够）
# 栅栏底面: pos_y = 0 + 1.5 = 1.5，X方向偏移到跑道两侧

# 两侧栅栏 × 2（各拉伸覆盖跑道全长）
.codemaker\editor-cli.exe --port 19836 exec "local uf1 = EditorAPI.create_obstacle(FENCE_KEY, math.Vector3(-5.5, 1.5, 20)); EditorAPI.set_unit_attr(uf1, 'scale', {1,1,2})"
.codemaker\editor-cli.exe --port 19836 exec "local uf2 = EditorAPI.create_obstacle(FENCE_KEY, math.Vector3(5.5, 1.5, 20)); EditorAPI.set_unit_attr(uf2, 'scale', {1,1,2})"
```

---

### 7.3 障碍物列阵

**结构**：在跑道上等间距排列障碍物，通过 `scale[2]` 控制高度

**底面对齐+缩放公式**：
```
障碍物原始半长=(hX, hY, hZ)，中心点=(0, cy, 0)，缩放 scale[2]=SY
实际 centerY = cy × SY
pos_y = groundY + 实际 centerY
间距（X方向）= hX × 2 × scale[1] + gap（gap建议≥1，留出空隙）
```

**CLI 调用序列**（5 个障碍物，等间距沿 X 排列）：

```powershell
# 查询得：仙人掌 key=CACTUS_KEY, 半长=(1.5,3.0,1.5), 中心=(0,3.0,0)
# scale={0.6,0.6,0.6}，缩小后高度=3.0×2×0.6=3.6，可跳过
# 实际 centerY = 3.0 × 0.6 = 1.8，pos_y = 0 + 1.8 = 1.8
# 间距 = 1.5×2×0.6 + 2 = 3.8，约 4 个单位间距

# 障碍物 × 5（沿 X 轴等间距，Z=15 位于跑道中段）
.codemaker\editor-cli.exe --port 19836 exec "local o1 = EditorAPI.create_obstacle(CACTUS_KEY, math.Vector3(-8, 1.8, 15)); EditorAPI.set_unit_attr(o1, 'scale', {0.6,0.6,0.6})"
.codemaker\editor-cli.exe --port 19836 exec "local o2 = EditorAPI.create_obstacle(CACTUS_KEY, math.Vector3(-4, 1.8, 15)); EditorAPI.set_unit_attr(o2, 'scale', {0.6,0.6,0.6})"
.codemaker\editor-cli.exe --port 19836 exec "local o3 = EditorAPI.create_obstacle(CACTUS_KEY, math.Vector3(0, 1.8, 15)); EditorAPI.set_unit_attr(o3, 'scale', {0.6,0.6,0.6})"
.codemaker\editor-cli.exe --port 19836 exec "local o4 = EditorAPI.create_obstacle(CACTUS_KEY, math.Vector3(4, 1.8, 15)); EditorAPI.set_unit_attr(o4, 'scale', {0.6,0.6,0.6})"
.codemaker\editor-cli.exe --port 19836 exec "local o5 = EditorAPI.create_obstacle(CACTUS_KEY, math.Vector3(8, 1.8, 15)); EditorAPI.set_unit_attr(o5, 'scale', {0.6,0.6,0.6})"
```
