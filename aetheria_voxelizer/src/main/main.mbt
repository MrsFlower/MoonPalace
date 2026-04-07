struct Vector2 {
  u : Double
  v : Double
} derive(Show, Default)

struct Vector3 {
  x : Double
  y : Double
  z : Double
} derive(Show, Default)

struct Triangle {
  v0 : Vector3
  v1 : Vector3
  v2 : Vector3
} derive(Show)

struct Mesh {
  vertices : Array[Vector3]
  uvs : Array[Vector2]
  indices : Array[Int]
} derive(Show)

struct VoxelGrid {
  width : Int
  height : Int
  depth : Int
  voxel_size : Double
  data : Array[Int] // 1D array representing 3D space
}

// 帮助函数：计算网格的包围盒 (Bounding Box)
fn Mesh::get_bounds(self : Mesh) -> (Vector3, Vector3) {
  let mut min_x = 999999.0
  let mut min_y = 999999.0
  let mut min_z = 999999.0
  let mut max_x = -999999.0
  let mut max_y = -999999.0
  let mut max_z = -999999.0

  for v in self.vertices {
    if v.x < min_x { min_x = v.x }
    if v.y < min_y { min_y = v.y }
    if v.z < min_z { min_z = v.z }
    if v.x > max_x { max_x = v.x }
    if v.y > max_y { max_y = v.y }
    if v.z > max_z { max_z = v.z }
  }
  ({ x: min_x, y: min_y, z: min_z }, { x: max_x, y: max_y, z: max_z })
}

// 核心逻辑 1：根据输入的物理尺寸 (Target Physical Size) 对网格进行缩放
fn scale_mesh_to_physical_size(mesh : Mesh, target_x : Double, target_y : Double, target_z : Double) -> Mesh {
  let (min_pt, max_pt) = mesh.get_bounds()
  let current_x = max_pt.x - min_pt.x
  let current_y = max_pt.y - min_pt.y
  let current_z = max_pt.z - min_pt.z

  // 计算每个轴的缩放比例（如果原始轴长度为 0 则不缩放）
  let scale_x = if current_x > 0.0 { target_x / current_x } else { 1.0 }
  let scale_y = if current_y > 0.0 { target_y / current_y } else { 1.0 }
  let scale_z = if current_z > 0.0 { target_z / current_z } else { 1.0 }

  println("[Voxelizer] Scale Factors: X=\{scale_x}, Y=\{scale_y}, Z=\{scale_z}")

  let scaled_vertices = Array::new(capacity=mesh.vertices.length())
  for v in mesh.vertices {
    // 将模型移动到原点并缩放
    scaled_vertices.push({
      x: (v.x - min_pt.x) * scale_x,
      y: (v.y - min_pt.y) * scale_y,
      z: (v.z - min_pt.z) * scale_z
    })
  }

  { vertices: scaled_vertices, uvs: mesh.uvs, indices: mesh.indices }
}

// 辅助：获取 1D 数组的 3D 索引
fn VoxelGrid::index(self : VoxelGrid, x : Int, y : Int, z : Int) -> Int {
  x + y * self.width + z * self.width * self.height
}

fn VoxelGrid::set(self : VoxelGrid, x : Int, y : Int, z : Int, val : Int) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height && z >= 0 && z < self.depth {
    self.data[self.index(x, y, z)] = val
  }
}

fn VoxelGrid::get(self : VoxelGrid, x : Int, y : Int, z : Int) -> Int {
  if x >= 0 && x < self.width && y >= 0 && y < self.height && z >= 0 && z < self.depth {
    self.data[self.index(x, y, z)]
  } else {
    0
  }
}

// Helper functions for min/max
fn min_d(a: Double, b: Double) -> Double { if a < b { a } else { b } }
fn max_d(a: Double, b: Double) -> Double { if a > b { a } else { b } }

