// Config struct for global states
struct ComfyConfig {
  mut url: String
  mut is_runcomfy: Bool
  mut runcomfy_token: String
}
let config: ComfyConfig = { url: "http://127.0.0.1:8188", is_runcomfy: false, runcomfy_token: "" }

let workflow_file = "fluxworkflow.json"

fn get_image(filename: String, subfolder: String, folder_type: String) -> Result[Bytes, String] {
  let encoded_filename = filename.replace_all(old=" ", new="%20")
  let url = config.url + "/view?filename=" + encoded_filename + "&subfolder=" + subfolder + "&type=" + folder_type
  @net.http_get_bytes(url)
}

fn get_history(prompt_id: String) -> Json {
  if config.is_runcomfy {
    let url = "https://api.runcomfy.net/prod/v1/deployments/eca194ca-7090-42bd-a14f-8bd5cfa0f636/requests/" + prompt_id + "/status"
    let headers = ["Authorization: Bearer " + config.runcomfy_token]
    match @net.http_get(url, headers~) {
      Ok(res) => {
        match (try { Ok(@json.parse(res.body)) } catch { err => Err(err.to_string()) }) {
          Ok(j) => j
          Err(_) => Json::object(Map::new())
        }
      }
      Err(_) => Json::object(Map::new())
    }
  } else {
    let url = config.url + "/history/" + prompt_id
    match @net.http_get_bytes(url) {
      Ok(bytes) => {
        let s = try { @utf8.decode(bytes) } catch { _ => "" }
        match (try { Ok(@json.parse(s)) } catch { err => Err(err.to_string()) }) {
          Ok(j) => j
          Err(_) => Json::object(Map::new())
        }
      }
      Err(_) => Json::object(Map::new())
    }
  }
}

/// Submits the prompt/workflow JSON to the ComfyUI server (either Local or RunComfy API).
/// Handles both the standard ComfyUI payload (`{"prompt": workflow}`) and the RunComfy payload (`{"workflow_api_json": workflow}`).
/// Catches HTTP/network errors cleanly instead of silently bubbling up JSON parsing failures.
fn queue_prompt(workflow: Json) -> Json {
      let url = if config.is_runcomfy {
        "https://api.runcomfy.net/prod/v1/deployments/eca194ca-7090-42bd-a14f-8bd5cfa0f636/inference"
      } else {
        config.url + "/prompt"
      }
  
      let data = if config.is_runcomfy {
        Json::object(Map::from_array([("workflow_api_json", workflow)]))
      } else {
        Json::object(Map::from_array([("prompt", workflow)]))
      }
  
      let data_str = data.stringify()
      let headers = if config.is_runcomfy {
        ["Content-Type: application/json", "Authorization: Bearer " + config.runcomfy_token]
      } else {
        ["Content-Type: application/json"]
      }
  
      match @net.http_post(url, headers, data_str) {
        Ok(res) => {
          match (try { Ok(@json.parse(res.body)) } catch { err => Err(err.to_string()) }) {
            Ok(j) => j
            Err(_) => Json::object(Map::new())
          }
        }
        Err(e) => {
            println("HTTP POST Error: \{e}")
            Json::object(Map::new())
        }
      }
    }

fn read_json_file(path: String) -> Result[Json, String] {
  // First try to read from the current directory
  let res1 = @net.read_file(path)
  match res1 {
    Ok(content) => {
      match ((try { Ok(@json.parse(content)) } catch { err => Err(err.to_string()) })) {
        Ok(json) => Ok(json)
        Err(e) => Err("JSON parse error: \{e}")
      }
    }
    Err(_) => {
      // Try an absolute fallback based on the parent folder
      let fallback_path = "..\\" + path
      match @net.read_file(fallback_path) {
        Ok(content) => {
          match ((try { Ok(@json.parse(content)) } catch { err => Err(err.to_string()) })) {
            Ok(json) => Ok(json)
            Err(e) => Err("JSON parse error in fallback: \{e}")
          }
        }
        Err(_) => {
           // Third fallback: specifically looking for moonpalace/fluxworkflow.json
           let fallback_path2 = "..\\..\\fluxworkflow.json"
           match @net.read_file(fallback_path2) {
             Ok(content) => {
               match ((try { Ok(@json.parse(content)) } catch { err => Err(err.to_string()) })) {
                 Ok(json) => Ok(json)
                 Err(e) => Err("JSON parse error in second fallback: \{e}")
               }
             }
             Err(e) => Err("Failed to read file from all paths: \{e}")
           }
        }
      }
    }
  }
}

