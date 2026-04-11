fn draw_generating(app: App) -> Unit {
  @raylib.draw_text(if app.lang == "EN" { "Generating Step \{app.generation_step}..." } else { "正在生成步骤 \{app.generation_step}..." }, 400, 300, 30, 50, 50, 50, 255)
  @raylib.draw_text(if app.lang == "EN" { "Please wait..." } else { "请稍候..." }, 400, 350, 20, 100, 100, 100, 255)

  if @fs.path_exists("response.json") {
    try {
      let content = @fs.read_file_to_string("response.json")
      let res_json = @json.parse(content)
      
      // check status
      if res_json is Object(obj) {
        match obj.get("status") {
          Some(String("success")) => {
            match obj.get("content") {
              Some(String(text)) => {
                app.generated_content = text
                app.state = AppState::Review
              }
              _ => {
                println("Error: content is not string")
                app.state = AppState::Drafting
              }
            }
          }
          _ => {
            println("Error from worker")
            app.state = AppState::Drafting
          }
        }
      } else {
        app.state = AppState::Drafting
      }
      
      // delete response.json after processing
      @fs.remove_file("response.json")
    } catch {
      _ => println("Failed to read/parse response.json")
    }
  }
}

fn draw_review(app: App) -> Unit {
  let title = if app.lang == "EN" {
    "Review Generation Step \{app.generation_step}"
  } else {
    "生成结果预览 (步骤 \{app.generation_step})"
  }
  @raylib.draw_text(title, 100, 30, 30, 50, 50, 50, 255)

  // Use the scrollable text area for displaying long text correctly
  @ui.draw_scrollable_text_area(app.generated_content, 100, 80, 800, 480, app.scroll_y)

  if app.generation_step == 0 {
    if @ui.draw_button(if app.lang == "EN" { "Back to Settings" } else { "返回设置" }, 100, 600, 200, 50) {
      app.state = AppState::Settings
    }
  } else if app.generation_step == 1 {
    if @ui.draw_button(if app.lang == "EN" { "Proceed to Step B (Story Tree)" } else { "继续: 步骤 B (多结局故事)" }, 650, 600, 300, 50) {   
      app.state = AppState::Generating
      app.scroll_y.val = 0.0
      start_generation_step(app, 2)
    }
  } else if app.generation_step == 2 {
    if @ui.draw_button(if app.lang == "EN" { "Proceed to Step C (Script)" } else { "继续: 步骤 C (分镜剧本)" }, 650, 600, 300, 50) {       
      app.state = AppState::Generating
      app.scroll_y.val = 0.0
      start_generation_step(app, 3)
    }
  } else if app.generation_step == 3 {
    if @ui.draw_button(if app.lang == "EN" { "Proceed to Step D (JSON)" } else { "继续: 步骤 D (生成JSON)" }, 650, 600, 300, 50) {
      app.state = AppState::Generating
      app.scroll_y.val = 0.0
      start_generation_step(app, 4)
    }
  } else if app.generation_step == 4 {
    if @ui.draw_button(if app.lang == "EN" { "Save Final Story JSON" } else { "保存最终故事JSON" }, 650, 600, 300, 50) {
      try {
        @fs.write_string_to_file("final_story.json", app.generated_content)     
        println("Final story saved!")
      } catch {
        _ => println("Failed to save final story")
      }
      app.state = AppState::Settings
    }
  }

  if @ui.draw_button(if app.lang == "EN" { "Back to Drafting" } else { "返回起草" }, 100, 600, 200, 50) {
    app.state = AppState::Drafting
  }
}
