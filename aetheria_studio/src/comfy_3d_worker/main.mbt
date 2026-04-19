// Config struct for global states
struct ComfyConfig {
  mut url: String
  mut is_runcomfy: Bool
  mut runcomfy_token: String
}
let config: ComfyConfig = { url: "http://127.0.0.1:8188", is_runcomfy: false, runcomfy_token: "" }

let workflow_file = "Trellis2.json"

fn get_history(prompt_id: String) -> Json {
  if config.is_runcomfy {
    let url = "https://api.runcomfy.net/prod/v1/deployments/707d1d90-f493-47eb-b023-a839ce732b27/requests/" + prompt_id + "/status"
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

fn queue_prompt(workflow: Json) -> Json {
  let url = if config.is_runcomfy {
    "https://api.runcomfy.net/prod/v1/deployments/707d1d90-f493-47eb-b023-a839ce732b27/inference"
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
  
  println("DEBUG: Requesting /prompt...")
  
  match @net.http_post(url, headers, data_str) {
    Ok(res) => {
      println("DEBUG: /prompt responded with status: \{res.status_code}")
      if res.status_code != 200 {
         println("DEBUG: /prompt response body: \{res.body}")
      }
      match (try { Ok(@json.parse(res.body)) } catch { err => Err(err.to_string()) }) {
        Ok(j) => j
        Err(_) => Json::object(Map::new())
      }
    }
    Err(e) => {
      println("DEBUG: /prompt request failed: \{e}")
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
           // Third fallback: specifically looking for moonpalace/Trellis2.json
           let fallback_path2 = "..\\..\\Trellis2.json"
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

fn upload_image(image_path: String) -> Result[String, String] {
  // Simple multipart/form-data upload via curl
  let url = config.url + "/upload/image"
  
  match @net.read_file_bytes(image_path) {
    Ok(_) => {
      // MoonBit net package doesn't have multipart upload.
      // And we can't get output from system command natively in standard env right now.
      // Since Trellis uses the image from ComfyUI, a workaround is to put the image in ComfyUI's input directory directly if we knew it.
      // Or we can rely on a local python script, but we don't want external dependencies.
      // Another workaround: ComfyUI API can accept base64 encoded images in some custom nodes, but standard LoadImage needs the file in input/.
      // Let's assume we can upload using a generated python/bat script that writes output to a file.
      let script_path = "upload_tmp.bat"
      let out_path = "upload_out.txt"
      let script_content = "@echo off\r\ncurl -s -X POST -F \"image=@" + image_path + "\" " + url + " > " + out_path + "\r\n"
      let _ = @net.write_file_bytes(script_path, @utf8.encode(script_content))
      
      @net.system_command(script_path)
      
      // Read the output
      match @net.read_file(out_path) {
        Ok(output_str) => {
          let _ = try { @fs.remove_file(script_path) } catch { _ => () }
          let _ = try { @fs.remove_file(out_path) } catch { _ => () }
          match (try { Ok(@json.parse(output_str)) } catch { err => Err(err.to_string()) }) {
            Ok(Json::Object(map)) => {
              match map.get("name") {
                Some(Json::String(s)) => Ok(s)
                _ => Err("Failed to extract filename from upload response: " + output_str)
              }
            }
            _ => Err("Invalid JSON response from upload: " + output_str)
          }
        }
        Err(e) => Err("Failed to read upload output: " + e)
      }
    }
    Err(e) => Err(e.to_string())
  }
}

// Pseudo random number generator
fn simple_random() -> Double {
  // get_random() returns a 30-bit integer now. Let's make sure it fits safely in int32.
  let r = @net.get_random()
  // Mask it to keep it positive and well within 2 billion
  let safe_r = r & 0x3FFFFFFF
  safe_r.to_double()
}

fn generate_3d_model(input_image: String, output_filename: String) -> Bool {
  if config.is_runcomfy {
    // RunComfy approach for Trellis2
    // We need to encode the image to base64
    println("Encoding source image to base64: \{input_image}")
    let base64_image = match @net.read_file_bytes(input_image) {
      Ok(_) => {
         // @encoding.base64 is not universally available, so we'll just read and base64 it in a small powershell script
         // to get a data URI string, or if we had a moonbit base64 package we could use it.
         // Actually, let's use powershell to output the base64 directly to a file
         let b64_script = "b64_tmp.ps1"
         let b64_out = "b64_out.txt"
         let ps_content = "$bytes = [System.IO.File]::ReadAllBytes('" + input_image + "')\n$b64 = [System.Convert]::ToBase64String($bytes)\n[System.IO.File]::WriteAllText('" + b64_out + "', 'data:image/png;base64,' + $b64)\n"
         let _ = @net.write_file_bytes(b64_script, @utf8.encode(ps_content))
         @net.system_command("powershell -NoProfile -ExecutionPolicy Bypass -File " + b64_script)
         let b64_str = match @net.read_file(b64_out) {
           Ok(s) => s
           Err(_) => ""
         }
         let _ = try { @fs.remove_file(b64_script) } catch { _ => () }
         let _ = try { @fs.remove_file(b64_out) } catch { _ => () }
         b64_str
      }
      Err(e) => {
        println("Failed to read image for base64: \{e}")
        ""
      }
    }
    
    if base64_image == "" {
       return false
    }

    let overrides = Json::object(Map::from_array([
      ("279", Json::object(Map::from_array([
        ("inputs", Json::object(Map::from_array([
          ("image", Json::string(base64_image))
        ])))
      ]))),
      ("140", Json::object(Map::from_array([
        ("inputs", Json::object(Map::from_array([
          ("filename_prefix", Json::string(output_filename))
        ])))
      ]))),
      ("278", Json::object(Map::from_array([
        ("inputs", Json::object(Map::from_array([
          ("seed", Json::number(simple_random()))
        ])))
      ])))
    ]))
    
    let req_body = Json::object(Map::from_array([("overrides", overrides)]))
    println("Submitting task to RunComfy (Trellis2)...")
    let queue_res = queue_prompt(req_body)
    
    let mut prompt_id = ""
    match queue_res {
      Json::Object(map) => {
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
    println("Waiting for generation to complete (RunComfy Trellis2)...")
    
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
            let result_url = "https://api.runcomfy.net/prod/v1/deployments/707d1d90-f493-47eb-b023-a839ce732b27/requests/" + prompt_id + "/result"
            let headers = ["Authorization: Bearer " + config.runcomfy_token]
            match @net.http_get_bytes(result_url, headers~) {
              Ok(bytes) => {
                 let s = try { @utf8.decode(bytes) } catch { _ => "" }
                 match (try { Ok(@json.parse(s)) } catch { err => Err(err.to_string()) }) {
                   Ok(j) => {
                     match j {
                       Json::Array(arr) => {
                         if arr.length() > 0 {
                           match arr[0] {
                             Json::Object(omap) => {
                               match omap.get("file_url") {
                                 Some(Json::String(url)) => {
                                   println("Downloading 3D model from \{url}")
                                   match @net.http_get_bytes(url) {
                                     Ok(glb_bytes) => {
                                        // Aetheria Studio expects GLB to be saved directly in the project folder with output_filename_WhiteMesh.glb or similar
                                        // Wait, the main.mbt expects the worker to put it at output_filename + "_WhiteMesh.glb"
                                        // In RunComfy, it's just a file. We will save it exactly where the out_name specifies.
                                        let final_name = output_filename + "_WhiteMesh.glb"
                                        let mut dir_path = "."
                                        // Extract dir from input_image
                                        if input_image.contains("\\") {
                                           let parts = input_image.split("\\").collect()
                                           if parts.length() > 1 {
                                              dir_path = parts[0].to_string()
                                           }
                                        }
                                        let save_path = dir_path + "\\" + final_name
                                        let tmp_name = save_path + ".tmp"
                                        let _ = @net.write_file_bytes(tmp_name, glb_bytes)
                                        @net.rename_file(tmp_name, save_path)
                                        println("Success! Model saved to \{save_path}")
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

  println("Uploading source image: \{input_image}")
  let mut uploaded_filename = ""
  match upload_image(input_image) {
    Ok(name) => {
      uploaded_filename = name
      println("Image uploaded successfully: \{name}")
    }
    Err(e) => {
      println("Failed to upload image: \{e}")
      return false
    }
  }

  match read_json_file(workflow_file) {
    Ok(workflow) => {
      let mut modified_workflow = workflow
      
      // Trellis2.json modifications
      // Node 13 inputs image: uploaded_filename
      // Node 35 inputs value: output_filename
      // Node 17, 20, 25 seed: simple_random()
      match modified_workflow {
        Json::Object(map) => {
          match map.get("13") {
            Some(Json::Object(node13)) => {
              match node13.get("inputs") {
                Some(Json::Object(inputs)) => {
                  inputs.set("image", Json::string(uploaded_filename))
                  node13.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("13", Json::object(node13))
            }
            _ => ()
          }
          
          match map.get("35") {
            Some(Json::Object(node35)) => {
              match node35.get("inputs") {
                Some(Json::Object(inputs)) => {
                  let mut base_output_name = output_filename
                  if output_filename.contains("\\") {
                     let parts = output_filename.split("\\").collect()
                     base_output_name = parts[parts.length() - 1].to_string()
                  }
                  inputs.set("value", Json::string(base_output_name))
                  node35.set("inputs", Json::object(inputs))
                }
                _ => ()
              }
              map.set("35", Json::object(node35))
            }
            _ => ()
          }
          
          let seed_nodes = ["17", "20", "25"]
          let seed_val = Json::number(simple_random())
          for node_id in seed_nodes {
            match map.get(node_id) {
              Some(Json::Object(node)) => {
                match node.get("inputs") {
                  Some(Json::Object(inputs)) => {
                    inputs.set("seed", seed_val)
                    node.set("inputs", Json::object(inputs))
                  }
                  _ => ()
                }
                map.set(node_id, Json::object(node))
              }
              _ => ()
            }
          }
          
          modified_workflow = Json::object(map)
        }
        _ => ()
      }
      
      println("Submitting 3D task to ComfyUI...")
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
      println("Waiting for generation to complete (this may take several minutes)...")
      
      while true {
        let history = get_history(prompt_id)
        match history {
          Json::Object(hmap) => {
            if hmap.contains(prompt_id) {
              // Task is done
              // We need to pull the generated GLB from ComfyUI output API instead of relying on it writing to a shared folder.
              let mut pulled = false
              match hmap.get(prompt_id) {
                Some(Json::Object(pmap)) => {
                  match pmap.get("outputs") {
                    Some(Json::Object(omap)) => {
                      for _, node_output in omap {
                        match node_output {
                          Json::Object(nmap) => {
                            // Iterate over all keys in the node output (e.g. "images", "mesh", "files", etc.)
                            for _, val in nmap {
                                match val {
                                    Json::Array(file_list) => {
                                        // Format A: [{ filename, subfolder, type }, ...]
                                        for item in file_list {
                                            match item {
                                                Json::Object(mmap) => {
                                                    let mut filename = ""
                                                    let mut subfolder = ""
                                                    let mut folder_type = ""
                                                    
                                                    match mmap.get("filename") {
                                                        Some(Json::String(s)) => filename = s
                                                        _ => ()
                                                    }
                                                    match mmap.get("subfolder") {
                                                        Some(Json::String(s)) => subfolder = s
                                                        _ => ()
                                                    }
                                                    match mmap.get("type") {
                                                        Some(Json::String(s)) => folder_type = s
                                                        _ => ()
                                                    }
                                                    
                                                    // Only process 3D models
                                                    if filename.contains(".glb") || filename.contains(".obj") {
                                                        println("Found 3D model \{filename} in ComfyUI history...")
                                                        
                                                        let mut filename_for_view = filename
                                                        if filename_for_view.contains("\\") {
                                                            let parts = filename_for_view.split("\\").collect()
                                                            if parts.length() > 0 {
                                                                filename_for_view = parts[parts.length() - 1].to_string()
                                                            }
                                                        }
                                                        if filename_for_view.contains("/") {
                                                            let parts2 = filename_for_view.split("/").collect()
                                                            if parts2.length() > 0 {
                                                                filename_for_view = parts2[parts2.length() - 1].to_string()
                                                            }
                                                        }
                                                        
                                                        let mut get_url = config.url + "/view?filename=" + filename_for_view + "&type=" + folder_type
                                                        if subfolder != "" {
                                                            get_url = get_url + "&subfolder=" + subfolder
                                                        }
                                                        
                                                        match @net.http_get_bytes(get_url) {
                                                            Ok(glb_bytes) => {
                                                                let mut dir_path = "."
                                                                if output_filename.contains("\\") {
                                                                    let parts = output_filename.split("\\").collect()
                                                                    if parts.length() > 1 {
                                                                        let mut dp = parts[0].to_string()
                                                                        for p_i = 1; p_i < parts.length() - 1; p_i = p_i + 1 {
                                                                            dp = dp + "\\" + parts[p_i].to_string()
                                                                        }
                                                                        dir_path = dp
                                                                    }
                                                                }
                                                                
                                                                let mut base_output_name = output_filename
                                                                if output_filename.contains("\\") {
                                                                    let parts = output_filename.split("\\").collect()
                                                                    base_output_name = parts[parts.length() - 1].to_string()
                                                                }

                                                                // Always rename to our standard output format
                                                                let final_name = base_output_name + "_Textured.glb"
                                                                let save_path = dir_path + "\\" + final_name
                                                                let tmp_name = save_path + ".tmp"
                                                                let _ = @net.write_file_bytes(tmp_name, glb_bytes)
                                                                
                                                                let written_bytes = @net.read_file_bytes(tmp_name)
                                                                match written_bytes {
                                                                    Ok(b) => {
                                                                        if b.length() > 100 {
                                                                            @net.rename_file(tmp_name, save_path)
                                                                            println("Success! Model saved from history to \{save_path}")
                                                                            if filename.contains(".glb") || filename.contains(".obj") {
                                                                                pulled = true
                                                                            }
                                                                        } else {
                                                                            println("Warning: Downloaded file from history is suspiciously small (\{b.length()} bytes)")
                                                                        }
                                                                    }
                                                                    _ => ()
                                                                }
                                                            }
                                                            Err(e) => {
                                                                println("Failed to download model from history: \{e}")
                                                            }
                                                        }
                                                    }
                                                }
                                                _ => ()
                                            }
                                        }
                                        
                                        // Format B: ["xxx.glb", "subfolder_or_empty", "type_or_empty", ...]
                                        if file_list.length() > 0 {
                                            let mut tuple_filename = ""
                                            let mut tuple_subfolder = ""
                                            let mut tuple_type = "output"
                                            
                                            match file_list[0] {
                                                Json::String(s) => tuple_filename = s
                                                _ => ()
                                            }
                                            if file_list.length() > 1 {
                                                match file_list[1] {
                                                    Json::String(s) => tuple_subfolder = s
                                                    _ => ()
                                                }
                                            }
                                            if file_list.length() > 2 {
                                                match file_list[2] {
                                                    Json::String(s) => tuple_type = s
                                                    _ => ()
                                                }
                                            }
                                            
                                            if tuple_filename.contains(".glb") || tuple_filename.contains(".obj") {
                                                println("Found tuple-style 3D model \{tuple_filename} in ComfyUI history...")
                                                
                                                let mut tuple_filename_for_view = tuple_filename
                                                if tuple_filename_for_view.contains("\\") {
                                                    let parts = tuple_filename_for_view.split("\\").collect()
                                                    if parts.length() > 0 {
                                                        tuple_filename_for_view = parts[parts.length() - 1].to_string()
                                                    }
                                                }
                                                if tuple_filename_for_view.contains("/") {
                                                    let parts2 = tuple_filename_for_view.split("/").collect()
                                                    if parts2.length() > 0 {
                                                        tuple_filename_for_view = parts2[parts2.length() - 1].to_string()
                                                    }
                                                }
                                                
                                                let mut get_url = config.url + "/view?filename=" + tuple_filename_for_view + "&type=" + tuple_type
                                                if tuple_subfolder != "" {
                                                    get_url = get_url + "&subfolder=" + tuple_subfolder
                                                }
                                                match @net.http_get_bytes(get_url) {
                                                    Ok(glb_bytes) => {
                                                        let mut dir_path = "."
                                                        if output_filename.contains("\\") {
                                                            let parts = output_filename.split("\\").collect()
                                                            if parts.length() > 1 {
                                                                let mut dp = parts[0].to_string()
                                                                for p_i = 1; p_i < parts.length() - 1; p_i = p_i + 1 {
                                                                    dp = dp + "\\" + parts[p_i].to_string()
                                                                }
                                                                dir_path = dp
                                                            }
                                                        }
                                                        
                                                        let mut base_output_name = output_filename
                                                        if output_filename.contains("\\") {
                                                            let parts = output_filename.split("\\").collect()
                                                            base_output_name = parts[parts.length() - 1].to_string()
                                                        }
                                                        
                                                        let final_name = base_output_name + "_Textured.glb"
                                                        let save_path = dir_path + "\\" + final_name
                                                        let tmp_name = save_path + ".tmp"
                                                        let _ = @net.write_file_bytes(tmp_name, glb_bytes)
                                                        
                                                        let written_bytes = @net.read_file_bytes(tmp_name)
                                                        match written_bytes {
                                                            Ok(b) => {
                                                                if b.length() > 100 {
                                                                    @net.rename_file(tmp_name, save_path)
                                                                    println("Success! Tuple-style model saved from history to \{save_path}")
                                                                    pulled = true
                                                                } else {
                                                                    println("Warning: Tuple-style model download too small (\{b.length()} bytes)")
                                                                }
                                                            }
                                                            _ => ()
                                                        }
                                                    }
                                                    Err(e) => println("Failed to download tuple-style model from history: \{e}")
                                                }
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
                    }
                    _ => ()
                  }
                }
                _ => ()
              }
              if pulled {
                return true
              }
              // Fallback if we couldn't download
              println("Generation finished. Checking if model was pulled...")
              if not(pulled) {
                 println("Warning: We didn't find any matching GLB file in the outputs. It might have been saved directly to ComfyUI's output folder.")
                 // Fallback: Check if we can blindly download using the expected prefix directly from ComfyUI API
                 // Node 35 outputs the filename prefix we set
                 let mut base_output_name = output_filename
                 if output_filename.contains("\\") {
                    let parts = output_filename.split("\\").collect()
                    base_output_name = parts[parts.length() - 1].to_string()
                 }
                 let expected_filename2 = base_output_name + "_Textured.glb"
                 let expected_filename = base_output_name + "_WhiteMesh.glb"
                 println("Attempting blind fallback download for: " + expected_filename2)
                 
                 let get_url2 = config.url + "/view?filename=" + expected_filename2 + "&type=output"
                 let get_url = config.url + "/view?filename=" + expected_filename + "&type=output"
                 
                 // Priority 1: Textured (get_url2)
                 match @net.http_get_bytes(get_url2) {
                    Ok(glb_bytes) => {
                       let mut dir_path = "."
                       if output_filename.contains("\\") {
                          let parts = output_filename.split("\\").collect()
                          if parts.length() > 1 {
                             let mut dp = parts[0].to_string()
                             for p_i = 1; p_i < parts.length() - 1; p_i = p_i + 1 {
                                 dp = dp + "\\" + parts[p_i].to_string()
                             }
                             dir_path = dp
                          }
                       }
                       let save_path = dir_path + "\\" + expected_filename2
                       let tmp_name = save_path + ".tmp"
                       let _ = @net.write_file_bytes(tmp_name, glb_bytes)
                       
                       let written_bytes = @net.read_file_bytes(tmp_name)
                       match written_bytes {
                           Ok(b) => {
                               if b.length() > 100 {
                                   @net.rename_file(tmp_name, save_path)
                                   println("Fallback download (Textured) successful! Model saved to \{save_path}")
                                   return true
                               } else {
                                   println("Fallback downloaded file is too small (\{b.length()} bytes)")
                               }
                           }
                           _ => ()
                       }
                    }
                    Err(_) => {
                       // Priority 2: WhiteMesh (get_url)
                       match @net.http_get_bytes(get_url) {
                          Ok(glb_bytes2) => {
                             let mut dir_path = "."
                             if output_filename.contains("\\") {
                                let parts = output_filename.split("\\").collect()
                                if parts.length() > 1 {
                                   let mut dp = parts[0].to_string()
                                   for p_i = 1; p_i < parts.length() - 1; p_i = p_i + 1 {
                                       dp = dp + "\\" + parts[p_i].to_string()
                                   }
                                   dir_path = dp
                                }
                             }
                             let save_path = dir_path + "\\" + expected_filename
                             let tmp_name = save_path + ".tmp"
                             let _ = @net.write_file_bytes(tmp_name, glb_bytes2)
                             
                             let written_bytes2 = @net.read_file_bytes(tmp_name)
                             match written_bytes2 {
                                 Ok(b) => {
                                     if b.length() > 100 {
                                         @net.rename_file(tmp_name, save_path)
                                         println("Fallback download (WhiteMesh) successful! Model saved to \{save_path}")
                                         return true
                                     } else {
                                         println("Fallback downloaded file is too small (\{b.length()} bytes)")
                                     }
                                 }
                                 _ => ()
                             }
                          }
                          Err(_) => {
                             println("Fallback download failed. You may need to copy it manually from ComfyUI output folder.")
                          }
                       }
                    }
                 }
              }
              // We return true anyway so the pipeline can continue.
              return true
            }
          }
          _ => ()
        }
        
        @net.sleep(2000)
      }
      
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
    let input_image = args[2]
    let out_name = if args.length() > 3 { args[3] } else { "generated_model" }
    let _ = generate_3d_model(input_image, out_name)
  } else {
    println("Usage: comfy_3d_worker.exe <comfy_url> <input_image_path> [output_prefix]")
  }
}
