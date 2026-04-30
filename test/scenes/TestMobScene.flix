// Tests for MobScene — Mob の生成・直線移動・画面外削除

// ========================================================================
// spawnMob: Mob 生成
// ========================================================================

/// spawnMob でシーンに RigidBody2D ノードが追加される
@Test
def testMobSceneSpawnMobAddsNode(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// spawnMob で追加された Mob の状態が MobData である
@Test
def testMobSceneSpawnMobState(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    match Scene.getState("mob_0" :: Nil, scene) {
        case Some(GameData.MobData(_)) => Assert.assertTrue(true)
        case _ => bug!("Expected MobData")
    }

/// spawnMob で Mob の位置が指定座標に設定される
@Test
def testMobSceneSpawnMobPosition(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 100.0, y = -50.0}, 0);
    let pos = Scene.globalPosition("mob_0", scene);
    Assert.assertEq(expected = (100.0, -50.0), (pos#x, pos#y))

/// spawnMob で AnimatedSprite2D 子ノードが追加される
@Test
def testMobSceneSpawnMobHasSpriteChild(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    match Scene.getState("mob_0" :: "sprite" :: Nil, scene) {
        case Some(GameData.MobSprite) => Assert.assertTrue(true)
        case _ => bug!("Expected MobSprite child")
    }

/// spawnMob で生成された Mob は RigidBody2D である
@Test
def testMobSceneSpawnMobIsRigidBody(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    match Scene.getEngineNode("mob_0" :: Nil, scene) {
        case Some(EngineNode.RigidBody2DWithState(_, _)) => Assert.assertTrue(true)
        case _ => bug!("Expected RigidBody2DWithState")
    }

/// spawnMob で ScreenNotifier2D 子ノードが追加される
@Test
def testMobSceneSpawnMobHasNotifierChild(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    match Scene.getEngineNode("mob_0" :: "notifier" :: Nil, scene) {
        case Some(EngineNode.ScreenNotifier2DWithState(_, GameData.MobNotifier)) =>
            Assert.assertTrue(true)
        case _ => bug!("Expected ScreenNotifier2DWithState child with MobNotifier")
    }

/// spawnMob で Mob が "mobs" グループに追加される
@Test
def testMobSceneSpawnMobInGroup(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0);
    let paths = Scene.getNodesInGroup(MobScene.mobGroup(), scene);
    Assert.assertEq(expected = ("mob_0" :: Nil) :: Nil, paths)

// ========================================================================
// gravity_scale = 0: 重力無効（Godot mob.tscn 準拠）
// ========================================================================

/// gravity_scale = 0 の Mob は重力で移動しない
///
///   初期位置: (240, -50)
///   重力: (0, 980)
///   delta: 0.5秒
///
///   gravity_scale = 0 のため位置は変化しない
///
@Test
def testMobSceneGravityDisabled(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0)
        |> PhysicsStep.integrate(0.5, PhysicsStep.defaultGravity());
    let pos = Scene.globalPosition("mob_0", scene);
    Assert.assertEq(expected = (240.0, -50.0), (pos#x, pos#y))

// ========================================================================
// ready: アニメーション選択（ランダム — Godot pick_random 準拠）
// ========================================================================

/// ready でアニメーション（fly/swim/walk）のいずれかが設定される
@Test
def testMobSceneReadyPicksValidAnimation(): Unit \ {Assert, Math.Random} =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0)
        |> MobScene.ready("mob_0" :: Nil, 1.5708);
    match Scene.getEngineNode("mob_0" :: "sprite" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            let anim = AnimatedSprite2D.getCurrentAnimation(sprite);
            Assert.assertTrue(anim == "fly" or anim == "swim" or anim == "walk")
        case _ => bug!("Expected AnimSprite2DWithState")
    }

// ========================================================================
// Path2D.sample: パスサンプリング
// ========================================================================

/// t=0 で上辺左端 (0, 0)
@Test
def testPath2DSampleTopLeft(): Unit \ Assert =
    let path = Path2D.screenEdgePath(480, 720);
    let r = Path2D.sample(0.0, path);
    Assert.assertEq(expected = (0.0, 0.0), (r#position#x, r#position#y))

/// t=0.25 で右辺上端 (480, 0)
@Test
def testPath2DSampleTopRight(): Unit \ Assert =
    let path = Path2D.screenEdgePath(480, 720);
    let r = Path2D.sample(0.25, path);
    Assert.assertEq(expected = (480.0, 0.0), (r#position#x, r#position#y))

/// t=0.5 で下辺右端 (480, 720)
@Test
def testPath2DSampleBottomRight(): Unit \ Assert =
    let path = Path2D.screenEdgePath(480, 720);
    let r = Path2D.sample(0.5, path);
    Assert.assertEq(expected = (480.0, 720.0), (r#position#x, r#position#y))

/// t=0.75 で左辺下端 (0, 720)
@Test
def testPath2DSampleBottomLeft(): Unit \ Assert =
    let path = Path2D.screenEdgePath(480, 720);
    let r = Path2D.sample(0.75, path);
    Assert.assertEq(expected = (0.0, 720.0), (r#position#x, r#position#y))

// ========================================================================
// ScreenNotifyHandler による画面外 Mob 削除
// ========================================================================

/// 画面内の Mob は削除されない
@Test
def testMobSceneKeepOnScreenMob(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0}, 0)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 画面上部にいるスポーン直後の Mob は削除されない（prevOnScreen 未登録）
///
///   Y = -50 → isOnScreen = false だが prevOnScreen にないので発火しない
///
@Test
def testMobSceneKeepSpawnedMobAboveScreen(): Unit \ Assert =
    let scene = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = -50.0}, 0)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene)))

/// 画面内→画面外で Mob が削除される（screen_exited 相当）
///
///   フレーム1: Y = 360 → 画面内 → prevOnScreen に登録
///   フレーム2: Y = 800 → 画面外 → onScreenExited 発火 → 削除
///
@Test
def testMobSceneRemoveExitedMob(): Unit \ Assert =
    // フレーム1: 画面内
    let scene1 = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0}, 0)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    // フレーム2: 画面外に移動
    let scene2 = Scene.setGlobalPosition("mob_0", {x = 240.0, y = 800.0}, scene1)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene2)))

/// Mob 削除時にスプライト子ノードも一緒に削除される
@Test
def testMobSceneRemoveAlsoRemovesChildren(): Unit \ Assert =
    let scene1 = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0}, 0)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    let scene2 = Scene.setGlobalPosition("mob_0", {x = 240.0, y = 800.0}, scene1)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: "sprite" :: Nil, scene2)))

