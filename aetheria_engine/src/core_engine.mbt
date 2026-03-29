// 引擎核心状态与主循环管理
// 我们将游戏状态机与渲染管线分离

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
    state: Init, 
    frame_count: 0,
    ui: UIManager::new(),
    player_pos: { x: 0.0, y: 5.0, z: 0.0 }
  }
}

pub fn Engine::update(self : Engine) -> Unit {
  self.frame_count = self.frame_count + 1
  self.ui.update()
  
  // 简单的状态流转测试与 UI 联动
  if self.frame_count == 60 && self.state == Init {
    self.state = Loading
    self.ui.toggle_debug() // 开启 Debug 面板
  } else if self.frame_count == 120 && self.state == Loading {
    self.state = Roam
  } else if self.frame_count == 180 && self.state == Roam {
    self.state = Dialog
    self.ui.show_dialog("You found a hidden item!")
  } else if self.frame_count == 240 && self.state == Dialog {
    self.state = Roam
    self.ui.hide_dialog()
  }
  
  // 模拟玩家移动
  if self.state == Roam {
    self.player_pos.x = self.player_pos.x + 0.1
  }
}

pub fn Engine::get_state_string(self : Engine) -> String {
  match self.state {
    Init => "State: INIT"
    Loading => "State: LOADING"
    Roam => "State: ROAM (Mock 3D Scene)"
    Dialog => "State: DIALOG"
  }
}

// 模拟渲染循环的输出
pub fn Engine::render(self : Engine) -> String {
  let mut output = "--- FRAME \{self.frame_count} ---\n"
  
  // 增加更直观的可视化字符画
  let pos_x = self.player_pos.x.to_int()
  let mut visual_scene = ""
  for i in 0..<20 {
    if i == pos_x {
      visual_scene = visual_scene + "🕺" // 玩家
    } else if i == 6 {
      visual_scene = visual_scene + "📦" // 隐藏物品
    } else {
      visual_scene = visual_scene + "_" // 地板
    }
  }
  
  output = output + "3D Scene Rendered:\n"
  output = output + "[ " + visual_scene + " ]\n"
  output = output + self.ui.render_mock(self.player_pos, 60, self.get_state_string())
  output + "\n-------------------\n"
}
