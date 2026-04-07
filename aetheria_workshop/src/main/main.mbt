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
    generation_step: 0,
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
  @raylib.draw_text("Settings", 400, 50, 40, 50, 50, 50, 255)
  
  @raylib.draw_text("API Base URL:", 100, 150, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 140, 500, 40) {
    app.active_textfield = 1
  }
  let new_api_url = @ui.draw_textbox(app.config.api_url, 300, 140, 500, 40, app.active_textfield == 1)

  @raylib.draw_text("API Key:", 100, 220, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 210, 500, 40) {
    app.active_textfield = 2
  }
  let new_api_key = @ui.draw_textbox(app.config.api_key, 300, 210, 500, 40, app.active_textfield == 2)

  @raylib.draw_text("Model Name:", 100, 290, 20, 80, 80, 80, 255)
  if @ui.is_clicked(300, 280, 500, 40) {
    app.active_textfield = 3
  }
  let new_model_name = @ui.draw_textbox(app.config.model_name, 300, 280, 500, 40, app.active_textfield == 3)
  
  app.config = { api_url: new_api_url, api_key: new_api_key, model_name: new_model_name }

  if @ui.draw_button("Save & Continue", 400, 400, 200, 50) {
    @config.save_config(app.config)
    app.state = AppState::Drafting
  }
}

fn draw_drafting(app: App) -> Unit {
  @raylib.draw_text("Drafting: Write your short story idea", 100, 50, 30, 50, 50, 50, 255)
  
  if @ui.is_clicked(100, 100, 800, 200) {
    app.active_textfield = 4
  }
  app.draft_text = @ui.draw_textbox(app.draft_text, 100, 100, 800, 200, app.active_textfield == 4)

  if @ui.draw_button("Back to Settings", 100, 600, 200, 50) {
    app.state = AppState::Settings
  }
  
  if @ui.draw_button("Generate Script", 700, 600, 200, 50) {
    app.state = AppState::Generating
    start_generation_step(app, 1)
  }
}
