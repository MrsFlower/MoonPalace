#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const STUDIO_ROOT = path.resolve(ROOT, "..");
const DEFAULT_COMFY_URL = process.env.COMFY_URL || "http://127.0.0.1:8188";
const DEFAULT_IMAGE = path.resolve(
  STUDIO_ROOT,
  "..",
  "Projects",
  "game_1776617205",
  "5.png"
);
const WORKFLOW_PATH = path.resolve(STUDIO_ROOT, "Trellis2.json");
const OUTPUT_DIR = path.resolve(ROOT, "tmp_local_offline");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function nowTag() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {
    comfyUrl: DEFAULT_COMFY_URL,
    imagePath: DEFAULT_IMAGE,
    outputPrefix: `offline_${nowTag()}`,
    fast: true
  };
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (a === "--url" && args[i + 1]) out.comfyUrl = args[++i];
    else if (a === "--image" && args[i + 1]) out.imagePath = path.resolve(args[++i]);
    else if (a === "--prefix" && args[i + 1]) out.outputPrefix = args[++i];
    else if (a === "--no-fast") out.fast = false;
  }
  return out;
}

async function callJson(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const e = new Error(`HTTP ${res.status} ${res.statusText}`);
    e.response = json;
    throw e;
  }
  return json;
}

async function uploadImage(comfyUrl, imagePath) {
  const bytes = fs.readFileSync(imagePath);
  const name = path.basename(imagePath);
  const fd = new FormData();
  fd.append("image", new Blob([bytes]), name);
  const json = await callJson(`${comfyUrl}/upload/image`, { method: "POST", body: fd });
  if (!json.name) {
    throw new Error(`上传返回缺少 name: ${JSON.stringify(json)}`);
  }
  return json.name;
}

function patchWorkflow(baseWorkflow, uploadedFilename, prefix, fastMode) {
  const wf = JSON.parse(JSON.stringify(baseWorkflow));
  const randomSeed = Math.floor(Math.random() * 1000000000);

  if (wf["13"]?.inputs) wf["13"].inputs.image = uploadedFilename;
  if (wf["35"]?.inputs) wf["35"].inputs.value = prefix;
  if (wf["12"]?.inputs) wf["12"].inputs.remove_background = true;

  for (const id of ["17", "20", "25"]) {
    if (wf[id]?.inputs) wf[id].inputs.seed = randomSeed;
  }

  if (fastMode) {
    // 加速离线调试，先确保链路可用；确认稳定后可用 --no-fast 跑高质量。
    if (wf["17"]?.inputs) {
      wf["17"].inputs.shape_steps = 8;
      wf["17"].inputs.sparse_structure_steps = 8;
      wf["17"].inputs.texture_steps = 8;
      wf["17"].inputs.max_views = 2;
      wf["17"].inputs.pipeline_type = "512";
    }
    if (wf["20"]?.inputs) {
      wf["20"].inputs.shape_steps = 8;
      wf["20"].inputs.texture_steps = 8;
      wf["20"].inputs.max_views = 2;
      wf["20"].inputs.resolution = 512;
    }
    if (wf["25"]?.inputs) {
      wf["25"].inputs.texture_steps = 8;
      wf["25"].inputs.resolution = 512;
      wf["25"].inputs.texture_size = 1024;
      wf["25"].inputs.max_views = 2;
    }
  }
  return wf;
}

