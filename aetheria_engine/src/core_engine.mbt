// 引擎核心状态与主循环管理
// 我们将游戏状态机与渲染管线分离
// 依赖外部输入进行真实交互

pub(all) enum GameState {
  Init
  Loading
  Roam
  Dialog
} derive(Eq, Show)

pub struct Engine {
  mut state : GameState
  mut camera_mode : Int
  ui : UIManager
  mut player_yaw : Double
  mut player_pitch : Double
  mut player_pos : Vector3
  world : VoxelWorld
  materials : Map[Int, UVRect]
}

pub fn Engine::new() -> Engine {
  // Load JSON data
  let mut world = VoxelWorld::new()
  let mut materials = Map::new()
  
  let asset_json = try {
    @fs.read_file_to_string("assets/asset.json")
  } catch {
    _ => "[]"
  }
  
  match VoxelWorld::load_from_json(asset_json) {
    Ok(w) => world = w
    Err(e) => println("Error loading asset.json: \{e}")
  }
  
  let materials_json = try {
    @fs.read_file_to_string("assets/materials.json")
  } catch {
    _ => "{}"
  }
  
  match parse_materials_json(materials_json) {
    Ok(m) => materials = m
    Err(e) => println("Error loading materials.json: \{e}")
  }

  { 
    state: Roam, // 跳过 Init 和 Loading，直接进入 Roam 模式测试控制
    camera_mode: 0, // 0 = default (custom), 1 = free
    ui: UIManager::new(),
    player_yaw: 0.0,
    player_pitch: 0.0,
    player_pos: { x: 0.0, y: 1.0, z: 0.0 },
    world,
    materials
  }
}

// target_x/y/z 用于做简单的碰撞检测
pub fn Engine::update(self: Engine, input_x: Double, input_z: Double) -> Unit {
  // Toggle camera mode with Right Mouse Button
  if @raylib.is_mouse_button_pressed(1) { // 1 = right mouse button
    if self.camera_mode == 0 {
      self.camera_mode = 1 // Enable Free Camera
      @raylib.disable_cursor()
    } else {
      self.camera_mode = 0 // Disable Free Camera
      @raylib.enable_cursor()
    }
  }

  // If in free camera mode, don't update player position with WASD
  if self.camera_mode == 1 {
    let (cx, cy, cz) = @raylib.get_camera_position()
    self.player_pos = { x: cx, y: cy - 0.5, z: cz } // Adjust for camera height
    self.ui.update()
    return
  }
  
  if @raylib.is_mouse_button_down(0) { // 0 = left mouse button
    // 鼠标按住左键拖动，更新 yaw 和 pitch
    let dx = @raylib.get_mouse_delta_x()
    let dy = @raylib.get_mouse_delta_y()
    
    self.player_yaw -= dx * 0.001
    self.player_pitch -= dy * 0.001
    
    // 限制 pitch 角度防止翻转 (-89 to 89 degrees)
    let pi_half = 1.5533
    if self.player_pitch > pi_half { self.player_pitch = pi_half }
    if self.player_pitch < -pi_half { self.player_pitch = -pi_half }
  }

  self.ui.update()
  
  // 仅在漫游状态下允许移动
  if self.state == Roam && self.camera_mode == 0 {
    let speed = 0.1
    
    // 如果没有输入，就不计算移动
    if input_x != 0.0 || input_z != 0.0 {
      let forward_x = -@math.sin(self.player_yaw)
      let forward_z = -@math.cos(self.player_yaw)
      
      let right_x = @math.cos(self.player_yaw)
      let right_z = -@math.sin(self.player_yaw)
      
      let move_x = (right_x * input_x + forward_x * input_z) * speed
      let move_z = (right_z * input_x + forward_z * input_z) * speed
      
      let next_x = self.player_pos.x + move_x
      let next_z = self.player_pos.z + move_z
  
      // 碰撞检测
      if self.world.check_collision(next_x, self.player_pos.y, next_z) {
        if (next_x - 6.0)*(next_x - 6.0) + (next_z - 0.0)*(next_z - 0.0) < 1.0 {
          self.state = Dialog
          self.ui.show_dialog("You bumped into a special voxel!")
        }
      } else {
        self.player_pos = { x: next_x, y: self.player_pos.y, z: next_z }
      }
    }
  }

  // 处于对话状态时，检查输入以恢复漫游
  if self.state == Dialog {
  }
}

pub fn Engine::dismiss_dialog(self: Engine) -> Unit {
  if self.state == Dialog {
    self.state = Roam
    self.ui.hide_dialog()
    // 稍微把玩家推开一点防止死锁
    self.player_pos = { x: self.player_pos.x - 0.5, y: self.player_pos.y, z: self.player_pos.z }
  }
}

pub fn Engine::set_player_pos(self: Engine, x: Double, y: Double, z: Double) -> Unit {
  self.player_pos = { x, y, z }
}

pub fn Engine::get_player_pos_x(self: Engine) -> Double { self.player_pos.x }
pub fn Engine::get_player_pos_y(self: Engine) -> Double { self.player_pos.y }
pub fn Engine::get_player_pos_z(self: Engine) -> Double { self.player_pos.z }
pub fn Engine::get_player_yaw(self: Engine) -> Double { self.player_yaw }
pub fn Engine::get_player_pitch(self: Engine) -> Double { self.player_pitch }

pub fn Engine::get_camera_mode(self: Engine) -> Int {
  self.camera_mode
}

pub fn Engine::get_state_string(self : Engine) -> String {
  match self.state {
    Init => "State: INIT"
    Loading => "State: LOADING"
    Roam => "State: ROAM (Use W/A/S/D to move)"
    Dialog => "State: DIALOG (Press SPACE to close)"
  }
}

