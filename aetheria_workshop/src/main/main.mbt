enum AppState {
  Settings
  Drafting
  Generating
  Review
}

struct App {
  mut state: AppState
  mut config: @config.Config
  mut active_textfield: Int
  mut draft_text: String
  mut generated_content: String
  mut generation_step: Int // 0: Idle, 1: Step A, 2: Step B, 3: Step C, 4: Step D
}

fn main {
  @raylib.init_window(1024, 768, "Aetheria3D Workshop")
  @raylib.set_target_fps(60)

  let app = {
    state: AppState::Settings,
    config: @config.load_config(),
    active_textfield: 0,
    draft_text: "",
    generated_content: "",
    generation_step: -1,
  }

  while not(@raylib.window_should_close()) {
    @raylib.begin_drawing()
    @raylib.clear_background(240, 240, 240, 255)

    match app.state {
      Settings => draw_settings(app)
      Drafting => draw_drafting(app)
      Generating => draw_generating(app)
      Review => draw_review(app)
    }

    @raylib.end_drawing()
  }

  @raylib.close_window()
}

fn draw_settings(app: App) -> Unit {
  @raylib.draw_text("Settings", 400, 20, 40, 50, 50, 50, 255)

  // Automatically read API Key from env if empty
  if app.config.creative_api.api_key == "" {
    let env_key = @raylib.get_env("CODINGPLAN_API_KEY")
    if env_key != "" {
      app.config = {
        creative_api: { ..app.config.creative_api, api_key: env_key },
        structural_api: { ..app.config.structural_api, api_key: env_key }
      }
    }
  }

  // Creative API (Steps A & B)
  @raylib.draw_text("Creative API (Steps A & B):", 100, 80, 20, 50, 50, 50, 255)

  @raylib.draw_text("API Base URL:", 100, 120, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 110, 500, 40) {
    app.active_textfield = 1
  }
  let new_c_api_url = @ui.draw_textbox(app.config.creative_api.api_url, 300, 110, 500, 40, app.active_textfield == 1)

  @raylib.draw_text("API Key:", 100, 170, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 160, 500, 40) {
    app.active_textfield = 2
  }
  let new_c_api_key = @ui.draw_textbox(app.config.creative_api.api_key, 300, 160, 500, 40, app.active_textfield == 2)

  @raylib.draw_text("Model Name:", 100, 220, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 210, 500, 40) {
    app.active_textfield = 3
  }
  let new_c_model_name = @ui.draw_textbox(app.config.creative_api.model_name, 300, 210, 500, 40, app.active_textfield == 3)

  // Structural API (Steps C & D)
  @raylib.draw_text("Structural API (Steps C & D):", 100, 280, 20, 50, 50, 50, 255)

  @raylib.draw_text("API Base URL:", 100, 320, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 310, 500, 40) {
    app.active_textfield = 4
  }
  let new_s_api_url = @ui.draw_textbox(app.config.structural_api.api_url, 300, 310, 500, 40, app.active_textfield == 4)

  @raylib.draw_text("API Key:", 100, 370, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 360, 500, 40) {
    app.active_textfield = 5
  }
  let new_s_api_key = @ui.draw_textbox(app.config.structural_api.api_key, 300, 360, 500, 40, app.active_textfield == 5)

  @raylib.draw_text("Model Name:", 100, 420, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 410, 500, 40) {
    app.active_textfield = 6
  }
  let new_s_model_name = @ui.draw_textbox(app.config.structural_api.model_name, 300, 410, 500, 40, app.active_textfield == 6)

  app.config = {
    creative_api: { api_url: new_c_api_url, api_key: new_c_api_key, model_name: new_c_model_name },
    structural_api: { api_url: new_s_api_url, api_key: new_s_api_key, model_name: new_s_model_name }
  }

  if @ui.draw_button("Use LKEAP URL", 100, 480, 200, 40) {
    app.config = {
      creative_api: { ..app.config.creative_api, api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions" },
      structural_api: { ..app.config.structural_api, api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions" }
    }
  }
  if @ui.draw_button("Use TokenHub URL", 320, 480, 200, 40) {
    app.config = {
      creative_api: { ..app.config.creative_api, api_url: "https://tokenhub.tencentmaas.com/v1/chat/completions" },
      structural_api: { ..app.config.structural_api, api_url: "https://tokenhub.tencentmaas.com/v1/chat/completions" }
    }
  }
  
  if @ui.draw_button("Test Creative API", 540, 480, 200, 40) {
    @config.save_config(app.config)
    start_generation_step(app, 0) // We'll use step 0 for a simple test
  }

  if @ui.draw_button("Save & Continue", 400, 540, 200, 50) {
    @config.save_config(app.config)
    
    // Save to environment variable for future sessions
    // Using a simple Python script to set user environment variable permanently on Windows
    let key = app.config.creative_api.api_key
    if key != "" {
      @raylib.system_command("setx CODINGPLAN_API_KEY \"" + key + "\"")
    }

    app.state = AppState::Drafting
  }

  // Display API test result
  if app.generation_step == 0 {
    if @fs.path_exists("response.json") {
      try {
        let content = @fs.read_file_to_string("response.json")
        let res_json = @json.parse(content)
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
            let preview = if msg.length() > 50 { msg[:50].to_string() + "..." } else { msg }
            @raylib.draw_text("Test Success: " + preview, 100, 600, 20, 0, 150, 0, 255)
            if @ui.draw_button("Copy Result", 800, 590, 120, 35) {
              @raylib.set_clipboard_text(msg)
            }
          } else {
            @raylib.draw_text("Test Failed: " + msg, 100, 600, 20, 255, 0, 0, 255)
            if @ui.draw_button("Copy Error", 800, 590, 120, 35) {
              @raylib.set_clipboard_text(msg)
            }
          }
        }
      } catch {
        _ => @raylib.draw_text("Parsing test result...", 100, 600, 20, 100, 100, 100, 255)
      }
    } else {
      @raylib.draw_text("Testing API... Please wait", 100, 600, 20, 100, 100, 100, 255)
    }
  }
}

fn draw_drafting(app: App) -> Unit {
  @raylib.draw_text("Drafting: Write your short story idea", 100, 50, 30, 50, 50, 50, 255)

  if @ui.is_clicked(100, 100, 800, 200) {
    app.active_textfield = 7
  }
  app.draft_text = @ui.draw_textbox(app.draft_text, 100, 100, 800, 200, app.active_textfield == 7)

  if @ui.draw_button("Back to Settings", 100, 600, 200, 50) {
    app.state = AppState::Settings
  }
  
  if @ui.draw_button("Generate Script", 700, 600, 200, 50) {
    app.state = AppState::Generating
    start_generation_step(app, 1)
  }
}
