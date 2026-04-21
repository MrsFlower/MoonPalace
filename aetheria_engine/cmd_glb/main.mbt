struct SceneChoice {
  text: String
  target_id: String
}

struct SceneNode {
  id: String
  narrative: String
  choices: Array[SceneChoice]
  model_path: String
  scene_width_m: Double
  scene_height_m: Double
  scene_depth_m: Double
  camera_hint: String
  lighting_hint: String
}

struct EnvPalette {
  sky_r: Int
  sky_g: Int
  sky_b: Int
  ground_top_r: Int
  ground_top_g: Int
  ground_top_b: Int
  ground_base_r: Int
  ground_base_g: Int
  ground_base_b: Int
  hud_r: Int
  hud_g: Int
  hud_b: Int
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

fn normalize_id_key(raw: String, fallback: String) -> String {
  let mut out = ""
  let mut last_underscore = false
  for i = 0; i < raw.length(); i = i + 1 {
    let c = raw[i].to_int()
    let is_alpha_num =
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122)
    if is_alpha_num {
      out = out + String::make(1, c.unsafe_to_char())
      last_underscore = false
    } else if c == 32 || c == 45 || c == 95 {
      if not(last_underscore) && out != "" {
        out = out + "_"
        last_underscore = true
      }
    }
  }
  if out.has_suffix("_") && out.length() > 0 {
    out = out[:out.length() - 1].to_string()
  }
  if out == "" { fallback } else { out }
}

fn pick_model_path_for_keys(project_dir: String, keys: Array[String]) -> String {
  for i = 0; i < keys.length(); i = i + 1 {
    let k = keys[i]
    let c0 = project_dir + "\\" + k + "_Textured_optimized.glb"
    if @fs.path_exists(c0) { return c0 }
    let c2_optimized = project_dir + "\\" + k + "_optimized.glb"
    if @fs.path_exists(c2_optimized) { return c2_optimized }
  }
  // Return first candidate optimized path as debug hint when missing.
  project_dir + "\\" + keys[0] + "_Textured_optimized.glb"
}

fn extract_step_content(state_map: Map[String, Json], index: Int) -> String {
  match state_map.get("step_contents") {
    Some(Json::Array(arr)) => {
      if index >= 0 && index < arr.length() {
        match arr[index] {
          Json::String(s) => extract_json_from_markdown(s)
          _ => ""
        }
      } else {
        ""
      }
    }
    _ => ""
  }
}

fn parse_step5_asset_keys(step5_json: String) -> Array[String] {
  let out : Array[String] = []
  if step5_json == "" { return out }
  let parsed = @json.parse(step5_json) catch { _ => Json::object(Map::new()) }
  let mut assets_arr : Array[Json] = []
  match parsed {
    Json::Array(arr) => assets_arr = arr
    Json::Object(m) => {
      for _, v in m {
        match v {
          Json::Array(arr) => {
            assets_arr = arr
            break
          }
          _ => ()
        }
      }
    }
    _ => ()
  }
  for i = 0; i < assets_arr.length(); i = i + 1 {
    match assets_arr[i] {
      Json::Object(am) => {
        let raw = match am.get("asset_name") { Some(Json::String(s)) => s; _ => "" }
        let key = to_safe_asset_id(raw, "asset_obj_" + i.to_string())
        out.push(key)
      }
      _ => out.push("asset_obj_" + i.to_string())
    }
  }
  out
}

fn parse_step5_asset_map(step5_json: String) -> Map[String, String] {
  let out = Map::new()
  if step5_json == "" { return out }
  let parsed = @json.parse(step5_json) catch { _ => Json::object(Map::new()) }
  let mut assets_arr : Array[Json] = []
  match parsed {
    Json::Array(arr) => assets_arr = arr
    Json::Object(m) => {
      for _, v in m {
        match v {
          Json::Array(arr) => {
            assets_arr = arr
            break
          }
          _ => ()
        }
      }
    }
    _ => ()
  }
  for i = 0; i < assets_arr.length(); i = i + 1 {
    match assets_arr[i] {
      Json::Object(am) => {
        let raw = match am.get("asset_name") { Some(Json::String(s)) => s; _ => "" }
        let safe_key = to_safe_asset_id(raw, "asset_obj_" + i.to_string())
        let norm_key = normalize_id_key(raw, normalize_id_key(safe_key, "asset_obj_" + i.to_string()))
        out.set(norm_key, safe_key)
      }
      _ => ()
    }
  }
  out
}

