struct SceneChoice {
  text: String
  target_id: String
}

struct SceneNode {
  id: String
  narrative: String
  choices: Array[SceneChoice]
  model_path: String
}

fn extract_json_from_markdown(content: String) -> String {
  let mut start_idx = -1
  let mut end_idx = -1
  for i = 0; i <= content.length() - 7; i = i + 1 {
    if content[i] == '`' && content[i + 1] == '`' && content[i + 2] == '`' && content[i + 3] == 'j' && content[i + 4] == 's' && content[i + 5] == 'o' && content[i + 6] == 'n' {
      start_idx = i + 7
      break
    }
  }
  if start_idx >= 0 {
    for i = content.length() - 3; i >= start_idx; i = i - 1 {
      if content[i] == '`' && content[i + 1] == '`' && content[i + 2] == '`' {
        end_idx = i
        break
      }
    }
  }
  if start_idx >= 0 && end_idx > start_idx {
    return content[start_idx:end_idx].to_string()
  }
  content
}

fn to_safe_asset_id(raw: String, fallback: String) -> String {
  let mut out = ""
  for i = 0; i < raw.length(); i = i + 1 {
    let c = raw[i].to_int()
    if c >= 32 && c <= 126 {
      out = out + String::make(1, c.unsafe_to_char())
    }
  }
  out = out.replace_all(old = " ", new = "_")
  if out == "" || out == "_" { fallback } else { out }
}

fn pick_model_path(project_dir: String, safe_id: String) -> String {
  let c1 = project_dir + "\\" + safe_id + "_Textured.glb"
  if @fs.path_exists(c1) { return c1 }
  let c2 = project_dir + "\\" + safe_id + ".glb"
  if @fs.path_exists(c2) { return c2 }
  let c3 = project_dir + "\\" + safe_id + ".obj"
  if @fs.path_exists(c3) { return c3 }
  c1
}

fn truncate_text(s: String, max_len: Int) -> String {
  if s.length() <= max_len { s } else { s[:max_len].to_string() + "..." }
}

