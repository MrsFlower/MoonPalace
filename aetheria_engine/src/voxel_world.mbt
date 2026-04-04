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
  let player_size = 0.8 // 稍微小于 1.0，留点冗余防止卡墙
  
  for v in self.voxels {
    // 基础的 AABB 碰撞检测
    // 方块的中心点假设在其坐标的 (x+0.5, y+0.5, z+0.5) 或者就是其本身（取决于渲染锚点）
    // 为了简单，假设方块锚点在左下角 (v.x, v.y, v.z)，尺寸 1x1x1
    let vx_min = v.x.to_double() - 0.5
    let vx_max = v.x.to_double() + 0.5
    let vy_min = v.y.to_double() - 0.5
    let vy_max = v.y.to_double() + 0.5
    let vz_min = v.z.to_double() - 0.5
    let vz_max = v.z.to_double() + 0.5
    
    let px_min = px - player_size / 2.0
    let px_max = px + player_size / 2.0
    let py_min = py - player_size / 2.0
    let py_max = py + player_size / 2.0
    let pz_min = pz - player_size / 2.0
    let pz_max = pz + player_size / 2.0
    
    let overlap_x = px_min < vx_max && px_max > vx_min
    let overlap_y = py_min < vy_max && py_max > vy_min
    let overlap_z = pz_min < vz_max && pz_max > vz_min
    
    if overlap_x && overlap_y && overlap_z {
      return true // 发生碰撞
    }
  }
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