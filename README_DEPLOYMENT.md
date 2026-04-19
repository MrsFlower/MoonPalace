# Aetheria3D 系统部署与开发手册

本文档是为 Aetheria3D (VoxStory Engine) 编写的快速入门与部署指南。

## 系统架构回顾

系统采用“计算与渲染解耦”的 C/S 变体架构：
1. **The AI Compiler (Python 端)**：负责调度 SDXL 生成 2D 资产、调度 LLM 生成 `world_data.json`。由于深度学习生态极度依赖 PyTorch 等 Python 库，这部分被保留为 Python 脚本，以获得最佳的兼容性与生成效果。
2. **The Moonbit Client (引擎运行端)**：使用 Moonbit 编写的高性能游戏引擎，通过极薄的 C-FFI 绑定 Raylib。负责极速解析 JSON，构建 AABB 碰撞树，并在 3D 空间中进行渲染与交互。

---

## 模块一：AI 资产生成管线 (Python)

该管线适合部署在带有 GPU 的云容器（如 AutoDL, AWS）或配置较高的本地开发机上。

### 1. 环境准备
确保您的机器安装了 Python 3.10+，并安装了相关的 AI 库（本示例为 Mock 版本，无需安装实际的 Diffusers）。
在真实生产环境中，您需要安装：
```bash
pip install torch diffusers transformers
```

### 2. 运行管线
进入根目录，执行 Pipeline Manager 脚本。通过传入 `--prompt` 参数，系统将自动调用 LLM 构建世界数据，并调用 SDXL 绘制 2D 贴图。
```bash
python3 ai_compiler_pipeline/pipeline_manager.py --prompt "A ruined mining town built in a snowy canyon"
```

**输出产物**：
执行完成后，会在 `assets/generated/` 目录下生成 `world_data.json` 和 `scene_base.png` 等数据资产，供引擎端加载。

---

## 模块二：高性能 3D 游戏引擎 (Moonbit + Raylib)

这是玩家实时游玩的核心程序。它基于 Moonbit 编写，被编译为 WebAssembly (Wasm) 或 Native，具备极高的启动速度与内存安全性。

### 1. 环境准备
确保您已安装 Moonbit 工具链（`moon` CLI）和基础的 C 编译环境（用于链接 Raylib）。

### 2. 核心模块说明
引擎源码位于 `aetheria_engine/src/` 目录下：
- `raylib.mbt`: Raylib C-FFI 的核心绑定层。
- `core_engine.mbt`: 游戏状态机（Init -> Loading -> Roam -> Dialog）。
- `physics.mbt`: 基于 AABB 的高性能 3D 物理碰撞引擎。
- `json_parser.mbt`: 为应对超长 AI 文本设计的稳定型流式数据提取器。
- `data_pipeline.mbt`: 处理 OBJ/PLY 数据到引擎内部结构的转换。

### 3. 编译与测试
在引擎目录中，您可以通过以下命令运行全量单元测试（确保状态机、碰撞算法 100% 正确）：
```bash
cd aetheria_engine
moon test
```

要运行引擎主循环的模拟程序：
```bash
moon run cmd
```
此时终端会打印出模拟的 3D 渲染画面、Debug 叠加面板以及玩家移动时的坐标变化。

---

## 结语
感谢您参与 Aetheria3D 项目。通过将沉重的 AI 推理（Python）与轻量敏捷的实时渲染（Moonbit）分离，我们成功打造了一套端到端的 3D 场景自动化构建系统底座。