fn truncate_text(s: String, max_len: Int) -> String {
  let mut out = ""
  let mut count = 0
  for c in s {
    if count >= max_len { break }
    out = out + String::make(1, c)
    count = count + 1
  }
  if count < max_len { s } else { out + "..." }
}

fn wrap_lines(s: String, max_chars_per_line: Int, max_lines: Int) -> Array[String] {
  let lines : Array[String] = []
  let mut current = ""
  let mut current_count = 0
  for c in s {
    if c == '\n' {
      if current != "" { lines.push(current) }
      current = ""
      current_count = 0
      if lines.length() >= max_lines { return lines }
    } else {
      current = current + String::make(1, c)
      current_count = current_count + 1
      if current_count >= max_chars_per_line {
        lines.push(current)
        current = ""
        current_count = 0
        if lines.length() >= max_lines { return lines }
      }
    }
  }
  if current != "" && lines.length() < max_lines { lines.push(current) }
  lines
}

fn build_scene_charset_text(node: SceneNode) -> String {
  let mut s = node.id + " " + node.narrative + " " + node.camera_hint + " " + node.lighting_hint
  for i = 0; i < node.choices.length(); i = i + 1 {
    s = s + " " + node.choices[i].text + " " + node.choices[i].target_id
  }
  s
}

fn clamp_double(v: Double, min_v: Double, max_v: Double) -> Double {
  if v < min_v {
    min_v
  } else if v > max_v {
    max_v
  } else {
    v
  }
}

fn scene_scale_multiplier(node: SceneNode) -> Double {
  // Step4 的 scale_meters 是语义尺度，我们把它映射为 Raylib 预览的额外缩放。
  let width_m = if node.scene_width_m > 0.1 { node.scene_width_m } else { 12.0 }
  let height_m = if node.scene_height_m > 0.1 { node.scene_height_m } else { 6.0 }
  let depth_m = if node.scene_depth_m > 0.1 { node.scene_depth_m } else { 12.0 }
  let avg_size = (width_m + height_m + depth_m) / 3.0
  clamp_double(avg_size / 18.0, 0.55, 1.25)
}

fn apply_scene_camera_hint(node: SceneNode, scene_scale: Double) -> Unit {
  let hint = node.camera_hint
  let mut cam_x = 0.0
  let mut cam_y = clamp_double(1.9 * scene_scale, 1.6, 2.8)
  let mut cam_z = 8.6 * scene_scale
  let mut tar_y = cam_y * 0.92

  if hint.contains("overhead") || hint.contains("bird") || hint.contains("top-down") || hint.contains("俯视") || hint.contains("鸟瞰") {
    cam_x = 0.0
    cam_y = 7.6 * scene_scale
    cam_z = 6.2 * scene_scale
    tar_y = 0.0
  } else if hint.contains("isometric") || hint.contains("等距") {
    cam_x = 5.8 * scene_scale
    cam_y = 5.8 * scene_scale
    cam_z = 5.8 * scene_scale
    tar_y = 0.0
  } else if hint.contains("side view") || hint.contains("profile") || hint.contains("侧视") {
    cam_x = 7.2 * scene_scale
    cam_y = clamp_double(1.9 * scene_scale, 1.5, 2.6)
    cam_z = 1.3 * scene_scale
    tar_y = cam_y * 0.9
  }

  if hint.contains("close-up") || hint.contains("close up") || hint.contains("特写") {
    cam_z = 5.4 * scene_scale
  } else if hint.contains("wide shot") || hint.contains("wide-angle") || hint.contains("全景") || hint.contains("远景") {
    cam_z = 11.2 * scene_scale
  }

  let fovy = clamp_double(58.0 + (scene_scale - 1.0) * 5.0, 52.0, 70.0)
  @raylib.setup_camera(cam_x, cam_y, cam_z, 0.0, tar_y, 0.0, 0.0, 1.0, 0.0, fovy)
}

