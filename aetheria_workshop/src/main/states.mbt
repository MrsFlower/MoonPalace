fn draw_generating(app: App) -> Unit {
  @raylib.draw_text("Generating Step \{app.generation_step}...", 400, 300, 30, 50, 50, 50, 255)
  @raylib.draw_text("Please wait...", 400, 350, 20, 100, 100, 100, 255)

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
  @raylib.draw_text("Review Generation Step \{app.generation_step}", 100, 50, 30, 50, 50, 50, 255)
  
  // A simple way to display long text (multiline is not native in basic Raylib draw_text, 
  // but let's just draw a substring or assume the user checks the console/file for now).
  // For actual use, we would write a word-wrap function.
  let preview = if app.generated_content.length() > 500 {
    app.generated_content[:500].to_string() + "..."
  } else {
    app.generated_content
  }
  
  @raylib.draw_text(preview, 100, 100, 20, 80, 80, 80, 255)
  
  if app.generation_step == 1 {
    if @ui.draw_button("Proceed to Step B (Story Tree)", 700, 600, 250, 50) {
      app.state = AppState::Generating
      start_generation_step(app, 2)
    }
  } else if app.generation_step == 2 {
    if @ui.draw_button("Proceed to Step C (Script)", 700, 600, 250, 50) {
      app.state = AppState::Generating
      start_generation_step(app, 3)
    }
  } else if app.generation_step == 3 {
    if @ui.draw_button("Proceed to Step D (JSON)", 700, 600, 250, 50) {
      app.state = AppState::Generating
      start_generation_step(app, 4)
    }
  } else if app.generation_step == 4 {
    if @ui.draw_button("Save Final Story JSON", 700, 600, 250, 50) {
      try {
        @fs.write_string_to_file("final_story.json", app.generated_content)
        println("Final story saved!")
      } catch {
        _ => println("Failed to save final story")
      }
      app.state = AppState::Settings
    }
  }
  
  if @ui.draw_button("Back to Drafting", 100, 600, 200, 50) {
    app.state = AppState::Drafting
  }
}
