# MoonPalace

MoonPalace is the overarching repository housing **Aetheria Studio** and its associated experimental game development workshops. The core philosophy of this project is to explore the intersection of Large Language Models (LLMs), Generative AI (like ComfyUI for 2D/3D assets), and modern programming languages (MoonBit) to automate and democratize the game asset creation pipeline.

---

## 🌟 Core Project: Aetheria Studio

**Aetheria Studio** is a 2D/3D game asset generation pipeline and creative workbench driven by LLMs and advanced image generation models (ComfyUI). Through AI Pair Programming (Vibe Coding), creators only need to input a brief core concept, and Aetheria Studio will automatically complete the entire process: from world-building, state machine blueprints, and storyboard generation, to the automated rendering and previewing of final 2D scene images and 3D model assets.

The frontend of this project adopts a modern WebUI architecture, while the backend is written entirely in the emerging **MoonBit** language, compiling into a Native desktop application that boasts both blazing-fast responsiveness and cross-platform flexibility.

### Key Features & Workflow

Aetheria Studio's workflow is divided into distinct, repeatable steps, ensuring that every AI-generated image or model is deeply tied to the game's script:

1. **Core Concept & World Bible**: Input a few words, and the LLM will expand it into a complete worldview, factions, and core conflicts.
2. **State Machine Blueprint**: Automatically generates branching narrative node logic based on the worldview.
3. **Detailed Script**: Fills each node with specific environmental descriptions, dialogues, and character actions.
4. **JSON Serialization**: Converts unstructured scripts into a strict JSON data structure directly readable by game engines.
5. **2D Asset Generation**: Proxies requests to RunComfy (using models like Flux2) to automatically generate stylized 2D scene images based on environmental descriptions.
6. **3D Asset Generation**: Uses generated images or prompts to request 3D generative models (like Trellis), producing standard `.glb` 3D models.
7. **2D/3D Game Preview**: The built-in Three.js WebGL engine allows for immediate previewing of 3D model scenes overlaid with narrative options directly within the software.

### Architecture Design

Aetheria Studio employs a modern **Frontend WebUI + Backend MoonBit** hybrid architecture:

- **Frontend**: Built with HTML/CSS/Vanilla JS and communicates with the underlying system via a WebUI library. It handles complex UI state management, long-text rendering, Three.js 3D previews, and time-consuming polling tasks (e.g., using `fetch` to poll RunComfy status, resolving CORS issues via a backend proxy).
- **Backend**: Written entirely in **MoonBit**, using C FFI (Foreign Function Interface) to bind system-level APIs. The backend focuses on efficient proxying of local file I/O, precise regex parsing of LLM text, persistent storage of state machines, and secure HTTP request proxying.

---

## 🚀 Getting Started

### 1. Building the MoonBit Backend
To build Aetheria Studio from the source, you need the MoonBit toolchain installed:

```bash
# Navigate to the studio directory
cd aetheria_studio

# Build for the native target using MoonBit CLI
moon build --target native

# Or simply run the provided batch script on Windows
.\build.bat
```
Upon successful compilation, `AetheriaStudio_v3.exe` and related worker executables will be generated in the root directory.

### 2. Usage Guide
1. **Launch**: Run the compiled `AetheriaStudio_v3.exe`.
2. **Configuration**: Click on `System Settings` in the left navigation bar.
   - Configure your **LLM API** (e.g., OpenAI compatible) URL, Key, and Model name for narrative and JSON generation.
   - Configure your **RunComfy API** (or Local ComfyUI) URL and Token for image generation.
   - Click `Save Configuration`.
3. **Create a Project**:
   - Go to the `Creative Workbench` and input your game inspiration in the first tab.
   - Click `Quick Generate Core Concept`.
   - Progress through generating the Worldview, Blueprint, and Detailed Script.
   - Once the JSON structure is generated in Step 4, click `Batch Generate 2D Assets`.
4. **Monitor Progress**: The UI will automatically poll and display the real-time download progress of each image and 3D model.
5. **Preview Game**: Switch to the `2D Game Preview` panel to load your generated models alongside the JSON narrative data with interactive option buttons.

---

## 🛠️ ComfyUI Image Generation Configuration

Aetheria Studio heavily relies on the ComfyUI architecture for asset generation (supporting both local deployment and RunComfy Cloud API).

- **Cloud Mode (Recommended)**: Enter the `https://api.runcomfy.net/...` Endpoint and your Bearer Token in the system settings. The frontend has built-in support for perfectly polling RunComfy's asynchronous task IDs.
- **Local Mode**: Ensure your local ComfyUI is running in API mode (`--listen`) and point the configuration URL to `http://127.0.0.1:8188`.

---

## 🙏 Acknowledgements & Dependencies

This project is made possible by the incredible support of the following open-source communities and toolchains:

- **[MoonBit](https://www.moonbitlang.com/)**: A blazing-fast, intelligent next-generation programming language that provides powerful performance and type safety for our Native backend.
- **[WebUI](https://webui.me/)**: A lightweight, cross-platform WebView library bridging the C/MoonBit and frontend worlds.
- **[Three.js](https://threejs.org/)**: A powerful WebGL 3D rendering library used to drive `.glb` game asset previews in the frontend.
- **[ComfyUI](https://github.com/comfyanonymous/ComfyUI)**: A modular Stable Diffusion node-graph interface serving as the underlying engine for image generation.
- **[RunComfy](https://www.runcomfy.com/)**: Providing ComfyUI Serverless API hosting services.