fn detect_env_palette(node: SceneNode) -> EnvPalette {
  let text = node.camera_hint + " " + node.lighting_hint + " " + node.narrative
  let is_night =
    text.contains("night") || text.contains("moonlight") || text.contains("midnight") ||
    text.contains("dark") || text.contains("夜") || text.contains("黑夜") ||
    text.contains("夜晚") || text.contains("月光") || text.contains("深夜")
  let is_dusk =
    text.contains("sunset") || text.contains("dusk") || text.contains("twilight") ||
    text.contains("evening") || text.contains("黄昏") || text.contains("傍晚") ||
    text.contains("暮色")
  let is_rainy =
    text.contains("rain") || text.contains("storm") || text.contains("overcast") ||
    text.contains("阴天") || text.contains("雨") || text.contains("暴风")

  if is_night {
    {
      sky_r: 22, sky_g: 34, sky_b: 68,
      ground_top_r: 66, ground_top_g: 82, ground_top_b: 110,
      ground_base_r: 38, ground_base_g: 50, ground_base_b: 74,
      hud_r: 205, hud_g: 225, hud_b: 255
    }
  } else if is_dusk {
    {
      sky_r: 242, sky_g: 168, sky_b: 116,
      ground_top_r: 186, ground_top_g: 146, ground_top_b: 110,
      ground_base_r: 140, ground_base_g: 109, ground_base_b: 87,
      hud_r: 80, hud_g: 58, hud_b: 44
    }
  } else if is_rainy {
    {
      sky_r: 150, sky_g: 176, sky_b: 196,
      ground_top_r: 160, ground_top_g: 176, ground_top_b: 160,
      ground_base_r: 126, ground_base_g: 142, ground_base_b: 126,
      hud_r: 52, hud_g: 68, hud_b: 90
    }
  } else {
    // Default sunny daytime.
    {
      sky_r: 160, sky_g: 210, sky_b: 255,
      ground_top_r: 212, ground_top_g: 234, ground_top_b: 187,
      ground_base_r: 170, ground_base_g: 198, ground_base_b: 150,
      hud_r: 60, hud_g: 80, hud_b: 110
    }
  }
}

fn build_game_charset_text(nodes: Array[SceneNode]) -> String {
  let mut s = ""
  for i = 0; i < nodes.length(); i = i + 1 {
    s = s + " " + build_scene_charset_text(nodes[i])
  }
  s
}

