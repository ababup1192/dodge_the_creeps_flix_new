// Tests for PhysicsBody2D trait

// ========================================================================
// getLinearVelocity / setLinearVelocity — CharacterBody2D
// ========================================================================

/// CharacterBody2D の速度を PhysicsBody2D trait 経由で取得できる
@Test
def testPhysicsBody2DGetLinearVelocityCharacterBody2D(): Unit \ Assert =
    let body = CharacterBody2D.make({x = 0.0, y = 0.0}, moveSpeed = 100.0)
        |> CharacterBody2D.setVelocity({x = 30.0, y = 40.0});
    let vel = PhysicsBody2D.getLinearVelocity(body);
    Assert.assertEq(expected = (30.0, 40.0), (vel#x, vel#y))

/// CharacterBody2D の速度を PhysicsBody2D trait 経由で設定できる
@Test
def testPhysicsBody2DSetLinearVelocityCharacterBody2D(): Unit \ Assert =
    let body = CharacterBody2D.make({x = 0.0, y = 0.0}, moveSpeed = 100.0)
        |> PhysicsBody2D.setLinearVelocity({x = 50.0, y = -10.0});
    let vel = CharacterBody2D.getVelocity(body);
    Assert.assertEq(expected = (50.0, -10.0), (vel#x, vel#y))

// ========================================================================
// getLinearVelocity / setLinearVelocity — RigidBody2D
// ========================================================================

/// RigidBody2D の速度を PhysicsBody2D trait 経由で取得できる
@Test
def testPhysicsBody2DGetLinearVelocityRigidBody2D(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setLinearVelocity({x = 100.0, y = 200.0});
    let vel = PhysicsBody2D.getLinearVelocity(body);
    Assert.assertEq(expected = (100.0, 200.0), (vel#x, vel#y))

/// RigidBody2D の速度を PhysicsBody2D trait 経由で設定できる
@Test
def testPhysicsBody2DSetLinearVelocityRigidBody2D(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> PhysicsBody2D.setLinearVelocity({x = -50.0, y = 75.0});
    let vel = RigidBody2D.getLinearVelocity(body);
    Assert.assertEq(expected = (-50.0, 75.0), (vel#x, vel#y))

// ========================================================================
// moveAndCollide — デフォルト実装（位置更新のみ）
// ========================================================================

/// CharacterBody2D を moveAndCollide でモーション分だけ移動できる
@Test
def testPhysicsBody2DMoveAndCollideCharacterBody2D(): Unit \ Assert =
    let body = CharacterBody2D.make({x = 10.0, y = 20.0}, moveSpeed = 100.0)
        |> PhysicsBody2D.moveAndCollide({x = 5.0, y = -3.0});
    let pos = Node2D.getPosition(body);
    Assert.assertEq(expected = (15.0, 17.0), (pos#x, pos#y))

/// RigidBody2D を moveAndCollide でモーション分だけ移動できる
@Test
def testPhysicsBody2DMoveAndCollideRigidBody2D(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 100.0, y = 200.0}, shape)
        |> PhysicsBody2D.moveAndCollide({x = -30.0, y = 50.0});
    let pos = Node2D.getPosition(body);
    Assert.assertEq(expected = (70.0, 250.0), (pos#x, pos#y))

/// ゼロモーションでは位置が変わらない
@Test
def testPhysicsBody2DMoveAndCollideZeroMotion(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 42.0, y = 99.0}, shape)
        |> PhysicsBody2D.moveAndCollide(Vec2.zero());
    let pos = Node2D.getPosition(body);
    Assert.assertEq(expected = (42.0, 99.0), (pos#x, pos#y))

// ========================================================================
// trait の統一性 — 両方の型が同じ trait を通じて操作できる
// ========================================================================

/// PhysicsBody2D trait は CharacterBody2D と RigidBody2D で一貫した速度設定ができる
@Test
def testPhysicsBody2DUnifiedVelocityInterface(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 5.0});
    let charBody = CharacterBody2D.make({x = 0.0, y = 0.0}, moveSpeed = 100.0)
        |> PhysicsBody2D.setLinearVelocity({x = 10.0, y = 20.0});
    let rigidBody = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> PhysicsBody2D.setLinearVelocity({x = 10.0, y = 20.0});
    let charVel = PhysicsBody2D.getLinearVelocity(charBody);
    let rigidVel = PhysicsBody2D.getLinearVelocity(rigidBody);
    Assert.assertEq(expected = (charVel#x, charVel#y), (rigidVel#x, rigidVel#y))
