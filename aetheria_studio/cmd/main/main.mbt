
fn extract_json_from_markdown(content: String) -> String {
  let mut start_idx = -1
  let mut end_idx = -1
  
  for i = 0; i <= content.length() - 7; i = i + 1 {
    if content[i] == '`' && content[i+1] == '`' && content[i+2] == '`' && content[i+3] == 'j' && content[i+4] == 's' && content[i+5] == 'o' && content[i+6] == 'n' {
      start_idx = i + 7
      break
    }
  }
  
  if start_idx >= 0 {
    for i = content.length() - 3; i >= start_idx; i = i - 1 {
      if content[i] == '`' && content[i+1] == '`' && content[i+2] == '`' {
        end_idx = i
        break
      }
    }
  }
  
  if start_idx >= 0 && end_idx > start_idx {
    return content[start_idx:end_idx].to_string()
  }
  
  // Fallback to first [ or {
  let mut first_brace = -1
  for i = 0; i < content.length(); i = i + 1 {
    if content[i] == '{' || content[i] == '[' {
      first_brace = i
      break
    }
  }
  let mut last_brace = -1
  for i = content.length() - 1; i >= 0; i = i - 1 {
    if content[i] == '}' || content[i] == ']' {
      last_brace = i + 1
      break
    }
  }
  
  if first_brace >= 0 && last_brace > first_brace {
    return content[first_brace:last_brace].to_string()
  }
  content
}

struct App {
  mut current_step: Int
  mut draft_text: String
  step_contents: Array[String]
  mut project_id: String
  mut config: @config.Config
}

fn resolve_worker_exe(exe_dir: String, worker_base_name: String) -> String {
  let worker_v4 = exe_dir + "\\" + worker_base_name + "_v4.exe"
  if @fs.path_exists(worker_v4) {
    return worker_v4
  }
  let worker_v3 = exe_dir + "\\" + worker_base_name + "_v3.exe"
  if @fs.path_exists(worker_v3) {
    return worker_v3
  }
  worker_v4
}

fn find_next_pipeline_step(app: App) -> Int {
  if app.step_contents[0] == "" || app.step_contents[0].has_prefix("Error:") {
    return 0
  }
  for i = 1; i < 6; i = i + 1 {
    if app.step_contents[i] == "" || app.step_contents[i].has_prefix("Error:") {
      return i
    }
  }
  6
}

