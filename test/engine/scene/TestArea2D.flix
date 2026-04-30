// Tests for Area2D module

// ========================================================================
// make
// ========================================================================

/// make で生成した Area2D のデフォルト値を検証
@Test
def testArea2DMakeDefaults(): Unit \ Assert =
    let area = Area2D.make({x = 10.0, y = 20.0},
                            CollisionShape2D.RectShape2D({width = 32.0, height = 32.0}));
    let Area2D.Area2D(r) = area;
    Assert.assertEq(expected = (10.0, 20.0, true, true, 0i32),
                     (r#position#x, r#position#y, r#monitoring, r#monitorable, r#priority))

/// make で生成した Area2D の衝突形状
@Test
def testArea2DMakeShape(): Unit \ Assert =
    let shape = CollisionShape2D.CircleShape2D({radius = 16.0});
    let area = Area2D.make(Vec2.zero(), shape);
    match CollisionObject2D.getCollisionShape(area) {
        case Some(CollisionShape2D.CircleShape2D(r)) => Assert.assertEq(expected = 16.0, r#radius)
        case _ => Assert.assertEq(expected = "Some(circle)", "None or wrong shape")
    }

// ========================================================================
// Node2D
// ========================================================================

/// setPosition / getPosition
@Test
def testArea2DPosition(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    let moved = Node2D.setPosition({x = 100.0, y = 200.0}, area);
    let pos = Node2D.getPosition(moved);
    Assert.assertEq(expected = (100.0, 200.0), (pos#x, pos#y))

/// translate
@Test
def testArea2DTranslate(): Unit \ Assert =
    let area = Area2D.make({x = 10.0, y = 10.0},
                            CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    let moved = Node2D.translate({x = 5.0, y = -3.0}, area);
    let pos = Node2D.getPosition(moved);
    Assert.assertEq(expected = (15.0, 7.0), (pos#x, pos#y))

// ========================================================================
// CanvasItem
// ========================================================================

/// setVisible / isVisible
@Test
def testArea2DVisible(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    let hidden = CanvasItem.hide(area);
    Assert.assertEq(expected = false, CanvasItem.isVisible(hidden))

/// setZIndex / getZIndex
@Test
def testArea2DZIndex(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    let updated = CanvasItem.setZIndex(5, area);
    Assert.assertEq(expected = 5, CanvasItem.getZIndex(updated))

// ========================================================================
// CollisionObject2D
// ========================================================================

/// isMonitoring デフォルト = true
@Test
def testArea2DMonitoringDefault(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    Assert.assertEq(expected = true, CollisionObject2D.isMonitoring(area))

/// setMonitoring で false に変更
@Test
def testArea2DSetMonitoring(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}))
                |> Area2D.setMonitoring(false);
    Assert.assertEq(expected = false, CollisionObject2D.isMonitoring(area))

/// isMonitorable デフォルト = true
@Test
def testArea2DMonitorableDefault(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    Assert.assertEq(expected = true, CollisionObject2D.isMonitorable(area))

/// setMonitorable で false に変更
@Test
def testArea2DSetMonitorable(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}))
                |> Area2D.setMonitorable(false);
    Assert.assertEq(expected = false, CollisionObject2D.isMonitorable(area))

/// getCollisionPriority デフォルト = 0
@Test
def testArea2DPriorityDefault(): Unit \ Assert =
    let area = Area2D.make(Vec2.zero(), CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    Assert.assertEq(expected = 0, CollisionObject2D.getCollisionPriority(area))

// ========================================================================
// EngineNode 経由で Scene に配置
// ========================================================================

/// Scene に EngineNode.Area2DWithState として追加して位置を取得できる
@Test
def testArea2DInScene(): Unit \ Assert =
    let area = Area2D.make({x = 50.0, y = 100.0},
                            CollisionShape2D.RectShape2D({width = 32.0, height = 32.0}));
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("hitbox", EngineNode.Area2DWithState(area, ()));
    match Scene.getEngineNode("hitbox" :: Nil, scene) {
        case Some(engineNode) =>
            let pos = Node2D.getPosition(engineNode);
            Assert.assertEq(expected = (50.0, 100.0), (pos#x, pos#y))
        case None => Assert.assertEq(expected = "Some", "None")
    }

/// 親子関係で globalPosition が合算される
@Test
def testArea2DGlobalPosition(): Unit \ Assert =
    let parent = Area2D.make({x = 100.0, y = 100.0},
                              CollisionShape2D.RectShape2D({width = 1.0, height = 1.0}));
    let child = Area2D.make({x = 16.0, y = 20.0},
                             CollisionShape2D.RectShape2D({width = 32.0, height = 24.0}));
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("player", EngineNode.Area2DWithState(parent, ()))
        |> Scene.addChild("player", "hitbox", EngineNode.Area2DWithState(child, ()));
    let gp = Scene.globalPositionAt("player" :: "hitbox" :: Nil, scene);
    Assert.assertEq(expected = (116.0, 120.0), (gp#x, gp#y))
