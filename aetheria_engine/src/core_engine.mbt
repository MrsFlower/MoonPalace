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
}

pub fn Engine::new() -> Engine {
  { state: Init, frame_count: 0 }
}

pub fn Engine::update(self : Engine) -> Unit {
  self.frame_count = self.frame_count + 1
  
  // 简单的状态流转测试
  if self.frame_count > 60 && self.state == Init {
    self.state = Loading
  } else if self.frame_count > 120 && self.state == Loading {
    self.state = Roam
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
