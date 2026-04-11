pub(all) struct ApiConfig {
  api_url: String
  api_key: String
  model_name: String
} derive(Show, ToJson, FromJson)

pub(all) struct Config {
  creative_api: ApiConfig
  structural_api: ApiConfig
} derive(Show, ToJson, FromJson)

pub fn Config::default() -> Config {
  {
    creative_api: {
      api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions",
      api_key: "",
      model_name: "hunyuan-2.0-thinking",
    },
    structural_api: {
      api_url: "https://api.lkeap.cloud.tencent.com/coding/v3/chat/completions",
      api_key: "",
      model_name: "hunyuan-2.0-instruct",
    }
  }
}

pub fn load_config() -> Config {
  let path = "config.json"
  if @fs.path_exists(path) {
    try {
      let content = @fs.read_file_to_string(path)
      let json_val = @json.parse(content)
      let config : Config = @json.from_json(json_val)
      config
    } catch {
      _ => Config::default()
    }
  } else {
    Config::default()
  }
}

pub fn save_config(config: Config) -> Unit {
  let json_str = config.to_json().stringify()
  try {
    @fs.write_string_to_file("config.json", json_str)
    println("Config saved successfully.")
  } catch {
    err => println("Failed to save config: \{err}")
  }
}
