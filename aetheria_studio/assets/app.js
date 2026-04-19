const app = {
    pollInterval: null,
    gameState: null,
    currentNode: null,
    project_id: "test_proj",

    configData: null,
    
    i18n: {
        EN: {
            nav_generator: "Generator",
            nav_preview: "2D Preview",
            nav_3d_model: "3D Model Generation",
            nav_settings: "Settings",
            title_pipeline: "Game Generator Pipeline",
            lbl_prompt: "Game Concept / Prompt:",
            btn_concept: "1. Generate Concept",
            btn_generate: "2. Confirm & Start Pipeline",
            btn_assets: "3. Batch Generate 2D Assets",
            tab_step0: "Concept",
            tab_step1: "World Bible",
            tab_step2: "Blueprint",
            tab_step3: "Script",
            tab_step4: "JSON",
            tab_step5: "2D Image Prompts",
            tab_step6: "2D Queue",
            title_3d_model: "3D Asset Generation",
            btn_generate_3d: "Generate 3D Models",
            btn_start_3d_preview: "3D Game Preview",
            btn_start_raylib: "Start Raylib Render",
            btn_load_project: "Load Existing Project",
            btn_start_game: "Start Game / Refresh",
            title_settings: "Configuration",
            title_preview: "2D Game Preview",
            lbl_provider: "API Provider",
            lbl_struct_url: "Structural API URL (For JSON gen)",
            lbl_struct_key: "Structural API Key",
            lbl_struct_model: "Structural Model Name",
            lbl_create_url: "Creative API URL (For text gen)",
            lbl_create_key: "Creative API Key",
            lbl_create_model: "Creative Model Name",
            lbl_system: "System Settings",
            lbl_comfy: "ComfyUI Server URL",
            lbl_lang: "Language",
            btn_save: "Save Configuration",
            btn_test_struct: "Test Structural API",
            btn_test_create: "Test Creative API"
        },
        ZH: {
            nav_generator: "创作工作台",
            nav_preview: "2D 游戏预览",
            nav_3d_model: "3D 模型生成",
            nav_settings: "系统设置",
            title_pipeline: "AI 游戏生成管线",
            lbl_prompt: "创作灵感 / 游戏大纲:",
            btn_concept: "1. 快速生成核心概念",
            btn_generate: "2. 确认无误，开始生成管线",
            btn_assets: "3. 批量生成 2D 资产",
            tab_step0: "核心概念",
            tab_step1: "世界观设定",
            tab_step2: "状态机蓝图",
            tab_step3: "分镜剧本",
            tab_step4: "最终 JSON",
            tab_step5: "2D 图片生成提示词",
            tab_step6: "待生成图片列表",
            title_3d_model: "3D 模型生成列表",
            btn_generate_3d: "批量生成 3D 模型",
            btn_start_3d_preview: "3D游戏预览",
            btn_start_raylib: "启动Raylib渲染",
            btn_load_project: "加载已有项目目录",
            btn_start_game: "启动游戏 / 刷新",
            title_settings: "系统配置",
            title_preview: "2D 游戏预览",
            lbl_provider: "AI 大模型提供商",
            lbl_struct_url: "结构化模型 API URL (用于生成 JSON)",
            lbl_struct_key: "结构化模型 API Key",
            lbl_struct_model: "结构化模型名称",
            lbl_create_url: "创造性模型 API URL (用于生成文本)",
            lbl_create_key: "创造性模型 API Key",
            lbl_create_model: "创造性模型名称",
            lbl_system: "系统设置",
            lbl_comfy: "ComfyUI 服务端地址",
            lbl_lang: "界面语言",
            btn_save: "保存配置",
            btn_test_struct: "测试结构化模型连通性",
            btn_test_create: "测试创造性模型连通性"
        }
    },

    init: function() {
        console.log("App init started...");
        this.loadConfig();
        this.fetchState();
        setInterval(() => {
            try {
                this.fetchState();
            } catch(e) {
                console.error("fetchState interval error:", e);
            }
        }, 3000);
        console.log("App init finished.");
    },

    applyLanguage: function() {
        let lang = "EN";
        if (this.configData && this.configData.lang === "ZH") {
            lang = "ZH";
        }
        let dict = this.i18n[lang];

        let el = document.getElementById('nav-generator'); if (el) el.innerText = dict.nav_generator;
        el = document.getElementById('nav-preview'); if (el) el.innerText = dict.nav_preview;
        el = document.getElementById('nav-3d-model'); if (el) el.innerText = dict.nav_3d_model;
        el = document.getElementById('nav-settings'); if (el) el.innerText = dict.nav_settings;
        el = document.getElementById('title-pipeline'); if (el) el.innerText = dict.title_pipeline;
        el = document.getElementById('lbl-prompt'); if (el) el.innerText = dict.lbl_prompt;
        el = document.getElementById('btnGenerate'); if (el) el.innerText = dict.btn_concept;
        el = document.getElementById('btnStartPipeline'); if (el) el.innerText = dict.btn_generate;
        el = document.getElementById('btnGenAssets'); if (el) el.innerText = dict.btn_assets;
        el = document.getElementById('btnLoadProject'); if (el) el.innerText = dict.btn_load_project;
        
        let activeTab = document.querySelector('.step-tab.active');
        let activeId = activeTab ? activeTab.id : null;
        
        el = document.getElementById('tab-step0'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step0"></span> ' + dict.tab_step0;
        el = document.getElementById('tab-step1'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step1"></span> ' + dict.tab_step1;
        el = document.getElementById('tab-step2'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step2"></span> ' + dict.tab_step2;
        el = document.getElementById('tab-step3'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step3"></span> ' + dict.tab_step3;
        el = document.getElementById('tab-step4'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step4"></span> ' + dict.tab_step4;
        el = document.getElementById('tab-step5'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step5"></span> ' + dict.tab_step5;
        el = document.getElementById('tab-step6'); if (el) el.innerHTML = '<span class="status-dot" id="dot-step6"></span> ' + dict.tab_step6;
        
        if (activeId) {
            el = document.getElementById(activeId); if (el) el.classList.add('active');
        }
        
        el = document.getElementById('title-3d-model'); if (el) el.innerText = dict.title_3d_model;
        el = document.getElementById('btnGenerate3D'); if (el) el.innerText = dict.btn_generate_3d;
        el = document.getElementById('btnStart3DGame'); if (el) el.innerText = dict.btn_start_3d_preview;
        el = document.getElementById('btnStartRaylib'); if (el) el.innerText = dict.btn_start_raylib;
        el = document.getElementById('title-preview'); if (el) el.innerText = dict.title_preview;
        el = document.getElementById('btnStartGame'); if (el) el.innerText = dict.btn_start_game;
        
        el = document.getElementById('title-settings'); if (el) el.innerText = dict.title_settings;
        el = document.getElementById('lbl-provider'); if (el) el.innerText = dict.lbl_provider;
        el = document.getElementById('lbl-struct-url'); if (el) el.innerText = dict.lbl_struct_url;
        el = document.getElementById('lbl-struct-key'); if (el) el.innerText = dict.lbl_struct_key;
        el = document.getElementById('lbl-struct-model'); if (el) el.innerText = dict.lbl_struct_model;
        el = document.getElementById('lbl-create-url'); if (el) el.innerText = dict.lbl_create_url;
        el = document.getElementById('lbl-create-key'); if (el) el.innerText = dict.lbl_create_key;
        el = document.getElementById('lbl-create-model'); if (el) el.innerText = dict.lbl_create_model;
        el = document.getElementById('lbl-system'); if (el) el.innerText = dict.lbl_system;
        el = document.getElementById('lbl-comfy'); if (el) el.innerText = dict.lbl_comfy;
        el = document.getElementById('lbl-lang'); if (el) el.innerText = dict.lbl_lang;
        el = document.getElementById('btnSave'); if (el) el.innerText = dict.btn_save;
        el = document.getElementById('btnTestStruct'); if (el) el.innerText = dict.btn_test_struct;
        el = document.getElementById('btnTestCreate'); if (el) el.innerText = dict.btn_test_create;
        
        this.updateProviderFields(); // refresh API titles
        if (this.gameState) {
            // Give DOM a tick to update before fetching state to re-apply classes to dots
            setTimeout(() => this.fetchState(), 0);
        }
    },

    switchLanguage: function() {
        if (this.configData) {
            this.configData.lang = document.getElementById('cfg-lang').value;
            this.applyLanguage();
            // Save immediately when language changes to persist across reloads
            this.saveConfig();
        }
    },

    // Keep filename generation consistent with backend MoonBit logic:
    // - strip non-ASCII chars
    // - replace spaces with underscores
    // - apply fallback when empty
    toSafeAssetId: function(raw, fallback) {
        let src = String(raw || "");
        let out = "";
        for (let i = 0; i < src.length; i++) {
            const code = src.charCodeAt(i);
            if (code >= 32 && code <= 126) out += src[i];
        }
        out = out.replace(/ /g, "_");
        if (!out || out === "_") out = fallback || "asset";
        return out;
    },

    setTextIfExists: function(id, text) {
        let el = document.getElementById(id);
        if (el) el.innerText = text;
    },

    setStyleIfExists: function(id, prop, value) {
        let el = document.getElementById(id);
        if (el) el.style[prop] = value;
    },

    setStatus: function(text, isError = false) {
        let el = document.getElementById('statusText');
        if (!el) return;
        el.innerText = text;
        el.style.color = isError ? '#ff7777' : '#888';
    },

    showTab: function(tabId) {
        document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
        document.querySelectorAll('.menu-item').forEach(el => el.classList.remove('active'));
        
        document.getElementById(tabId).classList.add('active');
        document.getElementById('nav-' + tabId).classList.add('active');
        
        // Handle polling intervals based on active tab
        if (tabId === '3d-model') {
            this.fetch3DStatus();
            if (!this.modelPollInterval) {
                this.modelPollInterval = setInterval(() => this.fetch3DStatus(), 2000);
            }
        } else {
            if (this.modelPollInterval) {
                clearInterval(this.modelPollInterval);
                this.modelPollInterval = null;
            }
        }
        
        // Hide image polling if leaving generator step 6
        if (tabId !== 'generator') {
            if (this.imagePollInterval) {
                clearInterval(this.imagePollInterval);
                this.imagePollInterval = null;
            }
        }
    },

    showStepContent: function(stepIndex) {
        document.querySelectorAll('.step-tab').forEach(el => el.classList.remove('active'));
        let currentTab = document.getElementById('tab-step' + stepIndex);
        if (currentTab) currentTab.classList.add('active');
        
        let view = document.getElementById('stepContentView');
        let step6View = document.getElementById('step-content-6');
        
        if (stepIndex === 6) {
            // Show Image Queue tab content
            if (view) view.style.display = 'none';
            if (step6View) step6View.style.display = 'block';
            
            // Start polling for image queue status
            this.fetchImageStatus();
            if (!this.imagePollInterval) {
                this.imagePollInterval = setInterval(() => this.fetchImageStatus(), 2000);
            }
            
            // Hide retry button for queue tab
            let btnRegen = document.getElementById('btnRegenerateStep');
            if (btnRegen) btnRegen.style.display = 'none';
            let stepError = document.getElementById('stepErrorMsg');
            if (stepError) stepError.innerText = '';
        } else {
            // Show text content for other tabs
            if (view) view.style.display = 'block';
            if (step6View) step6View.style.display = 'none';
            
            // Stop image polling
            if (this.imagePollInterval) {
                clearInterval(this.imagePollInterval);
                this.imagePollInterval = null;
            }
            
            let contentBox = document.getElementById('stepContentView');
            if (this.gameState && this.gameState.step_contents && this.gameState.step_contents[stepIndex]) {
                contentBox.value = this.gameState.step_contents[stepIndex];
            } else {
                contentBox.value = "No content available yet for this step.";
            }
            
            let btnRetry = document.getElementById('btnRegenerateStep');
            let errorMsg = document.getElementById('stepErrorMsg');
            let content = contentBox ? contentBox.value : "";
            
            if (content.startsWith("Error:")) {
                if (errorMsg) errorMsg.innerText = "LLM Generation Failed for this step.";
                if (btnRetry) btnRetry.style.display = 'inline-block';
            } else if (content !== "No content available yet for this step." && content !== "" && this.gameState && this.gameState.current_step !== stepIndex) {
                if (errorMsg) errorMsg.innerText = "";
                if (btnRetry) btnRetry.style.display = 'inline-block';
            } else {
                if (errorMsg) errorMsg.innerText = "";
                if (btnRetry) btnRetry.style.display = 'none';
            }
        }
    },

    saveStepContent: function() {
        if (typeof webui === 'undefined') return;
        let activeTab = document.querySelector('.step-tab.active');
        if (!activeTab) return;
        let stepIndex = parseInt(activeTab.id.replace('tab-step', ''));
        let newContent = document.getElementById('stepContentView').value;
        
        if (this.gameState && this.gameState.step_contents) {
            this.gameState.step_contents[stepIndex] = newContent;
            webui.call('backend_save_step_content', JSON.stringify({ step: stepIndex, content: newContent }));
        }
    },

    fetchState: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_get_state', '').then(res => {
            if (res) {
                this.gameState = JSON.parse(res);
                this.project_id = this.gameState.project_id || "test_proj";
                
                if (this.gameState.draft_text) {
                    let promptBox = document.getElementById('prompt');
                    if (promptBox && document.activeElement !== promptBox) {
                        promptBox.value = this.gameState.draft_text;
                    }
                }
                
                // Update UI lights
                for (let i = 0; i < 6; i++) {
                    let dot = document.getElementById('dot-step' + i);
                    if (!dot) continue;
                    
                    // Keep the class list clean
                    dot.className = 'status-dot';
                    
                    if (this.gameState.current_step === i) {
                        dot.classList.add('yellow'); // In progress
                    } else if (this.gameState.step_contents && this.gameState.step_contents[i] && this.gameState.step_contents[i] !== "") {
                        if (this.gameState.step_contents[i].startsWith("Error:")) {
                            dot.classList.add('red'); // Error
                        } else {
                            dot.classList.add('green'); // Done
                        }
                    }
                }
                
                // Update active tab text content and error msgs if applicable
                let activeTab = document.querySelector('.step-tab.active');
                if (activeTab) {
                    let step = parseInt(activeTab.id.replace('tab-step', ''));
                    if (step < 6) {
                        let contentBox = document.getElementById('stepContentView');
                        let errorMsg = document.getElementById('stepErrorMsg');
                        let btnRegen = document.getElementById('btnRegenerateStep');
                        
                        if (this.gameState.step_contents && this.gameState.step_contents[step]) {
                            // Do not overwrite user typing
                            if (document.activeElement !== contentBox) {
                                contentBox.value = this.gameState.step_contents[step];
                            }
                            
                            if (this.gameState.step_contents[step].startsWith("Error:")) {
                                errorMsg.innerText = "Generation failed for this step. Check logs.";
                                btnRegen.style.display = "inline-block";
                            } else {
                                errorMsg.innerText = "";
                                // Show regenerate button for completed steps as well
                                btnRegen.style.display = "inline-block";
                            }
                        } else {
                            if (document.activeElement !== contentBox) {
                                contentBox.value = "No content available yet for this step.";
                            }
                            errorMsg.innerText = "";
                            btnRegen.style.display = "none";
                        }
                    }
                }

                // Keep UI updated if we are not generating and the textarea is not focused
                if (!this.pollInterval && document.activeElement !== document.getElementById('stepContentView')) {
                    if (this.gameState.step_contents && this.gameState.step_contents[0] && this.gameState.step_contents[0] !== "") {
                        let btnStart = document.getElementById('btnStartPipeline');
                        if (btnStart) btnStart.disabled = false;
                    }
                    if (this.gameState.step_contents && this.gameState.step_contents[4] && this.gameState.step_contents[4] !== "") {
                        let btnAssets = document.getElementById('btnGenAssets');
                        if (btnAssets) btnAssets.disabled = false;
                    }
                }
            }
        }).catch(err => console.error("Failed to fetch state:", err));
    },

    loadProject: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_load_project', '').then(res => {
            if (res === "failed") {
                this.setStatus("加载项目失败。", true);
            } else if (res === "cancelled") {
                // do nothing
            } else {
                this.project_id = res;
                this.fetchState();
                setTimeout(() => {
                    this.fetchState();
                    setTimeout(() => this.showStepContent(this.findNextIncompleteStep()), 150);
                }, 150);
                this.setStatus("项目已加载。");
            }
        }).catch(err => this.setStatus("加载项目异常: " + err, true));
    },

    findNextIncompleteStep: function() {
        if (!this.gameState || !Array.isArray(this.gameState.step_contents)) return 0;
        for (let i = 0; i < 6; i++) {
            let c = this.gameState.step_contents[i];
            if (!c || c === "" || c.startsWith("Error:")) return i;
        }
        return 5;
    },

    startConcept: function() {
        if (typeof webui === 'undefined') return;
        const promptText = document.getElementById('prompt').value;
        if (!promptText) {
            this.setStatus("请先输入创作灵感。", true);
            return;
        }
        
        document.getElementById('btnGenerate').disabled = true;
        document.getElementById('btnStartPipeline').disabled = true;
        document.getElementById('btnGenAssets').disabled = true;
        this.updateProgress(5, "Step 0: Drafting Concept...");
        
        webui.call('backend_start_concept', promptText).then(response => {
            this.pollInterval = setInterval(() => this.pollConcept(), 1500);
        }).catch(err => {
            this.setStatus("启动概念生成失败: " + err, true);
            document.getElementById('btnGenerate').disabled = false;
            document.getElementById('btnGenAssets').disabled = false;
        });
    },

    pollConcept: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_poll_concept', '').then(res => {
            if (!res) return;
            let data = JSON.parse(res);
            if (data.status === "progress") {
                // Concept generation is running
                this.updateProgress(50, "Generating Concept Template...");
            } else if (data.status === "done") {
                this.updateProgress(100, "Concept Drafted! Please review and click Confirm & Start Pipeline.");
                clearInterval(this.pollInterval);
                this.pollInterval = null;
                document.getElementById('btnGenerate').disabled = false;
                document.getElementById('btnStartPipeline').disabled = false;
                
                // Only enable batch generate if step 5 has content
                if (this.gameState && this.gameState.step_contents && this.gameState.step_contents[5] && this.gameState.step_contents[5] !== "") {
                    document.getElementById('btnGenAssets').disabled = false;
                }
                
                this.fetchState();
                this.showStepContent(0);
            } else if (data.status === "error") {
                clearInterval(this.pollInterval);
                this.pollInterval = null;
                this.updateProgress(0, "Error occurred.");
                document.getElementById('btnGenerate').disabled = false;
                
                if (this.gameState && this.gameState.step_contents && this.gameState.step_contents[5] && this.gameState.step_contents[5] !== "") {
                    document.getElementById('btnGenAssets').disabled = false;
                }
                
                this.fetchState();
                this.showStepContent(0);
            }
        }).catch(err => {
            console.error("Poll concept failed:", err);
            clearInterval(this.pollInterval);
            this.pollInterval = null;
            document.getElementById('btnGenerate').disabled = false;
            document.getElementById('btnStartPipeline').disabled = false;
        });
    },

    startPipeline: function() {
        if (typeof webui === 'undefined') return;
        
        // Ensure latest edited concept is saved
        // Prevent auto-saving to avoid WebUI string truncation limit (8KB) on large LLM outputs
        // this.saveStepContent();
        
        document.getElementById('btnGenerate').disabled = true;
        document.getElementById('btnStartPipeline').disabled = true;
        document.getElementById('btnGenAssets').disabled = true;
        this.updateProgress(10, "Step 1: World Bible...");
        
        webui.call('backend_start_pipeline', '').then(response => {
            if (response === "need_concept") {
                this.setStatus("请先完成第1步核心概念。", true);
                document.getElementById('btnGenerate').disabled = false;
                document.getElementById('btnStartPipeline').disabled = false;
                return;
            }
            if (response === "already_done") {
                this.setStatus("当前项目已完成全部管线步骤。");
                document.getElementById('btnGenerate').disabled = false;
                document.getElementById('btnStartPipeline').disabled = false;
                document.getElementById('btnGenAssets').disabled = false;
                return;
            }
            this.pollInterval = setInterval(() => this.pollPipeline(), 1500);
        }).catch(err => {
            this.setStatus("启动管线失败: " + err, true);
            document.getElementById('btnGenerate').disabled = false;
            document.getElementById('btnStartPipeline').disabled = false;
            document.getElementById('btnGenAssets').disabled = false;
        });
    },

    pollPipeline: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_poll_pipeline', '').then(res => {
            if (!res) return;
            let data = JSON.parse(res);
            if (data.status === "progress") {
                let totalSteps = 6;
                this.updateProgress(10 + (data.step / totalSteps) * 90, "Running Step " + (data.step + 1) + "...");
                this.fetchState();
                this.showStepContent(data.step);
            } else if (data.status === "done") {
                this.updateProgress(100, "Generation Complete!");
                clearInterval(this.pollInterval);
                this.pollInterval = null;
                document.getElementById('btnGenerate').disabled = false;
                document.getElementById('btnStartPipeline').disabled = false;
                
                if (this.gameState && this.gameState.step_contents && this.gameState.step_contents[5] && this.gameState.step_contents[5] !== "") {
                    document.getElementById('btnGenAssets').disabled = false;
                }
                
                this.fetchState();
                this.showStepContent(5);
            } else if (data.status === "error") {
                clearInterval(this.pollInterval);
                this.pollInterval = null;
                this.updateProgress(0, "Error occurred in Step " + (data.step !== undefined ? data.step : "?") + ".");
                document.getElementById('btnGenerate').disabled = false;
                document.getElementById('btnStartPipeline').disabled = false;
                
                if (this.gameState && this.gameState.step_contents && this.gameState.step_contents[5] && this.gameState.step_contents[5] !== "") {
                    document.getElementById('btnGenAssets').disabled = false;
                }
                
                this.fetchState();
                if (data.step !== undefined) {
                    this.showStepContent(data.step);
                }
            }
        }).catch(err => {
            console.error("Poll pipeline failed:", err);
            clearInterval(this.pollInterval);
            this.pollInterval = null;
            document.getElementById('btnGenerate').disabled = false;
            document.getElementById('btnStartPipeline').disabled = false;
            document.getElementById('btnGenAssets').disabled = false;
        });
    },

    updateProgress: function(percent, text) {
        document.getElementById('progressContainer').style.display = 'block';
        document.getElementById('progressBar').style.width = percent + '%';
        document.getElementById('statusText').innerText = text;
    },

    regenerateCurrentStep: function() {
        if (typeof webui === 'undefined') return;
        let activeTab = document.querySelector('.step-tab.active');
        if (!activeTab) return;
        let stepIndex = parseInt(activeTab.id.replace('tab-step', ''));
        
        this.updateProgress(10 + (stepIndex / 6) * 90, "Retrying Step " + (stepIndex + 1) + "...");
        
        webui.call('backend_regenerate_step', stepIndex.toString()).then(response => {
            if (!this.pollInterval) {
                this.pollInterval = setInterval(() => this.pollPipeline(), 1500);
            }
        }).catch(err => {
            this.setStatus("重试步骤失败: " + err, true);
        });
    },

    /**
     * Iterates through the blueprint nodes (Step 4 JSON) and initiates the 2D asset generation loop.
     * Supports both `Local ComfyUI` (via backend batch worker) and `RunComfy Cloud API` (via frontend fetch).
     */
    generateAllAssets: async function() {
            if (typeof webui === 'undefined') return;
            if (!this.project_id) {
                this.setStatus("请先加载项目。", true);
                return;
            }
            
            try {
                let confStr = await webui.call('backend_get_config_all', '');
                let conf = JSON.parse(confStr);
                
                let isLocal = conf.comfy_mode === "local";
                if (!isLocal && (!conf.runcomfy_url || !conf.runcomfy_token)) {
                    this.setStatus("缺少 RunComfy 配置。", true);
                    return;
                }
                if (isLocal && !conf.comfy_url) {
                    this.setStatus("缺少本地 ComfyUI URL 配置。", true);
                    return;
                }
                
                let nodesData = JSON.parse(this.gameState.step_contents[4]);
                let nodes = nodesData.nodes || [];
                if (nodes.length === 0) {
                    this.setStatus("Step 4 JSON 中没有可生成节点。", true);
                    return;
                }
                
                let container = document.getElementById('image-queue-list');
                if (container) container.innerHTML = '';

                // Phase 1: materialize the full queue first so WebView can show all pending items immediately.
                let tasks = [];
                for (let i = 0; i < nodes.length; i++) {
                    let node = nodes[i];
                    let prompt = (node.cinematography && node.cinematography.image_prompt) ? node.cinematography.image_prompt : "";
                    let safeNodeId = this.toSafeAssetId(node.id, "node_" + i);
                    let filename = "scene_" + safeNodeId + ".png";
                    let uiKey = safeNodeId + "_" + i;
                    tasks.push({ node, prompt, filename, uiKey });

                    if (container) {
                        let div = document.createElement('div');
                        div.id = 'img-task-' + uiKey;
                        div.style.padding = "10px";
                        div.style.backgroundColor = "#2d2d30";
                        div.style.borderLeft = "4px solid #f1c40f";
                        div.style.borderRadius = "4px";
                        div.style.marginBottom = "10px";
                        div.innerHTML = `<div style="font-weight:bold;color:#dcdcaa">${filename}</div><div style="font-size:12px;color:#aaa;margin-top:5px;">${prompt}</div><div id="img-status-${uiKey}" style="font-size:12px;margin-top:5px;color:#f1c40f;">Status: Pending...</div>`;
                        container.appendChild(div);
                    }
                }

                // Local mode launches one backend batch worker for the entire queue.
                if (isLocal && tasks.length > 0) {
                    this.setTextIfExists('img-status-' + tasks[0].uiKey, "Status: Starting Local Backend Worker...");
                    let res = await webui.call('backend_generate_all_assets', '');
                    if (res === "started") {
                        this.updateProgress(35, "2D assets: local backend worker started...");
                    } else {
                        throw new Error("Backend worker failed to start");
                    }
                }
                
                // Phase 2: process each queue item and update status in place.
                for (let i = 0; i < tasks.length; i++) {
                    let task = tasks[i];
                    let node = task.node;
                    let prompt = task.prompt;
                    let filename = task.filename;
                    let uiKey = task.uiKey;

                    if (!prompt) {
                        this.setTextIfExists('img-status-' + uiKey, "Status: Skipped (empty prompt)");
                        this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #e74c3c");
                        continue;
                    }
                    
                    if (isLocal) {
                        try {
                            this.setTextIfExists('img-status-' + uiKey, "Status: Generating locally...");
                            
                            // Poll file existence to update UI
                            let max_tries = 300;
                            let fileFound = false;
                            for (let j = 0; j < max_tries; j++) {
                                let exists = await webui.call('backend_file_exists', app.project_id + "\\" + filename);
                                if (exists === "true") {
                                    fileFound = true;
                                    break;
                                }
                                await new Promise(r => setTimeout(r, 2000));
                            }
                            
                            if (fileFound) {
                                this.setTextIfExists('img-status-' + uiKey, "Status: Downloaded Successfully");
                                this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #4CAF50");
                            } else {
                                throw new Error("Timeout waiting for local file to be generated");
                            }
                        } catch (e) {
                            this.setTextIfExists('img-status-' + uiKey, "Status: Error - " + e.message);
                            this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #e74c3c");
                        }
                    } else {
                        // RunComfy Generation Logic
                        let reqBody = JSON.stringify({
                            input: {
                                prompt: prompt,
                                width: 1024,
                                height: 768
                            }
                        });
                        
                        let httpReq = {
                            url: conf.runcomfy_url + "/inference",
                            method: "POST",
                            token: conf.runcomfy_token,
                            body: reqBody
                        };
                        
                        let resStr = await webui.call('backend_http_request', JSON.stringify(httpReq));
                        let res = JSON.parse(resStr);
                        let prompt_id = res.request_id || res.run_id || res.id;
                        
                        if (!prompt_id) {
                            this.setTextIfExists('img-status-' + uiKey, "Status: Failed to submit");
                            this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #e74c3c");
                            continue;
                        }
                        
                        this.setTextIfExists('img-status-' + uiKey, "Status: Polling (ID: " + prompt_id + ")...");
                        
                        try {
                            let resultUrl = await this.runcomfyPoll(prompt_id, conf);
                            if (resultUrl) {
                                this.setTextIfExists('img-status-' + uiKey, "Status: Downloading...");
                                let dlReq = {
                                    url: resultUrl,
                                    filename: filename,
                                    is_runcomfy: true
                                };
                                let dlRes = await webui.call('backend_download_image', JSON.stringify(dlReq));
                                if (dlRes === "ok") {
                                    this.setTextIfExists('img-status-' + uiKey, "Status: Downloaded Successfully");
                                    this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #4CAF50");
                                } else {
                                    throw new Error(dlRes);
                                }
                            }
                        } catch (e) {
                            this.setTextIfExists('img-status-' + uiKey, "Status: Error - " + e.message);
                            this.setStyleIfExists('img-task-' + uiKey, "borderLeft", "4px solid #e74c3c");
                        }
                    }
                }
                if (!isLocal) this.updateProgress(100, "All 2D assets generated.");
            } catch (e) {
                console.error("Error generating assets:", e);
                this.updateProgress(0, "2D asset generation failed: " + (e.message || e));
            }
        },

    /**
         * Long-polls the RunComfy API until the task status resolves.
         * Compatible with ["SUCCESS", "SUCCEEDED", "COMPLETED", "DONE"].
         * 
         * @param {string} prompt_id - The ID of the inference task
         * @param {Object} conf - The config object containing `runcomfy_url` and `runcomfy_token`
         * @returns {Promise<string>} - Resolves to the result URL
         * @throws {Error} - Throws on failure or timeout
         */
        runcomfyPoll: async function(prompt_id, conf) {
            let max_tries = 120;
            for (let i = 0; i < max_tries; i++) {
                let url = conf.runcomfy_url.replace("/inference", "") + "/requests/" + prompt_id + "/status";
                let req = { url: url, method: "GET", token: conf.runcomfy_token, body: "" };
                let resStr = await webui.call('backend_http_request', JSON.stringify(req));
                let res = JSON.parse(resStr);
                let status = String(res.status || "").toUpperCase();
                
                if (["SUCCESS", "SUCCEEDED", "COMPLETED", "DONE"].includes(status)) {
                    let result_url = conf.runcomfy_url.replace("/inference", "") + "/requests/" + prompt_id + "/result";
                    let req2 = { url: result_url, method: "GET", token: conf.runcomfy_token, body: "" };
                    let res2Str = await webui.call('backend_http_request', JSON.stringify(req2));
                    let res2 = JSON.parse(res2Str);
                    
                    let outUrl = this.parseRuncomfyResult(res2);
                    if (outUrl) {
                        return outUrl;
                    }
                    throw new Error("No valid url found in result");
                } else if (["FAILED", "CANCELED", "CANCELLED", "TIMEOUT", "ERROR"].includes(status)) {
                    throw new Error("Task failed: " + status);
                }
                await new Promise(r => setTimeout(r, 2500));
            }
            throw new Error("Timeout polling RunComfy");
        },

        /**
         * Parses the result JSON from RunComfy and extracts the target file URL.
         * Handles both standard `images[].url` structure and Trellis `result[3]` arrays.
         * 
         * @param {Object} result - The raw result JSON object returned by RunComfy
         * @returns {string|null} - The valid asset URL or null if not found
         */
        parseRuncomfyResult: function(result) {
            const outputs = result && typeof result === "object" ? result.outputs : null;
            if (outputs && typeof outputs === "object") {
                for (const [nodeId, nodeOutput] of Object.entries(outputs)) {
                    if (!nodeOutput || typeof nodeOutput !== "object") continue;
                    for (const [bucket, arr] of Object.entries(nodeOutput)) {
                        if (!Array.isArray(arr)) continue;
                        
                        // Check for Trellis [filename, _, _, url] structure
                        if (bucket === "result" && arr.length >= 4 && typeof arr[3] === "string" && (arr[3].startsWith("http://") || arr[3].startsWith("https://"))) {
                            let url = arr[3];
                            if (!url.includes("/logs/") && !url.endsWith("/comfyui.txt")) return url;
                        }
                        
                        // Standard comfyui output
                        for (const item of arr) {
                            if (!item || typeof item !== "object") continue;
                            const url = item.url || item.file_url || item.image_url || item.download_url || item.signed_url;
                            if (url && (url.startsWith("http://") || url.startsWith("https://")) && !url.includes("/logs/") && !url.endsWith("/comfyui.txt")) {
                                return url;
                            }
                        }
                    }
                }
            }
            
            // Fallback direct URL keys
            for (const key of ["url", "file_url", "image_url", "download_url", "signed_url"]) {
                if (result && typeof result[key] === "string") {
                    let url = result[key];
                    if (url && (url.startsWith("http://") || url.startsWith("https://")) && !url.includes("/logs/") && !url.endsWith("/comfyui.txt")) {
                        return url;
                    }
                }
            }
            return null;
        },

    fetchImageStatus: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_get_asset_list', '').then(res => {
            if (!res) return;
            let list = [];
            try {
                list = JSON.parse(res);
            } catch (e) {
                console.error("Failed to parse image status list:", e);
                return;
            }
            let container = document.getElementById('image-queue-list');
            if (!container) return;
            container.innerHTML = "";

            if (!Array.isArray(list) || list.length === 0) {
                container.innerHTML = '<div style="color: #888;">No image generation task is currently running. Start batch generation to see progress.</div>';
                return;
            }

            list.forEach(item => {
                let name = item.name || "unknown.png";
                let prompt = item.prompt || "";
                let statusRaw = item.status || "pending";
                let kind = item.kind || (name.startsWith("scene_") ? "scene_2d" : "input_3d");
                let done = statusRaw === "done";

                let kindLabel = kind === "input_3d" ? "3D输入图" : "2D场景图";
                let statusText = done ? "Status: Downloaded Successfully" : "Status: Pending / Running";
                let statusColor = done ? "#4CAF50" : "#f1c40f";
                let borderColor = done ? "#4CAF50" : "#f1c40f";

                let div = document.createElement('div');
                div.style.padding = "10px";
                div.style.backgroundColor = "#2d2d30";
                div.style.borderLeft = "4px solid " + borderColor;
                div.style.borderRadius = "4px";
                div.style.marginBottom = "10px";
                div.innerHTML = `<div style="font-weight:bold;color:#dcdcaa">${name}</div><div style="font-size:12px;color:#7fb3ff;margin-top:4px;">Type: ${kindLabel}</div><div style="font-size:12px;color:#aaa;margin-top:5px;">${prompt}</div><div style="font-size:12px;margin-top:5px;color:${statusColor};">${statusText}</div>`;
                container.appendChild(div);
            });
        }).catch(err => {
            console.error("fetchImageStatus failed:", err);
        });
    },

    fetch3DStatus: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_get_3d_asset_list', '').then(res => {
            if (res) {
                let list = JSON.parse(res);
                let container = document.getElementById('model-queue-list');
                if (!container) return;
                container.innerHTML = "";
                
                if (list.length === 0) {
                    container.innerHTML = '<div style="color: #888;">No 3D generation task is currently running. Start generation first.</div>';
                    return;
                }
                
                list.forEach(item => {
                    let div = document.createElement('div');
                    div.style.padding = "10px";
                    div.style.backgroundColor = "#2d2d30";
                    div.style.borderLeft = item.status === 'done' ? "4px solid #4CAF50" : "4px solid #f1c40f";
                    div.style.borderRadius = "4px";
                    
                    let title = document.createElement('div');
                    title.style.fontWeight = "bold";
                    title.style.color = "#dcdcaa";
                    title.innerText = item.name;
                    
                    let prompt = document.createElement('div');
                    prompt.style.fontSize = "12px";
                    prompt.style.color = "#aaa";
                    prompt.style.marginTop = "5px";
                    prompt.innerText = "Source Image: " + item.source_image;
                    
                    let status = document.createElement('div');
                    status.style.fontSize = "12px";
                    status.style.marginTop = "5px";
                    if (item.status === 'done') {
                        status.style.color = "#4CAF50";
                        status.innerText = "Status: Generated";
                    } else {
                        status.style.color = "#f1c40f";
                        status.innerText = "Status: Pending / Running";
                    }
                    
                    div.appendChild(title);
                    div.appendChild(prompt);
                    div.appendChild(status);
                    container.appendChild(div);
                });
            }
        });
    },

    /**
     * Reads 3D model configurations (Step 5 JSON) and triggers the 3D generation pipeline.
     * In `RunComfy` mode, it first calls `Flux2` for multi-view imaging, and then `Trellis2` for 3D modeling.
     */
    generateAll3DAssets: async function() {
        if (!this.project_id) {
            this.setStatus("请先加载项目并完成前序步骤。", true);
            return;
        }
        if (typeof webui === 'undefined') return;
        
        try {
            let confStr = await webui.call('backend_get_config_all', '');
            let conf = JSON.parse(confStr);
            
            let isLocal = conf.comfy_mode === "local";
            if (!isLocal && (!conf.runcomfy_url || !conf.runcomfy_token)) {
                this.setStatus("缺少 RunComfy 配置。", true);
                return;
            }
            if (isLocal && !conf.comfy_url) {
                this.setStatus("缺少本地 ComfyUI URL 配置。", true);
                return;
            }
            
            let nodesArray = JSON.parse(this.gameState.step_contents[5]);
            let nodes = Array.isArray(nodesArray) ? nodesArray : (nodesArray.models || []);
            if (nodes.length === 0) {
                this.setStatus("Step 5 JSON 中没有 3D 节点。", true);
                return;
            }
            
            let container = document.getElementById('model-queue-list');
            if (container) container.innerHTML = '';
            
            for (let i = 0; i < nodes.length; i++) {
                let node = nodes[i];
                let prompt = node.image_prompt || node.description;
                let assetName = node.asset_name || node.id;
                let safeAssetName = this.toSafeAssetId(assetName, "asset_" + i);
                let filename = safeAssetName + "_Textured.glb";
                let tempImgName = safeAssetName + "_temp.png";
                
                if (container) {
                    let div = document.createElement('div');
                    div.id = 'model-task-' + assetName;
                    div.style.padding = "10px";
                    div.style.backgroundColor = "#2d2d30";
                    div.style.borderLeft = "4px solid #f1c40f";
                    div.style.borderRadius = "4px";
                    div.style.marginBottom = "10px";
                    div.innerHTML = `<div style="font-weight:bold;color:#dcdcaa">${filename}</div><div style="font-size:12px;color:#aaa;margin-top:5px;">${prompt}</div><div id="model-status-${assetName}" style="font-size:12px;margin-top:5px;color:#f1c40f;">Status: Submitting to Flux2 for multi-view...</div>`;
                    container.appendChild(div);
                }
                
                if (isLocal) {
                    try {
                        if (i === 0) {
                            document.getElementById('model-status-' + assetName).innerText = "Status: Submitting 3D task to Local Backend Worker...";
                            let res = await webui.call('backend_generate_all_3d_assets', '');
                            if (res === "started") {
                                document.getElementById('model-status-' + assetName).innerText = "Status: Local 3D Backend Worker Started... (Check Console)";
                                document.getElementById('model-task-' + assetName).style.borderLeft = "4px solid #4CAF50";
                            } else {
                                throw new Error("Backend worker failed to start");
                            }
                            this.updateProgress(40, "3D assets: local backend worker started...");
                        } else {
                            document.getElementById('model-status-' + assetName).innerText = "Status: Queued in same local batch...";
                        }
                    } catch (e) {
                        document.getElementById('model-status-' + assetName).innerText = "Status: Error - " + e.message;
                        document.getElementById('model-task-' + assetName).style.borderLeft = "4px solid #e74c3c";
                    }
                } else {
                    // Step 1: Generate Multi-view Image with Flux2
                    let reqBody = JSON.stringify({
                        input: {
                            prompt: prompt,
                            width: 1024,
                            height: 768
                        }
                    });
                    
                    let httpReq = {
                        url: conf.runcomfy_url + "/inference",
                        method: "POST",
                        token: conf.runcomfy_token,
                        body: reqBody
                    };
                    
                    let resStr = await webui.call('backend_http_request', JSON.stringify(httpReq));
                    let res = JSON.parse(resStr);
                    let prompt_id = res.request_id || res.run_id || res.id;
                    
                    if (!prompt_id) {
                        document.getElementById('model-status-' + assetName).innerText = "Status: Failed to submit to Flux2";
                        document.getElementById('model-task-' + assetName).style.borderLeft = "4px solid #e74c3c";
                        continue;
                    }
                    
                    document.getElementById('model-status-' + assetName).innerText = "Status: Polling Flux2 (ID: " + prompt_id + ")...";
                    
                    try {
                            let resultUrl = await this.runcomfyPoll(prompt_id, conf);
                            if (resultUrl) {
                                document.getElementById('model-status-' + assetName).innerText = "Status: Flux done. Submitting to Trellis2...";
                                let dlReq = { url: resultUrl, filename: tempImgName, is_runcomfy: true };
                                await webui.call('backend_download_image', JSON.stringify(dlReq));
                                
                                let TRELLIS_DEPLOYMENT_ID = "707d1d90-f493-47eb-b023-a839ce732b27";
                                 // Convert flux image to data uri using backend helper or just download it first. 
                                 // To be safe, let's use the local file and let the backend read it as base64, or just pass the public URL directly to Trellis.
                                 // The script `runcomfy_e2e_test.js` uses dataURI, but RunComfy Trellis node 279 can accept public URLs. Let's pass the URL.
                                 
                                 let trellisPayload = {
                                     overrides: {
                                         "279": { inputs: { image: resultUrl } },
                                         "142": { inputs: { remove_background: true } },
                                         "140": { inputs: { filename_prefix: "trellis_" + assetName } },
                                         "278": { inputs: { seed: Math.floor(Math.random() * 1000000000) } }
                                     }
                                 };
                                 
                                 let tReq = {
                                     url: "https://api.runcomfy.net/prod/v1/deployments/" + TRELLIS_DEPLOYMENT_ID + "/inference",
                                     method: "POST",
                                     token: conf.runcomfy_token,
                                     body: JSON.stringify(trellisPayload)
                                 };
                                 
                                 let tResStr = await webui.call('backend_http_request', JSON.stringify(tReq));
                                 let tRes = JSON.parse(tResStr);
                                 let t_id = tRes.request_id || tRes.run_id || tRes.id;
                                 
                                 if (!t_id) {
                                     throw new Error("Failed to submit to Trellis2");
                                 }
                                 
                                 document.getElementById('model-status-' + assetName).innerText = "Status: Polling Trellis2 (ID: " + t_id + ")...";
                                 
                                 // Polling Trellis
                                 let confTrellis = {
                                     runcomfy_url: "https://api.runcomfy.net/prod/v1/deployments/" + TRELLIS_DEPLOYMENT_ID + "/inference",
                                     runcomfy_token: conf.runcomfy_token
                                 };
                                 
                                 let trellisUrl = await this.runcomfyPoll(t_id, confTrellis);
                                 if (trellisUrl) {
                                     document.getElementById('model-status-' + assetName).innerText = "Status: Downloading 3D GLB...";
                                     let tDlReq = { url: trellisUrl, filename: filename, is_runcomfy: true };
                                     let dlRes = await webui.call('backend_download_image', JSON.stringify(tDlReq));
                                     if (dlRes === "ok") {
                                         document.getElementById('model-status-' + assetName).innerText = "Status: 3D Model Downloaded Successfully";
                                         document.getElementById('model-task-' + assetName).style.borderLeft = "4px solid #4CAF50";
                                     } else {
                                         throw new Error("Download GLB failed: " + dlRes);
                                     }
                                 }
                        }
                    } catch (e) {
                        document.getElementById('model-status-' + assetName).innerText = "Status: Error - " + e.message;
                        document.getElementById('model-task-' + assetName).style.borderLeft = "4px solid #e74c3c";
                    }
                }
            }
            if (!isLocal) this.updateProgress(100, "All 3D assets generated.");
        } catch (e) {
            console.error("Error generating 3D assets:", e);
            this.updateProgress(0, "3D asset generation failed: " + (e.message || e));
        }
    },

    fetch3DImageStatus: function() {
        // Deprecated: handled inside generateAll3DAssets
    },

    load3DAssets: function() {
        if (!this.project_id) {
            this.setStatus("请先加载项目。", true);
            return;
        }
        if (typeof webui === 'undefined') return;
        webui.call('backend_list_models', '').then(response => {
            try {
                let data = JSON.parse(response);
                let models = data.models || [];
                let selector = document.getElementById('model-selector');
                if (!selector) return;
                selector.innerHTML = '';
                if (models.length === 0) {
                    selector.innerHTML = '<div style="color:#888;">No .glb/.obj models found in the project folder.</div>';
                    return;
                }
                
                models.forEach(model => {
                    let btn = document.createElement('button');
                    btn.className = 'btn-secondary';
                    btn.innerText = model;
                    btn.onclick = () => this.preview3DModel(model);
                    selector.appendChild(btn);
                });
                
                // auto-load first model
                this.preview3DModel(models[0]);
            } catch (e) {
                console.error("Failed to parse models", e);
            }
        });
    },

    preview3DModel: function(modelFilename) {
        let container = document.getElementById('three-container');
        if (!container) return;
        
        // Remove previous placeholder if it exists
        let placeholder = document.getElementById('three-placeholder');
        if (placeholder) placeholder.style.display = 'none';
        
        if (!this.scene) {
            this.scene = new THREE.Scene();
            this.scene.background = new THREE.Color(0x222222);
            
            this.camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 1000);
            this.camera.position.z = 5;
            this.camera.position.y = 2;
            
            let ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
            this.scene.add(ambientLight);
            
            let dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
            dirLight.position.set(10, 20, 10);
            this.scene.add(dirLight);
            
            this.renderer = new THREE.WebGLRenderer({ antialias: true });
            this.renderer.setSize(container.clientWidth, container.clientHeight);
            
            this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
            this.controls.enableDamping = true;
            this.controls.dampingFactor = 0.05;
            
            // Insert renderer behind the UI overlay
            this.renderer.domElement.style.position = 'absolute';
            this.renderer.domElement.style.top = '0';
            this.renderer.domElement.style.left = '0';
            this.renderer.domElement.style.zIndex = '1';
            container.insertBefore(this.renderer.domElement, container.firstChild);
        }
        
        if (this.currentModel) {
            this.scene.remove(this.currentModel);
            this.currentModel = null;
        }
        
        let isGLB = modelFilename.toLowerCase().endsWith('.glb') || modelFilename.toLowerCase().endsWith('.gltf');
        let loader = isGLB ? new THREE.GLTFLoader() : new THREE.OBJLoader();
        
        webui.call('backend_prepare_file', modelFilename).then(tempPath => {
            if (!tempPath || tempPath === "error") {
                console.error("Error preparing model file.");
                return;
            }
            
            let url = tempPath + "?t=" + new Date().getTime();
            
            loader.load(url, (gltf) => {
                let obj = isGLB ? gltf.scene : gltf;
                this.currentModel = obj;
                
                // auto-scale and center
                let box = new THREE.Box3().setFromObject(obj);
                let size = box.getSize(new THREE.Vector3());
                let center = box.getCenter(new THREE.Vector3());
                
                obj.position.x += (obj.position.x - center.x);
                obj.position.y += (obj.position.y - center.y);
                obj.position.z += (obj.position.z - center.z);
                
                let maxDim = Math.max(size.x, size.y, size.z);
                let scale = 3 / maxDim;
                obj.scale.set(scale, scale, scale);
                
                this.scene.add(obj);
            }, undefined, (err) => {
                console.error("Error loading model", err);
            });
        });
        
        if (!this.animating) {
            this.animating = true;
            let animate = () => {
                requestAnimationFrame(animate);
                if (this.controls) this.controls.update();
                if (this.renderer && this.scene && this.camera) {
                    this.renderer.render(this.scene, this.camera);
                }
            };
            animate();
        }
    },

    loadConfig: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_get_config', '').then(res => {
            if (res) {
                let cfg = JSON.parse(res);
                this.configData = cfg;
                document.getElementById('cfg-provider').value = cfg.api_provider;
                document.getElementById('cfg-comfy-mode').value = cfg.comfy_mode || "local";
                document.getElementById('cfg-comfy-url').value = cfg.comfy_url;
                document.getElementById('cfg-runcomfy-key').value = cfg.runcomfy_api_key || "";
                document.getElementById('cfg-lang').value = cfg.lang || "ZH";
                
                this.updateProviderFields();
                this.switchComfyMode();
                this.applyLanguage();
            }
        }).catch(err => {
            console.error("Failed to load config:", err);
            // Retry after a delay if failed due to connection
            setTimeout(() => this.loadConfig(), 1000);
        });
    },

    switchProvider: function() {
        this.updateProviderFields();
    },

    switchComfyMode: function() {
        let mode = document.getElementById('cfg-comfy-mode').value;
        if (mode === "runcomfy") {
            document.getElementById('group-comfy-url').style.display = 'none';
            document.getElementById('group-runcomfy-key').style.display = 'block';
        } else {
            document.getElementById('group-comfy-url').style.display = 'block';
            document.getElementById('group-runcomfy-key').style.display = 'none';
        }
    },

    updateProviderFields: function() {
        let provider = document.getElementById('cfg-provider').value;
        let cfg = this.configData;
        if (!cfg) return;

        let lang = cfg.lang === "ZH" ? "ZH" : "EN";
        let title = document.getElementById('cfg-provider-title');
        
        if (provider === "Gemini") {
            title.innerText = lang === "ZH" ? "Google Gemini 配置" : "Google Gemini Settings";
            document.getElementById('cfg-struct-url').value = cfg.gemini_structural.api_url;
            document.getElementById('cfg-struct-key').value = cfg.gemini_structural.api_key;
            document.getElementById('cfg-struct-model').value = cfg.gemini_structural.model_name;
            document.getElementById('cfg-create-url').value = cfg.gemini_creative.api_url;
            document.getElementById('cfg-create-key').value = cfg.gemini_creative.api_key;
            document.getElementById('cfg-create-model').value = cfg.gemini_creative.model_name;
        } else {
            title.innerText = lang === "ZH" ? "OpenAI 兼容接口配置" : "OpenAI Compatible Settings";
            document.getElementById('cfg-struct-url').value = cfg.structural_api.api_url;
            document.getElementById('cfg-struct-key').value = cfg.structural_api.api_key;
            document.getElementById('cfg-struct-model').value = cfg.structural_api.model_name;
            document.getElementById('cfg-create-url').value = cfg.creative_api.api_url;
            document.getElementById('cfg-create-key').value = cfg.creative_api.api_key;
            document.getElementById('cfg-create-model').value = cfg.creative_api.model_name;
        }
    },

    saveConfig: function() {
        let provider = document.getElementById('cfg-provider').value;
        let cfg = this.configData;
        if (!cfg) return;

        cfg.api_provider = provider;
        cfg.comfy_mode = document.getElementById('cfg-comfy-mode').value;
        cfg.comfy_url = document.getElementById('cfg-comfy-url').value;
        cfg.runcomfy_api_key = document.getElementById('cfg-runcomfy-key').value;
        cfg.lang = document.getElementById('cfg-lang').value;

        if (provider === "Gemini") {
            cfg.gemini_structural.api_url = document.getElementById('cfg-struct-url').value;
            cfg.gemini_structural.api_key = document.getElementById('cfg-struct-key').value;
            cfg.gemini_structural.model_name = document.getElementById('cfg-struct-model').value;
            cfg.gemini_creative.api_url = document.getElementById('cfg-create-url').value;
            cfg.gemini_creative.api_key = document.getElementById('cfg-create-key').value;
            cfg.gemini_creative.model_name = document.getElementById('cfg-create-model').value;
        } else {
            cfg.structural_api.api_url = document.getElementById('cfg-struct-url').value;
            cfg.structural_api.api_key = document.getElementById('cfg-struct-key').value;
            cfg.structural_api.model_name = document.getElementById('cfg-struct-model').value;
            cfg.creative_api.api_url = document.getElementById('cfg-create-url').value;
            cfg.creative_api.api_key = document.getElementById('cfg-create-key').value;
            cfg.creative_api.model_name = document.getElementById('cfg-create-model').value;
        }
        
        if (typeof webui === 'undefined') return;
        webui.call('backend_save_config', JSON.stringify(cfg)).then(res => {
            let statusEl = document.getElementById('cfg-status');
            if (res === "ok") {
                statusEl.innerHTML = '<span class="success-msg">Configuration saved successfully.</span>';
            } else {
                statusEl.innerHTML = '<span class="error-msg">Failed to save configuration.</span>';
            }
            setTimeout(() => statusEl.innerHTML = '', 3000);
        });
    },

    // --- Preview Engine ---
    testApi: function(type) {
        let provider = document.getElementById('cfg-provider').value;
        let url = document.getElementById(type === 'struct' ? 'cfg-struct-url' : 'cfg-create-url').value;
        let key = document.getElementById(type === 'struct' ? 'cfg-struct-key' : 'cfg-create-key').value;
        let model = document.getElementById(type === 'struct' ? 'cfg-struct-model' : 'cfg-create-model').value;
        
        let payload = {
            api_provider: provider,
            api_url: url,
            api_key: key,
            model_name: model
        };
        
        let btn = document.getElementById(type === 'struct' ? 'btnTestStruct' : 'btnTestCreate');
        let oldText = btn.innerText;
        btn.innerText = "Testing...";
        btn.disabled = true;
        
        if (typeof webui === 'undefined') return;
        webui.call('backend_test_api', JSON.stringify(payload)).then(res => {
            this.setStatus("API 测试结果: " + res);
            btn.innerText = oldText;
            btn.disabled = false;
        }).catch(err => {
            this.setStatus("API 测试失败: " + err, true);
            btn.innerText = oldText;
            btn.disabled = false;
        });
    },

    startGamePreview: function() {
        if (!this.project_id) {
            this.setStatus("请先生成或加载项目。", true);
            return;
        }
        if (typeof webui === 'undefined') return;
        webui.call('backend_load_game_json', '').then(res => {
            if (res && res !== "error") {
                this.gameData = JSON.parse(res);
                if (!this.gameData || !Array.isArray(this.gameData.nodes) || this.gameData.nodes.length === 0) {
                    throw new Error("Invalid game JSON: missing nodes");
                }
                this.gameCurrentNodeId = this.gameData.nodes[0].id;
                this.renderGameNode();
            } else {
                this.setStatus("加载游戏 JSON 失败，请确认 Step 4 已完成。", true);
            }
        }).catch(err => {
            console.error("startGamePreview failed:", err);
            this.setStatus("启动 2D 预览失败: " + err.message, true);
        });
    },

    start3DGamePreview: function() {
        if (!this.project_id) {
            this.setStatus("请先生成或加载项目。", true);
            return;
        }
        if (typeof webui === 'undefined') return;
        webui.call('backend_load_game_json', '').then(res => {
            if (res && res !== "error") {
                this.gameData = JSON.parse(res);
                if (!this.gameData || !Array.isArray(this.gameData.nodes) || this.gameData.nodes.length === 0) {
                    throw new Error("Invalid game JSON: missing nodes");
                }
                this.gameCurrentNodeId = this.gameData.nodes[0].id;
                this.render3DGameNode();
            } else {
                this.setStatus("加载游戏 JSON 失败，请确认 Step 4 已完成。", true);
            }
        }).catch(err => {
            console.error("start3DGamePreview failed:", err);
            this.setStatus("启动 3D 预览失败: " + err.message, true);
        });
    },

    startRaylibPreview: function() {
        if (typeof webui === 'undefined') return;
        webui.call('backend_start_raylib_preview', '').then(res => {
            if (res === "started") {
                this.setStatus("Raylib 渲染窗口已启动。");
            } else {
                this.setStatus("未找到 Raylib 可执行文件，请先编译 aetheria_engine。", true);
            }
        }).catch(err => {
            console.error("startRaylibPreview failed:", err);
            this.setStatus("启动 Raylib 渲染失败: " + err, true);
        });
    },

    renderGameNode: function() {
        let node = this.gameData.nodes.find(n => n.id === this.gameCurrentNodeId);
        if (!node) return;
        
        let bg = document.getElementById('game-bg');
        let overlay = document.getElementById('game-overlay');
        let dialog = document.getElementById('game-dialog');
        let choices = document.getElementById('game-choices');
        
        let safeName = this.toSafeAssetId(node.id, "node_bg");
        
        webui.call('backend_prepare_file', "scene_" + safeName + ".png").then(tempPath => {
            if (tempPath && tempPath !== "error") {
                bg.src = tempPath + "?t=" + new Date().getTime();
                bg.style.display = "block";
            } else {
                bg.style.display = "none";
            }
        });
        
        overlay.style.display = "flex";
        dialog.innerText = node.narrative.text_content;
        
        choices.innerHTML = "";
        if (node.gameplay.choices && node.gameplay.choices.length > 0) {
            node.gameplay.choices.forEach(c => {
                let btn = document.createElement('button');
                btn.className = 'choice-btn';
                btn.innerText = c.text;
                btn.onclick = () => {
                    this.gameCurrentNodeId = c.target_id;
                    this.renderGameNode();
                };
                choices.appendChild(btn);
            });
        } else {
            let endBtn = document.createElement('button');
            endBtn.className = 'choice-btn';
            endBtn.innerText = "Restart Game";
            endBtn.onclick = () => {
                this.gameCurrentNodeId = this.gameData.nodes[0].id;
                this.renderGameNode();
            };
            choices.appendChild(endBtn);
        }
    },

    render3DGameNode: function() {
        let node = this.gameData.nodes.find(n => n.id === this.gameCurrentNodeId);
        if (!node) return;
        
        let overlay = document.getElementById('game-overlay-3d');
        let dialog = document.getElementById('game-dialog-3d');
        let choices = document.getElementById('game-choices-3d');
        
        let safeName = node.id.replace(/ /g, "_");
        let modelName = safeName + "_Textured.glb";
        
        // Preview 3D Model in background
        this.preview3DModel(modelName);
        
        overlay.style.display = "flex";
        dialog.innerText = node.narrative.text_content;
        
        choices.innerHTML = "";
        if (node.gameplay.choices && node.gameplay.choices.length > 0) {
            node.gameplay.choices.forEach(c => {
                let btn = document.createElement('button');
                btn.className = 'choice-btn';
                btn.innerText = c.text;
                btn.onclick = () => {
                    this.gameCurrentNodeId = c.target_id;
                    this.render3DGameNode();
                };
                choices.appendChild(btn);
            });
        } else {
            let endBtn = document.createElement('button');
            endBtn.className = 'choice-btn';
            endBtn.innerText = "Restart Game";
            endBtn.onclick = () => {
                this.gameCurrentNodeId = this.gameData.nodes[0].id;
                this.render3DGameNode();
            };
            choices.appendChild(endBtn);
        }
    }
};

// Wait for WebUI to be ready
document.addEventListener('DOMContentLoaded', () => {
    console.log("DOM loaded. Calling app.init()...");
    let initDone = false;
    
    // Attempt to use WebUI's built-in event callback for a precise connection trigger
    if (typeof webui !== 'undefined' && webui.setEventCallback) {
        try {
            webui.setEventCallback((e) => {
                if (e === webui.event.CONNECTED && !initDone) {
                    initDone = true;
                    console.log("WebUI connected via event. Starting app...");
                    app.init();
                }
            });
        } catch (e) {
            console.warn("setEventCallback failed", e);
        }
    }
    
    // Fallback: poll until webui is connected
    let fallbackCheck = setInterval(() => {
        if (initDone) {
            clearInterval(fallbackCheck);
            return;
        }
        
        // Check if webui is defined and successfully initialized
        if (typeof webui !== 'undefined') {
            initDone = true;
            clearInterval(fallbackCheck);
            console.log("WebUI object detected via polling. Starting app...");
            setTimeout(() => app.init(), 300);
        }
    }, 100);
});