// 核心逻辑 2：纯 Moonbit 的网格表面体素化 (Surface Voxelization)
// 我们采用包围盒扫描 + 简化的三角形距离检测
fn voxelize_mesh(mesh : Mesh, voxel_size : Double) -> VoxelGrid {
  let (min_pt, max_pt) = mesh.get_bounds()
  
  // 计算体素网格的维度
  let width = @math.ceil((max_pt.x - min_pt.x) / voxel_size).to_int() + 1
  let height = @math.ceil((max_pt.y - min_pt.y) / voxel_size).to_int() + 1
  let depth = @math.ceil((max_pt.z - min_pt.z) / voxel_size).to_int() + 1

  println("[Voxelizer] Creating Grid: \{width} x \{height} x \{depth} (Voxel Size: \{voxel_size}m)")
  
  let total_voxels = width * height * depth
  let grid_data = Array::make(total_voxels, 0)
  let grid = { width, height, depth, voxel_size, data: grid_data }

  // 遍历所有三角形进行体素化
  let num_triangles = mesh.indices.length() / 3
  for i = 0; i < num_triangles; i = i + 1 {
    let v0 = mesh.vertices[mesh.indices[i * 3]]
    let v1 = mesh.vertices[mesh.indices[i * 3 + 1]]
    let v2 = mesh.vertices[mesh.indices[i * 3 + 2]]

    // 1. 获取三角形的包围盒
    let t_min_x = min_d(min_d(v0.x, v1.x), v2.x)
    let t_min_y = min_d(min_d(v0.y, v1.y), v2.y)
    let t_min_z = min_d(min_d(v0.z, v1.z), v2.z)
    
    let t_max_x = max_d(max_d(v0.x, v1.x), v2.x)
    let t_max_y = max_d(max_d(v0.y, v1.y), v2.y)
    let t_max_z = max_d(max_d(v0.z, v1.z), v2.z)

    // 2. 将包围盒转换为体素坐标索引
    let min_vx = max_d(0.0, @math.floor(t_min_x / voxel_size)).to_int()
    let min_vy = max_d(0.0, @math.floor(t_min_y / voxel_size)).to_int()
    let min_vz = max_d(0.0, @math.floor(t_min_z / voxel_size)).to_int()
    
    let max_vx = min_d((width - 1).to_double(), @math.ceil(t_max_x / voxel_size)).to_int()
    let max_vy = min_d((height - 1).to_double(), @math.ceil(t_max_y / voxel_size)).to_int()
    let max_vz = min_d((depth - 1).to_double(), @math.ceil(t_max_z / voxel_size)).to_int()

    // 3. 遍历包围盒内的每一个体素，进行相交测试（此处原型使用包围盒填充近似替代精确 SAT 算法）
    for vx = min_vx; vx <= max_vx; vx = vx + 1 {
      for vy = min_vy; vy <= max_vy; vy = vy + 1 {
        for vz = min_vz; vz <= max_vz; vz = vz + 1 {
          // 这里可以加入精确的 AABB-Triangle 相交测试 (Separating Axis Theorem)
          // 作为原型，我们暂时将三角形 Bounding Box 覆盖的所有体素标记为该三角形的 ID (i + 1)
          grid.set(vx, vy, vz, i + 1)
        }
      }
    }
  }

  // 统计生成的体素数量
  let mut solid_count = 0
  for v in grid.data {
    if v != 0 { solid_count += 1 }
  }
  println("[Voxelizer] Finished! Solid Voxels: \{solid_count} / \{total_voxels}")

  grid
}

fn generate_mock_pyramid(voxel_size: Double) -> VoxelGrid {
  let width = 64
  let height = 32
  let depth = 64
  
  let total_voxels = width * height * depth
  let grid_data = Array::make(total_voxels, 0)
  let grid = { width, height, depth, voxel_size, data: grid_data }
  
  // Generate a stepped pyramid
  let cx = width / 2
  let cz = depth / 2
  
  for y = 0; y < height; y = y + 1 {
    let radius = height - y - 1 // radius decreases as y increases
    if radius < 0 { continue }
    
    for x = cx - radius; x <= cx + radius; x = x + 1 {
      for z = cz - radius; z <= cz + radius; z = z + 1 {
        grid.set(x, y, z, 1)
      }
    }
  }
  
  println("[Mock] Generated Pyramid: \{width}x\{height}x\{depth}")
  grid
}

fn main {
  println("--- Aetheria Voxelizer Prototype ---")
  
  println("\nGenerating Mock Pyramid data for engine rendering test...")
  let mock_grid = generate_mock_pyramid(0.5)
  export_chunk(mock_grid, None, "mock_pyramid.chunk")
  println("Exported mock_pyramid.chunk successfully!")

  let glb_file = parse_glb_file("../aetheria_engine/assets/optimized_plaza.glb")
  match glb_file {
    Some(glb) => {
      println("GLB parsed successfully!")
      println("JSON string length: \{glb.json_string.length()}")
      
      let mesh_opt = extract_mesh(glb)
      match mesh_opt {
        Some(raw_mesh) => {
          println("\n1. Raw Mesh Bounds:")
          let (min, max) = raw_mesh.get_bounds()
          println("Min: \{min}, Max: \{max}")
          
          println("\n2. Scaling to Physical Size (80m x 30m x 80m)...")
          let scaled_mesh = scale_mesh_to_physical_size(raw_mesh, 80.0, 30.0, 80.0)
          
          println("\n3. Voxelizing with 0.5m resolution...")
          let grid = voxelize_mesh(scaled_mesh, 0.5)
          
          println("\n4. Exporting to plaza.chunk...")
          export_chunk(grid, Some(scaled_mesh), "plaza.chunk")
          println("Export complete!")
        }
        None => println("Failed to extract mesh from GLB")
      }
    }
    None => {
      println("Failed to parse GLB")
    }
  }
}