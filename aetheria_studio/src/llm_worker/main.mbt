fn read_json_file(path: String) -> Result[Json, String] {
  match @net.read_file(path) {
    Ok(content) => {
      let parsed = try { Ok(@json.parse(content)) } catch { err => Err("JSON parse error: \{err}") }
      match parsed {
        Ok(json) => Ok(json)
        Err(e) => Err(e)
      }
    }
    Err(e) => Err(e)
  }
}

fn write_json_file(path: String, json: Json) -> Result[Unit, String] {
  let content = json.stringify()
  @net.write_file(path, content)
}

fn get_string(json: Json, key: String, default: String) -> String {
  match json {
    Json::Object(map) => {
      match map.get(key) {
        Some(Json::String(s)) => s
        _ => default
      }
    }
    _ => default
  }
}

fn get_array(json: Json, key: String) -> Array[Json] {
  match json {
    Json::Object(map) => {
      match map.get(key) {
        Some(Json::Array(a)) => a
        _ => []
      }
    }
    _ => []
  }
}

fn write_log(url: String, req_json: Json, res_body: String, log_file: String) -> Unit {
  let log_entry = "\n==================================================\nREQUEST TO: " + url + "\n" +
                  req_json.stringify() + "\n--------------------------------------------------\nRESPONSE:\n" +
                  res_body + "\n==================================================\n"
  let _ = @net.append_file(log_file, log_entry)
}

fn trim_string(s: String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = s[start]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = s[end - 1]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      end = end - 1
    } else {
      break
    }
  }
  if start >= end {
    ""
  } else {
    s[start:end].to_string()
  }
}

