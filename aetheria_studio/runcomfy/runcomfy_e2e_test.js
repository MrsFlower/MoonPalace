#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const BASE_URL = "https://api.runcomfy.net/prod/v1/deployments";
const FLUX_DEPLOYMENT_ID = "eca194ca-7090-42bd-a14f-8bd5cfa0f636";
const TRELLIS_DEPLOYMENT_ID = "707d1d90-f493-47eb-b023-a839ce732b27";

const ROOT = __dirname;
const OUTPUT_DIR = path.join(ROOT, "tmp_outputs");
const TRELLIS_WORKFLOW_PATH = path.join(
  ROOT,
  "trellis2",
  "workflow_api_00000000-0000-0000-0000-000000001331.json"
);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function nowTag() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function readToken() {
  if (process.env.RUNCOMFY_API_TOKEN) return process.env.RUNCOMFY_API_TOKEN.trim();
  if (process.env.RUNCOMFY_TOKEN) return process.env.RUNCOMFY_TOKEN.trim();

  const cfgPath = path.join(ROOT, "..", "config.json");
  if (fs.existsSync(cfgPath)) {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    if (cfg.runcomfy_api_key && String(cfg.runcomfy_api_key).trim()) {
      return String(cfg.runcomfy_api_key).trim();
    }
  }
  throw new Error(
    "未找到 RunComfy token。请设置 RUNCOMFY_API_TOKEN 环境变量，或在 aetheria_studio/config.json 中配置 runcomfy_api_key。"
  );
}

function deploymentUrl(deploymentId, suffix) {
  return `${BASE_URL}/${deploymentId}${suffix}`;
}

