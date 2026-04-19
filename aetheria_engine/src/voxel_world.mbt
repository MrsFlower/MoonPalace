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

/// 检查玩家包围盒与体素网格的碰撞
/// - 采用 O(1) 的体素坐标反向查找算法 (`get_voxel_at`)
/// - 分离了水平(墙壁)与垂直(地板)碰撞，避免了重力弹跳 (Jitter)
pub fn VoxelWorld::check_collision(self: VoxelWorld, px: Double, py: Double, pz: Double) -> Bool {
  let player_size = 0.6
  
  // 中心点
  if @raylib.get_voxel_at(px, py, pz) { return true }
  
  // 玩家包围盒半径 (宽度 0.6) -> half_size = 0.3
  let half_size = player_size / 2.0
  
  // 头部点检测
  if @raylib.get_voxel_at(px, py + 0.4, pz) { return true }
  
  // 【脚底检测】：如果我们需要把脚底作为墙壁碰撞箱，应该留出非常微小的安全距离 (如 0.499)，
  // 而不要用 0.5 导致刚好越界进入下方方块的判定区
  if @raylib.get_voxel_at(px, py - 0.499, pz) { return true }
  
  // 检查底角 (防卡死，留出 Epsilon)
  if @raylib.get_voxel_at(px - half_size, py - 0.499, pz - half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py - 0.499, pz - half_size) { return true }
  if @raylib.get_voxel_at(px - half_size, py - 0.499, pz + half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, py - 0.499, pz + half_size) { return true }
  
  // 检查水平身体防卡墙
  // 仅使用膝盖与胸部位置进行 X/Z 轴碰撞检测，避免地表微小起伏导致卡墙反弹
  let knee_y = py - 0.3
  if @raylib.get_voxel_at(px - half_size, knee_y, pz - half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, knee_y, pz - half_size) { return true }
  if @raylib.get_voxel_at(px - half_size, knee_y, pz + half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, knee_y, pz + half_size) { return true }
  
  let chest_y = py + 0.2
  if @raylib.get_voxel_at(px - half_size, chest_y, pz - half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, chest_y, pz - half_size) { return true }
  if @raylib.get_voxel_at(px - half_size, chest_y, pz + half_size) { return true }
  if @raylib.get_voxel_at(px + half_size, chest_y, pz + half_size) { return true }
  
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