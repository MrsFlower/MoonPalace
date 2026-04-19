fn extract_json_from_markdown(content: String) -> String {
  let json_marker = "```json"
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

fn get_all_assets(app: App) -> Array[Json] {
  let results : Array[Json] = []
  
  // Add 3D Assets (from Step 5)
  if app.step_status[4] == 2 {
    let json_str = extract_json_from_markdown(app.step_contents[4])
    let parsed = try { Ok(@json.parse(json_str)) } catch { _ => Err("err") }
    match parsed {
      Ok(Json::Array(assets)) => {
        for i = 0; i < assets.length(); i = i + 1 {
          match assets[i] {
            Json::Object(map) => {
              // Ensure we don't have unicode characters in file paths for Windows
              // Replace Chinese characters and spaces
              let name = match map.get("asset_name") { Some(Json::String(s)) => s; _ => "Asset_\{i}" }
              // A simple hack to convert non-ascii characters to ascii representation
              // by just stripping them out and using the index as a fallback
              let mut ascii_name = ""
              for j = 0; j < name.length(); j = j + 1 {
                let c = name[j].to_int()
                if c >= 32 && c <= 126 {
                  ascii_name = ascii_name + name[j].to_string()
                }
              }
              ascii_name = ascii_name.replace_all(old=" ", new="_")
              if ascii_name == "" || ascii_name == "_" {
                ascii_name = "asset_obj_" + i.to_string()
              }
              
              let new_map : Map[String, Json] = {
                "asset_name": Json::string(ascii_name),
                "display_name": Json::string(name)
              }
              
              // Copy other properties
              match map.get("image_prompt") { Some(p) => new_map.set("image_prompt", p); _ => () }
              match map.get("description") { Some(d) => new_map.set("description", d); _ => () }
              match map.get("estimated_size_meters") { Some(s) => new_map.set("estimated_size_meters", s); _ => () }
              
              results.push(Json::object(new_map))
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  
  // Add 2D Scene Backgrounds (from Step 4)
  if app.step_status[3] == 2 {
    let json_str = extract_json_from_markdown(app.step_contents[3])
    let parsed = try { Ok(@json.parse(json_str)) } catch { _ => Err("err") }
    match parsed {
      Ok(Json::Object(map)) => {
        match map.get("nodes") {
          Some(Json::Array(nodes)) => {
            for i = 0; i < nodes.length(); i = i + 1 {
              match nodes[i] {
                Json::Object(n) => {
                  let id = match n.get("id") { Some(Json::String(s)) => s; _ => "node_\{i}" }
                  
                  // Clean ID to ensure it's ascii
                  let mut ascii_id = ""
                  for j = 0; j < id.length(); j = j + 1 {
                    let c = id[j].to_int()
                    if c >= 32 && c <= 126 {
                      ascii_id = ascii_id + id[j].to_string()
                    }
                  }
                  ascii_id = ascii_id.replace_all(old=" ", new="_")
                  if ascii_id == "" || ascii_id == "_" {
                    ascii_id = "node_" + i.to_string()
                  }
                  
                  let image_prompt = match n.get("cinematography") {
                    Some(Json::Object(c)) => match c.get("image_prompt") { Some(Json::String(s)) => s; _ => "" }
                    _ => ""
                  }
                  if image_prompt != "" {
                    let asset_map : Map[String, Json] = {
                      "asset_name": Json::string("scene_" + ascii_id),
                      "display_name": Json::string("Scene: " + id),
                      "image_prompt": Json::string(image_prompt + ", anime visual novel background, 2d game art, high quality, masterpiece")
                    }
                    results.push(Json::object(asset_map))
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
  }
  
  results
}

fn draw_pipeline(app: App) -> Unit {
  // Left Panel: Progress and Input (0 to 350)
  @raylib.draw_rectangle(0, 0, 350, 800, 245, 245, 245, 255)
  @raylib.draw_line(350, 0, 350, 800, 200, 200, 200, 255)

  let title = if app.lang == "EN" { "Generation Pipeline" } else { "生成管线" }
  @raylib.draw_text(title, 20, 20, 24, 50, 50, 50, 255)

  let steps_en = ["1. World Bible", "2. Story Narrative", "3. Script Outline", "4. State Machine", "5. 3D Assets"]
  let steps_zh = ["1. 世界观设定", "2. 分支剧情", "3. 分镜剧本", "4. 状态机 JSON", "5. 3D资产需求"]
  let steps = if app.lang == "EN" { steps_en } else { steps_zh }

  for i = 0; i < 5; i = i + 1 {
    let step_num = i + 1
    let y = 70 + i * 70
    
    let status = app.step_status[i]
    let (r, g, b) = match status {
      0 => (220, 220, 220) // Pending
      1 => (255, 200, 100) // Running
      2 => (100, 200, 100) // Done
      3 => (255, 100, 100) // Error
      _ => (220, 220, 220)
    }
    
    @raylib.draw_rectangle(20, y, 260, 50, r, g, b, 255)
    if app.current_view_step == step_num {
      @raylib.draw_rectangle_lines(18, y - 2, 264, 54, 50, 50, 255, 255)
    }
    
    if @ui.is_clicked(20, y, 260, 50) {
      if app.current_view_step != step_num {
        app.current_view_step = step_num
        app.scroll_y.val = 0.0
      }
    }
    
    @raylib.draw_text(steps[i], 30, y + 15, 20, 50, 50, 50, 255)
    
    // Regenerate Button
    if status == 2 || status == 3 {
      if @ui.draw_button("Re", 290, y + 10, 40, 30) {
        for j = i; j < 5; j = j + 1 {
          app.step_status[j] = 0
          app.step_contents[j] = ""
        }
        app.step_status[i] = 1
        app.current_view_step = step_num
        app.auto_proceed = true
        start_generation_step(app, step_num)
      }
    }
  }

  // Left Bottom: Inspiration Input
  @raylib.draw_text(if app.lang == "EN" { "Draft Inspiration / Refine Idea:" } else { "创作灵感 / 修改指令:" }, 20, 450, 20, 50, 50, 50, 255)
  if @ui.is_clicked(20, 480, 310, 120) {
    app.active_textfield = 0
  }
  let cursor_ref : Ref[Int] = { val: app.draft_cursor }
  app.draft_text = @ui.draw_textbox(app.draft_text, 20, 480, 310, 120, app.active_textfield == 0, multiline=true, cursor_idx_ref=cursor_ref)
  app.draft_cursor = cursor_ref.val

  if @ui.draw_button(if app.lang == "EN" { "Restart All" } else { "重新生成全部" }, 20, 620, 310, 50) {
    if app.draft_text != "" {
      app.project_id = "game_" + @raylib.get_random_value(10000, 99999).to_string()
      @raylib.system_command("cmd /c if not exist " + app.project_id + " mkdir " + app.project_id)
      app.auto_proceed = true
      for i = 0; i < 5; i = i + 1 {
        app.step_status[i] = 0
        app.step_contents[i] = ""
      }
      app.cached_assets = None
      app.cached_state_machine = None
      app.step_status[0] = 1
      app.current_view_step = 1
      app.scroll_y.val = 0.0
      start_generation_step(app, 1)
    }
  }
  
  if @ui.draw_button(if app.lang == "EN" { "Back to Settings" } else { "返回设置" }, 20, 690, 310, 40) {
    app.state = AppState::Settings
  }

  // Right Panel: Tabbed UI (350 to 1280)
  let tabs_en = ["1. World", "2. Story", "3. Script", "4. JSON", "5. Assets", "6. 2D Preview"]
  let tabs_zh = ["世界观", "分支剧情", "分镜剧本", "JSON", "3D资产", "2D预览"]
  let tabs = if app.lang == "EN" { tabs_en } else { tabs_zh }
  
  for i = 0; i < 6; i = i + 1 {
    let tab_x = 370 + i * 140
    let is_active = app.current_view_step == i + 1
    
    if is_active {
      @raylib.draw_rectangle(tab_x, 20, 130, 40, 200, 200, 200, 255)
      @raylib.draw_rectangle_lines(tab_x, 20, 130, 40, 100, 100, 100, 255)
    } else {
      @raylib.draw_rectangle(tab_x, 20, 130, 40, 240, 240, 240, 255)
      @raylib.draw_rectangle_lines(tab_x, 20, 130, 40, 200, 200, 200, 255)
    }
    
    if @ui.is_clicked(tab_x, 20, 130, 40) {
      if app.current_view_step != i + 1 {
        app.current_view_step = i + 1
        app.scroll_y.val = 0.0
      }
    }
    
    @raylib.draw_text(tabs[i], tab_x + 15, 30, 20, 50, 50, 50, 255)
  }

  // Right Panel Content
  if app.current_view_step >= 1 && app.current_view_step <= 5 {
    let view_idx = app.current_view_step - 1
    let content = app.step_contents[view_idx]
    let status = app.step_status[view_idx]
    
    if status == 1 {
      @raylib.draw_text(if app.lang == "EN" { "Generating..." } else { "生成中..." }, 380, 80, 20, 100, 100, 100, 255)
    } else if status == 0 {
      @raylib.draw_text(if app.lang == "EN" { "Waiting..." } else { "等待中..." }, 380, 80, 20, 100, 100, 100, 255)
    } else {
      if app.current_view_step == 5 {
        @ui.draw_scrollable_text_area(content, 380, 80, 400, 680, app.scroll_y)
        
        let current_time = @raylib.get_time()
        
        // Refresh assets cache every 1.5 seconds to avoid UI lag
        if app.cached_assets is None || current_time - app.last_asset_check_time > 1.5 {
          let new_assets = get_all_assets(app)
          app.cached_assets = Some(new_assets)
          app.last_asset_check_time = current_time
          
          let mut count = 0
          for i = 0; i < new_assets.length(); i = i + 1 {
            match new_assets[i] {
              Json::Object(map) => {
                let name = match map.get("asset_name") {
                  Some(Json::String(s)) => s
                  _ => "Asset_\{i}"
                }
                let clean_name = name.replace_all(old=" ", new="_")
                let out_path = app.project_id + "/" + clean_name + ".png"
                if @fs.path_exists(out_path) {
                  count = count + 1
                }
              }
              _ => ()
            }
          }
          app.cached_done_count = count
        }
        
        let assets = match app.cached_assets {
          Some(a) => a
          None => []
        }
        let done_count = app.cached_done_count
        let total_count = assets.length()
        
        if total_count > 0 {
          let progress_text = " (" + done_count.to_string() + "/" + total_count.to_string() + ")"
          let btn_text = if app.lang == "EN" { "Generate All Assets" + progress_text } else { "一键生成所有资产图" + progress_text }
          if @ui.draw_button(btn_text, 800, 80, 440, 50) {
            let mut bat_content = "@echo off\r\nchcp 65001\r\n"
            for i = 0; i < assets.length(); i = i + 1 {
              match assets[i] {
                Json::Object(map) => {
                  let name = match map.get("asset_name") {
                    Some(Json::String(s)) => s
                    _ => "Asset_\{i}"
                  }
                  let prompt = match map.get("image_prompt") {
                    Some(Json::String(s)) => s
                    _ => ""
                  }
                  if prompt != "" {
                    let clean_prompt = prompt.replace_all(old="\"", new="'")
                    let clean_name = name.replace_all(old=" ", new="_")
                    let out_path = app.project_id + "\\" + clean_name + ".png"
                    bat_content = bat_content + "comfy_worker.exe \"" + clean_prompt + "\" \"" + out_path + "\"\r\n"
                  }
                }
                _ => ()
              }
            }
            bat_content = bat_content + "pause\r\n"
            let bat_path = app.project_id + "/gen_assets.bat"
            let bat_path_win = app.project_id + "\\gen_assets.bat"
            try {
              @fs.write_string_to_file(bat_path, bat_content)
              @raylib.system_command("start \"\" \"" + bat_path_win + "\"")
            } catch {
              _ => ()
            }
          }
          
          let mut y_offset = 150
          for i = 0; i < assets.length(); i = i + 1 {
            if y_offset > 740 { break }
            match assets[i] {
              Json::Object(map) => {
                let name = match map.get("asset_name") {
                  Some(Json::String(s)) => s
                  _ => "Asset_\{i}"
                }
                let clean_name = name.replace_all(old=" ", new="_")
                let out_path = app.project_id + "/" + clean_name + ".png"
                let is_done = @fs.path_exists(out_path)
                let status_icon = if is_done { "[OK]" } else { "[  ]" }
                
                let display_name_str = match map.get("display_name") {
                  Some(Json::String(s)) => s
                  _ => name
                }
                
                let size_info = match map.get("estimated_size_meters") {
                  Some(Json::Object(smap)) => {
                    let l = match smap.get("length") { Some(Json::Number(n, ..)) => n.to_string(); _ => "?" }
                    let w = match smap.get("width") { Some(Json::Number(n, ..)) => n.to_string(); _ => "?" }
                    let h = match smap.get("height") { Some(Json::Number(n, ..)) => n.to_string(); _ => "?" }
                    " [" + l + "x" + w + "x" + h + "m]"
                  }
                  _ => ""
                }
                
                let display_name = if display_name_str.length() > 30 { display_name_str.substring(end=27) + "..." } else { display_name_str }
                let final_display = "\{status_icon} \{display_name}\{size_info}"
                
                if is_done {
                  @raylib.draw_text(final_display, 800, y_offset, 20, 50, 150, 50, 255)
                } else {
                  @raylib.draw_text(final_display, 800, y_offset, 20, 50, 50, 50, 255)
                }
                y_offset = y_offset + 30
              }
              _ => ()
            }
          }
        } else {
          @raylib.draw_text(if app.lang == "EN" { "No assets found or still generating." } else { "未找到资产或仍在生成中。" }, 800, 80, 20, 200, 50, 50, 255)
        }
      } else {
        @ui.draw_scrollable_text_area(content, 380, 80, 860, 680, app.scroll_y)
      }
    }
  } else if app.current_view_step == 6 {
    let json_content = app.step_contents[3] // Step 4 JSON
    if app.step_status[3] != 2 || json_content == "" {
      @raylib.draw_text(if app.lang == "EN" { "Generate JSON State Machine first (Step 4)." } else { "请先生成状态机 JSON (步骤 4)。" }, 380, 80, 20, 100, 100, 100, 255)
    } else {
      if app.cached_state_machine is None {
        let json_str = extract_json_from_markdown(json_content)
        let parsed = try { Ok(@json.parse!(json_str)) } catch { _ => Err("err") }
        match parsed {
          Ok(j) => app.cached_state_machine = Some(j)
          _ => app.cached_state_machine = Some(Json::object(Map::new())) // Cache empty object to avoid re-parsing invalid JSON every frame
        }
      }
      
      let parsed = app.cached_state_machine
      match parsed {
        Some(Json::Object(map)) => {
          match map.get("nodes") {
            Some(Json::Array(nodes)) => {
              if nodes.length() > 0 {
                // Initialize node if empty
                if app.preview_node_id == "" {
                  // Find the node with ID "Node 1" or fallback to first node
                  let mut start_node_id = ""
                  for i = 0; i < nodes.length(); i = i + 1 {
                    match nodes[i] {
                      Json::Object(n) => {
                        let id = match n.get("id") { Some(Json::String(s)) => s; _ => "" }
                        if id == "Node 1" || id == "node_1" {
                          start_node_id = id
                          break
                        }
                      }
                      _ => ()
                    }
                  }
                  
                  if start_node_id != "" {
                    app.preview_node_id = start_node_id
                  } else {
                    match nodes[0] {
                      Json::Object(first_node) => {
                        app.preview_node_id = match first_node.get("id") { Some(Json::String(s)) => s; _ => "" }
                      }
                      _ => ()
                    }
                  }
                }
                
                // Find current node
                let mut current_node = None
                for i = 0; i < nodes.length(); i = i + 1 {
                  match nodes[i] {
                    Json::Object(n) => {
                      let id = match n.get("id") { Some(Json::String(s)) => s; _ => "" }
                      if id == app.preview_node_id {
                        current_node = Some(n)
                        break
                      }
                    }
                    _ => ()
                  }
                }
                
                match current_node {
                  Some(nmap) => {
                    let narrative = match nmap.get("narrative") {
                      Some(Json::Object(n)) => match n.get("text_content") { Some(Json::String(s)) => s; _ => "No text" }
                      _ => "No narrative"
                    }
                    
                    let image_prompt = match nmap.get("cinematography") {
                      Some(Json::Object(c)) => match c.get("image_prompt") { Some(Json::String(s)) => s; _ => "" }
                      _ => ""
                    }
                    
                    // Draw Background
                    // Convert node ID to ascii for file path
                    let mut ascii_id = ""
                    for j = 0; j < app.preview_node_id.length(); j = j + 1 {
                      let c = app.preview_node_id[j].to_int()
                      if c >= 32 && c <= 126 {
                        ascii_id = ascii_id + app.preview_node_id[j].to_string()
                      }
                    }
                    ascii_id = ascii_id.replace_all(old=" ", new="_")
                    if ascii_id == "" || ascii_id == "_" {
                      // Try to find the index of the node
                      let mut node_idx = 0
                      for i = 0; i < nodes.length(); i = i + 1 {
                        match nodes[i] {
                          Json::Object(n) => {
                            let nid = match n.get("id") { Some(Json::String(s)) => s; _ => "" }
                            if nid == app.preview_node_id { node_idx = i; break }
                          }
                          _ => ()
                        }
                      }
                      ascii_id = "node_" + node_idx.to_string()
                    }
                    
                    let expected_bg_path = app.project_id + "/scene_" + ascii_id + ".png"
                    
                    if @fs.path_exists(expected_bg_path) {
                      if app.preview_bg_path != expected_bg_path {
                        match app.preview_texture {
                          Some(t) => @raylib.unload_texture(t)
                          None => ()
                        }
                        let tex = @raylib.load_texture(expected_bg_path)
                        app.preview_texture = Some(tex)
                        app.preview_bg_path = expected_bg_path
                      }
                      
                      match app.preview_texture {
                        Some(tex) => {
                          // scale down to fit roughly 880x400
                          @raylib.draw_texture_ex(tex, 0.0, 0.0, 1024.0, 1024.0, 380.0, 80.0, 880.0, 400.0)
                        }
                        None => ()
                      }
                    } else {
                      @raylib.draw_rectangle(380, 80, 880, 400, 50, 50, 50, 255)
                      @raylib.draw_text("No 2D Art generated yet.", 700, 250, 20, 100, 100, 100, 255)
                      @raylib.draw_text("Please go to Step 5 and click [Generate All Assets].", 650, 280, 20, 100, 100, 100, 255)
                    }
                    
                    // Draw Dialog Box
                    @raylib.draw_rectangle(380, 480, 880, 150, 30, 30, 30, 220)
                    @raylib.draw_rectangle_lines(380, 480, 880, 150, 200, 200, 200, 255)
                    @ui.draw_scrollable_text_area(narrative, 390, 490, 860, 130, app.preview_scroll_y)
                    
                    // Draw Choices
                    match nmap.get("gameplay") {
                      Some(Json::Object(gmap)) => {
                        match gmap.get("choices") {
                          Some(Json::Array(choices)) => {
                            let mut cy = 650
                            if choices.length() == 0 {
                              // Fallback for Endings
                              if @ui.draw_button(if app.lang == "EN" { "Restart Story (Ending Reached)" } else { "重新开始 (已达成结局)" }, 400, cy, 840, 35) {
                                app.preview_node_id = "" // Reset to empty, so it will be initialized again
                              }
                            } else {
                              for i = 0; i < choices.length(); i = i + 1 {
                                if cy > 750 { break }
                                match choices[i] {
                                  Json::Object(cmap) => {
                                    let ctext = match cmap.get("text") { Some(Json::String(s)) => s; _ => "Choice" }
                                    let target = match cmap.get("target_id") { Some(Json::String(s)) => s; _ => "" }
                                    
                                    if @ui.draw_button(ctext, 400, cy, 840, 35) {
                                      if target != "" {
                                        app.preview_node_id = target
                                      }
                                    }
                                    cy = cy + 45
                                  }
                                  _ => ()
                                }
                              }
                            }
                          }
                          _ => ()
                        }
                      }
                      _ => ()
                    }
                  }
                  None => {
                    @raylib.draw_text("Node not found.", 380, 80, 20, 100, 100, 100, 255)
                  }
                }
              } else {
                @raylib.draw_text("Nodes array is empty.", 380, 80, 20, 100, 100, 100, 255)
              }
            }
            _ => @raylib.draw_text("Invalid nodes array format.", 380, 80, 20, 100, 100, 100, 255)
          }
        }
        _ => @raylib.draw_text(if app.lang == "EN" { "Failed to parse JSON." } else { "无法解析 JSON: 请检查 步骤 4 是否成功生成。" }, 380, 80, 20, 200, 50, 50, 255)
      }
    }
  }

  // Handle auto-proceed and worker response
  let res_file = app.project_id + "/response.json"
  let current_time = @raylib.get_time()
  
  if current_time - app.last_poll_time > 0.5 {
    app.last_poll_time = current_time
    
    // Only poll and process response.json if a step is actually running
    let running_step = app.generation_step
    let is_running = running_step >= 1 && running_step <= 5 && app.step_status[running_step - 1] == 1
    
    if is_running && @fs.path_exists(res_file) {
      try {
        let res_content = @fs.read_file_to_string(res_file)
        let parsed_json = try { Ok(@json.parse(res_content)) } catch { _ => Err("err") }
        
        let mut is_success = false
        let mut text_output = ""
        
        match parsed_json {
          Ok(Json::Object(obj)) => {
            match obj.get("status") {
              Some(Json::String(s)) => {
                if s == "success" {
                  match obj.get("content") {
                    Some(Json::String(text)) => {
                      is_success = true
                      text_output = text
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
        
        if running_step >= 1 && running_step <= 5 {
          if is_success {
            app.step_status[running_step - 1] = 2
            app.step_contents[running_step - 1] = text_output
            
            // Clear caches if step 4 or 5 is completed
            if running_step == 4 { app.cached_state_machine = None }
            if running_step == 5 { app.cached_assets = None }
            
            if running_step == 4 {
               try {
                 @fs.write_string_to_file(app.project_id + "/final_story.json", extract_json_from_markdown(text_output))
               } catch {
                 _ => ()
               }
            }
            if app.auto_proceed && running_step < 5 {
              app.step_status[running_step] = 1
              app.current_view_step = running_step + 1
              start_generation_step(app, running_step + 1)
            } else if app.auto_proceed && running_step == 5 {
              app.auto_proceed = false
            }
          } else {
            app.step_status[running_step - 1] = 3
            app.auto_proceed = false
          }
        }
      } catch {
        _ => ()
      }
      
      // Always remove the response file so we don't process it again next frame
      try {
        @fs.remove_file(res_file)
      } catch {
        _ => ()
      }
    }
  }
}
