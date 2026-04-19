# Mock Data Directory

此目录用于存放 Phase 0 阶段生成的假数据（Mock Data），用于在 AI 资产管线尚未就绪时，测试 Moonbit + Raylib 引擎的渲染、碰撞与状态机逻辑。

## 数据格式选型分析：`.obj` vs 自定义二进制 (Custom Binary Voxel)

在我们的 Aetheria3D 引擎中，由于我们采用了“体素网格 (Voxel Mesh)”路线<mccoremem id="03fuhi0oeab9sugrahu0eqinu" />，且需要兼顾：
1. 表面颜色 (Vertex Color)
2. 纹理/材质扩展性 (Texture/Material)
3. 物理碰撞 (Collision)
4. Moonbit 跨语言 FFI 加载性能

我们对 `.obj` 和 `自定义二进制` 进行了对比分析：

### 1. 传统 `.obj` + `.mtl` 格式
- **优势**：
  - **生态兼容性极强**：几乎所有的 3D 软件（Blender、MagicaVoxel 等）和引擎都支持。
  - **Raylib 原生支持**：可以直接调用 `LoadModel("scene.obj")`，无需在 Moonbit 端手动解析顶点数据。
  - **材质扩展容易**：配套的 `.mtl` 文件可以轻松定义多张贴图（Diffuse, Normal, Specular）和材质属性。
- **劣势**：
  - **体积庞大**：纯文本格式，包含大量冗余字符串（如 `v`, `vt`, `vn` 等）。
  - **解析慢**：文本解析比二进制慢得多，尤其是几十万个面的场景时。
  - **体素属性丢失**：`.obj` 只是多边形网格，它不知道自己是“体素”。如果你想在游戏中实现“挖除一个体素”或“获取某个坐标的方块类型”，会非常困难。

### 2. 自定义二进制体素格式 (例如 `.vox` 或自定义的 `.aether`)
- **优势**：
  - **体积极小**：如果场景是体素，可以只存储非空方块的坐标 `(x,y,z)` 和颜色/材质 ID `(r,g,b,a / mat_id)`，可能只有几百 KB。
  - **加载极快**：可以直接 `mmap` 或通过 `Array[Byte]` 无损传递给 Moonbit 和 Raylib，零文本解析开销。
  - **天然支持碰撞**：在内存中直接映射为 3D 数组 `Grid[X][Y][Z]`，AABB 碰撞检测的时间复杂度是 O(1)。
- **劣势**：
  - **渲染需要自己写逻辑**：Raylib 不能直接加载这种格式。我们需要在 C 端或 Moonbit 端遍历这个 3D 数组，动态生成 Mesh（Instancing 或 Greedy Meshing），然后提交给 GPU。
  - **纹理映射复杂**：给纯体素贴复杂的 UV 纹理比较麻烦，通常只能用顶点颜色 (Vertex Color) 或 Texture Atlas (纹理图集)。

---

### 💡 结论与推荐方案

考虑到我们的项目核心是 **AI 自动化构建** 和 **敏捷开发**，我强烈建议采用 **混合策略（Hybrid Approach）**：

**近期（Phase 0 - Phase 2）：直接使用 `.obj` 格式**
- **理由**：为了快速跑通 Raylib 的 FFI 绑定、渲染和基础漫游，`.obj` 是最稳妥的。我们可以用脚本生成一个带有顶点颜色或简单贴图的 `.obj` 作为假数据。这样我们不用一开始就陷入“如何用代码动态构建 3D 网格”的泥潭中。

**远期（Phase 4 数据重构阶段）：引入自定义二进制 / JSON 混合结构**
- **理由**：当我们需要从 3DGS 转换数据时，我们可以生成一个轻量级的 `world_data.json`（或二进制），里面只记录“碰撞包围盒”和“材质映射”。
- 具体的渲染模型可以打包成 `.gltf` / `.glb`（比 `.obj` 更好的二进制标准，Raylib 也支持），而碰撞逻辑由 Moonbit 读取轻量级结构来实现。

---

## 本期 Mock 数据生成计划

为了推进 Phase 0，我们将生成以下文件：
1. `mock_world.json`：定义世界观、出生点、碰撞盒（AABB）、剧情触发节点。
2. `mock_terrain.obj` & `mock_terrain.mtl`：一个简单的地形网格（包含基础颜色和法线）。

接下来，我将编写一个 Python 脚本来生成这些 Mock 数据，确保它们完全符合我们的规范。