fn start_generation_step(app: App, step: Int) -> Unit {
  app.current_step = step

  let lang_instruction = if app.config.lang == "ZH" {
    "\nCRITICAL LANGUAGE MODE: Chinese (Simplified). All generated narrative text, dialogue, descriptions, and choices MUST be in Chinese."
  } else {
    "\nCRITICAL LANGUAGE MODE: English. All generated narrative text, dialogue, descriptions, and choices MUST be in English."
  }
  let mut system_prompt = ""
  let mut user_prompt = ""
  let mut scale_node_hint = "4-6 nodes (recommended)"
  if app.step_contents[0].contains("2-3 scenes") {
    scale_node_hint = "2-3 nodes (at least 3 nodes)"
  } else if app.step_contents[0].contains("4-6 scenes") {
    scale_node_hint = "4-6 nodes"
  } else if app.step_contents[0].contains("7+ scenes") {
    scale_node_hint = "7+ nodes"
  }

  if step == 0 {
    system_prompt = "You are a professional Game Narrative Designer. Your task is to structure the user's idea into a strict, concise Game Concept Template. You MUST output ONLY the completed template, with no extra conversational text.\nCRITICAL INSTRUCTIONS:\n- The template must contain exactly these 6 fields: [Genre / Tone], [Art Style], [Core Theme], [Game Scale], [Story Summary], and [Plot Synopsis].\n- Fill in any missing details based on logical game design principles.\n- For [Game Scale], you MUST choose exactly one of these three: '2-3 scenes', '4-6 scenes', or '7+ scenes'. Do not invent other scales.\n- Incorporate any User Modification Suggestions if provided.\n- CRITICAL: If the user provides a specific phrase, classical idiom, fable, or existing story (e.g. '此地无银三百两'), you MUST use the exact original plot, characters, and events of that specific story. Do not just extract the moral lesson and invent a new story. You MUST strictly build the literal story around their exact input.\n- CRITICAL: [Story Summary] MUST be a concise but literal explanation of exactly what happens in the story (the who, what, and how). If it's a specific idiom/fable, explicitly write out the original tale's events here.\n- CRITICAL: Ensure the [Plot Synopsis] is detailed and explicitly states the core story beats, the beginning, the middle conflict, and the possible endings based on the [Story Summary]. This synopsis will be the strict foundation for the entire game.\n" + lang_instruction
    user_prompt = "User Idea: " + app.draft_text
  } else if step == 1 {
    system_prompt = "You are a master World Builder and Genre Analyst. First, analyze the user's concept to determine the exact genre, tone, and a specific **Core Conflict or Philosophical Theme**. Then, expand it into a detailed world-building bible.\nCRITICAL INSTRUCTIONS:\n- You must respect the user's requested Game Scale and Art Style constraints.\n- This Core Theme must be the driving force of the entire game.\n- CRITICAL: You MUST strictly adhere to the [Story Summary] and [Plot Synopsis] provided by the user. Do not invent a completely different story or setting. Do NOT substitute the user's concept with another famous story or idiom. Treat their input literally. If it's a known classical story, expand upon its exact original characters and plot, adding lore and depth, but keep the core events identical to the user's concept.\n- Avoid generic cliches. Tailor the world-building strictly to the determined genre. DO NOT force 'survival' or 'dark fantasy' unless the user explicitly asks for it.\n- Focus on the protagonist's specific daily routine, mundane struggles, and environment. Make the world feel lived-in and visceral.\nInclude:\n1. Core Theme & Philosophy\n2. History & Lore\n3. Factions & Hidden Conflicts\n4. Visual Tone & Atmosphere\n5. Protagonist's Background & Daily Life.\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.step_contents[0]
  } else if step == 2 {
    system_prompt = "You are a Game Narrative Designer. Your task is to design the **State Machine Blueprint (Node Topology)** for a branching narrative game based on the World Bible.\nCRITICAL INSTRUCTIONS:\n- You MUST output a FULL, complete list of ALL nodes. Do NOT output '[CONTINUE]', '...', placeholders, or summaries.\n- Node count must follow the requested Game Scale. Target size: " + scale_node_hint + ".\n- Each Node MUST represent a specific scene in the story.\n- DO NOT output pseudo-code conditionals like 'IF ...'.\n\nYou MUST use EXACTLY the following Markdown template for your entire response. Do not add any conversational text before or after the template.\n\n# Tracked Metrics\n- [Metric 1] (e.g., Health)\n- [Metric 2] (e.g., Trust)\n- [Metric 3] (e.g., Wealth)\n\n# Node List\n\n## Node 1: [Node Name]\n**Description:** [1-sentence summary of the plot event here]\n**Choices:**\n- [Choice 1 Text] (+Metric1, -Metric2) -> Leads to Node 2\n- [Choice 2 Text] (+Metric3) -> Leads to Node 3\n\n## Node 2: [Node Name]\n**Description:** [1-sentence summary]\n**Choices:**\n- [Choice 1 Text] -> Leads to Node 4\n\n(Continue this exact format for all remaining nodes. Include at least 1 ending node with empty Choices.)\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.step_contents[0] + "\n\nWorld Bible:\n" + app.step_contents[1]
  } else if step == 3 {
    system_prompt = "You are a Screenwriter and Art Director. Based on the State Machine Blueprint, flesh out the actual narrative content for every single Node. For each Node, you must provide:\n1. The Node ID (matching the blueprint).\n2. Detailed Narrative Text: Write the actual story, dialogue, and visceral descriptions of the protagonist's actions and environment. Maintain a consistent tone and emotional core. CRITICAL: The story must closely follow the [Story Summary] and [Plot Synopsis] provided in the User Concept.\n3. Cinematography: Describe the environment and lighting for this specific scene. (Keep it a static fixed perspective, no dynamic camera movements).\n4. The Choices available (matching the blueprint exactly).\nCRITICAL: Ensure the story flows seamlessly from one node to its connected target nodes. Foreshadowing planted in early nodes must pay off in later nodes.\nCRITICAL: Every node must be fully written. Never output placeholders like '(from previous...)', '[CONTINUE]', '...', 'TBD', or incomplete fragments.\nCRITICAL LANGUAGE REQUIREMENT: ALL generated story text, dialogue, descriptions, and choices MUST be entirely written in the user's requested language. DO NOT output English if another language is requested.\n" + lang_instruction
    user_prompt = "User Concept:\n" + app.step_contents[0] + "\n\nWorld Bible:\n" + app.step_contents[1] + "\n\nState Machine Blueprint:\n" + app.step_contents[2]
  } else if step == 4 {
    system_prompt = "You are a Technical Data Compiler. Your ONLY job is to convert the provided detailed script into a strict JSON state-machine graph. You MUST output a SINGLE valid JSON object with a root key 'nodes' containing an array of node objects.\nEach node must have:\n1. 'id' (string, exactly matching the script)\n2. 'narrative' (object with 'text_content' and 'mood')\n3. 'cinematography' (object with 'environment_desc', 'scale_meters': {width, height, depth}, 'lighting', and 'image_prompt')\n4. 'gameplay' (object with 'required_conditions' map, 'state_changes' map, 'mechanic_trigger' string, and 'choices' array).\nEach choice must have 'text', 'target_id', and optionally 'condition'.\nDO NOT output any markdown, only valid JSON. DO NOT invent new story content; serialize exactly what is provided.\nCRITICAL LANGUAGE REQUIREMENT: ALL text fields ('text_content', 'mood', 'environment_desc', 'lighting', choice 'text') MUST be translated into the user's requested language. ONLY 'image_prompt' must be in English.\n" + lang_instruction + "\nCRITICAL REQUIREMENTS:\n1. 'image_prompt' MUST BE IN ENGLISH. The image prompt should describe the OVERALL SCENE AND ENVIRONMENT matching the Art Style provided in the User Concept. CRITICAL: You MUST explicitly describe the relevant NPC characters (who speak or act in this node) appearing inside this environment. Do NOT describe an empty room. Describe what the NPCs look like and where they are standing in the scene. However, EXPLICITLY EXCLUDE the main protagonist (the player character) from the image_prompt. You MUST append ', static fixed perspective, masterpiece, 8k resolution, unreal engine 5 render, highly detailed' to the end of every image_prompt.\n2. Node ID Validation: Every 'target_id' in 'choices' MUST exactly match the 'id' of an existing node in your output. Endings must have an empty 'choices' array `[]`."
    user_prompt = "User Concept:\n" + app.step_contents[0] + "\n\nState Machine Blueprint:\n" + app.step_contents[2] + "\n\nDetailed Script:\n" + app.step_contents[3]
  } else if step == 5 {
    system_prompt = "You are a 3D Technical Art Director. Based on the JSON story graph, you must generate exactly one 3D asset entry for EACH node in the story graph, so that the 2D background and 3D environment map 1-to-1. Return a valid JSON array of objects, each containing 'asset_name' (MUST BE exactly the 'id' of the node), 'description', 'image_prompt', and 'estimated_size_meters'.\nCRITICAL INSTRUCTIONS for 'image_prompt':\n- MUST be in English and optimized for 3D model generation input (e.g. Trellis2).\n- You MUST include the relevant NPC characters (who are involved in the story or dialogue of this node) into the 3D diorama/environment description, so they are generated together as part of the scene. EXPLICITLY EXCLUDE the main protagonist (the player character).\n- It MUST describe the object as an isolated 3D model/diorama. Append ', isolated 3d diorama asset on plain white background, overhead isometric view, full complete object, no environment background, masterpiece, 8k resolution, highly detailed' to every prompt.\nDO NOT output any markdown, only valid JSON."
    user_prompt = "User Concept:\n" + app.step_contents[0] + "\n\nState Machine JSON:\n" + app.step_contents[4]
  }

  // Debug: print current user prompt size to ensure it's not empty
  println("Step \{step} System Prompt Length: \{system_prompt.length()}")
  println("Step \{step} User Prompt Length: \{user_prompt.length()}")

  let msg1 : Map[String, Json] = {
    "role": "system".to_json(),
    "content": system_prompt.to_json()
  }
  let msg2 : Map[String, Json] = {
    "role": "user".to_json(),
    "content": user_prompt.to_json()
  }
  let messages = [
    Json::object(msg1),
    Json::object(msg2)
  ]

  let is_gemini = app.config.api_provider == "Gemini"
  let api_cfg = if step == 0 || step == 1 || step == 2 || step == 3 {
    if is_gemini { app.config.gemini_creative } else { app.config.creative_api }
  } else {
    if is_gemini { app.config.gemini_structural } else { app.config.structural_api }
  }

  // Resolve ENV variable for API key
  let mut resolved_api_key = api_cfg.api_key
  if resolved_api_key.has_prefix("ENV:") {
      let env_var = resolved_api_key[4:].to_string()
      let env_val = @webui.get_env(env_var)
      if env_val != "" {
          resolved_api_key = env_val
      }
  }

  let req_obj : Map[String, Json] = {
    "api_provider": app.config.api_provider.to_json(),
    "api_url": api_cfg.api_url.to_json(),
    "api_key": resolved_api_key.to_json(),
    "model_name": api_cfg.model_name.to_json(),
    "messages": Json::array(messages)
  }

  if step == 4 || step == 5 {
    let rf : Map[String, Json] = { "type": "json_object".to_json() }
    req_obj.set("response_format", Json::object(rf))
  }

  let req_json = Json::object(req_obj)
  let req_str = req_json.stringify()

  @webui.system_command("cmd /c if not exist \"..\\Projects\" mkdir \"..\\Projects\"")
  @webui.system_command("cmd /c if not exist \"" + app.project_id + "\" mkdir \"" + app.project_id + "\"")
  
  let req_file = app.project_id + "\\request.json"
  let res_file = app.project_id + "\\response.json"

  if @fs.path_exists(res_file) {
    try { @fs.remove_file(res_file) } catch { _ => () }
  }

  try {
    @fs.write_string_to_file(req_file, req_str)
  } catch {
    _ => println("Failed to write request.json")
  }

  let worker_path = resolve_worker_exe(@net.get_exe_dir(), "llm_worker")
  @webui.system_command("start /B \"\" \"" + worker_path + "\" \"" + req_file + "\" \"" + res_file + "\"")
}

