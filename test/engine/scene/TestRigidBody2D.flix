// Tests for RigidBody2D module

// ========================================================================
// make
// ========================================================================

/// make で生成した RigidBody2D のデフォルト値を確認する
@Test
def testRigidBody2DMakeDefaults(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 100.0, y = 200.0}, shape);
    let pos = Node2D.getPosition(body);
    Assert.assertEq(expected = (100.0, 200.0, true, 0, 1.0, 1.0, 0.0, 0.0),
        (pos#x, pos#y,
         CanvasItem.isVisible(body),
         CanvasItem.getZIndex(body),
         RigidBody2D.getGravityScale(body),
         RigidBody2D.getMass(body),
         RigidBody2D.getBounce(body),
         RigidBody2D.getLinearDamp(body)))

/// make の monitorable デフォルトは true
@Test
def testRigidBody2DMakeMonitorable(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape);
    Assert.assertEq(expected = (false, true),
        (CollisionObject2D.isMonitoring(body), CollisionObject2D.isMonitorable(body)))

// ========================================================================
// linearVelocity
// ========================================================================

/// 線形速度の設定と取得
@Test
def testRigidBody2DLinearVelocity(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setLinearVelocity({x = 100.0, y = -50.0});
    let vel = RigidBody2D.getLinearVelocity(body);
    Assert.assertEq(expected = (100.0, -50.0), (vel#x, vel#y))

// ========================================================================
// angularVelocity
// ========================================================================

/// 角速度の設定と取得
@Test
def testRigidBody2DAngularVelocity(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setAngularVelocity(3.14);
    Assert.assertEq(expected = 3.14, RigidBody2D.getAngularVelocity(body))

// ========================================================================
// gravityScale
// ========================================================================

/// 重力倍率の設定と取得
@Test
def testRigidBody2DGravityScale(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setGravityScale(0.5);
    Assert.assertEq(expected = 0.5, RigidBody2D.getGravityScale(body))

// ========================================================================
// mass
// ========================================================================

/// 質量の設定と取得
@Test
def testRigidBody2DMass(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setMass(5.0);
    Assert.assertEq(expected = 5.0, RigidBody2D.getMass(body))

// ========================================================================
// bounce
// ========================================================================

/// 反発係数の設定と取得
@Test
def testRigidBody2DBounce(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setBounce(0.8);
    Assert.assertEq(expected = 0.8, RigidBody2D.getBounce(body))

// ========================================================================
// damping
// ========================================================================

/// 線形ダンピングの設定と取得
@Test
def testRigidBody2DLinearDamp(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setLinearDamp(2.0);
    Assert.assertEq(expected = 2.0, RigidBody2D.getLinearDamp(body))

/// 角ダンピングの設定と取得
@Test
def testRigidBody2DAngularDamp(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setAngularDamp(1.5);
    Assert.assertEq(expected = 1.5, RigidBody2D.getAngularDamp(body))

// ========================================================================
// Node2D trait
// ========================================================================

/// Node2D の位置設定が正しく動作する
@Test
def testRigidBody2DNode2DPosition(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> Node2D.setPosition({x = 50.0, y = 75.0});
    let pos = Node2D.getPosition(body);
    Assert.assertEq(expected = (50.0, 75.0), (pos#x, pos#y))

/// Node2D の回転設定が正しく動作す���
@Test
def testRigidBody2DNode2DRotation(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> Node2D.setRotation(1.57);
    Assert.assertEq(expected = 1.57, Node2D.getRotation(body))

// ========================================================================
// CollisionObject2D trait
// ========================================================================

/// CollisionObject2D の衝突形状が正しく取得できる
@Test
def testRigidBody2DCollisionShape(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 15.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape);
    let result = not Option.isEmpty(CollisionObject2D.getCollisionShape(body));
    Assert.assertEq(expected = true, result)

/// CollisionObject2D の priority 設定
@Test
def testRigidBody2DPriority(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> RigidBody2D.setPriority(5);
    Assert.assertEq(expected = 5, CollisionObject2D.getCollisionPriority(body))

// ========================================================================
// CanvasItem trait
// ========================================================================

/// CanvasItem の可視性の切り替え
@Test
def testRigidBody2DCanvasItemVisibility(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 10.0});
    let body = RigidBody2D.make({x = 0.0, y = 0.0}, shape)
        |> CanvasItem.hide;
    Assert.assertEq(expected = false, CanvasItem.isVisible(body))