async function queuePrompt(comfyUrl, workflow) {
  const payload = { prompt: workflow };
  const json = await callJson(`${comfyUrl}/prompt`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  if (!json.prompt_id) {
    throw new Error(`未返回 prompt_id: ${JSON.stringify(json)}`);
  }
  return json.prompt_id;
}

function getByPath(obj, p) {
  return p.split(".").reduce((acc, key) => (acc && key in acc ? acc[key] : undefined), obj);
}

function collectCandidatesFromOutputs(outputs) {
  const candidates = [];
  const seen = new Set();

  function push(filename, subfolder, type, source) {
    if (!filename || !String(filename).toLowerCase().endsWith(".glb")) return;
    const key = `${filename}|${subfolder}|${type}`;
    if (seen.has(key)) return;
    seen.add(key);
    candidates.push({ filename, subfolder: subfolder || "", type: type || "output", source });
  }

  for (const [nodeId, nodeOutput] of Object.entries(outputs || {})) {
    if (!nodeOutput || typeof nodeOutput !== "object") continue;
    for (const [bucket, value] of Object.entries(nodeOutput)) {
      // 标准结构: [{filename,subfolder,type}]
      if (Array.isArray(value)) {
        for (let i = 0; i < value.length; i += 1) {
          const item = value[i];
          if (item && typeof item === "object" && !Array.isArray(item)) {
            push(item.filename, item.subfolder, item.type, `outputs.${nodeId}.${bucket}[${i}]`);
          }
        }
        // 部分节点 result 结构: [filename, subfolder, type] 或 [filename, null, null, url]
        if (value.length >= 1 && typeof value[0] === "string" && value[0].toLowerCase().endsWith(".glb")) {
          const subfolder = typeof value[1] === "string" ? value[1] : "";
          const type = typeof value[2] === "string" ? value[2] : "output";
          push(value[0], subfolder, type, `outputs.${nodeId}.${bucket}[tuple]`);
        }
      }
      // 极端情况: 直接对象包裹
      if (value && typeof value === "object" && !Array.isArray(value)) {
        push(value.filename, value.subfolder, value.type, `outputs.${nodeId}.${bucket}`);
      }
    }
  }
  return candidates;
}

function isGlb(buffer) {
  return buffer && buffer.length >= 4 && buffer.toString("ascii", 0, 4) === "glTF";
}

async function downloadCandidate(comfyUrl, cand, outPath) {
  let filenameForView = cand.filename;
  if (filenameForView.includes("\\")) {
    const parts = filenameForView.split("\\");
    filenameForView = parts[parts.length - 1];
  }
  if (filenameForView.includes("/")) {
    const parts = filenameForView.split("/");
    filenameForView = parts[parts.length - 1];
  }
  const q = new URLSearchParams({
    filename: filenameForView,
    type: cand.type || "output"
  });
  if (cand.subfolder) q.set("subfolder", cand.subfolder);
  const url = `${comfyUrl}/view?${q.toString()}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`下载失败 ${res.status}: ${url}`);
  }
  const arr = await res.arrayBuffer();
  const buf = Buffer.from(arr);
  fs.writeFileSync(outPath, buf);
  return { size: buf.length, glb: isGlb(buf), url };
}

async function waitHistoryDone(comfyUrl, promptId, timeoutMs = 40 * 60 * 1000) {
  const started = Date.now();
  while (true) {
    const hist = await callJson(`${comfyUrl}/history/${promptId}`, { method: "GET" });
    const item = hist[promptId];
    if (item) return { historyAll: hist, historyItem: item };
    if (Date.now() - started > timeoutMs) {
      throw new Error(`等待 history 超时: prompt_id=${promptId}`);
    }
    process.stdout.write(".");
    await sleep(2000);
  }
}

async function run() {
  ensureDir(OUTPUT_DIR);
  const cfg = parseArgs();
  if (!fs.existsSync(cfg.imagePath)) throw new Error(`输入图片不存在: ${cfg.imagePath}`);
  if (!fs.existsSync(WORKFLOW_PATH)) throw new Error(`找不到 Trellis2.json: ${WORKFLOW_PATH}`);

  console.log("ComfyUI:", cfg.comfyUrl);
  console.log("Image:", cfg.imagePath);
  console.log("Prefix:", cfg.outputPrefix, "fastMode:", cfg.fast);

  const workflowBase = JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
  const uploaded = await uploadImage(cfg.comfyUrl, cfg.imagePath);
  console.log("上传成功:", uploaded);

  const workflow = patchWorkflow(workflowBase, uploaded, cfg.outputPrefix, cfg.fast);
  const promptId = await queuePrompt(cfg.comfyUrl, workflow);
  console.log("已提交 prompt_id:", promptId);
  console.log("等待 history 完成");

  const { historyAll, historyItem } = await waitHistoryDone(cfg.comfyUrl, promptId);
  console.log("\n任务完成，开始解析 outputs");

  const dumpPath = path.join(OUTPUT_DIR, `${cfg.outputPrefix}_history.json`);
  fs.writeFileSync(dumpPath, JSON.stringify(historyAll, null, 2), "utf8");
  console.log("history 已保存:", dumpPath);

  const outputs = getByPath(historyItem, "outputs") || {};
  const candidates = collectCandidatesFromOutputs(outputs);
  console.log("解析到 GLB 候选数:", candidates.length);
  for (const c of candidates) console.log(" -", c.filename, `(${c.source})`);

  if (!candidates.length) {
    throw new Error("outputs 中未找到任何 GLB 候选。请查看 history 文件确认真实返回结构。");
  }

  let okPath = null;
  for (let i = 0; i < candidates.length; i += 1) {
    const c = candidates[i];
    const localName = `${cfg.outputPrefix}_${i + 1}_${path.basename(c.filename)}`;
    const localPath = path.join(OUTPUT_DIR, localName);
    try {
      const info = await downloadCandidate(cfg.comfyUrl, c, localPath);
      console.log("下载:", localPath, info);
      if (info.size > 100 && info.glb) {
        okPath = localPath;
        break;
      }
    } catch (e) {
      console.log("下载候选失败:", e.message);
    }
  }

  if (!okPath) {
    throw new Error("候选都下载失败或不是合法 GLB。");
  }
  console.log("离线 Trellis2 测试成功，模型文件:", okPath);
}

run().catch((err) => {
  console.error("离线测试失败:", err.message);
  if (err.response) console.error(JSON.stringify(err.response, null, 2));
  process.exitCode = 1;
});