fn load_nodes_from_project(project_dir: String) -> Array[SceneNode] {
  let state_path = project_dir + "\\state.json"
  if not(@fs.path_exists(state_path)) {
    return [{
      id: "fallback_scene",
      narrative: "state.json not found. Please generate pipeline Step 4 first.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb",
      scene_width_m: 12.0,
      scene_height_m: 6.0,
      scene_depth_m: 12.0,
      camera_hint: "",
      lighting_hint: ""
    }]
  }

  let state_str = @fs.read_file_to_string(state_path) catch { _ => "" }
  if state_str == "" {
    return [{
      id: "fallback_scene",
      narrative: "state.json is empty.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb",
      scene_width_m: 12.0,
      scene_height_m: 6.0,
      scene_depth_m: 12.0,
      camera_hint: "",
      lighting_hint: ""
    }]
  }

  let parsed_state = @json.parse(state_str) catch { _ => Json::object(Map::new()) }
  let mut step4 = ""
  let mut step5 = ""
  match parsed_state {
    Json::Object(m) => {
      step4 = extract_step_content(m, 4)
      step5 = extract_step_content(m, 5)
    }
    _ => ()
  }
  let step5_asset_keys = parse_step5_asset_keys(step5)
  let step5_asset_map = parse_step5_asset_map(step5)

  if step4 == "" {
    return [{
      id: "fallback_scene",
      narrative: "Step 4 JSON is missing. Complete JSON generation in Studio first.",
      choices: [],
      model_path: project_dir + "\\fallback_scene_Textured.glb",
      scene_width_m: 12.0,
      scene_height_m: 6.0,
      scene_depth_m: 12.0,
      camera_hint: "",
      lighting_hint: ""
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
                let norm_id = normalize_id_key(id, normalize_id_key(safe_id, "node_" + i.to_string()))
                let key_from_step5 = if i < step5_asset_keys.length() { step5_asset_keys[i] } else { "" }
                let key_from_map = match step5_asset_map.get(norm_id) {
                  Some(s) => s
                  None => ""
                }
                let candidate_keys = [
                  (if key_from_map != "" { key_from_map } else if key_from_step5 != "" { key_from_step5 } else { safe_id }),
                  safe_id,
                  normalize_id_key(safe_id, safe_id),
                  "asset_obj_" + i.to_string(),
                  "node_" + i.to_string()
                ]
                let model_path = pick_model_path_for_keys(project_dir, candidate_keys)
                let mut scene_width_m = 12.0
                let mut scene_height_m = 6.0
                let mut scene_depth_m = 12.0
                let mut camera_hint = ""
                let mut lighting_hint = ""
                let narrative = match nm.get("narrative") {
                  Some(Json::Object(narr)) => match narr.get("text_content") {
                    Some(Json::String(t)) => t
                    _ => ""
                  }
                  _ => ""
                }
                match nm.get("cinematography") {
                  Some(Json::Object(cm)) => {
                    match cm.get("image_prompt") {
                      Some(Json::String(s)) => camera_hint = s
                      _ => ()
                    }
                    match cm.get("lighting") {
                      Some(Json::String(s)) => lighting_hint = s
                      _ => ()
                    }
                    match cm.get("scale_meters") {
                      Some(Json::Object(sm)) => {
                        match sm.get("width") {
                          Some(Json::Number(n, ..)) => scene_width_m = n
                          _ => ()
                        }
                        match sm.get("height") {
                          Some(Json::Number(n, ..)) => scene_height_m = n
                          _ => ()
                        }
                        match sm.get("depth") {
                          Some(Json::Number(n, ..)) => scene_depth_m = n
                          _ => ()
                        }
                        // 部分模型流水线用 length 代表 depth
                        if scene_depth_m <= 0.1 {
                          match sm.get("length") {
                            Some(Json::Number(n, ..)) => scene_depth_m = n
                            _ => ()
                          }
                        }
                      }
                      _ => ()
                    }
                  }
                  _ => ()
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
                nodes_out.push({ id, narrative, choices, model_path, scene_width_m, scene_height_m, scene_depth_m, camera_hint, lighting_hint })
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
      model_path: project_dir + "\\fallback_scene_Textured.glb",
      scene_width_m: 12.0,
      scene_height_m: 6.0,
      scene_depth_m: 12.0,
      camera_hint: "",
      lighting_hint: ""
    }]
  } else {
    nodes_out
  }
}

fn find_node_index(nodes: Array[SceneNode], target_id: String, fallback_idx: Int) -> Int {
  let target_norm = normalize_id_key(target_id, target_id)
  for i = 0; i < nodes.length(); i = i + 1 {
    if nodes[i].id == target_id || normalize_id_key(nodes[i].id, nodes[i].id) == target_norm {
      return i
    }
  }
  fallback_idx
}

fn main {
  let key_enter = 257
  let key_r = 82
  let args = @env.args()
  let project_dir = if args.length() > 1 { args[1] } else { "..\\aetheria_studio\\test_proj" }
  let nodes = load_nodes_from_project(project_dir)

  println("Aetheria3D Scene Preview (Raylib) Starting...")
  println("Project: " + project_dir)
  println("Loaded nodes: " + nodes.length().to_string())

  @raylib.init_window(1400, 900, "Aetheria3D Raylib Scene Preview")
  @raylib.set_target_fps(60)
  let sample_text = build_game_charset_text(nodes)
  // Load a CJK-capable UI font and refresh its glyph set using current scene text.
  let mut font_ok = false
  if not(font_ok) && @raylib.load_ui_font("C:\\Windows\\Fonts\\simhei.ttf", 32) { font_ok = @raylib.refresh_ui_font_charset(sample_text) }
  if not(font_ok) && @raylib.load_ui_font("C:\\Windows\\Fonts\\msyh.ttf", 32) { font_ok = @raylib.refresh_ui_font_charset(sample_text) }
  if not(font_ok) && @raylib.load_ui_font("C:\\Windows\\Fonts\\msyh.ttc", 32) { font_ok = @raylib.refresh_ui_font_charset(sample_text) }
  if not(font_ok) && @raylib.load_ui_font("C:\\Windows\\Fonts\\simsun.ttc", 32) { font_ok = @raylib.refresh_ui_font_charset(sample_text) }
  if not(font_ok) && @raylib.load_ui_font("C:\\Windows\\Fonts\\msyhbd.ttc", 32) { font_ok = @raylib.refresh_ui_font_charset(sample_text) }

  let mut current_idx = 0
  let mut selected_choice = 0
  let mut current_model_path = nodes[0].model_path
  let mut scene_scale = scene_scale_multiplier(nodes[0])
  let mut env_palette = detect_env_palette(nodes[0])
  apply_scene_camera_hint(nodes[0], scene_scale)
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
        scene_scale = scene_scale_multiplier(nodes[current_idx])
        env_palette = detect_env_palette(nodes[current_idx])
        apply_scene_camera_hint(nodes[current_idx], scene_scale)
        if @fs.path_exists(current_model_path) {
          @raylib.load_global_model(current_model_path)
          model_loaded = true
        } else {
          model_loaded = false
        }
      }
    }

    if @raylib.is_key_pressed(key_r) {
      apply_scene_camera_hint(nodes[current_idx], scene_scale)
    }

    @raylib.begin_drawing()
    @raylib.clear_background(env_palette.sky_r, env_palette.sky_g, env_palette.sky_b, 255)

    @raylib.begin_mode_3d_current_camera()
    @raylib.draw_cube(0.0, -0.05, 0.0, 260.0, 0.1, 260.0, env_palette.ground_top_r, env_palette.ground_top_g, env_palette.ground_top_b, 255)
    @raylib.draw_cube(0.0, -0.06, 0.0, 260.0, 0.02, 260.0, env_palette.ground_base_r, env_palette.ground_base_g, env_palette.ground_base_b, 255)
    if model_loaded {
      @raylib.draw_global_model(0.0, 0.0, 0.0, scene_scale)
    }
    @raylib.end_mode_3d()

    @raylib.draw_text("Raylib 3D Scene Preview", 20, 16, 22, 220, 220, 220, 255)
    @raylib.draw_text("Scene: " + nodes[current_idx].id + "  (" + (current_idx + 1).to_string() + "/" + nodes.length().to_string() + ")", 20, 46, 18, 160, 210, 255, 255)
    @raylib.draw_text("Mouse: look | WASD: move | Space: next option | Enter: confirm | R: reset view", 20, 70, 18, 170, 220, 170, 255)
    @raylib.draw_text("Scene scale: " + scene_scale.to_string() + "x  (from scale_meters)", 20, 94, 18, env_palette.hud_r, env_palette.hud_g, env_palette.hud_b, 255)
    @raylib.draw_text("Model: " + current_model_path, 20, 118, 16, env_palette.hud_r, env_palette.hud_g, env_palette.hud_b, 255)
    @raylib.draw_fps(1260, 16)

    // Bottom dialog panel
    @raylib.draw_rectangle(20, 610, 1360, 270, 8, 10, 16, 220)
    @raylib.draw_rectangle_lines(20, 610, 1360, 270, 90, 120, 180, 255)
    @raylib.draw_text("Narrative:", 40, 628, 22, 255, 225, 120, 255)
    if not(font_ok) {
      @raylib.draw_text("UI font load failed. Chinese may show as '?'.", 40, 652, 18, 255, 140, 140, 255)
    }
    let narr_lines = wrap_lines(nodes[current_idx].narrative, 58, 3)
    for i = 0; i < narr_lines.length(); i = i + 1 {
      @raylib.draw_text(narr_lines[i], 40, 660 + i * 24, 22, 235, 235, 235, 255)
    }

    if not(model_loaded) {
      @raylib.draw_text("Model not found: " + current_model_path, 40, 692, 18, 255, 120, 120, 255)
    }

    let choices_y = 740
    if nodes[current_idx].choices.length() == 0 {
      @raylib.draw_text("[END] No choices in this scene.", 40, choices_y, 22, 255, 170, 120, 255)
    } else {
      @raylib.draw_text("Choices:", 40, choices_y, 22, 120, 220, 255, 255)
      for i = 0; i < nodes[current_idx].choices.length() && i < 6; i = i + 1 {
        let prefix = if i == selected_choice { "> " } else { "  " }
        let line = prefix + (i + 1).to_string() + ". " + truncate_text(nodes[current_idx].choices[i].text, 80)
        if i == selected_choice {
          @raylib.draw_text(line, 60, choices_y + 30 + i * 18, 20, 255, 255, 120, 255)
        } else {
          @raylib.draw_text(line, 60, choices_y + 30 + i * 18, 20, 220, 220, 220, 255)
        }
      }
    }

    @raylib.end_drawing()
  }

  @raylib.close_window()
  println("Aetheria3D Scene Preview Stopped.")
}
