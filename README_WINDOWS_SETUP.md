# Aetheria3D Windows 桌面端可视化运行指南

由于在纯命令行（尤其是无头 Linux/WSL 环境）下无法直接拉起带 GPU 硬件加速的图形窗口，我们需要将引擎编译为原生的 Windows `.exe` 程序（或 WebAssembly 跑在浏览器中）才能看到真正的 3D 渲染画面。

我们在代码中已经写好了 `Raylib` 的 FFI 绑定壳子（`aetheria_engine/src/raylib/raylib.mbt` 和 `aetheria_engine/c_src/raylib_wrapper.c`），接下来只需要在 Windows 下进行编译链接即可。

## 方案一：在 Windows 原生环境中编译为 `.exe`（推荐）

这是最贴合项目初期“交付轻量级桌面端.exe”目标的方案。

### 1. 环境准备
1. **安装 C 编译器**：在 Windows 上安装 [MSYS2 (MinGW-w64)](https://www.msys2.org/) 或 Visual Studio Build Tools。
2. **下载 Raylib**：从 [Raylib 官网](https://www.raylib.com/) 下载 Windows 版预编译库（通常包含 `raylib.dll` 和 `raylib.lib`）。
3. **安装 Moonbit 工具链**：确保在 Windows 的 CMD/PowerShell 中可以运行 `moon` 命令。

### 2. 编译流程
我们将使用 Moonbit 的 `native` target 将 `.mbt` 代码编译为 C 代码，然后用 GCC/Clang 与 Raylib 链接。

1. **导出 Moonbit 代码为 C**：
   在 `aetheria_engine` 目录下运行：
   ```cmd
   moon build --target native
   ```
   这会在 `target/native/` 目录下生成转换后的 `.c` 和 `.o` 文件。

2. **使用 GCC 链接 Raylib 并生成可执行文件**：
   编写一个简单的编译脚本（或直接在命令行执行）：
   ```cmd
   gcc aetheria_engine/c_src/raylib_wrapper.c target/native/release/build/main/*.c -o Aetheria3D.exe -O3 -I<path_to_raylib_include> -L<path_to_raylib_lib> -lraylib -lgdi32 -lwinmm
   ```

3. **运行游戏**：
   双击 `Aetheria3D.exe`，您将看到一个真实的窗口被创建出来！

---

## 方案二：编译为 WebAssembly (Wasm) 并在浏览器中预览

如果您不想在 Windows 上配置繁琐的 C/C++ 环境，Moonbit 最强大的能力是编译为 Wasm，结合 Emscripten，可以直接在浏览器里跑 Raylib 游戏！

1. **安装 Emscripten**：[emsdk](https://emscripten.org/docs/getting_started/downloads.html)。
2. **构建指令**：
   ```bash
   # 1. 编译 Moonbit 为 Wasm
   moon build --target wasm
   
   # 2. 使用 emcc 将 C wrapper 和 Raylib 链接到网页
   emcc aetheria_engine/c_src/raylib_wrapper.c -s USE_RAYLIB=1 -s WASM=1 -o index.html
   ```
3. **运行**：
   使用 Python 启动一个本地服务器 `python -m http.server`，在浏览器打开 `localhost:8000`，即可看到可视化的 3D 游戏画面！

## 总结
我们在 Linux/WSL 中的开发**绝对没有白费**。引擎的“大脑”（状态机、物理计算、JSON解析）是跨平台的纯逻辑代码。**UI 无法显示只是因为当前操作系统（Linux 终端）没有提供桌面窗口管理器。** 您只需要把这个代码仓库 `clone` 到您的 Windows 主机上，接上 Raylib 的库文件一编译，图形界面就会立刻显现。
