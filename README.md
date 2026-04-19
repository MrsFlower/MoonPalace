# MoonPalace

MoonPalace 是一个面向“AI 自动生成游戏内容”的多项目仓库。它并非单一应用，而是由以下几类系统共同组成：

- 生成编排与创作工作台（`aetheria_studio`）
- 实时渲染与交互引擎（`aetheria_engine`）
- 资产预处理与体素化工具链（`aetheria_foundry`、`aetheria_voxelizer`）
- 离线 AI 编译管线与原型脚手架（`ai_compiler_pipeline`、`3d_project_scaffold`）

当前主线工作流为：`Aetheria Studio` 负责生成内容与资产，`Aetheria Engine` 负责加载并运行这些资产。

## 仓库结构总览

### 核心主线模块

- `aetheria_studio/`
  - 项目定位：AI 游戏创作工作台（WebUI + MoonBit 后端）
  - 主要职责：从概念到世界观/状态机/脚本/JSON，再到 2D 与 3D 资产生成和预览
  - 运行形态：Native 桌面程序（含独立 worker 可执行文件）
- `aetheria_engine/`
  - 项目定位：MoonBit + Raylib 的实时 3D 引擎
  - 主要职责：游戏状态机、物理碰撞、体素世界加载、GLB 渲染
  - 运行形态：双入口（体素物理主线 + 纯 GLB 预览线）
- `aetheria_foundry/`
  - 项目定位：离线资产处理脚本集合（Python）
  - 主要职责：GLB 优化、切分、体素相关处理、3D 资产辅助工具
- `aetheria_voxelizer/`
  - 项目定位：体素化处理工程（MoonBit）
  - 主要职责：将模型转换为引擎可消费的体素 chunk 数据

### 支撑与实验模块

- `ai_compiler_pipeline/`
  - 离线 Python 管线示例：`prompt -> world_data.json + scene_base.png`
- `aetheria_workshop/`
  - 早期实验/验证工程，保留若干旧链路与测试代码
- `3d_project_scaffold/`
  - 原型脚手架与方法论文档（早期概念验证）
- `mock_data/`
  - AI 未接入或联调阶段使用的假数据资产
- `docs/`
  - 项目架构说明与设计文档（重点看引擎架构）

## 端到端流程（当前主链路）

1. 在 `aetheria_studio` 输入核心概念，生成世界观与状态机蓝图。
2. 继续生成分镜脚本并序列化为结构化 JSON。
3. 调用 `comfy_worker` 生成 2D 资产（本地 ComfyUI 或 RunComfy）。
4. 调用 `comfy_3d_worker` 生成 3D 模型（GLB）。
5. 通过预览功能或 `aetheria_engine` 运行时加载资产，进行交互与渲染验证。
6. 对高复杂度 GLB 先经过 `aetheria_foundry` 预处理，再进入引擎链路。

## 快速开始

### 路线 A：先跑通 Aetheria Studio（推荐）

```bash
cd aetheria_studio
moon build --target native
```

Windows 可直接运行：

```bash
.\build.bat
```

完成后运行 `AetheriaStudio_v4.exe`，在 `System Settings` 中配置：

- LLM API（用于文本与 JSON 生成）
- ComfyUI / RunComfy 配置（用于 2D/3D 资产生成）

### LLM 推荐配置（当前）

- 推荐优先使用 Gemini API（项目默认 `api_provider` 即为 `Gemini`）。
- 默认模型分工：
  - 创意生成（世界观/剧情扩写）：`gemini-2.5-pro`
  - 结构化生成（JSON/状态机）：`gemini-2.5-flash`
- 当前联调与测试主要使用：`gemini-2.5-flash`（结构化链路稳定、速度更快）。
- API Key 推荐使用环境变量：`GEMINI_API_KEY`（配置中可写 `ENV:GEMINI_API_KEY`）。

### 路线 B：单独运行引擎

```bash
cd aetheria_engine
moon build --target native
```

- 体素物理主线入口：`cmd/`
- 纯 GLB 预览入口：`cmd_glb/`（可用于美术资产快速检查）

## 常见开发入口

- Studio 主程序入口：`aetheria_studio/cmd/main/main.mbt`
- Studio Workers：
  - `aetheria_studio/src/llm_worker/main.mbt`
  - `aetheria_studio/src/comfy_worker/main.mbt`
  - `aetheria_studio/src/comfy_3d_worker/main.mbt`
- Engine 主入口：`aetheria_engine/cmd/main.mbt`
- Engine GLB 入口：`aetheria_engine/cmd_glb/main.mbt`
- 资产处理脚本：
  - `aetheria_foundry/optimize_glb_for_raylib.py`
  - `aetheria_foundry/split_glb_to_chunks.py`
  - `aetheria_foundry/glb_to_voxel.py`

## 文档索引

- 项目架构文档：`docs/ARCHITECTURE.md`
- Windows 运行说明：`README_WINDOWS_SETUP.md`
- 系统部署与开发手册：`README_DEPLOYMENT.md`
- Studio 子项目说明：`aetheria_studio/README.md`
- Engine 子项目说明：`aetheria_engine/README.md`

## 依赖与技术栈

- [MoonBit](https://www.moonbitlang.com/)
- [Raylib](https://www.raylib.com/)
- Raylib C FFI（MoonBit <-> Raylib 的原生绑定实现，位于 `aetheria_engine/src/raylib`）
- [WebUI](https://webui.me/)
- [Three.js](https://threejs.org/)
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [RunComfy](https://www.runcomfy.com/)

## 说明

- 本仓库包含多个阶段产物与实验分支，文档会持续更新。
- 若你刚接触本项目，建议优先从 `aetheria_studio` 和 `docs/ARCHITECTURE.md` 开始。
