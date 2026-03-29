// 核心 Raylib C-FFI 绑定
// 为了性能和稳定性，我们将采用 "极薄绑定" 策略。

fn init_window_wrapper(width: Int, height: Int) = "env" "InitWindow_wrapper"
fn window_should_close_wrapper() -> Int = "env" "WindowShouldClose_wrapper"
fn close_window_wrapper() = "env" "CloseWindow_wrapper"
fn set_target_fps_wrapper(fps: Int) = "env" "SetTargetFPS_wrapper"
fn begin_drawing_wrapper() = "env" "BeginDrawing_wrapper"
fn end_drawing_wrapper() = "env" "EndDrawing_wrapper"
fn clear_background_wrapper(r: Int, g: Int, b: Int, a: Int) = "env" "ClearBackground_wrapper"
fn draw_text_wrapper(x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) = "env" "DrawText_wrapper"

pub fn init_window(width: Int, height: Int, _title: String) -> Unit {
  init_window_wrapper(width, height)
}

pub fn window_should_close() -> Bool {
  window_should_close_wrapper() != 0
}

pub fn close_window() -> Unit {
  close_window_wrapper()
}

pub fn set_target_fps(fps: Int) -> Unit {
  set_target_fps_wrapper(fps)
}

pub fn begin_drawing() -> Unit {
  begin_drawing_wrapper()
}

pub fn end_drawing() -> Unit {
  end_drawing_wrapper()
}

pub fn clear_background(r: Int, g: Int, b: Int, a: Int) -> Unit {
  clear_background_wrapper(r, g, b, a)
}

pub fn draw_text(_text: String, x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) -> Unit {
  draw_text_wrapper(x, y, fontSize, r, g, b, a)
}
