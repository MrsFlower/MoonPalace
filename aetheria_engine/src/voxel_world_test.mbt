test "VoxelWorld parse JSON" {
  println("Running parse JSON test")
  let mock_json = "[{\"x\":1,\"y\":2,\"z\":3,\"mat_id\":42}]"
  match VoxelWorld::load_from_json(mock_json) {
    Ok(world) => {
      println("Parsed successfully")
      assert_eq(world.voxels.length(), 1)
      assert_eq(world.voxels[0].x, 1)
      assert_eq(world.voxels[0].y, 2)
      assert_eq(world.voxels[0].z, 3)
      assert_eq(world.voxels[0].mat_id, 42)
    }
    Err(_) => fail("Failed to parse mock JSON")
  }
}

test "VoxelWorld collision detection" {
  println("Running collision detection test")
  let world = VoxelWorld::new()
  world.voxels.push({ x: 5, y: 0, z: 5, mat_id: 1 })
  
  // 没有碰撞
  assert_false(world.check_collision(0.0, 0.0, 0.0))
  
  // 发生碰撞 (假设方块在 5,0,5, 玩家在 4.8,0.2,4.8 会碰到)
  assert_true(world.check_collision(4.8, 0.2, 4.8))
  
  // 边界外
  assert_false(world.check_collision(4.0, 0.0, 4.0))
}