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
}

pub fn Engine::new() -> Engine {
  { 
    state: Roam, // 跳过 Init 和 Loading，直接进入 Roam 模式测试控制
    frame_count: 0,
    ui: UIManager::new(),
    player_pos: { x: 0.0, y: 0.5, z: 0.0 }
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

    // AABB 碰撞检测 (Player: 1x1x1 at next_pos, Target: 1x1x1 at 6.0, 0.5, 0.0)
    let target_x = 6.0
    let target_z = 0.0
    let size = 1.0

    // 检查是否在 X 轴和 Z 轴上重叠
    let dx = next_x - target_x
    let dz = next_z - target_z
    let abs_dx = if dx < 0.0 { -dx } else { dx }
    let abs_dz = if dz < 0.0 { -dz } else { dz }
    
    let hit_x = abs_dx < size
    let hit_z = abs_dz < size

    if hit_x && hit_z {
      // 发生碰撞，不更新位置，并触发对话框
      self.state = Dialog
      self.ui.show_dialog("You found a hidden item!")
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

