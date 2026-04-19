# RunComfy Integration Guide

This document outlines the architecture and implementation details of integrating RunComfy API (for both Flux2 and Trellis2 generation) within Aetheria Studio. It details the hybrid approach taken using a MoonBit backend proxy and frontend JavaScript polling.

## 1. Architecture Overview

### 1.1 The Challenge
RunComfy provides Serverless APIs to execute ComfyUI workflows. However, running these workflows directly from a web frontend (e.g., using `fetch`) usually results in **CORS (Cross-Origin Resource Sharing) blocks** because `api.runcomfy.net` restricts unauthorized domain origins.
Additionally, doing a long-polling task in a MoonBit blocking batch script (`.bat`) freezes the UI entirely.

### 1.2 The Solution
Aetheria Studio adopts a **Hybrid WebUI Architecture**:
- **MoonBit Backend (Proxy):** `cmd/main/main.mbt` exposes two WebUI endpoints (`backend_http_request` and `backend_download_image`). These endpoints execute pure system-level HTTP requests that are immune to browser CORS policies.
- **JavaScript Frontend (Controller):** `assets/app.js` coordinates the logic. It pushes requests to the MoonBit proxy, maintains the `setInterval` / `while` polling loops, and updates the UI DOM (progress texts, borders, error states) fluidly without blocking the main render thread.

## 2. API Polling Implementation (`runcomfyPoll`)

The frontend implements an asynchronous polling function `runcomfyPoll` located in `app.js`.

```javascript
async function runcomfyPoll(prompt_id, conf) { ... }
```

### Key Logic:
1. **Status Checking:** The function calls `/requests/{prompt_id}/status`.
2. **State Machine Compatibility:** It verifies the status against multiple completion indicators: `["SUCCESS", "SUCCEEDED", "COMPLETED", "DONE"]`.
3. **Failure Handling:** It accurately captures failure states: `["FAILED", "CANCELED", "CANCELLED", "TIMEOUT", "ERROR"]`.
4. **Delay:** It waits 2.5 seconds (`setTimeout`) between polls to avoid rate-limiting.

## 3. Result Parsing (`parseRuncomfyResult`)

RunComfy results are deeply nested and vary depending on the ComfyUI nodes used (e.g., standard SaveImage vs Trellis node).

The `parseRuncomfyResult` function gracefully traverses the JSON output:
1. **Trellis2 Output Array (`result[3]`):** Trellis outputs often look like `outputs["149"].result = [filename, null, null, url]`. The parser identifies this specific pattern and extracts the valid URL from the 4th element.
2. **Standard Output Array (`images[].url`):** Checks for `url`, `image_url`, `file_url`, etc.
3. **Log Filtering:** Ensures that the downloaded file is not a text log (e.g., skips `!url.includes("/logs/")` and `!url.endsWith("/comfyui.txt")`).

## 4. End-to-End Pipeline (Flux2 -> Trellis2)

In `generateAll3DAssets` (`app.js`), the process works sequentially:
1. **Flux2 (Text-to-Image):** Generates a multi-view reference image based on the Step 5 prompt.
2. **Trellis2 (Image-to-3D):** Takes the resulting image URL from Flux2 and injects it into a Trellis Payload.
   - **Crucial Override:** `142.inputs.remove_background = true` is injected to ensure RGB compatibility without alpha channel crashes.
   - **Random Seed:** Injects a dynamic `seed` for varied generations.
3. **Downloading:** Uses `backend_download_image` to fetch the `.glb` binary safely to the local `game_XXXX` project folder.

## 5. Switching to Local ComfyUI
The logic in `app.js` is fully aware of `app.config.comfy_mode`. 
If the mode is set to `"local"`, the JS frontend abandons the `fetch` polling approach and delegates the task to the MoonBit backend worker (`comfy_worker` or `comfy_3d_worker`), since local ComfyUI environments (`http://127.0.0.1:8188`) generally don't use the RunComfy API spec.
