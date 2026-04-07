fn start_generation_step(app: App, step: Int) -> Unit {
  app.generation_step = step
  
  let mut system_prompt = ""
  let mut user_prompt = ""

  if step == 1 {
    system_prompt = "You are a top-tier world builder. Please expand the following idea into a detailed world-building bible (500 words) including history, factions, and visual tone."
    user_prompt = app.draft_text
  } else if step == 2 {
    system_prompt = "You are an interactive fiction writer. Based on the world bible, write a branching narrative with at least 3 endings. Provide text only."
    user_prompt = app.generated_content
  } else if step == 3 {
    system_prompt = "You are a screenwriter and art director. Convert the branching narrative into a detailed scene-by-scene script outline, specifying environment, lighting, camera angle, and key props for each scene."
    user_prompt = app.generated_content
  } else if step == 4 {
    system_prompt = "You are a technical designer. Convert the script outline into a strict JSON story tree. Each node must have 'id', 'is_ending', 'narrative' (text_content, mood), 'cinematography' (environment_desc, scale_meters: {width, height, depth}, lighting, camera_angle, image_prompt), 'assets' (key_props array), and 'gameplay' (choices array with text and target_id). DO NOT output any markdown, only valid JSON."
    user_prompt = app.generated_content
  }

  // Create the request JSON
  let msg1 : Map[String, Json] = {
    "role": "system".to_json(),
    "content": system_prompt.to_json()
  }
  let msg2 : Map[String, Json] = {
    "role": "user".to_json(),
    "content": user_prompt.to_json()
  }
  let messages = [
    msg1.to_json(),
    msg2.to_json()
  ]
  
  let req_obj : Map[String, Json] = {
    "api_url": app.config.api_url.to_json(),
    "api_key": app.config.api_key.to_json(),
    "model_name": app.config.model_name.to_json(),
    "messages": messages.to_json()
  }

  if step == 4 {
    req_obj.set("response_format", "json_object".to_json())
  }
  
  let req_json = req_obj.to_json()
  let req_str = req_json.to_string()
  
  // Write to request.json
  try {
    @fs.write_string_to_file("request.json", req_str)
  } catch {
    _ => println("Failed to write request.json")
  }
  
  // Delete response.json if exists
  if @fs.path_exists("response.json") {
    try {
      @fs.remove_file("response.json")
    } catch {
      _ => ()
    }
  }

  // Launch python worker in background
  @raylib.system_command("start /B python llm_worker.py request.json response.json")
}
