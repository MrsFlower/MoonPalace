// Visual Novel Engine - Core Data Structures
// Phase 1: Basic types and story node management
// Build test

/// Choice represents a player-selectable option in the story
pub struct Choice {
  /// The display text for this choice
  text: String
  /// The ID of the node this choice leads to
  target_node_id: Int
}

/// Node represents a single story node/scene in the visual novel
pub struct Node {
  /// Unique identifier for this node
  id: Int
  /// URL or path to the background image for this scene
  background_image_url: String
  /// The main text content displayed in this scene
  text_content: String
  /// Available choices for the player
  choices: Array[Choice]
}

/// GameState manages the current state of the visual novel
pub struct GameState {
  /// All story nodes indexed by their ID
  mut nodes: Map[Int, Node]
  /// Currently active node ID
  mut current_node_id: Int
  /// History of visited node IDs
  mut history: Array[Int]
  /// Buffer for FFI strings
  mut in_chars: Array[Char]
}

/// Global game state instance (mutable for game state management)
let game_state: GameState = GameState::{
  nodes: {},
  current_node_id: -1,
  history: [],
  in_chars: []
}

// Constructor functions
pub fn Choice::new(text: String, target_node_id: Int) -> Choice {
  Choice::{ text, target_node_id }
}

pub fn Node::new(id: Int, background_image_url: String, text_content: String, choices: Array[Choice]) -> Node {
  Node::{ id, background_image_url, text_content, choices }
}

// Story management functions
pub fn add_node(node: Node) -> Unit {
  game_state.nodes.set(node.id, node)
}

pub fn ffi_clear_nodes() -> Unit {
  game_state.nodes = {}
  game_state.history = []
  game_state.current_node_id = -1
}

pub fn ffi_add_node(id: Int) -> Unit {
  // text and background are read from ffi buffer (we can pass text first, then background)
  // To keep it simple, let JS set ffi buffer, then call ffi_add_node_text, ffi_add_node_bg
  let node = Node::new(id, "", "", [])
  add_node(node)
}

pub fn ffi_set_node_text(id: Int) -> Unit {
  let text = ffi_buffer_get_string()
  match game_state.nodes.get(id) {
    Some(node) => {
      let new_node = Node::new(node.id, node.background_image_url, text, node.choices)
      add_node(new_node)
    }
    None => ()
  }
}

pub fn ffi_set_node_bg(id: Int) -> Unit {
  let bg = ffi_buffer_get_string()
  match game_state.nodes.get(id) {
    Some(node) => {
      let new_node = Node::new(node.id, bg, node.text_content, node.choices)
      add_node(new_node)
    }
    None => ()
  }
}

pub fn ffi_add_choice(node_id: Int, target_id: Int) -> Unit {
  let text = ffi_buffer_get_string()
  match game_state.nodes.get(node_id) {
    Some(node) => {
      let new_choices = []
      for c in node.choices {
        new_choices.push(c)
      }
      new_choices.push(Choice::new(text, target_id))
      let new_node = Node::new(node.id, node.background_image_url, node.text_content, new_choices)
      add_node(new_node)
    }
    None => ()
  }
}

pub fn ffi_start_game(start_id: Int) -> Unit {
  set_current_node(start_id)
}

pub fn set_current_node(id: Int) -> Unit {
  match game_state.nodes.get(id) {
    Some(_) => {
      game_state.current_node_id = id
      // Only push to history if it's the first node or different from the last visited node
      let history_len = game_state.history.length()
      if history_len == 0 {
          game_state.history.push(id)
      } else {
          let last_id = game_state.history[history_len - 1]
          if last_id != id {
              game_state.history.push(id)
          }
      }
    }
    None => ()
  }
}

pub fn get_current_node() -> Option[Node] {
  let node_id = game_state.current_node_id
  game_state.nodes.get(node_id)
}

pub fn escape_json_string(s: String) -> String {
  let mut result = ""
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == '"' {
      result = result + "\\\""
    } else if c == '\\' {
      result = result + "\\\\"
    } else if c == '\n' {
      result = result + "\\n"
    } else if c == '\r' {
      result = result + "\\r"
    } else if c == '\t' {
      result = result + "\\t"
    } else {
      let ch = c.to_int().unsafe_to_char()
      result = result + ch.to_string()
    }
  }
  result
}

pub fn get_current_node_json() -> String {
  match get_current_node() {
    Some(node) => {
      // Manual JSON serialization to avoid external dependencies for now
      let mut json = "{\"id\":" + node.id.to_string() + ","
      // we don't return background_image_url to JS to avoid large strings freezing wasm
      // Wait, UI needs background_image_url! But it's very large (base64).
      // If passing it back causes memory issues, we can just pass the id and let JS look up the bg.
      // But let's try to pass it first.
      json = json + "\"background_image_url\":\"" + escape_json_string(node.background_image_url) + "\","
      json = json + "\"text_content\":\"" + escape_json_string(node.text_content) + "\","
      json = json + "\"choices\":["
      
      for i = 0; i < node.choices.length(); i = i + 1 {
        let choice = node.choices[i]
        if i > 0 {
          json = json + ","
        }
        json = json + "{\"text\":\"" + escape_json_string(choice.text) + "\",\"target_node_id\":" + choice.target_node_id.to_string() + "}"
      }
      
      json + "]}"
    }
    None => "{}"
  }
}

pub fn get_node_id(node: Node) -> Int {
  node.id
}

