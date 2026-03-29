// 基础的 AABB 物理碰撞检测模块

// 检查两个 AABB 是否相交
pub fn check_collision_aabb(a: AABB, b: AABB) -> Bool {
  let overlap_x = a.max.x > b.min.x && a.min.x < b.max.x
  let overlap_y = a.max.y > b.min.y && a.min.y < b.max.y
  let overlap_z = a.max.z > b.min.z && a.min.z < b.max.z
  
  overlap_x && overlap_y && overlap_z
}

// 检查点是否在 AABB 内
pub fn check_point_in_aabb(p: Vector3, box: AABB) -> Bool {
  p.x >= box.min.x && p.x <= box.max.x &&
  p.y >= box.min.y && p.y <= box.max.y &&
  p.z >= box.min.z && p.z <= box.max.z
}

// 简单的物理引擎状态
pub struct PhysicsEngine {
  colliders : Array[AABB]
}

pub fn PhysicsEngine::new(colliders: Array[AABB]) -> PhysicsEngine {
  { colliders: colliders }
}

// 尝试移动一个对象（比如玩家），返回是否发生碰撞
pub fn PhysicsEngine::try_move(self: PhysicsEngine, player_box: AABB, velocity: Vector3) -> Bool {
  let next_box: AABB = {
    id: player_box.id,
    min: { x: player_box.min.x + velocity.x, y: player_box.min.y + velocity.y, z: player_box.min.z + velocity.z },
    max: { x: player_box.max.x + velocity.x, y: player_box.max.y + velocity.y, z: player_box.max.z + velocity.z }
  }
  
  for collider in self.colliders {
    if check_collision_aabb(next_box, collider) {
      return true // 发生碰撞
    }
  }
  false // 可以移动
}
