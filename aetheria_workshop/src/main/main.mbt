pub enum AppState {
  Settings
  Drafting
  Generating
} derive(Eq)

pub struct App {
  mut state: AppState
  mut config: @config.Config
  mut active_textfield: Int
  mut draft_text: String
  mut draft_cursor: Int
  mut refine_text: String
  mut refine_cursor: Int
  mut draft_status: Int // 0: inputting, 1: generating, 2: generated
  generated_content: String
  mut generation_step: Int // 0: Test, 1: Step A, 2: Step B, 3: Step C, 4: Step D
  mut current_view_step: Int // Step content currently viewed in UI
  step_contents: Array[String] // Stores content for step 1 to 5 (index 0 to 4)
  step_status: Array[Int] // 0=Pending, 1=Running, 2=Done, 3=Error
  mut auto_proceed: Bool
  mut lang: String // "EN" or "ZH"
  scroll_y: Ref[Double]
  story_scale: Int // Deprecated, keeping to avoid changing struct schema right now
  mut project_id: String
  mut input_project_id: String
  mut load_error: String
  mut preview_node_id: String
  mut preview_bg_path: String
  mut preview_texture: @raylib.Texture2D?
  preview_scroll_y: Ref[Double]
  
  mut cached_assets: Array[Json]?
  mut last_asset_check_time: Double
  mut last_poll_time: Double
  mut cached_done_count: Int
  
  mut cached_state_machine: Json?
}

fn main {
  // Note: For native Windows IME support, we can't do much from MoonBit alone 
  // as it requires specific Win32 API calls in the message loop.
  // However, removing the ASCII limit in `ui.mbt` allows Raylib's `GetCharPressed()` 
  // to grab whatever the OS IME passes it (which handles Chinese composition).
  
  @raylib.init_window(1280, 800, "Aetheria Workshop (MoonBit Native)")
  @raylib.set_target_fps(60)
  @raylib.enable_event_waiting() // Enable retained-mode-like event waiting to save CPU and reduce UI lag
  @raylib.load_app_font()

  let app = {
    state: AppState::Settings,
    config: @config.load_config(),
    active_textfield: 0,
    draft_text: "",
    draft_cursor: -1,
    refine_text: "",
    refine_cursor: -1,
    draft_status: 0,
    generated_content: "",
    generation_step: -1,
    current_view_step: 1,
    step_contents: ["", "", "", "", ""],
    step_status: [0, 0, 0, 0, 0],
    auto_proceed: false,
    lang: "ZH",
    scroll_y: { val: 0.0 },
    story_scale: 1, // Default to Medium
    project_id: "",
    input_project_id: "",
    load_error: "",
    preview_node_id: "",
    preview_bg_path: "",
    preview_texture: None,
    preview_scroll_y: { val: 0.0 },
    cached_assets: None,
    last_asset_check_time: 0.0,
    last_poll_time: 0.0,
    cached_done_count: 0,
    cached_state_machine: None,
  }

  // Load environment variables ONCE at startup if config is empty
  if app.config.creative_api.api_key == "" {
    let env_key = @raylib.get_env("CODINGPLAN_API_KEY")
    if env_key != "" {
      app.config = { ..app.config,
        creative_api: { ..app.config.creative_api, api_key: env_key },
        structural_api: { ..app.config.structural_api, api_key: env_key }
      }
    }
  }
  if app.config.gemini_creative.api_key == "" {
    let env_key = @raylib.get_env("GEMINI_API_KEY")
    if env_key != "" {
      app.config = { ..app.config,
        gemini_creative: { ..app.config.gemini_creative, api_key: env_key },
        gemini_structural: { ..app.config.gemini_structural, api_key: env_key }
      }
    }
  }

  while not(@raylib.window_should_close()) {
    // If we are waiting for background tasks (LLM or assets), disable event waiting
    // to allow polling the filesystem for response.json or generated images
    if app.state == AppState::Generating || app.draft_status == 1 || app.generation_step == -1 {
      @raylib.disable_event_waiting()
    } else {
      @raylib.enable_event_waiting()
    }

    @raylib.begin_drawing()
    @raylib.clear_background(240, 240, 240, 255)

    match app.state {
      Settings => draw_settings(app)
      Drafting => draw_drafting(app)
      Generating => draw_pipeline(app)
    }

    @raylib.end_drawing()
  }

  @raylib.close_window()
}

