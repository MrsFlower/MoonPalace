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
  mut frame_count : Int
  ui : UIManager
  player_pos : Vector3
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
    frame_count: 0,
    ui: UIManager::new(),
    player_pos: { x: 0.0, y: 1.0, z: 0.0 },
    world,
    materials
  }
}

// target_x/y/z 用于做简单的碰撞检测
pub fn Engine::update(self : Engine, input_x: Double, input_z: Double) -> Unit {
  self.frame_count = self.frame_count + 1
  self.ui.update()
  
  // 仅在漫游状态下允许移动
  if self.state == Roam {
    // 简单的速度
    let speed = 0.1
    let next_x = self.player_pos.x + input_x * speed
    let next_z = self.player_pos.z + input_z * speed

    // 碰撞检测
    if self.world.check_collision(next_x, self.player_pos.y, next_z) {
      // 发生碰撞，不更新位置
      // 如果发生碰撞且目标材质是特殊的（例如我们模拟一个宝箱在 mat_id = 3），可以触发对话
      // 这里做一个简化的假设：假设所有方块都是固体，只有靠近特定坐标才会弹窗
      if (next_x - 6.0)*(next_x - 6.0) + (next_z - 0.0)*(next_z - 0.0) < 1.0 {
        self.state = Dialog
        self.ui.show_dialog("You bumped into a special voxel!")
      }
    } else {
      // 未发生碰撞，更新位置
      self.player_pos.x = next_x
      self.player_pos.z = next_z
    }
  }

  // 处于对话状态时，检查输入以恢复漫游
  if self.state == Dialog {
     // 用特殊的标记来让外部告诉引擎 "关闭对话框" 
     // 简单起见：如果按下反向键或者其他动作，这里我们假设输入不为 0 时尝试跳出
     // 实际中可能需要专门的 'action' 键
  }
}

pub fn Engine::dismiss_dialog(self: Engine) -> Unit {
  if self.state == Dialog {
    self.state = Roam
    self.ui.hide_dialog()
    // 稍微把玩家推开一点防止死锁
    self.player_pos.x = self.player_pos.x - 0.5
  }
}

pub fn Engine::get_state_string(self : Engine) -> String {
  match self.state {
    Init => "State: INIT"
    Loading => "State: LOADING"
    Roam => "State: ROAM (Use W/A/S/D to move)"
    Dialog => "State: DIALOG (Press SPACE to close)"
  }
}