// Pseudo random number generator
fn simple_random() -> Double {
  let r = @net.get_random()
  let safe_r = r & 0x3FFFFFFF
  safe_r.to_double()
}

fn generate_image(prompt_text: String, output_filename: String) -> Bool {
  if config.is_runcomfy {
    // RunComfy approach
    let overrides = Json::object(Map::from_array([
      ("76", Json::object(Map::from_array([
        ("inputs", Json::object(Map::from_array([
          ("value", Json::string(prompt_text))
        ])))
      ])))
    ]))
    
    let req_body = Json::object(Map::from_array([("overrides", overrides)]))
    println("Submitting task to RunComfy (Flux2)...")
    let queue_res = queue_prompt(req_body)
    
    let mut prompt_id = ""
    match queue_res {
      Json::Object(map) => {
        // RunComfy returns the task ID in "request_id" for the /inference endpoint
        match map.get("request_id") {
          Some(Json::String(id)) => prompt_id = id
          _ => match map.get("run_id") {
            Some(Json::String(id)) => prompt_id = id
            _ => match map.get("id") {
              Some(Json::String(id)) => prompt_id = id
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
    
    if prompt_id == "" {
      println("Failed to get task ID from RunComfy. Raw Response:")
      println(queue_res.stringify())
      return false
    }
    
    println("Task queued. ID: \{prompt_id}")
    println("Waiting for generation to complete (RunComfy Flux2)...")
    
    while true {
      let history = get_history(prompt_id)
      match history {
        Json::Object(hmap) => {
          let mut status = ""
          match hmap.get("status") {
            Some(Json::String(s)) => status = s
            _ => ()
          }
          if status == "SUCCESS" {
            println("RunComfy task SUCCESS. Downloading result...")
            let result_url = "https://api.runcomfy.net/prod/v1/deployments/eca194ca-7090-42bd-a14f-8bd5cfa0f636/requests/" + prompt_id + "/result"
            let headers = ["Authorization: Bearer " + config.runcomfy_token]
            match @net.http_get_bytes(result_url, headers~) {
              Ok(bytes) => {
                 // For RunComfy, result returns JSON or ZIP depending on workflow.
                 // Actually, RunComfy result for image is a JSON with a direct download link usually?
                 // Or we might need to parse the JSON and get the URL.
                 let s = try { @utf8.decode(bytes) } catch { _ => "" }
                 match (try { Ok(@json.parse(s)) } catch { err => Err(err.to_string()) }) {
                   Ok(j) => {
                     match j {
                       Json::Array(arr) => {
                         if arr.length() > 0 {
                           match arr[0] {
                             Json::Object(omap) => {
                               match omap.get("image_url") {
                                 Some(Json::String(url)) => {
                                   println("Downloading from \{url}")
                                   match @net.http_get_bytes(url) {
                                     Ok(img_bytes) => {
                                        let tmp_name = output_filename + ".tmp"
                                        let _ = @net.write_file_bytes(tmp_name, img_bytes)
                                        @net.rename_file(tmp_name, output_filename)
                                        println("Success! Image saved to \{output_filename}")
                                        return true
                                     }
                                     Err(e) => println("Download failed: \{e}")
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
                   Err(_) => ()
                 }
                 println("Could not parse result properly.")
                 return false
              }
              Err(e) => {
                println("Failed to fetch result: \{e}")
                return false
              }
            }
          } else if status == "FAILED" || status == "CANCELED" || status == "TIMEOUT" {
            println("RunComfy task failed with status: \{status}")
            return false
          }
        }
        _ => ()
      }
      @net.sleep(2000)
    }
    return false
  }

  match read_json_file(workflow_file) {
    Ok(workflow) => {
      let mut modified_workflow = workflow
      
      // Node 6 inputs text (Local Workflow - fallback to node 76 if 6 not found, wait, local used 6 for old SDXL, but for flux2 we use what's in json)
      match modified_workflow {
        Json::Object(map) => {
          // If local flux2 workflow uses node 76, we should update 76. If it uses 6, we update 6.
          // Let's try both.
          match map.get("6") {
            Some(Json::Object(node6)) => {
              match node6.get("inputs") {
                Some(Json::Object(inputs)) => {
                  inputs.set("text", Json::string(prompt_text))
                  node6.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("6", Json::object(node6))
            }
            _ => ()
          }
          match map.get("76") {
            Some(Json::Object(node76)) => {
              match node76.get("inputs") {
                Some(Json::Object(inputs)) => {
                  // Some nodes use "value" (PrimitiveStringMultiline) and some use "text"
                  if inputs.contains("value") {
                     inputs.set("value", Json::string(prompt_text))
                  } else {
                     inputs.set("text", Json::string(prompt_text))
                  }
                  node76.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("76", Json::object(node76))
            }
            _ => ()
          }
          
          match map.get("25") {
            Some(Json::Object(node25)) => {
              match node25.get("inputs") {
                Some(Json::Object(inputs)) => {
                  inputs.set("noise_seed", Json::number(simple_random()))
                  node25.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("25", Json::object(node25))
            }
            _ => ()
          }
          
          match map.get("75:73") { // Flux2 random noise node
            Some(Json::Object(node73)) => {
              match node73.get("inputs") {
                Some(Json::Object(inputs)) => {
                  inputs.set("noise_seed", Json::number(simple_random()))
                  node73.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("75:73", Json::object(node73))
            }
            _ => ()
          }
          
          modified_workflow = Json::object(map)
        }
        _ => ()
      }
      
      println("Submitting task to Local ComfyUI...")
      let queue_res = queue_prompt(modified_workflow)
      
      let mut prompt_id = ""
      match queue_res {
        Json::Object(map) => {
          match map.get("prompt_id") {
            Some(Json::String(id)) => prompt_id = id
            _ => ()
          }
        }
        _ => ()
      }
      
      if prompt_id == "" {
        println("Failed to get prompt_id from ComfyUI.")
        return false
      }
      
      println("Task queued. ID: \{prompt_id}")
      println("Waiting for generation to complete...")
      
      while true {
        let history = get_history(prompt_id)
        match history {
          Json::Object(hmap) => {
            if hmap.contains(prompt_id) {
              match hmap.get(prompt_id) {
                Some(Json::Object(pmap)) => {
                  match pmap.get("outputs") {
                    Some(Json::Object(omap)) => {
                      for _, node_output in omap {
                        match node_output {
                          Json::Object(nmap) => {
                            match nmap.get("images") {
                              Some(Json::Array(images)) => {
                                for img in images {
                                  match img {
                                    Json::Object(imap) => {
                                      let mut filename = ""
                                      let mut subfolder = ""
                                      let mut folder_type = ""
                                      
                                      match imap.get("filename") {
                                        Some(Json::String(s)) => filename = s
                                        _ => ()
                                      }
                                      match imap.get("subfolder") {
                                        Some(Json::String(s)) => subfolder = s
                                        _ => ()
                                      }
                                      match imap.get("type") {
                                        Some(Json::String(s)) => folder_type = s
                                        _ => ()
                                      }
                                      
                                      println("Downloading image \{filename}...")
                                      match get_image(filename, subfolder, folder_type) {
                                        Ok(bytes) => {
                                          let tmp_name = output_filename + ".tmp"
                                          let _ = @net.write_file_bytes(tmp_name, bytes)
                                          @net.rename_file(tmp_name, output_filename)
                                          println("Success! Image saved to \{output_filename}")
                                          return true
                                        }
                                        Err(e) => {
                                          println("Failed to download image: \{e}")
                                        }
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
                    }
                    _ => ()
                  }
                }
                _ => ()
              }
              break
            }
          }
          _ => ()
        }
        
        @net.sleep(2000)
      }
      
      println("Generation finished but no image was found in output.")
      return false
    }
    Err(e) => {
      println("Error: Could not find \{workflow_file}: \{e}")
      return false
    }
  }
}

fn main {
  let args = @env.args()
  if args.length() > 2 {
    let url_arg = args[1]
    if url_arg.has_prefix("runcomfy|") {
      config.is_runcomfy = true
      config.runcomfy_token = url_arg[9:].to_string()
    } else {
      config.url = url_arg
    }
    
    let prompt_text = args[2]
    let out_name = if args.length() > 3 { args[3] } else { "generated_concept.png" }
    let _ = generate_image(prompt_text, out_name)
  } else {
    println("Usage: comfy_worker.exe <comfy_url> <prompt> [output_filename.png]")
  }
}