fn load_nodes_from_project(project_dir: String) -> Array[SceneNode] {
  let state_path = project_dir + "\\state.json"
  if not(@fs.path_exists(state_path)) {
    return [{
      id: "fallback_scene",
      narrative: "state.json not found. Please generate pipeline Step 4 first.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb"
    }]
  }

  let state_str = @fs.read_file_to_string(state_path) catch { _ => "" }
  if state_str == "" {
    return [{
      id: "fallback_scene",
      narrative: "state.json is empty.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb"
    }]
  }

  let parsed_state = @json.parse(state_str) catch { _ => Json::object(Map::new()) }
  let mut step4 = ""
  match parsed_state {
    Json::Object(m) => {
      match m.get("step_contents") {
        Some(Json::Array(arr)) => {
          if arr.length() > 4 {
            match arr[4] {
              Json::String(s) => step4 = extract_json_from_markdown(s)
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
    _ => ()
  }

  if step4 == "" {
    return [{
      id: "fallback_scene",
      narrative: "Step 4 JSON is missing. Complete JSON generation in Studio first.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb"
    }]
  }

  let parsed_game = @json.parse(step4) catch { _ => Json::object(Map::new()) }
  let nodes_out : Array[SceneNode] = []
  match parsed_game {
    Json::Object(m) => {
      match m.get("nodes") {
        Some(Json::Array(nodes)) => {
          for i = 0; i < nodes.length(); i = i + 1 {
            match nodes[i] {
              Json::Object(nm) => {
                let id = match nm.get("id") { Some(Json::String(s)) => s; _ => "node_" + i.to_string() }
                let safe_id = to_safe_asset_id(id, "node_" + i.to_string())
                let model_path = pick_model_path(project_dir, safe_id)
                let narrative = match nm.get("narrative") {
                  Some(Json::Object(narr)) => match narr.get("text_content") {
                    Some(Json::String(t)) => t
                    _ => ""
                  }
                  _ => ""
                }
                let choices : Array[SceneChoice] = []
                match nm.get("gameplay") {
                  Some(Json::Object(gm)) => match gm.get("choices") {
                    Some(Json::Array(arr)) => {
                      for j = 0; j < arr.length(); j = j + 1 {
                        match arr[j] {
                          Json::Object(cm) => {
                            let text = match cm.get("text") { Some(Json::String(t)) => t; _ => "Option " + (j + 1).to_string() }
                            let target_id = match cm.get("target_id") { Some(Json::String(t)) => t; _ => "" }
                            choices.push({ text, target_id })
                          }
                          _ => ()
                        }
                      }
                    }
                    _ => ()
                  }
                  _ => ()
                }
                nodes_out.push({ id, narrative, choices, model_path })
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

  if nodes_out.length() == 0 {
    [{
      id: "fallback_scene",
      narrative: "No nodes found in Step 4 JSON.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb"
    }]
  } else {
    nodes_out
  }
}

fn find_node_index(nodes: Array[SceneNode], target_id: String, fallback_idx: Int) -> Int {
  for i = 0; i < nodes.length(); i = i + 1 {
    if nodes[i].id == target_id {
      return i
    }
  }
  fallback_idx
}

fn main {
  let key_enter = 257
  let args = @env.args()
  let project_dir = if args.length() > 1 { args[1] } else { "..\\aetheria_studio\\test_proj" }
  let nodes = load_nodes_from_project(project_dir)

  println("Aetheria3D Scene Preview (Raylib) Starting...")
  println("Project: " + project_dir)
  println("Loaded nodes: " + nodes.length().to_string())

  @raylib.init_window(1400, 900, "Aetheria3D Raylib Scene Preview")
  @raylib.set_target_fps(60)
  @raylib.setup_camera(0.0, 10.0, 20.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 45.0)

  let mut current_idx = 0
  let mut selected_choice = 0
  let mut current_model_path = nodes[0].model_path
  let mut model_loaded = false
  if @fs.path_exists(current_model_path) {
    @raylib.load_global_model(current_model_path)
    model_loaded = true
  }

  while not(@raylib.window_should_close()) {
    // First-person mode gives mouse-look + WASD movement.
    @raylib.update_camera(@raylib.camera_first_person)

    let current = nodes[current_idx]
    let choice_count = current.choices.length()

    // Space cycles highlighted option.
    if @raylib.is_key_pressed(@raylib.key_space) && choice_count > 0 {
      selected_choice = if selected_choice >= choice_count - 1 { 0 } else { selected_choice + 1 }
    }

    // Enter confirms selected option and jumps to target scene.
    if @raylib.is_key_pressed(key_enter) && choice_count > 0 {
      let target_id = current.choices[selected_choice].target_id
      let next_idx = find_node_index(nodes, target_id, current_idx)
      if next_idx != current_idx {
        current_idx = next_idx
        selected_choice = 0
        current_model_path = nodes[current_idx].model_path
        if @fs.path_exists(current_model_path) {
          @raylib.load_global_model(current_model_path)
          model_loaded = true
        } else {
          model_loaded = false
        }
      }
    }

    @raylib.begin_drawing()
    @raylib.clear_background(18, 20, 28, 255)

    @raylib.begin_mode_3d_current_camera()
    @raylib.draw_grid(50, 2.0)
    if model_loaded {
      @raylib.draw_global_model(0.0, 0.0, 0.0, 80.0)
    }
    @raylib.end_mode_3d()

    @raylib.draw_text("Raylib 3D Scene Preview", 20, 16, 22, 220, 220, 220, 255)
    @raylib.draw_text("Scene: " + nodes[current_idx].id + "  (" + (current_idx + 1).to_string() + "/" + nodes.length().to_string() + ")", 20, 46, 18, 160, 210, 255, 255)
    @raylib.draw_text("Mouse: look | WASD: move | Space: next option | Enter: confirm option", 20, 70, 18, 170, 220, 170, 255)
    @raylib.draw_fps(1260, 16)

    // Bottom dialog panel
    @raylib.draw_rectangle(20, 610, 1360, 270, 8, 10, 16, 220)
    @raylib.draw_rectangle_lines(20, 610, 1360, 270, 90, 120, 180, 255)
    @raylib.draw_text("Narrative:", 40, 628, 22, 255, 225, 120, 255)
    @raylib.draw_text(truncate_text(nodes[current_idx].narrative, 180), 40, 660, 22, 235, 235, 235, 255)

    if not(model_loaded) {
      @raylib.draw_text("Model not found: " + current_model_path, 40, 692, 18, 255, 120, 120, 255)
    }

    if nodes[current_idx].choices.length() == 0 {
      @raylib.draw_text("[END] No choices in this scene.", 40, 734, 22, 255, 170, 120, 255)
    } else {
      @raylib.draw_text("Choices:", 40, 734, 22, 120, 220, 255, 255)
      for i = 0; i < nodes[current_idx].choices.length() && i < 6; i = i + 1 {
        let prefix = if i == selected_choice { "> " } else { "  " }
        let line = prefix + (i + 1).to_string() + ". " + truncate_text(nodes[current_idx].choices[i].text, 120)
        if i == selected_choice {
          @raylib.draw_text(line, 60, 766 + i * 18, 20, 255, 255, 120, 255)
        } else {
          @raylib.draw_text(line, 60, 766 + i * 18, 20, 220, 220, 220, 255)
        }
      }
    }

    @raylib.end_drawing()
  }

  @raylib.close_window()
  println("Aetheria3D Scene Preview Stopped.")
}
