// Tests for MobScene — Mob の生成・落下・画面外削除

// ========================================================================
// spawnMob: Mob 生成
// ========================================================================

/// spawnMob でシーンに RigidBody2D ノードが追加される
@Test
def testMobSceneSpawnMobAddsNode(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0});
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// spawnMob で追加された Mob の状態が MobData である
@Test
def testMobSceneSpawnMobState(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0});
    match Scene.getState("mob_0" :: Nil, scene) {
        case Some(GameData.MobData) => Assert.assertTrue(true)
        case _ => bug!("Expected MobData")
    }

/// spawnMob で Mob の位置が指定座標に設定される
@Test
def testMobSceneSpawnMobPosition(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 100.0, y = -50.0});
    let pos = Scene.globalPosition("mob_0", scene);
    Assert.assertEq(expected = (100.0, -50.0), (pos#x, pos#y))

/// spawnMob で Sprite2D 子ノードが追加される
@Test
def testMobSceneSpawnMobHasSpriteChild(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0});
    match Scene.getState("mob_0" :: "sprite" :: Nil, scene) {
        case Some(GameData.MobSprite) => Assert.assertTrue(true)
        case _ => bug!("Expected MobSprite child")
    }

/// spawnMob で生成された Mob は RigidBody2D である（重力で落下する）
@Test
def testMobSceneSpawnMobIsRigidBody(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0});
    match Scene.getEngineNode("mob_0" :: Nil, scene) {
        case Some(EngineNode.RigidBody2DWithState(_, _)) => Assert.assertTrue(true)
        case _ => bug!("Expected RigidBody2DWithState")
    }

// ========================================================================
// 重力による落下（PhysicsStep 統合）
// ========================================================================

/// PhysicsStep.integrate で Mob が下方向に移動する
///
///   初期位置: (240, -50)
///   重力: (0, 980)
///   delta: 0.5秒
///
///   速度: 0 + 980 * 0.5 = 490
///   位置: -50 + 490 * 0.5 = 195
///
@Test
def testMobSceneFallsWithGravity(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0})
        |> PhysicsStep.integrate(0.5, PhysicsStep.defaultGravity());
    let pos = Scene.globalPosition("mob_0", scene);
    Assert.assertEq(expected = (240.0, 195.0), (pos#x, pos#y))

// ========================================================================
// removeOffScreenMobs: 画面下部から出た Mob の削除
// ========================================================================

/// 画面内の Mob は削除されない
@Test
def testMobSceneKeepOnScreenMob(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0})
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 画面上部にいるスポーン直後の Mob は削除されない
///
///   Y = -50 → 画面上部にいるが、まだ落下中なので保持する
///
@Test
def testMobSceneKeepSpawnedMobAboveScreen(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0})
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 画面下部より下に落ちた Mob は削除される
///
///   画面高さ: 720px、Mob サイズ: 64x64（半分 = 32）
///   Y = 800 → Mob 上端 = 800 - 32 = 768 > 720 → 削除
///
@Test
def testMobSceneRemoveBelowScreenMob(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 800.0})
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 画面下端ギリギリの Mob は削除されない
///
///   Y = 750 → Mob 上端 = 750 - 32 = 718 < 720 → 保持
///
@Test
def testMobSceneKeepMobNearBottomEdge(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 750.0})
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 複数の Mob のうち画面下部から出たものだけ削除される
@Test
def testMobSceneRemoveOnlyBelowScreenMobs(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 100.0, y = 300.0})
        |> MobScene.spawnMob("mob_1", {x = 200.0, y = 900.0})
        |> MobScene.spawnMob("mob_2", {x = 300.0, y = 500.0})
        |> MobScene.removeOffScreenMobs;
    let mob0Exists = not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene));
    let mob1Exists = not Option.isEmpty(Scene.getEngineNode("mob_1" :: Nil, scene));
    let mob2Exists = not Option.isEmpty(Scene.getEngineNode("mob_2" :: Nil, scene));
    // mob_0 (y=300) と mob_2 (y=500) は画面内、mob_1 (y=900) は画面下部外
    Assert.assertEq(expected = (true, false, true), (mob0Exists, mob1Exists, mob2Exists))

/// Mob 削除時にスプライト子ノードも一緒に削除される
@Test
def testMobSceneRemoveAlsoRemovesChildren(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 900.0})
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: "sprite" :: Nil, scene)))

// ========================================================================
// maybeSpawnMob: タイマーベースのスポーン
// ========================================================================

/// タイマーが残っている間は Mob が生成されない
@Test
def testMobSceneMaybeSpawnMobWaits(): Unit \ Assert =
    let state: GameState = {
        scene = Scene.empty(),
        mobSpawnTimer = 1.0,
        mobCounter = 0
    };
    let updated = MobScene.maybeSpawnMob(0.5, state);
    // タイマーが 0.5 減る、まだ生成されない
    Assert.assertEq(expected = (0.5, 0), (updated#mobSpawnTimer, updated#mobCounter))

/// タイマーが 0 以下になったら Mob が生成される
@Test
def testMobSceneMaybeSpawnMobSpawns(): Unit \ Assert =
    let state: GameState = {
        scene = Scene.empty(),
        mobSpawnTimer = 0.5,
        mobCounter = 0
    };
    let updated = MobScene.maybeSpawnMob(1.0, state);
    // Mob が生成され、カウンタが増え、タイマーがリセットされる
    let mobExists = not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, updated#scene));
    Assert.assertEq(expected = (true, 1), (mobExists, updated#mobCounter))

/// 連続スポーンで異なる名前の Mob が生成される
@Test
def testMobSceneMaybeSpawnMobUniqueName(): Unit \ Assert =
    let state: GameState = {
        scene = Scene.empty(),
        mobSpawnTimer = 0.0,
        mobCounter = 0
    };
    let after1 = MobScene.maybeSpawnMob(0.1, state);
    let after2 = MobScene.maybeSpawnMob(2.0, after1);
    let mob0Exists = not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, after2#scene));
    let mob1Exists = not Option.isEmpty(Scene.getEngineNode("mob_1" :: Nil, after2#scene));
    Assert.assertEq(expected = (true, true, 2), (mob0Exists, mob1Exists, after2#mobCounter))

// ========================================================================
// 統合: 重力落下 → 画面外削除
// ========================================================================

/// Mob が重力で落下し、画面下部から出たら削除される
///
///   画面高さ: 720px
///   重力: (0, 980)
///   初期位置: (240, 600)
///
///   1秒後: 速度 = 980, 位置 = 600 + 980 = 1580 → 画面下部外
///
@Test
def testMobSceneIntegrationFallAndRemove(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 600.0})
        |> PhysicsStep.integrate(1.0, PhysicsStep.defaultGravity())
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// Mob が落下中でもまだ画面内なら削除されない
///
///   初期位置: (240, -50)
///   0.5秒後: 位置 = 195 → 画面内 → 保持
///
@Test
def testMobSceneIntegrationFallButStillOnScreen(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0})
        |> PhysicsStep.integrate(0.5, PhysicsStep.defaultGravity())
        |> MobScene.removeOffScreenMobs;
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))
