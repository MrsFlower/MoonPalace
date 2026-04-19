# Aetheria Studio

Aetheria Studio 是一个基于大语言模型 (LLM) 和先进图像生成模型 (ComfyUI) 驱动的 **2D/3D 游戏资产全自动生成管线与创作工作台**。通过与 AI 结对编程 (Vibe Coding)，创作者只需输入简短的核心概念，Aetheria Studio 便能自动完成从世界观设定、状态机蓝图、分镜剧本生成，到最终的 2D 场景图片和 3D 模型资产的自动化构建与渲染预览。

本项目前端采用现代化的 WebUI 架构，后端完全由新兴的 **MoonBit** 语言编写，编译为 Native 桌面级应用，兼具极速的响应性能与跨平台的灵活性。

---

## 目录
- [项目介绍](#项目介绍)
  - [核心组件与工作流](#核心组件与工作流)
- [架构设计](#架构设计)
- [使用教程](#使用教程)
- [软件安装与配置](#软件安装与配置)
- [依赖项目](#依赖项目)

---

## 项目介绍

Aetheria Studio 旨在解决独立游戏开发者在早期原型设计时面临的“资产荒”和“剧情断层”问题。它将游戏开发拆解为严格的、可重复的流水线步骤，确保 AI 生成的每一张图片、每一个模型都与游戏剧本深度绑定。

### 核心组件与工作流

Aetheria Studio 的工作流分为六大步骤，分别由不同的独立子系统协同完成：

1. **核心概念 (Concept) & 世界观设定 (World Bible)**：输入寥寥数语，LLM 将为你扩展出完整的世界观、派系和核心冲突。
2. **状态机蓝图 (State Machine Blueprint)**：基于世界观，自动生成具备条件分支的剧情节点 (Node) 逻辑。
3. **分镜剧本 (Detailed Script)**：为每一个节点填充具体的环境描述、对话和角色动作。
4. **JSON 序列化 (JSON Serialization)**：将非结构化的剧本转换为游戏引擎可直接读取的严格 JSON 数据结构。
5. **2D 图像资产生成 (2D Assets)**：通过前端代理请求 RunComfy (Flux2 等模型)，根据分镜中的环境描述自动生成带风格化的 2D 场景图片。
6. **3D 模型资产生成 (3D Assets)**：利用生成好的图像或提示词，请求 Trellis 等 3D 生成模型，产出标准的 `.glb` 格式 3D 模型。
7. **2D/3D 游戏预览 (Game Preview)**：内置的 Three.js WebGL 引擎可以直接在软件内部预览带有剧情选项覆盖层的 3D 模型场景。

---

## 架构设计

Aetheria Studio 采用了现代化的 **前端 WebUI + 后端 MoonBit** 的混合架构：

- **前端 (Frontend)**：基于 HTML/CSS/Vanilla JS 构建，通过 WebUI 库与系统底层通信。它负责复杂的 UI 状态管理、长文本渲染、Three.js 3D 预览，以及处理耗时的轮询任务（如使用 `fetch` 轮询 RunComfy 状态，通过后端代理解决 CORS 问题）。
- **后端 (Backend)**：完全使用 **MoonBit** 编写，通过 C FFI (Foreign Function Interface) 绑定系统级 API。后端专注于本地文件的高效读写代理、大模型文本的精准正则解析、状态机的持久化存储，以及 HTTP 请求的安全代理。

**为什么选择 WebUI 而不是 Raylib？**
初期项目曾考虑使用基于 Raylib 的立即渲染模式 GUI (IMGUI)。但在实际开发中发现，长文本的 JSON 解析、大段对话的渲染以及同步的文件 I/O 会严重阻塞 60FPS 的渲染循环，导致界面卡顿。切换到 WebUI 后，繁重的渲染与异步轮询任务被卸载到浏览器内核，后端 MoonBit 专注核心逻辑，实现了完美的性能解耦。

---

## 使用教程

1. **启动应用**：运行编译好的 `AetheriaStudio_v3.exe`。
2. **环境配置**：点击左侧导航栏的 `系统设置`。
   - 配置你的 **LLM API** (如 OpenAI 兼容接口) 的 URL、Key 和模型名称，用于生成剧情与 JSON。
   - 配置你的 **RunComfy API** (或本地 ComfyUI) 的 URL 和 Token，用于图像生成。
   - 点击 `保存配置`。
3. **创建项目**：
   - 进入 `创作工作台`，在第一个 Tab 输入你的游戏灵感（例如：“一个赛博朋克风格的侦探故事”）。
   - 点击 `快速生成核心概念`。
   - 依次检查后续生成的“世界观”、“蓝图”和“分镜剧本”。
   - 在 Step 4 生成完整的 JSON 结构后，点击 `批量生成 2D 资产`。
4. **生成进度监控**：UI 会自动轮询并实时展示每张图片和 3D 模型的下载进度。
5. **预览游戏**：切换到 `2D 游戏预览` 面板，应用将加载你生成的 3D 模型，并配合 JSON 剧情数据展示可交互的选项按钮。

---

## 软件安装与配置

### 1. 编译 MoonBit 后端
如果你希望从源码构建本项目，你需要安装 MoonBit 工具链：
```bash
# 确保你安装了 MoonBit CLI
moon build --target native
# 或者直接运行项目内提供的批处理脚本
.\build.bat
```
编译成功后，根目录将生成 `AetheriaStudio_v3.exe` 及相关 worker 执行文件。

### 2. ComfyUI 图像生成配置
Aetheria Studio 的图像生成强依赖于 ComfyUI 架构（支持本地部署或 RunComfy 云端 API）。
- **云端模式 (推荐)**：在系统设置中填入 `https://api.runcomfy.net/...` 的 Endpoint 和你的 Bearer Token。前端内置了对 RunComfy 异步任务 ID 轮询的完美支持。
- **本地模式**：确保本地 ComfyUI 开启了 API 模式 (`--listen`)，并将配置中的 URL 指向 `http://127.0.0.1:8188`。

---

## 依赖项目

本项目由衷感谢以下开源社区和工具链的支持：

- **[MoonBit](https://www.moonbitlang.com/)**: 极速、智能的下一代编程语言，为本项目的 Native 后端提供了强大的性能与类型安全保障。
- **[WebUI](https://webui.me/)**: 轻量级的跨平台 WebView 库，连接了 C/MoonBit 与前端世界。
- **[Three.js](https://threejs.org/)**: 强大的 WebGL 3D 渲染库，用于在前端驱动 `.glb` 游戏资产预览。
- **[ComfyUI](https://github.com/comfyanonymous/ComfyUI)**: 模块化的 Stable Diffusion 节点图界面，提供图像生成的底层引擎。
- **[RunComfy](https://www.runcomfy.com/)**: 提供 ComfyUI Serverless API 托管服务。
