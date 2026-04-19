test "AABB collision detection" {
  let box1: AABB = { id: "1", min: { x: 0.0, y: 0.0, z: 0.0 }, max: { x: 2.0, y: 2.0, z: 2.0 } }
  let box2: AABB = { id: "2", min: { x: 1.0, y: 1.0, z: 1.0 }, max: { x: 3.0, y: 3.0, z: 3.0 } }
  let box3: AABB = { id: "3", min: { x: 3.0, y: 3.0, z: 3.0 }, max: { x: 5.0, y: 5.0, z: 5.0 } }
  
  // 相交测试
  assert_eq(check_collision_aabb(box1, box2), true) |> ignore
  // 不相交测试
  assert_eq(check_collision_aabb(box1, box3), false) |> ignore
}

test "PhysicsEngine try_move" {
  let ground: AABB = { id: "ground", min: { x: -10.0, y: -1.0, z: -10.0 }, max: { x: 10.0, y: 0.0, z: 10.0 } }
  let wall: AABB = { id: "wall", min: { x: 5.0, y: 0.0, z: -5.0 }, max: { x: 6.0, y: 5.0, z: 5.0 } }
  
  let physics = PhysicsEngine::new([ground, wall])
  
  let player: AABB = { id: "player", min: { x: 0.0, y: 0.0, z: 0.0 }, max: { x: 1.0, y: 2.0, z: 1.0 } }
  
  // 往右走，不撞墙
  let move_right: Vector3 = { x: 1.0, y: 0.0, z: 0.0 }
  assert_eq(physics.try_move(player, move_right), false) |> ignore
  
  // 往右走很多，撞墙
  let move_far_right: Vector3 = { x: 5.0, y: 0.0, z: 0.0 }
  assert_eq(physics.try_move(player, move_far_right), true) |> ignore
  
  // 往下掉，撞地板
  let fall_down: Vector3 = { x: 0.0, y: -0.5, z: 0.0 }
  assert_eq(physics.try_move(player, fall_down), true) |> ignore
}
