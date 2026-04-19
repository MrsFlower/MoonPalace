pub(all) struct ApiConfig {
  api_url: String
  api_key: String
  model_name: String
} derive(Show, ToJson, FromJson)

pub(all) struct Config {
  api_provider: String // "OpenAI" or "Gemini"
  
  creative_api: ApiConfig
  structural_api: ApiConfig
  
  gemini_creative: ApiConfig
  gemini_structural: ApiConfig
  lang: String
  comfy_mode: String // "local" or "runcomfy"
  comfy_url: String
  runcomfy_api_key: String
} derive(Show, ToJson, FromJson)

pub fn Config::default() -> Config {
  {
    api_provider: "Gemini",
    creative_api: {
      api_url: "http://127.0.0.1:11434/v1",
      api_key: "ENV:OPENAI_API_KEY",
      model_name: "qwen2.5-coder-32b-instruct",
    },
    structural_api: {
      api_url: "http://127.0.0.1:11434/v1",
      api_key: "ENV:OPENAI_API_KEY",
      model_name: "qwen2.5-coder-32b-instruct",
    },
    gemini_creative: {
      api_url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
      api_key: "ENV:GEMINI_API_KEY",
      model_name: "gemini-2.5-pro",
    },
    gemini_structural: {
      api_url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      api_key: "ENV:GEMINI_API_KEY",
      model_name: "gemini-2.5-flash",
    },
    lang: "ZH",
    comfy_mode: "local",
    comfy_url: "http://127.0.0.1:8188",
    runcomfy_api_key: ""
  }
}

pub fn load_config() -> Config {
  let path = "config.json"
  if @fs.path_exists(path) {
    let content = @fs.read_file_to_string(path) catch { _ => "" }
    let json_val = @json.parse(content) catch { _ => Json::object(Map::new()) }
    let config : Config = @json.from_json(json_val) catch { _ => Config::default() }
    config
  } else {
    Config::default()
  }
}

pub fn save_config(config: Config) -> Unit {
  let json_str = config.to_json().stringify()
  ignore(@fs.write_string_to_file("config.json", json_str) catch { _ => () })
  println("Config saved successfully.")
}