fn main {
  let args = @env.args()
  if args.length() < 3 {
    println("Usage: llm_worker.exe <request_json> <response_json>")
    return
  }
  
  let req_file = args[1]
  let res_file = args[2]
  
  let req_json = match read_json_file(req_file) {
    Ok(j) => j
    Err(e) => {
      let m : Map[String, Json] = { "status": Json::string("error"), "message": Json::string(e) }
      let _ = write_json_file(res_file, Json::object(m))
      return
    }
  }
  
  let api_provider = get_string(req_json, "api_provider", "OpenAI")
  let mut api_url = get_string(req_json, "api_url", "https://api.deepseek.com/v1")
  let api_key = get_string(req_json, "api_key", "")
  let model = get_string(req_json, "model_name", "deepseek-chat")
  let messages = get_array(req_json, "messages")
  let format = get_string(req_json, "response_format", "")

  let mut payload_str = ""
  let mut headers = []
  
  if api_provider == "Gemini" {
    // Construct Gemini API request
    
    // Auto-append v1beta/models/{model}:generateContent if missing, to be robust
    if not(api_url.contains(":generateContent")) {
      let sep = if api_url.has_suffix("/") { "" } else { "/" }
      // Check if it already has v1beta
      if api_url.contains("v1beta") {
         api_url = api_url + sep + "models/" + model + ":generateContent"
      } else {
         api_url = api_url + sep + "v1beta/models/" + model + ":generateContent"
      }
    }
    
    // Requires key in URL: url?key=...
    if not(api_url.contains("?key=")) {
      let sep = if api_url.contains("?") { "&" } else { "?" }
      api_url = api_url + sep + "key=" + api_key
    }
    
    // Convert messages to Gemini format
    let gemini_contents = []
    let mut system_instruction = ""
    for i = 0; i < messages.length(); i = i + 1 {
      match messages[i] {
        Json::Object(_) => {
          let role = get_string(messages[i], "role", "user")
          let content = get_string(messages[i], "content", "")
          if role == "system" {
            system_instruction = content
          } else {
            let g_role = if role == "assistant" { "model" } else { "user" }
            let parts : Array[Json] = [Json::object({ "text": Json::string(content) })]
            let g_msg : Map[String, Json] = {
              "role": Json::string(g_role),
              "parts": Json::array(parts)
            }
            gemini_contents.push(Json::object(g_msg))
          }
        }
        _ => ()
      }
    }
    
    let payload_map : Map[String, Json] = {
      "contents": Json::array(gemini_contents)
    }
    
    if system_instruction != "" {
      let sys_parts : Array[Json] = [Json::object({ "text": Json::string(system_instruction) })]
      let sys_inst : Map[String, Json] = { "parts": Json::array(sys_parts) }
      payload_map.set("system_instruction", Json::object(sys_inst))
    }
    
    if format == "json_object" {
      let gen_config : Map[String, Json] = {
        "response_mime_type": Json::string("application/json")
      }
      payload_map.set("generationConfig", Json::object(gen_config))
    }
    
    payload_str = Json::object(payload_map).stringify()
    headers = [ "Content-Type: application/json" ]
    
  } else {
    // Construct OpenAI API request
    if not(api_url.has_suffix("/chat/completions")) {
      if api_url.has_suffix("/") {
        api_url = api_url + "chat/completions"
      } else {
        api_url = api_url + "/chat/completions"
      }
    }
    
    let payload_map : Map[String, Json] = {
      "model": Json::string(model),
      "messages": Json::array(messages),
      "temperature": Json::number(0.7),
      "max_tokens": Json::number(8192.0)
    }
    
    if format == "json_object" {
      let fm : Map[String, Json] = { "type": Json::string("json_object") }
      payload_map.set("response_format", Json::object(fm))
    }
    
    payload_str = Json::object(payload_map).stringify()
    headers = [
      "Authorization: Bearer " + api_key,
      "Content-Type: application/json"
    ]
  }
  
  match @net.http_post(api_url, headers, payload_str) {
    Ok(response) => {
      let log_json : Result[Json, String] = try { Ok(@json.parse(payload_str)) } catch { _ => Ok(Json::object(Map::new())) }
      write_log(api_url, log_json.unwrap(), response.body, res_file + ".log")
      
      if response.status_code >= 200 && response.status_code < 300 {
        let parsed = try { Ok(@json.parse(response.body)) } catch { err => Err(err.to_string()) }
        match parsed {
          Ok(res_json) => {
            let mut content = ""
            
            if api_provider == "Gemini" {
              // Parse Gemini response format
              match res_json {
                Json::Object(map) => {
                  match map.get("candidates") {
                    Some(Json::Array(candidates)) => {
                      if candidates.length() > 0 {
                        match candidates[0] {
                          Json::Object(candidate) => {
                            match candidate.get("content") {
                              Some(Json::Object(c_obj)) => {
                                match c_obj.get("parts") {
                                  Some(Json::Array(parts)) => {
                                    if parts.length() > 0 {
                                      match parts[0] {
                                        Json::Object(p_obj) => {
                                          match p_obj.get("text") {
                                            Some(Json::String(s)) => content = s
                                            _ => ()
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
              // Parse OpenAI response format
              match res_json {
                Json::Object(map) => {
                  match map.get("choices") {
                    Some(Json::Array(choices)) => {
                      if choices.length() > 0 {
                        match choices[0] {
                          Json::Object(choice) => {
                            match choice.get("message") {
                              Some(Json::Object(msg)) => {
                                match msg.get("content") {
                                  Some(Json::String(s)) => content = s
                                  _ => ()
                                }
                              }
                              _ => ()
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
            
            // Extract JSON from markdown or raw text
            let mut clean_content = trim_string(content)
            
            // If it contains ```json, extract everything between ```json and ```
            let _json_marker = "```json"
            let _end_marker = "```"
            
            let mut json_start = -1
            let mut json_end = -1
            
            // Simple string search for ```json
            for i = 0; i <= clean_content.length() - 7; i = i + 1 {
              if clean_content[i] == '`' && clean_content[i+1] == '`' && clean_content[i+2] == '`' && clean_content[i+3] == 'j' && clean_content[i+4] == 's' && clean_content[i+5] == 'o' && clean_content[i+6] == 'n' {
                json_start = i + 7
                break
              }
            }
            
            if json_start >= 0 {
              for i = clean_content.length() - 3; i >= json_start; i = i - 1 {
                if clean_content[i] == '`' && clean_content[i+1] == '`' && clean_content[i+2] == '`' {
                  json_end = i
                  break
                }
              }
            }
            
            if json_start >= 0 && json_end > json_start {
              clean_content = clean_content[json_start:json_end].to_string()
            } else {
              // Fallback to finding first { and last }
              let mut start_idx = -1
              for i = 0; i < clean_content.length(); i = i + 1 {
                if clean_content[i] == '{' || clean_content[i] == '[' {
                  start_idx = i
                  break
                }
              }
              
              let mut end_idx = -1
              for i = clean_content.length() - 1; i >= 0; i = i - 1 {
                if clean_content[i] == '}' || clean_content[i] == ']' {
                  end_idx = i + 1
                  break
                }
              }
              
              if start_idx >= 0 && end_idx > start_idx {
                clean_content = clean_content[start_idx:end_idx].to_string()
              }
            }
            
            let sm : Map[String, Json] = { "status": Json::string("success"), "content": Json::string(clean_content) }
            let _ = write_json_file(res_file, Json::object(sm))
          }
          Err(e) => {
            let em : Map[String, Json] = { "status": Json::string("error"), "message": Json::string("JSON parse error: \{e}") }
            let _ = write_json_file(res_file, Json::object(em))
          }
        }
      } else {
        let err_msg = "HTTP \{response.status_code}: \{response.body}"
        let em : Map[String, Json] = { "status": Json::string("error"), "message": Json::string(err_msg) }
        let _ = write_json_file(res_file, Json::object(em))
      }
    }
    Err(e) => {
      let em : Map[String, Json] = { "status": Json::string("error"), "message": Json::string(e) }
      let _ = write_json_file(res_file, Json::object(em))
    }
  }
}
