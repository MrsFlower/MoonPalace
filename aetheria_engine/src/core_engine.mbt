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
  mut player_velocity_y : Double
  mut is_grounded : Bool
  world : VoxelWorld
  materials : Map[Int, UVRect]
  chunk_count : Int
}

pub fn Engine::new() -> Engine {
  // Load JSON data
  let mut world = VoxelWorld::new()
  let mut materials = Map::new()
  
  // Try to load chunk files until we can't find more
  // (In a real game, we'd read a directory or an index file, here we just try a range)
  // 我们已经通过 python 脚本将 64 个 chunk 合并为了 1 个包含多个 mesh 的单一优化 glb 文件。
  // 这大大加快了读取和上传显存的速度。
  let chunk_count = 1
  
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
    // 初始位置设置在非常高的空中，确保玩家不会在生成时卡在建筑物里
    player_pos: { x: 0.0, y: 50.0, z: 0.0 }, 
    player_velocity_y: 0.0,
    is_grounded: false,
    world,
    materials,
    chunk_count
  }
}

pub fn Engine::get_chunk_count(self: Engine) -> Int {
  self.chunk_count
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
    // 因为 main 循环里的 update_camera 和 cursor disable 会在同一帧发生，
    // GetMouseDelta() 在 DisableCursor 被调用前后的行为在某些操作系统上有不可预测的跳变。
    // 我们强制丢弃第一帧（甚至前两帧）的 Delta，因为在按下左键的瞬间，操作系统的光标可能会回中。
    if not(@raylib.is_mouse_button_pressed(0)) {
      let dx = @raylib.get_mouse_delta_x()
      let dy = @raylib.get_mouse_delta_y()
      
      // 修正：鼠标位移(dx/dy)本身就是基于物理时间的增量，
      // 如果再乘以 dt(帧时间)，会导致帧率越高，灵敏度呈指数级爆炸。
      // 因此直接使用一个基础的绝对灵敏度常量即可。
      let mouse_sensitivity = 0.005 
      
      // 如果 dx 或 dy 异常大（比如超过 100 像素），这绝对是操作系统的重置跳变，不是人类手滑，直接忽略
      if dx < 100.0 && dx > -100.0 && dy < 100.0 && dy > -100.0 {
        self.player_yaw -= dx * mouse_sensitivity
        self.player_pitch -= dy * mouse_sensitivity
        
        // 限制 pitch 角度防止翻转 (-89 to 89 degrees)
        let pi_half = 1.5533
        if self.player_pitch > pi_half { self.player_pitch = pi_half }
        if self.player_pitch < -pi_half { self.player_pitch = -pi_half }
      }
    } else {
      // 第一帧被按下，直接清空当前的 Delta，防止下一帧累积
      let _discard_x = @raylib.get_mouse_delta_x()
      let _discard_y = @raylib.get_mouse_delta_y()
    }
    
    // IMPORTANT: Raylib's GetMouseDelta() depends on DisableCursor to work correctly without hitting screen edges.
    // However, since we just use it raw, moving the mouse to the screen edge stops Delta.
    // If we use HideCursor instead of DisableCursor, the Delta is bounded by the screen resolution.
  } else {
    // 【关键修复】：如果鼠标没有被按下，我们必须消耗掉 (清空) 这一帧的鼠标增量，
    // 否则操作系统的光标移动累积的 Delta 会在下一次按下左键或者引擎内部其他地方被意外读取，导致瞬间的跳动/抽动。
    let _discard_x = @raylib.get_mouse_delta_x()
    let _discard_y = @raylib.get_mouse_delta_y()
  }

  self.ui.update()
  
  // 仅在漫游状态下允许移动
  if self.state == Roam && self.camera_mode == 0 {
    let speed = 0.1
    let dt = 1.0 / 60.0 // 固定时间步长（简化的物理引擎）
    let gravity = -9.8
    let jump_force = 4.5
    
    // 跳跃
    if @raylib.is_key_pressed(@raylib.key_space) && self.is_grounded {
      self.player_velocity_y = jump_force
      self.is_grounded = false
    }
    
    // 应用重力
    self.player_velocity_y += gravity * dt
    
    // 先计算 Y 轴（垂直方向）的移动和碰撞
    let next_y = self.player_pos.y + self.player_velocity_y * dt
    
    // Y 轴碰撞检测
    if self.world.check_collision(self.player_pos.x, next_y, self.player_pos.z) {
      if self.player_velocity_y < 0.0 {
        // 落地
        self.is_grounded = true
        // 对齐到地面的体素表面
        self.player_pos = { x: self.player_pos.x, y: @math.floor(self.player_pos.y) + 0.5, z: self.player_pos.z }
      } else {
        // 头顶撞到天花板
        self.player_pos = { x: self.player_pos.x, y: @math.ceil(self.player_pos.y) - 0.5, z: self.player_pos.z }
      }
      self.player_velocity_y = 0.0
    } else {
      // 在空中
      self.player_pos = { x: self.player_pos.x, y: next_y, z: self.player_pos.z }
      self.is_grounded = false
    }
    
    // 然后计算 X/Z 轴（水平方向）的移动
    if input_x != 0.0 || input_z != 0.0 {
      let forward_x = -@math.sin(self.player_yaw)
      let forward_z = -@math.cos(self.player_yaw)
      
      let right_x = @math.cos(self.player_yaw)
      let right_z = -@math.sin(self.player_yaw)
      
      let move_x = (right_x * input_x + forward_x * input_z) * speed
      let move_z = (right_z * input_x + forward_z * input_z) * speed
      
      // 分别在 X 和 Z 方向做碰撞检测 (Slide along walls)
      let next_x = self.player_pos.x + move_x
      if not(self.world.check_collision(next_x, self.player_pos.y, self.player_pos.z)) {
        self.player_pos = { x: next_x, y: self.player_pos.y, z: self.player_pos.z }
      }
      
      let next_z = self.player_pos.z + move_z
      if not(self.world.check_collision(self.player_pos.x, self.player_pos.y, next_z)) {
        self.player_pos = { x: self.player_pos.x, y: self.player_pos.y, z: next_z }
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

