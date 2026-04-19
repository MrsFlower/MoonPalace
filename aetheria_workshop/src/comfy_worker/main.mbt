let comfyui_url = "http://127.0.0.1:8188"
let workflow_file = "fluxworkflow.json"

fn get_image(filename: String, subfolder: String, folder_type: String) -> Result[Bytes, String] {
  // url encode the data... manually replace spaces with %20.
  let encoded_filename = filename.replace_all(old=" ", new="%20")
  let url = comfyui_url + "/view?filename=" + encoded_filename + "&subfolder=" + subfolder + "&type=" + folder_type
  @net.http_get_bytes(url)
}

fn get_history(prompt_id: String) -> Json {
  let url = comfyui_url + "/history/" + prompt_id
  match @net.http_get_bytes(url) {
    Ok(bytes) => {
      let s = try { @utf8.decode(bytes) } catch { _ => "" }
      match (try { Ok(@json.parse!(s)) } catch { err => Err(err.to_string()) }) {
        Ok(j) => j
        Err(_) => Json::object(Map::new())
      }
    }
    Err(_) => Json::object(Map::new())
  }
}

fn queue_prompt(workflow: Json) -> Json {
  let url = comfyui_url + "/prompt"
  let data = Json::object(Map::from_array([("prompt", workflow)]))
  let data_str = data.stringify()
  let headers = ["Content-Type: application/json"]
  match @net.http_post(url, headers, data_str) {
    Ok(res) => {
      match (try { Ok(@json.parse!(res.body)) } catch { err => Err(err.to_string()) }) {
        Ok(j) => j
        Err(_) => Json::object(Map::new())
      }
    }
    Err(_) => Json::object(Map::new())
  }
}

fn read_json_file(path: String) -> Result[Json, String] {
  match @net.read_file(path) {
    Ok(content) => {
      match ((try { Ok(@json.parse!(content)) } catch { err => Err(err.to_string()) })) {
        Ok(json) => Ok(json)
        Err(e) => Err("JSON parse error: \{e}")
      }
    }
    Err(e) => Err(e)
  }
}

// Pseudo random number generator
fn simple_random() -> Double {
  @net.get_random().to_double()
}

fn generate_image(prompt_text: String, output_filename: String) -> Bool {
  match read_json_file(workflow_file) {
    Ok(workflow) => {
      let mut modified_workflow = workflow
      
      // Node 6 inputs text
      // In MoonBit, modifying a deep JSON is slightly tedious because it's immutable
      // We will reconstruct it or use Map set
      match modified_workflow {
        Json::Object(map) => {
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
          
          modified_workflow = Json::object(map)
        }
        _ => ()
      }
      
      println("Submitting task to ComfyUI...")
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
      println("Waiting for generation to complete (this may take a minute on Flux Dev)...")
      
      while true {
        let history = get_history(prompt_id)
        match history {
          Json::Object(hmap) => {
            if hmap.contains(prompt_id) {
              // Task is done
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
        // println(".") // no flush available
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
  if args.length() > 1 {
    let prompt_text = args[1]
    let out_name = if args.length() > 2 { args[2] } else { "generated_concept.png" }
    let _ = generate_image(prompt_text, out_name)
  } else {
    println("Usage: comfy_worker.exe \"Your image prompt here\" [output_filename.png]")
  }
}