pub fn get_node_background_url(node: Node) -> String {
  node.background_image_url
}

pub fn get_node_text_content(node: Node) -> String {
  node.text_content
}

pub fn get_choices_count(node: Node) -> Int {
  node.choices.length()
}

pub fn get_choice_text(node: Node, index: Int) -> String {
  if index >= 0 && index < node.choices.length() {
    node.choices[index].text
  } else {
    ""
  }
}

pub fn get_choice_target_id(node: Node, index: Int) -> Int {
  if index >= 0 && index < node.choices.length() {
    node.choices[index].target_node_id
  } else {
    -1
  }
}

pub fn make_choice(target_id: Int) -> Unit {
  set_current_node(target_id)
}

pub fn undo_choice() -> Unit {
  if game_state.history.length() > 1 {
    let _ = game_state.history.pop()
    match game_state.history.last() {
      Some(prev_id) => {
        game_state.current_node_id = prev_id
      }
      None => ()
    }
  }
}

// Memory management for FFI

pub fn ffi_buffer_init() -> Unit {
  game_state.in_chars = []
}

pub fn ffi_buffer_append_char(c: Int) -> Unit {
  game_state.in_chars.push(c.unsafe_to_char())
}

pub fn ffi_buffer_get_string() -> String {
  String::from_array(game_state.in_chars)
}

pub fn moonbit_alloc(size: Int) -> Int {
  0
}

pub fn moonbit_free(ptr: Int) -> Unit {
}

pub fn select_choice(index: Int) -> Unit {
  match get_current_node() {
    Some(node) => {
      if index >= 0 && index < node.choices.length() {
        let target_id = node.choices[index].target_node_id
        set_current_node(target_id)
      }
    }
    None => ()
  }
}

pub fn get_save_data() -> String {
  let history_str = game_state.history.to_string()
  "{\"current_node_id\":\{game_state.current_node_id},\"history\":\{history_str}}"
}

// Helper functions for parsing integers
fn is_digit_byte(b: Byte) -> Bool {
  (b >= b'0') && (b <= b'9')
}

fn byte_to_digit(b: Byte) -> Int {
  b.to_int() - 9
}

fn parse_int(s: String) -> Result[Int, String] {
  if s.length() == 0 {
    return Err("Empty string".to_string())
  }
  let view = s.view()
  let mut result = 0
  let mut i = 0

  while i < view.length() {
    let b = view[i].to_byte()
    if is_digit_byte(b) {
      result = result * 10 + byte_to_digit(b)
    } else {
      return Err("Invalid character in integer string".to_string())
    }
    i = i + 1
  }
  Ok(result)
}

pub fn load_save_data() -> Unit {
  let state_string = ffi_buffer_get_string()
  // This is a simplified parser. A real implementation would need a proper JSON library.
  let parts = state_string.split(",").to_array()
  if parts.length() == 2 {
    let node_part = parts[0]
    let history_part = parts[1]

    let node_id_str = node_part.split(":").to_array()[1]
    let current_node_id = match parse_int(node_id_str.to_string()) {
      Ok(id) => id
      Err(_) => 0
    }

    let history_str = history_part.split("[").to_array()[1].split("]").to_array()[0]
    let history_parts = history_str.split(",").to_array()
    let history = Array::new()
    for part in history_parts {
      let id = match parse_int(part.to_string().trim().to_string()) {
        Ok(id) => id
        Err(_) => 0
      }
      if id != 0 {
        history.push(id)
      }
    }

    game_state.current_node_id = current_node_id
    game_state.history = history
  }
}

pub fn get_history() -> String {
  let mut result = "["
  for i = 0; i < game_state.history.length(); i = i + 1 {
    if i > 0 {
      result = result + ","
    }
    result = result + game_state.history[i].to_string()
  }
  result + "]"
}


// Placeholder for JSON loading (will be implemented with proper JSON parsing)
pub fn load_story_data() -> Unit {
  let _json_string = ffi_buffer_get_string()
  // TODO: Implement JSON parsing when available in Moonbit
  // For now, we'll use a simple demo story
  let node1 = Node::new(1, "images/scene1.png", "You stand at the entrance of a mysterious forest. The trees whisper secrets of ancient times.", [Choice::new("Enter the forest", 2), Choice::new("Turn back", 3)])
  
  let node2 = Node::new(2, "images/forest.png", "The forest envelops you in its emerald embrace. A glowing path leads deeper inside.", [Choice::new("Follow the glowing path", 4), Choice::new("Search for another way", 5)])
  
  let node3 = Node::new(3, "images/exit.png", "You decide to leave the mystery unsolved. Perhaps another day...", [])
  
  let node4 = Node::new(4, "images/deep_forest.png", "You discover a hidden clearing with an ancient shrine.", [Choice::new("Approach the shrine", 6), Choice::new("Return to the entrance", 1)])
  
  let node5 = Node::new(5, "images/side_path.png", "You find a small stream. The water sparkles with an otherworldly light.", [Choice::new("Drink from the stream", 6), Choice::new("Return to the entrance", 1)])
  
  let node6 = Node::new(6, "images/ending.png", "You feel a surge of magical energy. Your journey has only begun...", [])
  
  add_node(node1)
  add_node(node2)
  add_node(node3)
  add_node(node4)
  add_node(node5)
  add_node(node6)
  
  set_current_node(1)
}

// Initialize the story when the module loads
fn init {
  load_story_data()
}