async function callJson(url, token, options = {}) {
  const headers = {
    Authorization: `Bearer ${token}`,
    ...options.headers
  };
  const res = await fetch(url, {
    ...options,
    headers
  });
  const raw = await res.text();
  let json;
  try {
    json = raw ? JSON.parse(raw) : {};
  } catch {
    json = { raw };
  }
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status} ${res.statusText}`);
    err.response = json;
    throw err;
  }
  return json;
}

async function submitInference(deploymentId, token, payload) {
  const url = deploymentUrl(deploymentId, "/inference");
  const body = JSON.stringify(payload);
  const json = await callJson(url, token, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body
  });
  const requestId = json.request_id || json.run_id || json.id;
  if (!requestId) {
    const err = new Error("推理请求未返回 request_id/run_id/id");
    err.response = json;
    throw err;
  }
  return { requestId, raw: json };
}

async function getStatus(deploymentId, token, requestId) {
  const url = deploymentUrl(deploymentId, `/requests/${requestId}/status`);
  return callJson(url, token, { method: "GET" });
}

async function getResult(deploymentId, token, requestId) {
  const url = deploymentUrl(deploymentId, `/requests/${requestId}/result`);
  return callJson(url, token, { method: "GET" });
}

async function waitForSuccess(deploymentId, token, requestId, timeoutMs = 30 * 60 * 1000) {
  const started = Date.now();
  while (true) {
    const st = await getStatus(deploymentId, token, requestId);
    const status = String(st.status || "").toUpperCase();
    const progress = st.progress ? ` progress=${JSON.stringify(st.progress)}` : "";
    console.log(`[${deploymentId}] status=${status || "UNKNOWN"}${progress}`);

    if (["SUCCESS", "SUCCEEDED", "COMPLETED", "DONE"].includes(status)) return st;
    if (["FAILED", "CANCELED", "CANCELLED", "TIMEOUT", "ERROR"].includes(status)) {
      const err = new Error(`任务失败: ${status}`);
      err.response = st;
      throw err;
    }
    if (Date.now() - started > timeoutMs) {
      const err = new Error("等待任务超时");
      err.response = st;
      throw err;
    }
    await sleep(2500);
  }
}

function collectArtifactsFromResult(result) {
  const out = [];
  const seen = new Set();

  function classify(url, filename = "", type = "") {
    const u = String(url || "").toLowerCase();
    const f = String(filename || "").toLowerCase();
    const t = String(type || "").toLowerCase();
    if (u.endsWith(".glb") || f.endsWith(".glb") || t.includes("model")) return "model";
    if (u.endsWith(".png") || u.endsWith(".jpg") || u.endsWith(".jpeg") || u.endsWith(".webp")) return "image";
    if (f.endsWith(".png") || f.endsWith(".jpg") || f.endsWith(".jpeg") || f.endsWith(".webp")) return "image";
    return "unknown";
  }

  function push(url, filenameHint, kind, source) {
    if (!url || !(url.startsWith("http://") || url.startsWith("https://"))) return;
    if (url.includes("/logs/") || url.endsWith("/comfyui.txt")) return;
    const key = `${kind}|${url}`;
    if (seen.has(key)) return;
    seen.add(key);
    out.push({ url, filenameHint, kind, source });
  }

  const outputs = result && typeof result === "object" ? result.outputs : null;
  if (outputs && typeof outputs === "object") {
    for (const [nodeId, nodeOutput] of Object.entries(outputs)) {
      if (!nodeOutput || typeof nodeOutput !== "object") continue;
      for (const [bucket, arr] of Object.entries(nodeOutput)) {
        if (!Array.isArray(arr)) continue;
        // Some RunComfy nodes (e.g. Preview3D) return: [filename, _, _, url]
        if (
          bucket === "result" &&
          arr.length >= 4 &&
          typeof arr[0] === "string" &&
          typeof arr[3] === "string" &&
          (arr[3].startsWith("http://") || arr[3].startsWith("https://"))
        ) {
          const kind = classify(arr[3], arr[0], bucket);
          push(arr[3], arr[0], kind, `outputs.${nodeId}.${bucket}[3]`);
        }
        for (const item of arr) {
          if (!item || typeof item !== "object") continue;
          const url = item.url || item.file_url || item.image_url || item.download_url || item.signed_url;
          const filenameHint = item.filename || item.name || item.file_name || "";
          const kind = classify(url, filenameHint, item.type || bucket);
          push(url, filenameHint, kind, `outputs.${nodeId}.${bucket}`);
        }
      }
    }
  }

  for (const key of ["url", "file_url", "image_url", "download_url", "signed_url"]) {
    if (result && typeof result[key] === "string") {
      push(result[key], "", classify(result[key]), `result.${key}`);
    }
  }
  return out;
}

function guessExtension(contentType, fallback = ".bin") {
  const ct = String(contentType || "").toLowerCase();
  if (ct.includes("image/png")) return ".png";
  if (ct.includes("image/jpeg")) return ".jpg";
  if (ct.includes("image/webp")) return ".webp";
  if (ct.includes("model/gltf-binary")) return ".glb";
  if (ct.includes("application/octet-stream")) return fallback;
  return fallback;
}

async function downloadFile(url, outPath) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`下载失败: ${res.status} ${res.statusText} url=${url}`);
  }
  const arr = await res.arrayBuffer();
  fs.writeFileSync(outPath, Buffer.from(arr));
  return {
    contentType: res.headers.get("content-type") || "",
    size: Buffer.byteLength(Buffer.from(arr))
  };
}

function isPng(buf) {
  if (!buf || buf.length < 8) return false;
  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  return sig.every((b, i) => buf[i] === b);
}

function isJpeg(buf) {
  return !!buf && buf.length > 2 && buf[0] === 0xff && buf[1] === 0xd8;
}

function isWebp(buf) {
  return (
    !!buf &&
    buf.length > 12 &&
    buf.toString("ascii", 0, 4) === "RIFF" &&
    buf.toString("ascii", 8, 12) === "WEBP"
  );
}

function isGlb(buf) {
  return !!buf && buf.length > 4 && buf.toString("ascii", 0, 4) === "glTF";
}

function toDataUri(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const mime = ext === ".png" ? "image/png" : ext === ".webp" ? "image/webp" : "image/jpeg";
  const b64 = fs.readFileSync(filePath).toString("base64");
  return `data:${mime};base64,${b64}`;
}

function buildPrompt() {
  return [
    "A stylized miniature guardian golem made of mossy stone and polished brass, standing on an ancient floating ruin",
    "full body character, clean silhouette, centered composition, soft global illumination",
    "neutral background with subtle depth gradient, physically based rendering feel, highly detailed surface materials"
  ].join(", ");
}

function patchTrellisWorkflowForDataUri(workflowJson, dataUri, prefix) {
  const cloned = JSON.parse(JSON.stringify(workflowJson));
  if (!cloned["279"] || !cloned["279"].inputs) {
    throw new Error("workflow_api_json 中未找到 Trellis 节点 279.inputs.image");
  }
  cloned["279"].inputs.image = dataUri;
  if (cloned["142"] && cloned["142"].inputs) {
    // Flux output is often RGB-only; force Trellis preprocessor to remove background.
    cloned["142"].inputs.remove_background = true;
  }
  if (cloned["140"] && cloned["140"].inputs) cloned["140"].inputs.filename_prefix = prefix;
  if (cloned["278"] && cloned["278"].inputs) {
    cloned["278"].inputs.seed = Math.floor(Math.random() * 1000000000);
  }
  return cloned;
}

async function run() {
  ensureDir(OUTPUT_DIR);
  const token = readToken();
  const tag = nowTag();
  const prompt = buildPrompt();

  console.log("=== Step 1: Flux2 文生图 ===");
  console.log("Prompt:", prompt);
  const fluxPayload = {
    overrides: {
      "76": {
        inputs: { value: prompt }
      }
    }
  };
  const fluxSubmit = await submitInference(FLUX_DEPLOYMENT_ID, token, fluxPayload);
  console.log("Flux request_id:", fluxSubmit.requestId);
  await waitForSuccess(FLUX_DEPLOYMENT_ID, token, fluxSubmit.requestId);
  const fluxResult = await getResult(FLUX_DEPLOYMENT_ID, token, fluxSubmit.requestId);
  if (String(fluxResult.status || "").toLowerCase() === "failed") {
    throw new Error(`Flux result failed: ${JSON.stringify(fluxResult.error || fluxResult, null, 2)}`);
  }
  fs.writeFileSync(
    path.join(OUTPUT_DIR, `${tag}_flux_result.json`),
    JSON.stringify(fluxResult, null, 2),
    "utf8"
  );

  const fluxCandidates = collectArtifactsFromResult(fluxResult).filter((x) => x.kind === "image");
  if (!fluxCandidates.length) {
    throw new Error("Flux result 未解析出可下载图片 URL，请检查 *_flux_result.json");
  }
  const fluxUrl = fluxCandidates[0].url;
  const fluxImagePath = path.join(OUTPUT_DIR, `${tag}_flux.png`);
  const fluxDownloaded = await downloadFile(fluxUrl, fluxImagePath);
  const fluxBytes = fs.readFileSync(fluxImagePath);
  if (!(isPng(fluxBytes) || isJpeg(fluxBytes) || isWebp(fluxBytes))) {
    throw new Error("Flux 下载结果不是合法图片文件（可能错误下载了日志或文本）");
  }
  console.log("Flux 图片已下载:", fluxImagePath, fluxDownloaded);

  console.log("=== Step 2: Trellis2 图生3D ===");
  const imageDataUri = toDataUri(fluxImagePath);
  const trellisPrefix = `e2e_${tag}`;

  let trellisSubmit;
  let trellisMode = "overrides";
  try {
    const trellisOverridesPayload = {
      overrides: {
        "279": { inputs: { image: imageDataUri } },
        "142": { inputs: { remove_background: true } },
        "140": { inputs: { filename_prefix: trellisPrefix } },
        "278": { inputs: { seed: Math.floor(Math.random() * 1000000000) } }
      }
    };
    trellisSubmit = await submitInference(TRELLIS_DEPLOYMENT_ID, token, trellisOverridesPayload);
  } catch (err) {
    console.log("Trellis overrides 模式失败，尝试 dynamic workflow。", err.response || err.message);
    const wf = JSON.parse(fs.readFileSync(TRELLIS_WORKFLOW_PATH, "utf8"));
    const patchedWorkflow = patchTrellisWorkflowForDataUri(wf, imageDataUri, trellisPrefix);
    const dynamicPayload = { workflow_api_json: patchedWorkflow };
    trellisSubmit = await submitInference(TRELLIS_DEPLOYMENT_ID, token, dynamicPayload);
    trellisMode = "dynamic-workflow";
  }

  console.log("Trellis request_id:", trellisSubmit.requestId, "mode:", trellisMode);
  await waitForSuccess(TRELLIS_DEPLOYMENT_ID, token, trellisSubmit.requestId, 50 * 60 * 1000);
  const trellisResult = await getResult(TRELLIS_DEPLOYMENT_ID, token, trellisSubmit.requestId);
  if (String(trellisResult.status || "").toLowerCase() === "failed") {
    throw new Error(`Trellis result failed: ${JSON.stringify(trellisResult.error || trellisResult, null, 2)}`);
  }
  fs.writeFileSync(
    path.join(OUTPUT_DIR, `${tag}_trellis_result.json`),
    JSON.stringify(trellisResult, null, 2),
    "utf8"
  );

  const trellisCandidates = collectArtifactsFromResult(trellisResult).filter((x) => x.kind === "model");
  if (!trellisCandidates.length) {
    throw new Error("Trellis result 未解析出可下载模型 URL，请检查 *_trellis_result.json");
  }

  let modelSaved = null;
  for (let i = 0; i < trellisCandidates.length; i += 1) {
    const cand = trellisCandidates[i];
    const fallbackName = `${tag}_trellis_${i + 1}.glb`;
    const hinted = cand.filenameHint && path.extname(cand.filenameHint) ? cand.filenameHint : fallbackName;
    const ext = path.extname(hinted) || ".glb";
    const outPath = path.join(OUTPUT_DIR, `${path.basename(hinted, path.extname(hinted))}${ext}`);
    try {
      const info = await downloadFile(cand.url, outPath);
      let finalPath = outPath;
      if (ext === ".bin") {
        const guessed = guessExtension(info.contentType, ".bin");
        if (guessed !== ".bin") {
          finalPath = path.join(OUTPUT_DIR, `${path.basename(outPath, ".bin")}${guessed}`);
          fs.renameSync(outPath, finalPath);
        }
      }
      console.log("Trellis 模型候选已下载:", finalPath, info, "from", cand.source);
      if (finalPath.toLowerCase().endsWith(".glb") && isGlb(fs.readFileSync(finalPath))) {
        modelSaved = finalPath;
        break;
      }
    } catch (e) {
      console.log("下载候选失败:", cand.url, e.message);
    }
  }

  if (!modelSaved) {
    throw new Error("已拿到候选 URL，但未成功下载到 glb 模型。请查看 tmp_outputs 下结果 JSON 调整解析键。");
  }

  console.log("=== E2E 成功 ===");
  console.log("图片:", fluxImagePath);
  console.log("模型:", modelSaved);
}

run().catch((err) => {
  console.error("E2E 失败:", err.message);
  if (err.response) {
    console.error("远端返回:", JSON.stringify(err.response, null, 2));
  }
  process.exitCode = 1;
});