/// 複数の Mob のうち画面外に出たものだけ削除される
@Test
def testMobSceneRemoveOnlyExitedMobs(): Unit \ Assert =
    // フレーム1: 全 Mob 画面内
    let scene1 = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 100.0, y = 300.0}, 0)
        |> MobScene.spawnMob("mob_1", {x = 200.0, y = 400.0}, 1)
        |> MobScene.spawnMob("mob_2", {x = 300.0, y = 500.0}, 2)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    // フレーム2: mob_1 だけ画面外に移動
    let scene2 = Scene.setGlobalPosition("mob_1", {x = 200.0, y = 900.0}, scene1)
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    let mob0Exists = not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene2));
    let mob1Exists = not Option.isEmpty(Scene.getEngineNode("mob_1" :: Nil, scene2));
    let mob2Exists = not Option.isEmpty(Scene.getEngineNode("mob_2" :: Nil, scene2));
    Assert.assertEq(expected = (true, false, true), (mob0Exists, mob1Exists, mob2Exists))

// ========================================================================
// 統合: 線形速度による移動 → ScreenNotifyHandler による画面外削除
// ========================================================================

/// Mob が線形速度で移動し、画面外に出たら削除される
///
///   画面高さ: 720px、線形速度: (0, 980)
///   初期位置: (240, 360) → 画面内
///
///   1秒後: 位置 = 360 + 980 = 1340 → 画面外
///
@Test
def testMobSceneIntegrationMoveAndRemove(): Unit \ Assert =
    // フレーム1: 画面内 → prevOnScreen に登録
    let scene1 = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0}, 0)
        |> Scene.mapEngineNode("mob_0" :: Nil,
            EngineNode.mapRigidBody2D(RigidBody2D.setLinearVelocity({x = 0.0, y = 980.0})))
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    // フレーム2: 線形速度で画面外まで移動 → 削除
    let scene2 = scene1
        |> PhysicsStep.integrate(1.0, PhysicsStep.defaultGravity())
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene2)))

/// Mob が移動中でもまだ画面内なら削除されない
///
///   初期位置: (240, 360)
///   線形速度: (0, 100)
///   0.1秒後: 位置 = 360 + 100*0.1 = 370 → 画面内 → 保持
///
@Test
def testMobSceneIntegrationMoveButStillOnScreen(): Unit \ Assert =
    // フレーム1: 画面内
    let scene1 = Scene.empty()
        |> MobScene.spawnMob("mob_0", {x = 240.0, y = 360.0}, 0)
        |> Scene.mapEngineNode("mob_0" :: Nil,
            EngineNode.mapRigidBody2D(RigidBody2D.setLinearVelocity({x = 0.0, y = 100.0})))
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    // フレーム2: 少しだけ移動 → まだ画面内
    let scene2 = scene1
        |> PhysicsStep.integrate(0.1, PhysicsStep.defaultGravity())
        |> ScreenNotifyEvent.handleScreenNotify(
            screenWidth = 480, screenHeight = 720);
    Assert.assertTrue(not Option.isEmpty(Scene.getEngineNode("mob_0" :: Nil, scene2)))
