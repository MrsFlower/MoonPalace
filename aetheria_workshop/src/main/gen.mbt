fn start_generation_step(app: App, step: Int) -> Unit {
  app.generation_step = step

  let mut system_prompt = ""
  let mut user_prompt = ""

  let lang_instruction = if app.lang == "ZH" {
    "请使用中文进行输出。"
  } else {
    "Please output in English."
  }

  if step == 0 { // Drafting phase AI completion
    system_prompt = "You are a professional Game Narrative Designer. Your task is to structure the user's idea into a strict, concise Game Concept Template. You MUST output ONLY the completed template, with no extra conversational text.\nCRITICAL INSTRUCTIONS:\n- The template must contain exactly these 5 fields: [Genre / Tone], [Art Style], [Core Theme], [Game Scale], and [Plot Synopsis].\n- Fill in any missing details based on logical game design principles.\n- For [Game Scale], you MUST choose exactly one of these three: '2-3 scenes', '4-6 scenes', or '7+ scenes'. Do not invent other scales.\n- Incorporate any User Modification Suggestions if provided.\n- CRITICAL: Ensure the [Plot Synopsis] is detailed and explicitly states the core story beats, the beginning, the middle, and the possible endings. This synopsis will be the foundation for the entire game.\n" + lang_instruction
    user_prompt = "User Idea / Modification: " + app.refine_text + "\n\nPrevious Concept (if any): " + app.draft_text
  } else if step == -1 { // Test API
    system_prompt = "You are a helpful assistant."
    user_prompt = if app.lang == "ZH" { "你好，请回复'API connection successful!'。" } else { "Hello, please reply with 'API connection successful!'." }
  } else if step == 1 {
    system_prompt = "You are a master World Builder and Genre Analyst. First, analyze the user's idea to determine the exact genre, tone, and a specific **Core Conflict or Philosophical Theme**. Then, expand it into a detailed world-building bible.\nCRITICAL INSTRUCTIONS:\n- You must respect the user's requested Game Scale and Art Style constraints.\n- This Core Theme must be the driving force of the entire game.\n- CRITICAL: You MUST strictly adhere to the Plot Synopsis provided by the user. Do not invent a completely different story or setting. Expand upon the provided synopsis, adding lore and depth, but keep the core characters, setting, and plot identical to the user's concept.\n- Avoid generic clichés. Tailor the world-building strictly to the determined genre. DO NOT force 'survival' or 'dark fantasy' unless the user explicitly asks for it.\n- Focus on the protagonist's specific daily routine, mundane struggles, and environment. Make the world feel lived-in and visceral.\nInclude:\n1. Core Theme & Philosophy\n2. History & Lore\n3. Factions & Hidden Conflicts\n4. Visual Tone & Atmosphere\n5. Protagonist's Background & Daily Life.\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.draft_text
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 2 {
    system_prompt = "You are a Game Narrative Designer. Based on the world bible and the Core Theme, design the **State Machine Blueprint (Node Topology)** for a branching narrative game. DO NOT write detailed story text or dialogue yet. Focus ONLY on the structure and choices.\nCRITICAL INSTRUCTIONS:\n- CRITICAL: You MUST respect the Game Scale constraint provided in the User Concept.\n- CRITICAL: Ensure the narrative structure exactly follows the Plot Synopsis in the User Concept. The blueprint must trace the beginning, the middle conflicts, and the exact endings described in the synopsis.\n- Create a network of connected Nodes (e.g., Node 1, Node 2...).\n- Define 3 to 5 tracked metrics (e.g., Health, Sanity, Trust, Wealth).\n- For each Node, provide a brief 1-sentence summary of the plot event.\n- For each Node, list the exact Choices available, how they affect the tracked metrics (+/-), and exactly which target Node they lead to.\n- Ensure the graph has branches, consequences, and at least 3 distinct Endings (Nodes with no choices).\n- Ensure choices logically reflect the Core Theme.\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.draft_text + "\n\nWorld Bible:\n" + app.step_contents[0]
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 3 {
    system_prompt = "You are a Screenwriter and Art Director. Based on the State Machine Blueprint, flesh out the actual narrative content for every single Node. For each Node, you must provide:\n1. The Node ID (matching the blueprint).\n2. Detailed Narrative Text: Write the actual story, dialogue, and visceral descriptions of the protagonist's actions and environment. Maintain a consistent tone and emotional core. CRITICAL: The story must closely follow the Plot Synopsis provided in the User Concept.\n3. Cinematography: Describe the environment, lighting, and camera angle for this specific scene.\n4. The Choices available (matching the blueprint exactly).\nCRITICAL: Ensure the story flows seamlessly from one node to its connected target nodes. Foreshadowing planted in early nodes must pay off in later nodes.\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.draft_text + "\n\nState Machine Blueprint:\n" + app.step_contents[1]
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 4 {
    system_prompt = "You are a Technical Data Compiler. Your ONLY job is to convert the provided detailed script into a strict JSON state-machine graph. You MUST output a SINGLE valid JSON object with a root key 'nodes' containing an array of node objects.\nEach node must have:\n1. 'id' (string, exactly matching the script)\n2. 'narrative' (object with 'text_content' and 'mood')\n3. 'cinematography' (object with 'environment_desc', 'scale_meters': {width, height, depth}, 'lighting', 'camera_angle', and 'image_prompt')\n4. 'gameplay' (object with 'required_conditions' map, 'state_changes' map, 'mechanic_trigger' string, and 'choices' array).\nEach choice must have 'text', 'target_id', and optionally 'condition'.\nDO NOT output any markdown, only valid JSON. DO NOT invent new story content; serialize exactly what is provided.\n" + lang_instruction + "\nCRITICAL REQUIREMENTS:\n1. 'image_prompt' MUST BE IN ENGLISH. The image prompt should describe the OVERALL SCENE AND ENVIRONMENT matching the Art Style provided in the User Concept. Do NOT describe isolated objects or props. You MUST append ', masterpiece, 8k resolution, unreal engine 5 render, highly detailed' to the end of every image_prompt.\n2. Node ID Validation: Every 'target_id' in 'choices' MUST exactly match the 'id' of an existing node in your output. Endings must have an empty 'choices' array `[]`."
    user_prompt = "User Concept:\n" + app.draft_text + "\n\nDetailed Script:\n" + app.step_contents[2]
    if app.refine_text != "" {
      user_prompt = user_prompt + "\n\nUser Modification Suggestions: " + app.refine_text
    }
  } else if step == 5 {
    system_prompt = "You are a 3D Technical Art Director. Based on the JSON story graph, analyze the entire game to determine the necessary 3D environment scenes and key characters. DO NOT include any small props, weapons, hats, kettles, or handheld items. ONLY include full environments/architecture and full characters. You must maintain a strictly unified art style across all assets, matching the Art Style provided in the User Concept. Return a valid JSON array of objects, each containing 'asset_name', 'description', 'image_prompt', and 'estimated_size_meters' (an object with 'length', 'width', 'height' as numbers representing the physical dimensions of the asset in reality). The 'image_prompt' MUST be in English and optimized for image-to-3D model generation input (e.g. Trellis2). It MUST emphasize that the object/environment is an isolated, complete 3D model viewed from an overhead isometric or side angle. Append ', isolated 3d asset on plain white background, overhead isometric view, full complete object, no environment background, masterpiece, 8k resolution, highly detailed' to every prompt. DO NOT output any markdown, only valid JSON."
    user_prompt = "User Concept:\n" + app.draft_text + "\n\nState Machine JSON:\n" + app.step_contents[3]
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
  
  let is_gemini = app.config.api_provider == "Gemini"
  
  let api_cfg = if step == -1 || step == 0 || step == 1 || step == 2 || step == 5 {
    if is_gemini { app.config.gemini_creative } else { app.config.creative_api }
  } else {
    if is_gemini { app.config.gemini_structural } else { app.config.structural_api }
  }

  let req_obj : Map[String, Json] = {
    "api_provider": app.config.api_provider.to_json(),
    "api_url": api_cfg.api_url.to_json(),
    "api_key": api_cfg.api_key.to_json(),
    "model_name": api_cfg.model_name.to_json(),
    "messages": messages.to_json()
  }

  if step == 4 || step == 5 {
    let rf : Map[String, Json] = { "type": "json_object".to_json() }
    req_obj.set("response_format", Json::object(rf))
  }
  
  let req_json = Json::object(req_obj)
    let req_str = req_json.stringify()

  // Delete response.json if exists
  let req_file = if step == -1 { "request.json" } else { app.project_id + "/request.json" }
  let res_file = if step == -1 { "response.json" } else { app.project_id + "/response.json" }
  
  if @fs.path_exists(res_file) {
    try {
      @fs.remove_file(res_file)
    } catch {
      _ => () // ignore errors
    }
  }
  
  // Create project directory synchronously if it doesn't exist
  if step != -1 {
    @raylib.system_command("cmd /c if not exist " + app.project_id + " mkdir " + app.project_id)
  }

  // Write to request.json
  try {
    @fs.write_string_to_file(req_file, req_str)
  } catch {
    _ => println("Failed to write request.json")
  }
  
  // Launch worker in background
  @raylib.system_command("start /B llm_worker.exe " + req_file + " " + res_file)
}
