#!/bin/bash
# 简单的构建脚本，用于结合 Moonbit Wasm 和 Raylib C Wrapper

# 确保 raylib 已安装 (在 CI/CD 或本地环境)
# 这里仅作结构展示，后续需要结合 emscripten (emcc) 或 wasmtime 编译完整的 FFI 模块。

echo "Building Moonbit Wasm module..."
moon build

echo "Build complete. (In a full setup, this would invoke emcc to link wasm with C raylib_wrapper.c)"
