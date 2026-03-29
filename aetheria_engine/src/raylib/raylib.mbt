// 核心 Raylib C-FFI 绑定
// 为了性能和稳定性，我们将采用 "极薄绑定" 策略。

extern "C" fn init_window_wrapper(width: Int, height: Int) = "InitWindow_wrapper"
extern "C" fn window_should_close_wrapper() -> Int = "WindowShouldClose_wrapper"
extern "C" fn close_window_wrapper() = "CloseWindow_wrapper"
extern "C" fn set_target_fps_wrapper(fps: Int) = "SetTargetFPS_wrapper"
extern "C" fn begin_drawing_wrapper() = "BeginDrawing_wrapper"
extern "C" fn end_drawing_wrapper() = "EndDrawing_wrapper"
extern "C" fn clear_background_wrapper(r: Int, g: Int, b: Int, a: Int) = "ClearBackground_wrapper"

// 键盘输入
extern "C" fn is_key_down_wrapper(key: Int) -> Int = "IsKeyDown_wrapper"
extern "C" fn is_key_pressed_wrapper(key: Int) -> Int = "IsKeyPressed_wrapper"

// 安全传递字符串的 C-FFI 辅助函数
extern "C" fn clear_text_buffer() = "clear_text_buffer"
extern "C" fn append_text_char(c: Int) = "append_text_char"
extern "C" fn draw_text_from_buffer(x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) = "draw_text_from_buffer"

// 3D 渲染支持
extern "C" fn begin_mode_3d_wrapper(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) = "BeginMode3D_wrapper"
extern "C" fn end_mode_3d_wrapper() = "EndMode3D_wrapper"
extern "C" fn draw_cube_wrapper(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) = "DrawCube_wrapper"
extern "C" fn draw_cube_wires_wrapper(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) = "DrawCubeWires_wrapper"
extern "C" fn draw_grid_wrapper(slices: Int, spacing: Double) = "DrawGrid_wrapper"
extern "C" fn draw_fps_wrapper(x: Int, y: Int) = "DrawFPS_wrapper"

// Raylib 键盘常量 (部分)
pub let key_w: Int = 87
pub let key_a: Int = 65
pub let key_s: Int = 83
pub let key_d: Int = 68
pub let key_up: Int = 265
pub let key_down: Int = 264
pub let key_left: Int = 263
pub let key_right: Int = 262
pub let key_space: Int = 32

pub fn init_window(width: Int, height: Int, title: String) -> Unit {
  clear_text_buffer()
  let bytes = title.to_bytes()
  for i in 0..<bytes.length() {
    append_text_char(bytes[i].to_int())
  }
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

pub fn is_key_down(key: Int) -> Bool {
  is_key_down_wrapper(key) != 0
}

pub fn is_key_pressed(key: Int) -> Bool {
  is_key_pressed_wrapper(key) != 0
}

pub fn draw_text(text: String, x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) -> Unit {
  clear_text_buffer()
  let bytes = text.to_bytes()
  for i in 0..<bytes.length() {
    append_text_char(bytes[i].to_int())
  }
  draw_text_from_buffer(x, y, fontSize, r, g, b, a)
}

pub fn draw_fps(x: Int, y: Int) -> Unit {
  draw_fps_wrapper(x, y)
}

pub fn begin_mode_3d(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) -> Unit {
  begin_mode_3d_wrapper(cam_px, cam_py, cam_pz, tar_x, tar_y, tar_z, up_x, up_y, up_z, fovy)
}

pub fn end_mode_3d() -> Unit {
  end_mode_3d_wrapper()
}

pub fn draw_cube(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) -> Unit {
  draw_cube_wrapper(x, y, z, w, h, l, r, g, b, a)
}

pub fn draw_cube_wires(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) -> Unit {
  draw_cube_wires_wrapper(x, y, z, w, h, l, r, g, b, a)
}

pub fn draw_grid(slices: Int, spacing: Double) -> Unit {
  draw_grid_wrapper(slices, spacing)
}