fn main {
  let app : App = {
      current_step: -1,
      draft_text: "",
      step_contents: ["", "", "", "", "", ""],
      project_id: "test_proj",
      config: @config.load_config()
  }

  let window = @webui.webui_new_window()
  
  @webui.on(window, "backend_get_state", fn(w, _req, event_number) {
      w |> ignore
      let state_json : Map[String, Json] = {
          "current_step": app.current_step.to_json(),
          "draft_text": app.draft_text.to_json(),
          "project_id": app.project_id.to_json(),
          "step_contents": Json::array([
              app.step_contents[0].to_json(),
              app.step_contents[1].to_json(),
              app.step_contents[2].to_json(),
              app.step_contents[3].to_json(),
              app.step_contents[4].to_json(),
              app.step_contents[5].to_json()
          ])
      }
      @webui.webui_set_response(window, event_number, Json::object(state_json).stringify())
  })
  
  @webui.on(window, "backend_get_config", fn(w, _req, event_number) {
      w |> ignore
      @webui.webui_set_response(window, event_number, app.config.to_json().stringify())
  })
  
  @webui.on(window, "backend_save_config", fn(w, req, event_number) {
      w |> ignore
      try {
          let parsed = @json.parse(req) catch { _ => Json::object(Map::new()) }
          match parsed {
              Json::Object(_) => {
                  let new_config : @config.Config = @json.from_json(parsed)
                  app.config = new_config
                  @config.save_config(new_config)
                  @webui.webui_set_response(window, event_number, "ok")
              }
              _ => @webui.webui_set_response(window, event_number, "error")
          }
      } catch {
          _ => @webui.webui_set_response(window, event_number, "error")
      }
  })
  
  @webui.on(window, "backend_test_api", fn(w, req, event_number) {
      w |> ignore
      let test_dir = "test_proj"
      @webui.system_command("cmd /c if not exist " + test_dir + " mkdir " + test_dir)
      let req_file = test_dir + "\\test_request.json"
      let res_file = test_dir + "\\test_response.json"
      if @fs.path_exists(res_file) {
        try { @fs.remove_file(res_file) } catch { _ => () }
      }
      try {
          let parsed = @json.parse(req) catch { _ => Json::object(Map::new()) }
          match parsed {
              Json::Object(m) => {
                  let test_prompt = "Hello! Please reply with exactly the word 'OK' if you can read this."
                  let msg1 : Map[String, Json] = { "role": "user".to_json(), "content": test_prompt.to_json() }
                  let msgs = [Json::object(msg1)]
                  
                  let req_obj = m
                  
                  // Resolve ENV for test API as well
                  match req_obj.get("api_key") {
                      Some(Json::String(s)) => {
                          if s.has_prefix("ENV:") {
                              let env_var = s[4:].to_string()
                              let v = @webui.get_env(env_var)
                              if v != "" {
                                  req_obj.set("api_key", v.to_json())
                              }
                          }
                      }
                      _ => ()
                  }

                  req_obj.set("messages", Json::array(msgs))
                  let req_json = Json::object(req_obj)
                  @fs.write_string_to_file(req_file, req_json.stringify())
                  
                  let worker_path = resolve_worker_exe(@net.get_exe_dir(), "llm_worker")
                  @webui.system_command("start /B /WAIT \"\" \"" + worker_path + "\" \"" + req_file + "\" \"" + res_file + "\"")
                  
                  if @fs.path_exists(res_file) {
                      let res_str = @fs.read_file_to_string(res_file)
                      let p = @json.parse(res_str)
                      match p {
                          Json::Object(pm) => {
                              match pm.get("status") {
                                  Some(Json::String(s)) => {
                                      if s == "error" {
                                          match pm.get("message") {
                                              Some(Json::String(err_msg)) => @webui.webui_set_response(window, event_number, "Error: " + err_msg)
                                              _ => @webui.webui_set_response(window, event_number, "Unknown error from API")
                                          }
                                      } else {
                                          match pm.get("content") {
                                              Some(Json::String(c)) => @webui.webui_set_response(window, event_number, "Success: " + c)
                                              _ => @webui.webui_set_response(window, event_number, "Failed to get text content from API")
                                          }
                                      }
                                  }
                                  _ => @webui.webui_set_response(window, event_number, "Invalid response format")
                              }
                          }
                          _ => @webui.webui_set_response(window, event_number, "Failed to parse API response JSON")
                      }
                  } else {
                      @webui.webui_set_response(window, event_number, "Timeout or network error")
                  }
              }
              _ => @webui.webui_set_response(window, event_number, "Invalid payload")
          }
      } catch {
          _ => @webui.webui_set_response(window, event_number, "Error during test")
      }
  })
  
  @webui.on(window, "backend_get_asset_list", fn(w, _req, event_number) {
      w |> ignore
      let json_str_2d = extract_json_from_markdown(app.step_contents[4])
      let json_str_3d = extract_json_from_markdown(app.step_contents[5])
      let arr = []
      
      let parsed_2d = try { @json.parse(json_str_2d) } catch { _ => Json::object(Map::new()) }
      let parsed_3d = try { @json.parse(json_str_3d) } catch { _ => Json::object(Map::new()) }
      
      match parsed_2d {
          Json::Object(map) => {
                  match map.get("nodes") {
                      Some(Json::Array(nodes)) => {
                          for i = 0; i < nodes.length(); i = i + 1 {
                              match nodes[i] {
                                  Json::Object(n) => {
                                      let id = match n.get("id") { Some(Json::String(s)) => s; _ => "node_" + i.to_string() }
                                      let mut ascii_id = ""
                                      for j = 0; j < id.length(); j = j + 1 {
                                          let c = id[j].to_int()
                                          if c >= 32 && c <= 126 { ascii_id = ascii_id + String::make(1, c.unsafe_to_char()) }
                                      }
                                      ascii_id = ascii_id.replace_all(old=" ", new="_")
                                      if ascii_id == "" || ascii_id == "_" { ascii_id = "node_" + i.to_string() }
                                      
                                      let image_prompt = match n.get("cinematography") {
                                          Some(Json::Object(c)) => match c.get("image_prompt") { Some(Json::String(s)) => s; _ => "" }
                                          _ => ""
                                      }
                                      
                                      if image_prompt != "" {
                                          let clean_name = "scene_" + ascii_id + ".png"
                                          let out_path = app.project_id + "\\" + clean_name
                                          let exists = @fs.path_exists(out_path)
                                          let item : Map[String, Json] = {
                                              "name": clean_name.to_json(),
                                              "prompt": image_prompt.to_json(),
                                          "kind": "scene_2d".to_json(),
                                          "status": (if exists { "done" } else { "pending" }).to_json()
                                          }
                                          arr.push(Json::object(item))
                                      }
                                  }
                                  _ => ()
                              }
                          }
                      }
                      _ => ()
                  }
              }
              _ => ()
          }

          let mut assets_array = []
          match parsed_3d {
              Json::Array(assets) => assets_array = assets
              Json::Object(map) => {
                  // The LLM was forced to return json_object, so it might wrap the array
                  // e.g. {"assets": [...]}, {"models": [...]}, {"items": [...]}
                  for _, v in map {
                      match v {
                          Json::Array(arr) => {
                              assets_array = arr
                              break
                          }
                          _ => ()
                      }
                  }
              }
              _ => ()
          }
          
          if assets_array.length() > 0 {
              for i = 0; i < assets_array.length(); i = i + 1 {
                  match assets_array[i] {
                      Json::Object(n) => {
                          let image_prompt = match n.get("image_prompt") {
                              Some(Json::String(s)) => s
                              _ => ""
                          }
                          let name = match n.get("asset_name") {
                              Some(Json::String(s)) => s
                              _ => "asset_" + i.to_string()
                          }
                          
                          if image_prompt != "" {
                              let mut ascii_name = ""
                              for j = 0; j < name.length(); j = j + 1 {
                                  let c = name[j].to_int()
                                  if c >= 32 && c <= 126 { ascii_name = ascii_name + String::make(1, c.unsafe_to_char()) }
                              }
                              ascii_name = ascii_name.replace_all(old=" ", new="_")
                              if ascii_name == "" || ascii_name == "_" { ascii_name = "asset_obj_" + i.to_string() }
                              
                              let clean_name = ascii_name + ".png"
                              let out_path = app.project_id + "\\" + clean_name
                              let exists = @fs.path_exists(out_path)
                              let item : Map[String, Json] = {
                                  "name": clean_name.to_json(),
                                  "prompt": image_prompt.to_json(),
                                  "kind": "input_3d".to_json(),
                                  "status": (if exists { "done" } else { "pending" }).to_json()
                              }
                              arr.push(Json::object(item))
                          }
                      }
                      _ => ()
                  }
              }
          }
          
      @webui.webui_set_response(window, event_number, Json::array(arr).stringify())
  })

  /// Backend proxy to bypass CORS when frontend JS fetches RunComfy / Local API.
  /// Expects JSON string: `{"url": "...", "method": "...", "token": "...", "body": "..."}`
  @webui.on(window, "backend_http_request", fn(w, req, event_number) {
        w |> ignore
        let parsed = @json.parse(req) catch { _ => Json::object(Map::new()) }
        match parsed {
            Json::Object(m) => {
                let url = match m.get("url") { Some(Json::String(s)) => s; _ => "" }
                let req_method = match m.get("method") { Some(Json::String(s)) => s; _ => "GET" }
                let token = match m.get("token") { Some(Json::String(s)) => s; _ => "" }
                let body = match m.get("body") { Some(Json::String(s)) => s; _ => "" }
                
                let headers = if token != "" { ["Authorization: Bearer " + token] } else { [] }
                
                if req_method == "POST" {
                    let mut final_headers = [""]
                    final_headers = headers
                    if not(headers.contains("Content-Type: application/json")) {
                        final_headers.push("Content-Type: application/json")
                    }
                    match @net.http_post(url, final_headers, body) {
                        Ok(res) => @webui.webui_set_response(window, event_number, res.body)
                        Err(e) => @webui.webui_set_response(window, event_number, "{\"error\": \"" + e.to_string() + "\"}")
                    }
                } else {
                    match @net.http_get(url, headers~) {
                        Ok(res) => @webui.webui_set_response(window, event_number, res.body)
                        Err(e) => @webui.webui_set_response(window, event_number, "{\"error\": \"" + e.to_string() + "\"}")
                    }
                }
            }
            _ => @webui.webui_set_response(window, event_number, "{\"error\": \"invalid request\"}")
        }
    })

    /// Provides the full configuration environment needed by the JS frontend 
  /// to make direct RunComfy or Local ComfyUI calls, bypassing backend `.bat` blocking scripts.
  @webui.on(window, "backend_file_exists", fn(w, path, event_number) {
        w |> ignore
        let exists = @fs.path_exists(path)
        let resp = if exists { "true" } else { "false" }
        @webui.webui_set_response(window, event_number, resp)
  })

  @webui.on(window, "backend_get_config_all", fn(w, _req, event_number) {
        w |> ignore
        let conf_json : Map[String, Json] = {
            "comfy_mode": app.config.comfy_mode.to_json(),
            "comfy_url": app.config.comfy_url.to_json(),
            "runcomfy_url": "https://api.runcomfy.net".to_json(), // Provide default or hardcoded if not in config
            "runcomfy_token": app.config.runcomfy_api_key.to_json()
        }
        @webui.webui_set_response(window, event_number, Json::object(conf_json).stringify())
    })

    /// Safely downloads an image/glb file from a given URL into the local project directory.
  /// Used by frontend JS when a RunComfy long-polling task completes successfully.
  @webui.on(window, "backend_download_image", fn(w, req, event_number) {
        w |> ignore
        let parsed = @json.parse(req) catch { _ => Json::object(Map::new()) }
        match parsed {
            Json::Object(m) => {
                let url = match m.get("url") { Some(Json::String(s)) => s; _ => "" }
                let filename = match m.get("filename") { Some(Json::String(s)) => s; _ => "" }
                let is_runcomfy = match m.get("is_runcomfy") { Some(Json::True) => true; _ => false }
                let out_path = app.project_id + "\\" + filename
                
                let headers = if is_runcomfy { ["Authorization: Bearer " + app.config.runcomfy_api_key] } else { [] }
                
                match @net.http_get_bytes(url, headers~) {
                    Ok(bytes) => {
                        ignore(@net.write_file_bytes(out_path, bytes))
                        @webui.webui_set_response(window, event_number, "ok")
                    }
                    Err(e) => @webui.webui_set_response(window, event_number, "error: " + e.to_string())
                }
            }
            _ => @webui.webui_set_response(window, event_number, "error: invalid JSON")
        }
    })

    @webui.on(window, "backend_generate_all_assets", fn(w, _req, event_number) {
      w |> ignore
      let json_str_2d = extract_json_from_markdown(app.step_contents[4])
      let json_str_3d = extract_json_from_markdown(app.step_contents[5])
      try {
          let parsed_2d = try { @json.parse(json_str_2d) } catch { _ => Json::object(Map::new()) }
          let parsed_3d = try { @json.parse(json_str_3d) } catch { _ => Json::object(Map::new()) }
          let mut bat_content = "@echo off\r\nchcp 65001\r\n"
          
          match parsed_2d {
              Json::Object(map) => {
                  match map.get("nodes") {
                      Some(Json::Array(nodes)) => {
                          for i = 0; i < nodes.length(); i = i + 1 {
                              match nodes[i] {
                                  Json::Object(n) => {
                                      let id = match n.get("id") { Some(Json::String(s)) => s; _ => "node_" + i.to_string() }
                                      let mut ascii_id = ""
                                      for j = 0; j < id.length(); j = j + 1 {
                                          let c = id[j].to_int()
                                          if c >= 32 && c <= 126 { ascii_id = ascii_id + String::make(1, c.unsafe_to_char()) }
                                      }
                                      ascii_id = ascii_id.replace_all(old=" ", new="_")
                                      if ascii_id == "" || ascii_id == "_" { ascii_id = "node_" + i.to_string() }
                                      
                                      let image_prompt = match n.get("cinematography") {
                                          Some(Json::Object(c)) => match c.get("image_prompt") { Some(Json::String(s)) => s; _ => "" }
                                          _ => ""
                                      }
                                      
                                      if image_prompt != "" {
                                          let clean_prompt = (
                                              image_prompt
                                              .replace_all(old="\"", new="'")
                                              .replace_all(old="\r", new=" ")
                                              .replace_all(old="\n", new=" ")
                                              .replace_all(old="\t", new=" ")
                                              .replace_all(old="%", new="%%")
                                          ) + ", anime visual novel background, 2d game art, high quality, masterpiece"
                                          let clean_name = "scene_" + ascii_id
                                          let out_path = app.project_id + "\\" + clean_name + ".png"
                                          let comfy_url = if app.config.comfy_mode == "runcomfy" { "runcomfy|" + app.config.runcomfy_api_key } else { app.config.comfy_url }
                                          let worker_path = resolve_worker_exe(@net.get_exe_dir(), "comfy_worker")
                                          bat_content = bat_content + "call \"" + worker_path + "\" \"" + comfy_url + "\" \"" + clean_prompt + "\" \"" + out_path + "\"\r\n"
                                      }
                                  }
                                  _ => ()
                              }
                          }
                      }
                      _ => ()
                  }
              }
              _ => ()
          }

          let mut assets_array_bat = []
          match parsed_3d {
              Json::Array(assets) => assets_array_bat = assets
              Json::Object(map) => {
                  for _, v in map {
                      match v {
                          Json::Array(arr) => {
                              assets_array_bat = arr
                              break
                          }
                          _ => ()
                      }
                  }
              }
              _ => ()
          }

          if assets_array_bat.length() > 0 {
              for i = 0; i < assets_array_bat.length(); i = i + 1 {
                  match assets_array_bat[i] {
                      Json::Object(n) => {
                          let image_prompt = match n.get("image_prompt") {
                              Some(Json::String(s)) => s
                              _ => ""
                          }
                          let name = match n.get("asset_name") {
                              Some(Json::String(s)) => s
                              _ => "asset_" + i.to_string()
                          }
                          
                          if image_prompt != "" {
                              let clean_prompt = image_prompt
                                  .replace_all(old="\"", new="'")
                                  .replace_all(old="\r", new=" ")
                                  .replace_all(old="\n", new=" ")
                                  .replace_all(old="\t", new=" ")
                                  .replace_all(old="%", new="%%")
                              let mut ascii_name = ""
                              for j = 0; j < name.length(); j = j + 1 {
                                  let c = name[j].to_int()
                                  if c >= 32 && c <= 126 { ascii_name = ascii_name + String::make(1, c.unsafe_to_char()) }
                              }
                              ascii_name = ascii_name.replace_all(old=" ", new="_")
                              if ascii_name == "" || ascii_name == "_" { ascii_name = "asset_obj_" + i.to_string() }
                              
                              let out_path = app.project_id + "\\" + ascii_name + ".png"
                              let comfy_url = if app.config.comfy_mode == "runcomfy" { "runcomfy|" + app.config.runcomfy_api_key } else { app.config.comfy_url }
                              let worker_path = resolve_worker_exe(@net.get_exe_dir(), "comfy_worker")
                              bat_content = bat_content + "call \"" + worker_path + "\" \"" + comfy_url + "\" \"" + clean_prompt + "\" \"" + out_path + "\"\r\n"
                          }
                      }
                      _ => ()
                  }
              }
          }
          
          bat_content = bat_content + "pause\r\n"
          let bat_path = app.project_id + "\\gen_assets.bat"
          let _ = @net.write_file_bytes(bat_path, @utf8.encode(bat_content))
          
          let absolute_bat_path = bat_path
          let cmd = "start \"\" \"" + absolute_bat_path + "\""
          @webui.system_command(cmd)
          @webui.webui_set_response(window, event_number, "started")
      } catch {
          _ => @webui.webui_set_response(window, event_number, "failed")
      }
  })

  @webui.on(window, "backend_get_3d_asset_list", fn(w, _req, event_number) {
      w |> ignore
      let json_str_3d = extract_json_from_markdown(app.step_contents[5])
      let arr = []
      
      let parsed_3d = try { @json.parse(json_str_3d) } catch { _ => Json::object(Map::new()) }
      
      let mut assets_array_poll = []
      match parsed_3d {
          Json::Array(assets) => assets_array_poll = assets
          Json::Object(map) => {
              for _, v in map {
                  match v {
                      Json::Array(arr) => {
                          assets_array_poll = arr
                          break
                      }
                      _ => ()
                  }
              }
          }
          _ => ()
      }

      if assets_array_poll.length() > 0 {
          for i = 0; i < assets_array_poll.length(); i = i + 1 {
              match assets_array_poll[i] {
                  Json::Object(n) => {
                      let image_prompt = match n.get("image_prompt") {
                          Some(Json::String(s)) => s
                          _ => ""
                      }
                      let name = match n.get("asset_name") {
                          Some(Json::String(s)) => s
                          _ => "asset_" + i.to_string()
                      }
                      
                      if image_prompt != "" {
                          let mut ascii_name = ""
                          for j = 0; j < name.length(); j = j + 1 {
                              let c = name[j].to_int()
                              if c >= 32 && c <= 126 { ascii_name = ascii_name + String::make(1, c.unsafe_to_char()) }
                          }
                          ascii_name = ascii_name.replace_all(old=" ", new="_")
                          if ascii_name == "" || ascii_name == "_" { ascii_name = "asset_obj_" + i.to_string() }
                          
                          let clean_name = ascii_name + "_Textured.glb"
                          let out_path = app.project_id + "\\" + clean_name
                          let exists = @fs.path_exists(out_path)
                          let item : Map[String, Json] = {
                              "name": clean_name.to_json(),
                              "source_image": (ascii_name + ".png").to_json(),
                              "status": (if exists { "done" } else { "pending" }).to_json()
                          }
                          arr.push(Json::object(item))
                      }
                  }
                  _ => ()
              }
          }
      }
      @webui.webui_set_response(window, event_number, Json::array(arr).stringify())
  })

  @webui.on(window, "backend_generate_all_3d_assets", fn(w, _req, event_number) {
      w |> ignore
      let json_str_3d = extract_json_from_markdown(app.step_contents[5])
      try {
          let parsed_3d = try { @json.parse(json_str_3d) } catch { _ => Json::object(Map::new()) }
          let mut bat_content = "@echo off\r\nchcp 65001\r\n"
          
          let mut assets_array_bat_3d = []
      match parsed_3d {
          Json::Array(assets) => assets_array_bat_3d = assets
          Json::Object(map) => {
              for _, v in map {
                  match v {
                      Json::Array(arr) => {
                          assets_array_bat_3d = arr
                          break
                      }
                      _ => ()
                  }
              }
          }
          _ => ()
      }

      if assets_array_bat_3d.length() > 0 {
          for i = 0; i < assets_array_bat_3d.length(); i = i + 1 {
              match assets_array_bat_3d[i] {
                  Json::Object(n) => {
                      let image_prompt = match n.get("image_prompt") {
                          Some(Json::String(s)) => s
                          _ => ""
                      }
                      let name = match n.get("asset_name") {
                          Some(Json::String(s)) => s
                          _ => "asset_" + i.to_string()
                      }
                      
                      if image_prompt != "" {
                          let mut ascii_name = ""
                          for j = 0; j < name.length(); j = j + 1 {
                              let c = name[j].to_int()
                              if c >= 32 && c <= 126 { ascii_name = ascii_name + String::make(1, c.unsafe_to_char()) }
                          }
                          ascii_name = ascii_name.replace_all(old=" ", new="_")
                          if ascii_name == "" || ascii_name == "_" { ascii_name = "asset_obj_" + i.to_string() }
                          
                          let in_image = app.project_id + "\\" + ascii_name + ".png"
                          let out_name = app.project_id + "\\" + ascii_name
                          let comfy_url = if app.config.comfy_mode == "runcomfy" { "runcomfy|" + app.config.runcomfy_api_key } else { app.config.comfy_url }
                          let worker_path = resolve_worker_exe(@net.get_exe_dir(), "comfy_3d_worker")
                          bat_content = bat_content + "call \"" + worker_path + "\" \"" + comfy_url + "\" \"" + in_image + "\" \"" + out_name + "\"\r\n"
                      }
                  }
                  _ => ()
              }
          }
      }
           
          bat_content = bat_content + "pause\r\n"
          let bat_path = app.project_id + "\\gen_3d_assets.bat"
          let _ = @net.write_file_bytes(bat_path, @utf8.encode(bat_content))
          
          // Use absolute path for execution to avoid CWD issues
          let absolute_bat_path = bat_path
          let cmd = "start \"\" \"" + absolute_bat_path + "\""
          @webui.system_command(cmd)
          @webui.webui_set_response(window, event_number, "started")
      } catch {
          _ => @webui.webui_set_response(window, event_number, "failed")
      }
   })

  @webui.on(window, "backend_file_exists", fn(w, path, event_number) {
      w |> ignore
      let exists = @fs.path_exists(path)
      let resp = if exists { "true" } else { "false" }
      @webui.webui_set_response(window, event_number, resp)
  })

  @webui.on(window, "backend_load_project", fn(w, _req, event_number) {
      w |> ignore
      // Use C-FFI or system command to pick a folder.
      // Since we don't have a native folder picker yet, we can use powershell to show a folder browser dialog.
      // And output the path to a temp file, then read it.
      let temp_ps = "pick_folder.ps1"
      let temp_out = "picked_folder.txt"
      
      let ps_script = "Add-Type -AssemblyName System.Windows.Forms\n$initialPath = Join-Path (Get-Location) '..\\Projects'\nif (-not (Test-Path $initialPath)) { $initialPath = Get-Location }\n$owner = New-Object System.Windows.Forms.Form\n$owner.TopMost = $true\n$owner.ShowInTaskbar = $false\n$owner.WindowState = 'Minimized'\n$owner.Opacity = 0\n$owner.Show()\n$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog\n$folderBrowser.Description = 'Select a Game Project Folder'\n$folderBrowser.SelectedPath = (Resolve-Path $initialPath).Path\n$result = $folderBrowser.ShowDialog($owner)\n$owner.Close()\nif ($result -eq [System.Windows.Forms.DialogResult]::OK) {\n    [IO.File]::WriteAllText('picked_folder.txt', $folderBrowser.SelectedPath)\n} else {\n    [IO.File]::WriteAllText('picked_folder.txt', 'CANCELLED')\n}\n"
      try {
          @fs.write_string_to_file(temp_ps, ps_script)
          @webui.system_command("powershell -ExecutionPolicy Bypass -File pick_folder.ps1")
          let path = @fs.read_file_to_string(temp_out)
          let _ = try { @fs.remove_file(temp_ps) } catch { _ => () }
          let _ = try { @fs.remove_file(temp_out) } catch { _ => () }
          
          if path == "CANCELLED" || path == "" {
              @webui.webui_set_response(window, event_number, "cancelled")
          } else {
              // Extract relative path if possible, or just use absolute
              // To make it compatible with relative logic, let's just use the absolute path
              app.project_id = path
              app.draft_text = ""
              for i = 0; i < 6; i = i + 1 {
                  app.step_contents[i] = ""
              }
              
              // Load step_contents from state.json if it exists, otherwise try to reconstruct
              let state_file = app.project_id + "\\state.json"
              if @fs.path_exists(state_file) {
                  let state_str = @fs.read_file_to_string(state_file)
                  let parsed = try { @json.parse(state_str) } catch { _ => Json::object(Map::new()) }
                  match parsed {
                      Json::Object(map) => {
                          match map.get("draft_text") {
                              Some(Json::String(s)) => app.draft_text = s
                              _ => ()
                          }
                          match map.get("step_contents") {
                              Some(Json::Array(arr)) => {
                                  for i = 0; i < arr.length() && i < 6; i = i + 1 {
                                      match arr[i] {
                                          Json::String(s) => app.step_contents[i] = s
                                          _ => ()
                                      }
                                  }
                              }
                              _ => ()
                          }
                      }
                      _ => ()
                  }
              } else {
                  // Reconstruct from files if state.json is missing
                  let files = ["game_design.json", "story_outline.json", "scene_descriptions.json", "game_logic.js", "main.html", "game_styles.css"]
                  for i = 0; i < 6; i = i + 1 {
                      let file_path = app.project_id + "\\" + files[i]
                      if @fs.path_exists(file_path) {
                          app.step_contents[i] = @fs.read_file_to_string(file_path) catch { _ => "" }
                      }
                  }
              }
              
              app.current_step = -1 // Not generating
              @webui.webui_set_response(window, event_number, path)
          }
      } catch {
          _ => @webui.webui_set_response(window, event_number, "failed")
      }
  })

  @webui.on(window, "backend_start_concept", fn(w, prompt, event_number) {
      w |> ignore
      app.draft_text = prompt
      // Generate a valid project directory name
      let id_str = @webui.get_time().to_string()
      app.project_id = @net.get_exe_dir() + "\\..\\Projects\\game_" + id_str
      // Ensure the parent directory exists
      @webui.system_command("cmd /c if not exist \"" + @net.get_exe_dir() + "\\..\\Projects\" mkdir \"" + @net.get_exe_dir() + "\\..\\Projects\"")
      // Ensure the project directory itself exists before we write anything to it
      @webui.system_command("cmd /c if not exist \"" + app.project_id + "\" mkdir \"" + app.project_id + "\"")
      
      app.current_step = 0
      start_generation_step(app, 0)
      @webui.webui_set_response(window, event_number, "ok")
  })

  @webui.on(window, "backend_poll_concept", fn(w, _req, event_number) {
      w |> ignore
      let res_file = app.project_id + "\\response.json"
      
      if @fs.path_exists(res_file) {
          try {
              let res_str = @fs.read_file_to_string(res_file)
              let rstr = res_str
              let parsed = @json.parse(rstr) catch { _ => Json::object(Map::new()) }
              let mut content = ""
              match parsed {
                  Json::Object(m) => {
                      match m.get("content") {
                          Some(Json::String(s)) => content = s
                          _ => ()
                      }
                  }
                  _ => ()
              }
              
              app.step_contents[0] = content
              try { @fs.remove_file(res_file) } catch { _ => () }
              
              let status = if content.has_prefix("Error:") { 
                  "error" 
              } else {
                  "done"
              }
              
              // Set current_step to -1 so it's not "yellow" (in progress) anymore
              app.current_step = -1
              
              let resp_json : Map[String, Json] = {
                  "status": status.to_json(),
                  "content": content.to_json()
              }
              @webui.webui_set_response(window, event_number, Json::object(resp_json).stringify())
          } catch {
              _ => {
                  let resp_json : Map[String, Json] = { "status": "progress".to_json() }
                  @webui.webui_set_response(window, event_number, Json::object(resp_json).stringify())
              }
          }
      } else {
          let resp_json : Map[String, Json] = { "status": "progress".to_json() }
          @webui.webui_set_response(window, event_number, Json::object(resp_json).stringify())
      }
  })

  @webui.on(window, "backend_save_step_content", fn(w, req, event_number) {
      w |> ignore
      let parsed = @json.parse(req) catch { _ => Json::object(Map::new()) }
      match parsed {
          Json::Object(m) => {
              match (m.get("step"), m.get("content")) {
                  (Some(Json::Number(step_num)), Some(Json::String(content))) => {
                      let s = step_num.to_int()
                      if s >= 0 && s < 6 {
                          app.step_contents[s] = content
                          let state_json : Map[String, Json] = {
                              "current_step": app.current_step.to_json(),
                              "draft_text": app.draft_text.to_json(),
                              "project_id": app.project_id.to_json(),
                              "step_contents": Json::array([
                                  app.step_contents[0].to_json(),
                                  app.step_contents[1].to_json(),
                                  app.step_contents[2].to_json(),
                                  app.step_contents[3].to_json(),
                                  app.step_contents[4].to_json(),
                                  app.step_contents[5].to_json()
                              ])
                          }
                          let state_str = Json::object(state_json).stringify()
                          let state_file = app.project_id + "\\state.json"
                          ignore(@fs.write_string_to_file(state_file, state_str) catch { _ => () })
                      }
                  }
                  _ => ()
              }
          }
          _ => ()
      }
      @webui.webui_set_response(window, event_number, "ok")
  })

  @webui.on(window, "backend_start_pipeline", fn(w, _prompt, event_number) {
      w |> ignore
      let next_step = find_next_pipeline_step(app)
      if next_step == 0 {
          @webui.webui_set_response(window, event_number, "need_concept")
      } else if next_step >= 6 {
          @webui.webui_set_response(window, event_number, "already_done")
      } else {
          app.current_step = next_step
          start_generation_step(app, next_step)
          @webui.webui_set_response(window, event_number, "ok")
      }
  })
  
  @webui.on(window, "backend_poll_pipeline", fn(w, _req, event_number) {
      w |> ignore
      let res_file_pipe = app.project_id + "\\response.json"
      
      if app.current_step == 6 {
        let resp_json_done : Map[String, Json] = {
            "status": "done".to_json()
        }
        @webui.webui_set_response(window, event_number, Json::object(resp_json_done).stringify())
      } else {
        if @fs.path_exists(res_file_pipe) {
            let res_str_pipe = @fs.read_file_to_string(res_file_pipe) catch { _ => "" }
            let parsed_pipe = @json.parse(res_str_pipe) catch { _ => Json::object(Map::new()) }
            let mut content_pipe = ""
                match parsed_pipe {
                    Json::Object(m) => {
                        match m.get("status") {
                            Some(Json::String(s)) => {
                                if s == "error" {
                                    match m.get("message") {
                                        Some(Json::String(err_msg)) => content_pipe = "Error: " + err_msg
                                        _ => content_pipe = "Error: Unknown API error"
                                    }
                                } else {
                                    match m.get("content") {
                                        Some(Json::String(c)) => content_pipe = c
                                        _ => content_pipe = "Error: No content returned"
                                    }
                                }
                            }
                            _ => {
                                match m.get("content") {
                                    Some(Json::String(c)) => content_pipe = c
                                    _ => content_pipe = "Error: Invalid response"
                                }
                            }
                        }
                    }
                    _ => content_pipe = "Error: Invalid JSON response"
                }
                
                if app.current_step < 6 {
                    app.step_contents[app.current_step] = content_pipe
                    let state_json : Map[String, Json] = {
                        "current_step": app.current_step.to_json(),
                        "draft_text": app.draft_text.to_json(),
                        "project_id": app.project_id.to_json(),
                        "step_contents": Json::array([
                            app.step_contents[0].to_json(),
                            app.step_contents[1].to_json(),
                            app.step_contents[2].to_json(),
                            app.step_contents[3].to_json(),
                            app.step_contents[4].to_json(),
                            app.step_contents[5].to_json()
                        ])
                    }
                    let state_str = Json::object(state_json).stringify()
                    let state_file = app.project_id + "\\state.json"
                    ignore(@fs.write_string_to_file(state_file, state_str) catch { _ => () })
                }
                
                // We must delete response.json before proceeding to next step
                // so that the next step doesn't immediately read the old response.json
                ignore(@fs.remove_file(res_file_pipe) catch { _ => () })
                
                let old_step_pipe = app.current_step
                if content_pipe.has_prefix("Error:") {
                    app.current_step = 6 // stop pipeline
                } else {
                    app.current_step = app.current_step + 1
                }
                
                if app.current_step < 6 {
                    start_generation_step(app, app.current_step)
                }
                
                let status_pipe = if content_pipe.has_prefix("Error:") { 
                    "error" 
                } else if old_step_pipe == 5 {
                    "done"
                } else {
                    "progress"
                }
                
                let resp_json_pipe : Map[String, Json] = {
                    "status": status_pipe.to_json(),
                    "step": old_step_pipe.to_json(),
                    "content": content_pipe.to_json()
                }
                @webui.webui_set_response(window, event_number, Json::object(resp_json_pipe).stringify())
        } else {
            let resp_json_wait : Map[String, Json] = { "status": "waiting".to_json() }
            @webui.webui_set_response(window, event_number, Json::object(resp_json_wait).stringify())
        }
      }
  })
  
  @webui.on(window, "backend_regenerate_step", fn(w, step_str, event_number) {
      w |> ignore
      let mut step = -1
      step = try { @strconv.parse_int(step_str) } catch { _ => -1 }
      
      if step >= 0 && step < 6 {
          app.current_step = step
          start_generation_step(app, step)
          @webui.webui_set_response(window, event_number, "ok")
      } else {
          @webui.webui_set_response(window, event_number, "error")
      }
  })

  @webui.on(window, "backend_load_game_json", fn(w, _req, event_number) {
      w |> ignore
      let mut json_str = ""
      if app.step_contents[4] != "" {
          json_str = extract_json_from_markdown(app.step_contents[4])
      } else {
          let state_file = app.project_id + "\\state.json"
          if @fs.path_exists(state_file) {
              let state_str = @fs.read_file_to_string(state_file) catch { _ => "" }
              if state_str != "" {
                  let parsed_state = @json.parse(state_str) catch { _ => Json::object(Map::new()) }
                  match parsed_state {
                      Json::Object(m) => {
                          match m.get("step_contents") {
                              Some(Json::Array(arr)) => {
                                  if arr.length() > 4 {
                                      match arr[4] {
                                          Json::String(s) => json_str = extract_json_from_markdown(s)
                                          _ => ()
                                      }
                                  }
                              }
                              _ => ()
                          }
                      }
                      _ => ()
                  }
              }
          }
      }

      if json_str == "" {
          @webui.webui_set_response(window, event_number, "error")
      } else {
          let parsed = @json.parse(json_str) catch { _ => Json::object(Map::new()) }
          match parsed {
              Json::Object(m) => {
                  match m.get("nodes") {
                      Some(Json::Array(_)) => @webui.webui_set_response(window, event_number, json_str)
                      _ => @webui.webui_set_response(window, event_number, "error")
                  }
              }
              _ => @webui.webui_set_response(window, event_number, "error")
          }
      }
  })

  @webui.on(window, "backend_start_raylib_preview", fn(w, _req, event_number) {
      w |> ignore
      let studio_dir = @net.get_exe_dir()
      let engine_dir = studio_dir + "\\..\\aetheria_engine"
      let candidates = [
          engine_dir + "\\Aetheria3D_GLB.exe",
          engine_dir + "\\Aetheria3D.exe",
          engine_dir + "\\_build\\native\\debug\\build\\cmd_glb\\cmd_glb.exe",
          engine_dir + "\\_build\\native\\debug\\build\\cmd\\main\\main.exe"
      ]
      let mut target_exe = ""
      for i = 0; i < candidates.length(); i = i + 1 {
          if @fs.path_exists(candidates[i]) {
              target_exe = candidates[i]
              break
          }
      }
      if target_exe == "" {
          @webui.webui_set_response(window, event_number, "missing")
      } else {
          let cmd = "cmd /c start \"\" /D \"" + engine_dir + "\" \"" + target_exe + "\" \"" + app.project_id + "\""
          @webui.system_command(cmd)
          @webui.webui_set_response(window, event_number, "started")
      }
  })

  ignore(@webui.on(window, "backend_prepare_file", fn(w, req, event_number) {
      ignore(w)
      let filename = req
      let source_path = app.project_id + "\\" + filename
      let target_dir = @net.get_exe_dir() + "\\assets\\temp"
      let target_path = target_dir + "\\" + filename
      
      ignore(@net.create_dir(target_dir))
      
      let content = try {
          let b = @fs.read_file_to_bytes(source_path)
          println("Read file success: \{b.length()} bytes")
          b
      } catch {
          e => {
              println("Read file failed: \{e}")
              b""
          }
      }
      
      if content.length() > 0 {
          try {
              @fs.write_bytes_to_file(target_path, content)
              println("Write file success: \{target_path}")
              @webui.webui_set_response(window, event_number, "temp/" + filename)
          } catch {
              e => {
                  println("Write file failed: \{e}")
                  @webui.webui_set_response(window, event_number, "error")
              }
          }
      } else {
          println("File content is empty")
          @webui.webui_set_response(window, event_number, "error")
      }
  }))
  ignore(@webui.on(window, "backend_list_models", fn(w, req, event_number) {
      ignore(w)
      let folder = app.project_id
      let ps_script = "Get-ChildItem -Path '" + folder + "' -Filter *.obj | Select-Object -ExpandProperty Name | ConvertTo-Json"
      let bat_content = "@echo off\r\npowershell -NoProfile -Command \"" + ps_script + "\" > \"" + folder + "\\models.json\"\r\n"
      let bat_path = folder + "\\list_models.bat"
      ignore(@net.write_file_bytes(bat_path, @utf8.encode(bat_content)))
      let absolute_bat_path = bat_path
      let cmd = "start /wait \"\" \"" + absolute_bat_path + "\""
      @webui.system_command(cmd)
      
      let mut files_json = Json::array([])
      let models_json_path = folder + "\\models.json"
      let content = @fs.read_file_to_string(models_json_path) catch { _ => "" }
      if content != "" {
          let parsed = @json.parse(content) catch { _ => Json::array([]) }
          match parsed {
              Json::String(_) => files_json = Json::array([parsed])
              Json::Array(_) => files_json = parsed
              _ => ()
          }
      }
      
      let resp : Map[String, Json] = {
          "models": files_json
      }
      @webui.webui_set_response(window, event_number, Json::object(resp).stringify())
  }))
  
  // Set infinite timeout so WebUI wait doesn't close prematurely
  @webui.webui_set_timeout(0)
  @webui.webui_set_size(window, 1600, 960)
  @webui.webui_set_minimum_size(window, 1200, 760)
  
  let abs_assets = @net.get_exe_dir() + "\\assets"
  ignore(@webui.webui_set_root_folder(window, abs_assets))
  
  // By default, let's try Edge/Chrome browser engine instead of the bare embedded WebView.
  // 1 = AnyBrowser, but Edge/Chrome handles local webui injection much more consistently.
  ignore(@webui.webui_show_browser(window, "index.html", 1))
  
  @webui.webui_wait()
}
