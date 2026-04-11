fn start_generation_step(app: App, step: Int) -> Unit {
  app.generation_step = step

  let mut system_prompt = ""
  let mut user_prompt = ""

  let scale_desc = if app.story_scale == 0 {
    if app.lang == "ZH" { "这是一部包含 2 到 3 个关键场景的【短篇】作品。" } else { "This is a [SHORT] scale story with 2-3 key scenes." }
  } else if app.story_scale == 1 {
    if app.lang == "ZH" { "这是一部包含 4 到 6 个关键场景的【中篇】作品。" } else { "This is a [MEDIUM] scale story with 4-6 key scenes." }
  } else {
    if app.lang == "ZH" { "这是一部包含 7 个以上场景的【史诗】巨作。" } else { "This is an [EPIC] scale story with 7+ key scenes." }
  }

  let lang_instruction = if app.lang == "ZH" {
    "请使用中文进行输出。"
  } else {
    "Please output in English."
  }

  if step == 0 { // Test API
    system_prompt = "You are a helpful assistant."
    user_prompt = if app.lang == "ZH" { "你好，请回复'API connection successful!'。" } else { "Hello, please reply with 'API connection successful!'." }
  } else if step == 1 {
    system_prompt = "You are a top-tier world builder. Please expand the following idea into a detailed world-building bible (500 words) including history, factions, and visual tone.\n" + lang_instruction
    user_prompt = app.draft_text + "\n\n" + scale_desc
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 2 {
    system_prompt = "You are an interactive fiction writer. Based on the world bible, write a branching narrative with at least 3 endings. Provide text only.\n" + lang_instruction
    user_prompt = app.generated_content + "\n\n" + scale_desc
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 3 {
    system_prompt = "You are a screenwriter and art director. Convert the branching narrative into a detailed scene-by-scene script outline, specifying environment, lighting, camera angle, and key props for each scene. Remember to incorporate 'Narrative Funnels', 'State Tracking', and 'Systemic Gameplay' into the design of the script. Do not output JSON yet.\n" + lang_instruction
    user_prompt = app.generated_content + "\n\n" + scale_desc
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 4 {
    system_prompt = "You are a technical designer. Convert the script outline into a strict JSON story tree. Each node must have:\n1. 'id' (string)\n2. 'narrative' (object with text_content, mood)\n3. 'cinematography' (environment_desc, scale_meters: {width, height, depth}, lighting, camera_angle, image_prompt)\n4. 'gameplay' (object with 'required_conditions' map, 'state_changes' map, 'mechanic_trigger' string, and 'choices' array).\nEach choice must have 'text', 'target_id', and optionally 'condition'.\nDO NOT output any markdown, only valid JSON.\n" + lang_instruction + "\nCRITICAL: Even if the rest of the JSON is in Chinese, the 'image_prompt' field inside 'cinematography' MUST BE IN ENGLISH, as it will be used for Stable Diffusion / Trellis generation."
    user_prompt = app.generated_content
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
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
  
  let api_cfg = if step == 0 || step == 1 || step == 2 {
    app.config.creative_api
  } else {
    app.config.structural_api
  }

  let req_obj : Map[String, Json] = {
    "api_url": api_cfg.api_url.to_json(),
    "api_key": api_cfg.api_key.to_json(),
    "model_name": api_cfg.model_name.to_json(),
    "messages": messages.to_json()
  }

  if step == 4 {
    req_obj.set("response_format", "json_object".to_json())
  }
  
  let req_json = req_obj.to_json()
  let req_str = req_json.stringify()

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
