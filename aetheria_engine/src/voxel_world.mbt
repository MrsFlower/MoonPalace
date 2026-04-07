// 解析 asset.json 产生的 Voxel 数据结构
pub(all) struct Voxel {
  x: Int
  y: Int
  z: Int
  mat_id: Int
} derive(Show, Eq)

pub struct VoxelWorld {
  voxels: Array[Voxel]
}

pub fn VoxelWorld::new() -> VoxelWorld {
  { voxels: [] }
}

// 极其简化的 JSON 解析（实际项目中应使用更健壮的 JSON 库或二进制反序列化）
// 假设 asset.json 的格式为: [{"x": 0, "y": 0, "z": 0, "mat_id": 1}, ...]
pub fn VoxelWorld::load_from_json(json_str: String) -> Result[VoxelWorld, String] {
  let parse_result = @json.parse(json_str) catch {
    _ => return Err("JSON parse error")
  }
  
  let voxels : Array[Voxel] = []
  match parse_result {
    Json::Array(arr) => {
      for item in arr {
        match item {
          Json::Object(map) => {
            let mut vx = 0
            let mut vy = 0
            let mut vz = 0
            let mut vmat = 0
            
            match map.get("x") {
              Some(Json::Number(n, ..)) => { vx = n.to_int() }
              _ => ()
            }
            match map.get("y") {
              Some(Json::Number(n, ..)) => { vy = n.to_int() }
              _ => ()
            }
            match map.get("z") {
              Some(Json::Number(n, ..)) => { vz = n.to_int() }
              _ => ()
            }
            match map.get("mat_id") {
              Some(Json::Number(n, ..)) => { vmat = n.to_int() }
              _ => ()
            }
            
            voxels.push({x: vx, y: vy, z: vz, mat_id: vmat})
          }
          _ => ()
        }
      }
      Ok({ voxels: voxels })
    }
    _ => Err("Root must be an array")
  }
}

// 检查给定的连续浮点坐标 (通常是玩家的 AABB) 是否与任何 Solid 方块碰撞
// 这里我们做一个非常简单的假设：玩家 AABB 是 1x1x1，中心在 (px, py, pz)
pub fn VoxelWorld::check_collision(self: VoxelWorld, px: Double, py: Double, pz: Double) -> Bool {
  let player_size = 0.6
  
  // 检查玩家包围盒周围的几个关键点即可
  // 中心点
  if @raylib.get_voxel_at(px, py, pz) { return true }
  // 脚底点 (稍微比 0.5 多一点，避免在边缘误差导致不断弹跳)
  if @raylib.get_voxel_at(px, py - 0.49, pz) { return true }
  // 头部点
  if @raylib.get_voxel_at(px, py + 0.49, pz) { return true }
  
  // 包围盒 4 个底角
  let half_size = player_size / 2.0
  if @raylib.get_voxel_at(px - half_size, py - 0.49, pz - half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py - 0.49, pz - half_size) { return true }
  if @raylib.get_voxel_at(px - half_size, py - 0.49, pz + half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py - 0.49, pz + half_size) { return true }
  
  // 包围盒 4 个顶角
  if @raylib.get_voxel_at(px - half_size, py + 0.49, pz - half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py + 0.49, pz - half_size) { return true }
  if @raylib.get_voxel_at(px - half_size, py + 0.49, pz + half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py + 0.49, pz + half_size) { return true }
  
  false
}

pub(all) struct UVRect {
  u_min: Double
  v_min: Double
  u_max: Double
  v_max: Double
} derive(Show, Eq)

pub fn parse_materials_json(json_str: String) -> Result[Map[Int, UVRect], String] {
  let parse_result = @json.parse(json_str) catch {
    _ => return Err("JSON parse error")
  }
  
  let map_out = Map::new()
  match parse_result {
    Json::Object(map) => {
      for key, value in map {
        let mat_id = try {
          @strconv.parse_int(key)
        } catch {
          _ => continue
        }
        match value {
          Json::Object(uv_map) => {
            let mut u_min = 0.0
            let mut v_min = 0.0
            let mut u_max = 1.0
            let mut v_max = 1.0
            
            match uv_map.get("u_min") {
              Some(Json::Number(n, ..)) => { u_min = n }
              _ => ()
            }
            match uv_map.get("v_min") {
              Some(Json::Number(n, ..)) => { v_min = n }
              _ => ()
            }
            match uv_map.get("u_max") {
              Some(Json::Number(n, ..)) => { u_max = n }
              _ => ()
            }
            match uv_map.get("v_max") {
              Some(Json::Number(n, ..)) => { v_max = n }
              _ => ()
            }
            
            map_out.set(mat_id, {u_min, v_min, u_max, v_max})
          }
          _ => ()
        }
      }
      Ok(map_out)
    }
    _ => Err("Root must be an object")
  }
}