# Aetheria Studio - AI Handover Document

## 1. 项目背景与架构
**Aetheria Studio** (MoonPalace 项目的核心模块) 是一个利用大语言模型 (LLM) 和 AI 图像生成工具 (ComfyUI) 辅助创建 2D/3D 文字冒险与角色扮演游戏的综合工作台。

### 技术栈
- **后端 (核心引擎)**: [MoonBit](https://www.moonbitlang.com/) 编写。负责调度 LLM 请求、管理项目状态、处理文件 I/O、调用本地 `.bat` 和 `.exe` 脚本来生成资源。
- **前端 (UI 界面)**: HTML + CSS + 原生 JavaScript，内嵌于后端引擎驱动的 **WebUI** 窗口中。使用了 Three.js 进行 3D 资产预览。
- **底层支持**: 依赖系统级的 API 进行文件操作、C 语言 FFI 以及 Windows 环境的脚本执行。

### 核心功能与工作流
1. **概念生成 (Concept)**: 输入一段简短提示词，生成游戏剧情大纲。
2. **设定集 (World Bible) 与 蓝图 (Blueprint)**: 生成详细的设定及逻辑节点图。
3. **剧本与 JSON**: 导出节点剧情文本并序列化为前端解析的 JSON 格式。
4. **2D 图像与 3D 模型生成**: 解析生成的 JSON，批量调用 `comfy_worker.exe` 和 `comfy_3d_worker.exe`（依赖 ComfyUI），生成对应的 2D 场景图片和 3D 模型 (`.obj` 等)。
5. **UI 预览**: 在 "2D Game Preview" 中体验文字冒险，在 "3D Asset Generation" 选项卡中加载渲染生成的 3D 模型。

---

## 2. 核心工作经验与文件结构
### 关键文件
- **`cmd/main/main.mbt`**: 项目的核心入口点。包含了大量的后端路由 `@webui.on`，控制配置的读写、文件 I/O、以及生成进度（`backend_poll_pipeline`）。
- **`assets/app.js` & `assets/index.html`**: 所有的前端交互逻辑。`app.js` 负责维护状态、发起轮询、渲染剧情节点、加载 Three.js 3D 预览等。
- **`src/config/config.mbt`**: 系统配置的数据结构定义及本地持久化存储 (`config.json`)。
- **`src/net/http.mbt`**: 网络请求及底层文件读写的包装层。
- **`src/webui/webui.mbt`**: MoonBit 与底层 WebUI 库的 C FFI 绑定层。

### 项目构建
由于涉及 C 代码与 FFI，项目的标准构建流程必须调用自定义的 `build.bat` 脚本（它会执行 `moon build --target native` 并将编译产物拷贝到根目录）：
```bat
build.bat
```
生成的可执行文件为 `AetheriaStudio.exe`。

---

## 3. 踩过的坑与避坑指南 (CRITICAL)

接手本项目时，请务必仔细阅读以下踩坑记录，这些都是通过血泪教训排查出来的：

### 1. 字符串处理与 ASCII 码的致命陷阱 (MoonBit 特性)
- **问题**: 在 MoonBit 中，当你遍历字符串 `s` 获取单个字符时，`s[i].to_string()` **不会** 返回该字符的字面量（比如 `"A"`），而是会返回它的 **ASCII 十进制数字的字符串形式**（比如 `"65"`）！
- **后果**: 导致之前在清理文件名时（例如把 `Node 1` 转换为 `Node_1`），生成的图片文件名变成了一长串诡异的数字（如 `781111001013249.png`），进而引发了文件找不到的 `IOError`。
- **正确做法**: 必须使用 `String::make(1, s[i].to_int().unsafe_to_char())` 或 `Char::from_int(s[i].to_int()).to_string()` 进行转换拼接。

### 2. 文件读写的底层封装 (慎用旧 C 接口)
- **问题**: 之前项目中为了读取文件使用了一个自定义的 `worker_read_file` C 语言封装。该封装内置了 16MB 的缓冲限制，并且通过一个极其低效的循环逐字节推入 MoonBit 数组。在读取大图片时，会导致后端严重超时并返回空数据，导致 2D 预览黑屏。
- **正确做法**: **全面弃用自定义封装**。现在必须使用 MoonBit 官方库 `@fs` 提供的 `@fs.read_file_to_bytes(path)` 和 `@fs.write_bytes_to_file(path, bytes)`，性能极佳且带有完善的 Result 错误处理。

### 3. WebUI 前端初始化的时序冲突
- **问题**: 前端在 `app.init()` 中会向后端发送 `backend_get_config` 请求拉取配置。如果直接使用系统内置的基础 WebView（而非 Chromium/Edge 内核），WebUI 的核心通信对象 `webui` 及其 `webui.call` 方法注入会产生微小的延迟。这会导致配置拉取静默失败，界面变成纯英文且没有数据。
- **正确做法**:
  1. 在 `app.js` 的 `DOMContentLoaded` 中，设置一个 `setInterval` 轮询，**必须等待** `typeof webui !== 'undefined' && typeof webui.call === 'function'` 成立后，再延迟 `300ms` 执行 `app.init()`。
  2. 在 `main.mbt` 中，强制指定使用兼容性更好的浏览器内核：`@webui.webui_show_browser(window, "index.html", 1)` (1 代表 Edge/Chrome)。

### 4. 绝对路径与 CWD 环境问题
- **问题**: 在批量生成 3D/2D 模型时，后端需要通过系统终端执行 `.bat` 或 `.exe`。如果依赖相对路径，由于执行时的当前工作目录（CWD）可能不一致，会导致脚本找不到传入的图片或输出目录。
- **正确做法**: 所有涉及系统命令的操作，都必须使用 `@net.get_exe_dir() + "\\..."` 拼装出完整的绝对路径，并严格用双引号 `""` 将路径包裹起来防止空格断层：
  ```moonbit
  let worker_path = @net.get_exe_dir() + "\\comfy_3d_worker.exe"
  bat_content = bat_content + "\"" + worker_path + "\" \"" + comfy_url + "\" \"" + in_image + "\" \"" + out_name + "\"\r\n"
  ```

### 5. `try...catch` 的隐式吞没
- **问题**: 在解析 JSON 或读写配置时，如果用一个巨大的 `try { ... } catch { _ => ... }` 包裹所有逻辑，任何一个内部 API（如 `read_file`）抛出的轻微异常都会直接让整个代码块中断，并返回默认值。
- **正确做法**: 将可能出错的步骤（IO 操作，JSON 解析等）拆分开，使用小颗粒度的 `catch` 兜底，例如：
  ```moonbit
  let content = @fs.read_file_to_string(path) catch { _ => "" }
  let json_val = @json.parse(content) catch { _ => Json::object(Map::new()) }
  ```

### 6. 前端静态资源的根目录绑定
- **问题**: 忘记给 WebUI 设置根目录，会导致它在 `file:///` 协议下直接强开 `index.html`，触发跨域限制且找不到 CSS/JS。
- **正确做法**: 在 `main.mbt` 启动时必须执行：
  ```moonbit
  let abs_assets = @net.get_exe_dir() + "\\assets"
  ignore(@webui.webui_set_root_folder(window, abs_assets))
  ```

---
**接手者注意**: 请继续遵循以上规范，特别是在进行字符串操作、调用外部脚本以及处理文件 I/O 时，务必严谨。祝你接下来的开发顺利！