fn draw_settings(app: App) -> Unit {
  if @ui.draw_button(if app.lang == "EN" { "中" } else { "EN" }, 950, 20, 50, 40) {
    app.lang = if app.lang == "EN" { "ZH" } else { "EN" }
  }

  @raylib.draw_text(if app.lang == "EN" { "Settings" } else { "设置" }, 400, 20, 40, 50, 50, 50, 255)

  @raylib.draw_text(if app.lang == "EN" { "API Provider:" } else { "API 提供商:" }, 100, 80, 20, 50, 50, 50, 255)
  if @ui.draw_button(if app.config.api_provider == "OpenAI" { "[X] OpenAI (Hunyuan)" } else { "[ ] OpenAI (Hunyuan)" }, 300, 75, 200, 30) {
    app.config = { ..app.config, api_provider: "OpenAI" }
  }
  if @ui.draw_button(if app.config.api_provider == "Gemini" { "[X] Gemini" } else { "[ ] Gemini" }, 520, 75, 200, 30) {
    app.config = { ..app.config, api_provider: "Gemini" }
  }

  let is_openai = app.config.api_provider == "OpenAI"

  let current_c_api = if is_openai { app.config.creative_api } else { app.config.gemini_creative }
  let current_s_api = if is_openai { app.config.structural_api } else { app.config.gemini_structural }

  // Creative API (Steps A & B)
  @raylib.draw_text(if app.lang == "EN" { "Creative API (Steps A & B):" } else { "创造力模型配置 (步骤 A & B):" }, 100, 130, 20, 50, 50, 50, 255)

  @raylib.draw_text(if app.lang == "EN" { "API Base URL:" } else { "API 请求地址:" }, 100, 170, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 160, 500, 40) { app.active_textfield = 1 }
  let new_c_api_url = @ui.draw_textbox(current_c_api.api_url, 300, 160, 500, 40, app.active_textfield == 1)

  @raylib.draw_text(if app.lang == "EN" { "API Key:" } else { "API 密钥:" }, 100, 220, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 210, 500, 40) { app.active_textfield = 2 }
  let new_c_api_key = @ui.draw_textbox(current_c_api.api_key, 300, 210, 500, 40, app.active_textfield == 2)

  @raylib.draw_text(if app.lang == "EN" { "Model Name:" } else { "模型名称:" }, 100, 270, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 260, 500, 40) { app.active_textfield = 3 }
  let new_c_model_name = @ui.draw_textbox(current_c_api.model_name, 300, 260, 500, 40, app.active_textfield == 3)

  // Structural API (Steps C & D)
  @raylib.draw_text(if app.lang == "EN" { "Structural API (Steps C & D):" } else { "结构化模型配置 (步骤 C & D):" }, 100, 330, 20, 50, 50, 50, 255)

  @raylib.draw_text(if app.lang == "EN" { "API Base URL:" } else { "API 请求地址:" }, 100, 370, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 360, 500, 40) { app.active_textfield = 4 }
  let new_s_api_url = @ui.draw_textbox(current_s_api.api_url, 300, 360, 500, 40, app.active_textfield == 4)

  @raylib.draw_text(if app.lang == "EN" { "API Key:" } else { "API 密钥:" }, 100, 420, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 410, 500, 40) { app.active_textfield = 5 }
  let new_s_api_key = @ui.draw_textbox(current_s_api.api_key, 300, 410, 500, 40, app.active_textfield == 5)

  @raylib.draw_text(if app.lang == "EN" { "Model Name:" } else { "模型名称:" }, 100, 470, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 460, 500, 40) { app.active_textfield = 6 }
  let new_s_model_name = @ui.draw_textbox(current_s_api.model_name, 300, 460, 500, 40, app.active_textfield == 6)
  
  let updated_c_api : @config.ApiConfig = { api_url: new_c_api_url, api_key: new_c_api_key, model_name: new_c_model_name }
  let updated_s_api : @config.ApiConfig = { api_url: new_s_api_url, api_key: new_s_api_key, model_name: new_s_model_name }

  if is_openai {
    app.config = { ..app.config, creative_api: updated_c_api, structural_api: updated_s_api }
  } else {
    app.config = { ..app.config, gemini_creative: updated_c_api, gemini_structural: updated_s_api }
  }

  if is_openai {
    if @ui.draw_button("Use LKEAP URL", 100, 520, 200, 40) {
      app.config = { ..app.config,
        creative_api: { ..app.config.creative_api, api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions" },
        structural_api: { ..app.config.structural_api, api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions" }
      }
    }
    if @ui.draw_button("Use TokenHub URL", 320, 520, 200, 40) {
      app.config = { ..app.config,
        creative_api: { ..app.config.creative_api, api_url: "https://tokenhub.tencentmaas.com/v1/chat/completions" },
        structural_api: { ..app.config.structural_api, api_url: "https://tokenhub.tencentmaas.com/v1/chat/completions" }
      }
    }
  } else {
    if @ui.draw_button("Use Gemini Default", 100, 520, 200, 40) {
      app.config = { ..app.config,
        gemini_creative: { ..app.config.gemini_creative, api_url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" },
        gemini_structural: { ..app.config.gemini_structural, api_url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" }
      }
    }
  }
  
  if @ui.draw_button("Test Creative API", 540, 520, 200, 40) {
    @config.save_config(app.config)
    start_generation_step(app, -1) // We'll use step -1 for a simple test
  }

  if @ui.draw_button(if app.lang == "EN" { "Save Settings" } else { "保存设置" }, 250, 580, 200, 50) {
    @config.save_config(app.config)
    
    if is_openai {
      let key = app.config.creative_api.api_key
      if key != "" {
        @raylib.system_command("start /B setx CODINGPLAN_API_KEY \"" + key + "\" >nul 2>&1")
      }
    } else {
      let key = app.config.gemini_creative.api_key
      if key != "" {
        @raylib.system_command("start /B setx GEMINI_API_KEY \"" + key + "\" >nul 2>&1")
      }
    }
  }

  if @ui.draw_button(if app.lang == "EN" { "Continue" } else { "继续起草" }, 550, 580, 200, 50) {
    app.state = AppState::Drafting
  }

  // Display API test result
  if app.generation_step == -1 {
    let res_file = "response.json"
    if @fs.path_exists(res_file) {
      try {
        let res_content = @fs.read_file_to_string(res_file)
        let res_json = @json.parse!(res_content)
        if res_json is Object(obj) {
          let status = match obj.get("status") {
            Some(String(s)) => s
            _ => "unknown"
          }
          let msg = match obj.get("content") {
            Some(String(m)) => m
            _ => match obj.get("message") {
              Some(String(m)) => m
              _ => "No message"
            }
          }
          if status == "success" {
            let preview = if msg.length() > 50 { msg.substring(end=50) + "..." } else { msg }
            @raylib.draw_text("Test Success: " + preview, 100, 650, 20, 0, 150, 0, 255)
            if @ui.draw_button("Copy Result", 800, 640, 120, 35) {
              @raylib.set_clipboard_text(msg)
            }
          } else {
            @raylib.draw_text("Test Failed: " + msg, 100, 650, 20, 255, 0, 0, 255)
            if @ui.draw_button("Copy Error", 800, 640, 120, 35) {
              @raylib.set_clipboard_text(msg)
            }
          }
        }
      } catch {
        _ => @raylib.draw_text("Parsing test result...", 100, 650, 20, 100, 100, 100, 255)
      }
    } else {
      @raylib.draw_text("Testing API... Please wait", 100, 650, 20, 100, 100, 100, 255)
    }
  }
}

fn draw_drafting(app: App) -> Unit {
  @raylib.draw_text(if app.lang == "EN" { "Drafting: Chat with LLM to build your concept" } else { "起草：与 AI 对话完善你的游戏概念" }, 100, 50, 30, 50, 50, 50, 255)

  // Top Box: User Input
  @raylib.draw_text(if app.lang == "EN" { "Your Idea / Modification:" } else { "你的想法 / 修改意见:" }, 100, 100, 20, 50, 50, 50, 255)
  if @ui.is_clicked(100, 130, 800, 150) {
    app.active_textfield = 7
  }
  let refine_cursor_ref : Ref[Int] = { val: app.refine_cursor }
  app.refine_text = @ui.draw_textbox(app.refine_text, 100, 130, 800, 150, app.active_textfield == 7, multiline=true, scroll_y=app.scroll_y, cursor_idx_ref=refine_cursor_ref)
  app.refine_cursor = refine_cursor_ref.val

  // AI Action Button
  if app.draft_status == 1 {
    @raylib.draw_rectangle(100, 300, 200, 40, 200, 200, 200, 255)
    @raylib.draw_text(if app.lang == "EN" { "AI Generating..." } else { "AI 正在生成..." }, 130, 310, 20, 100, 100, 100, 255)
  } else {
    let btn_text = if app.draft_status == 0 { 
      if app.lang == "EN" { "Generate Concept" } else { "生成概念模板" }
    } else {
      if app.lang == "EN" { "Apply Modification" } else { "应用修改" }
    }
    
    if @ui.draw_button(btn_text, 100, 300, 200, 40) {
      if app.refine_text != "" || app.draft_status == 0 {
        app.draft_status = 1
        if app.project_id == "" {
          app.project_id = "game_" + @raylib.get_random_value(10000, 99999).to_string()
        }
        @raylib.system_command("cmd /c if not exist " + app.project_id + " mkdir " + app.project_id)
        app.step_contents[0] = "" // Reset world bible
        start_generation_step(app, 0)
      }
    }
  }

  // Bottom Box: AI Output / Template
  @raylib.draw_text(if app.lang == "EN" { "Generated Concept (Editable):" } else { "生成的概念模板 (可直接编辑):" }, 100, 360, 20, 50, 50, 50, 255)
  if @ui.is_clicked(100, 390, 800, 250) {
    app.active_textfield = 8
  }
  let draft_cursor_ref : Ref[Int] = { val: app.draft_cursor }
  app.draft_text = @ui.draw_textbox(app.draft_text, 100, 390, 800, 250, app.active_textfield == 8, multiline=true, scroll_y=app.scroll_y, cursor_idx_ref=draft_cursor_ref)
  app.draft_cursor = draft_cursor_ref.val

  if @ui.draw_button(if app.lang == "EN" { "Back to Settings" } else { "返回设置" }, 100, 680, 200, 50) {
    app.state = AppState::Settings
  }
  
  // Load existing project
  @raylib.draw_text(if app.lang == "EN" { "Load Project:" } else { "加载已有项目:" }, 320, 695, 20, 50, 50, 50, 255)
  if @ui.is_clicked(450, 685, 120, 40) {
    app.active_textfield = 9
  }
  app.input_project_id = @ui.draw_textbox(app.input_project_id, 450, 685, 120, 40, app.active_textfield == 9)
  
  if @ui.draw_button(if app.lang == "EN" { "Load" } else { "加载" }, 580, 685, 80, 40) {
    if app.input_project_id != "" {
      let target_dir = app.input_project_id
      if @fs.path_exists(target_dir) {
        app.project_id = target_dir
        app.load_error = ""
        app.state = AppState::Generating
        app.auto_proceed = false
        for i = 0; i < 5; i = i + 1 {
          app.step_status[i] = 0
          app.step_contents[i] = ""
        }
        
        // Try to load final_story.json if it exists
        let story_file = target_dir + "/final_story.json"
        if @fs.path_exists(story_file) {
          try {
            let story_content = @fs.read_file_to_string(story_file)
            app.step_contents[3] = story_content // Load into Step 4 (JSON)
            app.step_status[3] = 2 // Mark Step 4 as done
            app.current_view_step = 4
          } catch {
            _ => ()
          }
        }
        
      } else {
        app.load_error = if app.lang == "EN" { "Folder not found!" } else { "找不到该文件夹!" }
      }
    }
  }
  
  if app.load_error != "" {
    @raylib.draw_text(app.load_error, 450, 735, 16, 200, 50, 50, 255)
  }
  
  if app.draft_status == 2 {
    if @ui.draw_button(if app.lang == "EN" { "Start Pipeline" } else { "确认并开始生成管线" }, 700, 680, 200, 50) {
      if app.draft_text != "" {
        app.state = AppState::Generating
        app.auto_proceed = true
        for i = 0; i < 5; i = i + 1 {
          app.step_status[i] = 0
          app.step_contents[i] = ""
        }
        app.step_status[0] = 1
        app.current_view_step = 1
        app.scroll_y.val = 0.0
        // Clear refine text as it's been absorbed
        app.refine_text = ""
        start_generation_step(app, 1)
      }
    }
  }
  
  // Handle AI generation poll
  let res_file = app.project_id + "/response.json"
  let current_time = @raylib.get_time()
  
  if app.draft_status == 1 && current_time - app.last_poll_time > 0.5 {
    app.last_poll_time = current_time
    if @fs.path_exists(res_file) {
      try {
        let res_content = @fs.read_file_to_string(res_file)
        let parsed_json = try { Ok(@json.parse(res_content)) } catch { _ => Err("err") }
        
        match parsed_json {
          Ok(Json::Object(obj)) => {
            match obj.get("status") {
              Some(Json::String(s)) => {
                if s == "success" {
                  match obj.get("content") {
                    Some(Json::String(text)) => {
                      app.draft_text = text
                      app.draft_status = 2
                      app.refine_text = "" // Clear input after success
                    }
                    _ => ()
                  }
                } else {
                  app.draft_status = 0 // Error, back to input
                }
              }
              _ => ()
            }
          }
          _ => ()
        }
      } catch {
        _ => ()
      }
      try { @fs.remove_file(res_file) } catch { _ => () }
    }
  }
}
