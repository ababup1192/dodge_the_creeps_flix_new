// Tests for Frogger Game module

// ========================================================================
// テスト用ヘルパー
// ========================================================================

def withMockEngine(f: Unit -> a \ ef + Engine.Game): a \ ef =
    run f() with handler Engine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016f32)
        def isKeyPressed(_, k) = k(false)
        def getFontAtlas(_, k) = k(testFontAtlas())
    }

/// テスト用のダミー FontAtlas（空のグリフマップ）
def testFontAtlas(): FontAtlas = {
    textureName = "font_test",
    fontSize = 32.0f32,
    textureSize = 512.0f32,
    glyphs = Map.empty()
}

/// テスト用ヘルパー: buildState のシーンを取得
def testScene(): Scene[GameData] = Game.buildState(testFontAtlas())#scene

/// テスト用ヘルパー: buildState を取得
def testState(): GameState = Game.buildState(testFontAtlas())

// ========================================================================
// buildState: ノード数・構造
// ========================================================================

/// ノード合計
///   背景5 + ホーム5(+sprites=10) + プレイヤー1(+Sprite+Hitbox=3)
///   + 車両15(+sprite=30) + 丸太12(+sprites=46) + 亀5(+sprites=22)
///   + timerLabel1 + livesLabel1 = 118
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 118, Scene.nodeCount(testScene()))

/// ルートノード = 背景5 + ホーム5 + プレイヤー1 + 車両15 + 丸太12 + 亀5
///   + timerLabel1 + livesLabel1 = 45
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 45, Map.size(Scene.states(testScene())))

// ========================================================================
// buildState: プレイヤー構成 (CharacterBody2D + AnimatedSprite2D + Hitbox)
// ========================================================================

/// プレイヤーの初期位置が (384, 832)
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", testScene());
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// プレイヤー（CharacterBody2D）は不可視（描画は子スプライトが担当）
@Test
def testPlayerIsInvisible(): Unit \ Assert =
    match Scene.getEngineNode("player" :: Nil, testScene()) {
        case Some(engineNode) => Assert.assertFalse(CanvasItem.isVisible(engineNode))
        case None => bug!("player not found")
    }

/// プレイヤーの子は Sprite と Hitbox の 2 つ
@Test
def testPlayerChildrenCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 2,
        List.length(Scene.getChildren("player", testScene())))

/// Sprite 子ノードは AnimatedSprite2D で、idle アニメーションの最初のフレームは FroggerIdle
@Test
def testPlayerSpriteAnimation(): Unit \ Assert =
    match Scene.getEngineNode("player" :: "Sprite" :: Nil, testScene()) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(
                expected = ("idle", "FroggerIdle"),
                (AnimatedSprite2D.getCurrentAnimation(sprite),
                 AnimatedSprite2D.currentTexture(sprite)))
        case _ => bug!("player Sprite not found")
    }

/// Hitbox 子ノードは Area2D で、monitoring=true（Vehicle と衝突検出）
@Test
def testPlayerHitboxMonitoring(): Unit \ Assert =
    match Scene.getEngineNode("player" :: "Hitbox" :: Nil, testScene()) {
        case Some(engineNode) => Assert.assertTrue(CollisionObject2D.isMonitoring(engineNode))
        case None => bug!("player Hitbox not found")
    }

// ========================================================================
// buildState: 背景ゾーン配置
// ========================================================================

/// 水ゾーン背景の位置が (0, 64)
@Test
def testBgWaterPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgWater", testScene());
    Assert.assertEq(expected = (0.0f32, 64.0f32), (pos#x, pos#y))

/// 道路ゾーン背景の位置が (0, 512)
@Test
def testBgRoadPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgRoad", testScene());
    Assert.assertEq(expected = (0.0f32, 512.0f32), (pos#x, pos#y))

/// 中央分離帯背景の位置が (0, 448)
@Test
def testBgMedianPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgMedian", testScene());
    Assert.assertEq(expected = (0.0f32, 448.0f32), (pos#x, pos#y))

// ========================================================================
// buildState: 車両配置
// ========================================================================

/// レーン0の最初の車両が Y=512 に配置される
@Test
def testVehicleLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_0", testScene());
    Assert.assertEq(expected = 512.0f32, pos#y)

/// レーン0の2台目の車両は spacing=100 で 164px 先
///   startX = 1 * (64 + 100) = 164
@Test
def testVehicleLane0SecondPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_1", testScene());
    Assert.assertEq(expected = (164.0f32, 512.0f32), (pos#x, pos#y))

// ========================================================================
// buildState: 丸太配置
// ========================================================================

/// レーン0の最初の丸太が Y=64 に配置される
@Test
def testLogLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("l0_0", testScene());
    Assert.assertEq(expected = 64.0f32, pos#y)

/// レーン0の丸太は middles=1 なので 3 つの子スプライト（LogStart + LogMiddle + LogEnd）
@Test
def testLogLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("l0_0", testScene())))

/// 丸太のプラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testLogNotMonitoring(): Unit \ Assert =
    match Scene.getEngineNode("l0_0" :: Nil, testScene()) {
        case Some(engineNode) =>
            Assert.assertEq(
                expected = (false, false),
                (CollisionObject2D.isMonitoring(engineNode), CollisionObject2D.isMonitorable(engineNode)))
        case None => bug!("log l0_0 not found")
    }

// ========================================================================
// Player process: ターゲットへの移動
// ========================================================================

/// Vec2 を比較可能なタプルに変換するヘルパー
def vecToTuple(v: Vec2.Vec2): (Float32, Float32) = (v#x, v#y)

/// process でプレイヤーが target に向かって移動する
///   moveSpeed=512, dt=0.1 → 51.2px 移動。832-51.2=780.8
@Test
def testPlayerProcessMovesTowardTarget(): Unit \ Assert =
    let scene = testScene();
    // ターゲットを上に設定
    let scene1 = Scene.mapState("player" :: Nil, state -> match state {
        case GameData.PlayerData(r) =>
            GameData.PlayerData({target = {x = 384.0f32, y = 768.0f32} | r})
        case other => other
    }, scene);
    let processed = Scene.processAll(0.1, false, scene1);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 780.8f32), vecToTuple(pos))

/// ターゲットが現在位置と同じ場合、移動しない
@Test
def testPlayerProcessStaysAtTarget(): Unit \ Assert =
    let scene = testScene();
    let processed = Scene.processAll(0.1, false, scene);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 832.0f32), vecToTuple(pos))

// ========================================================================
// AnimatedSprite2D process: フレーム進行
// ========================================================================

/// fps=4 で 0.3 秒後（frameDuration=0.25 超過）にフレームが 1 に進む
@Test
def testAnimSpriteAdvancesFrame(): Unit \ Assert =
    let scene = testScene();
    let processed = Scene.processAll(0.3, false, scene);
    match Scene.getEngineNode("player" :: "Sprite" :: Nil, processed) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "FroggerLeap", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player Sprite not found after process")
    }

// ========================================================================
// Vehicle process: 移動とラップ
// ========================================================================

/// Vehicle が process で vx * dt 分移動する
@Test
def testVehicleProcessMoves(): Unit \ Assert =
    let scene = testScene();
    let origPos = Scene.globalPosition("v0_0", scene);
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("v0_0", processed);
    Assert.assertEq(
        expected = (origPos#x - 20.0f32, origPos#y),
        (newPos#x, newPos#y))

/// Vehicle が画面左端を超えたら右端にラップする
@Test
def testVehicleWrapsLeft(): Unit \ Assert =
    let scene = testScene()
        |> Scene.setGlobalPosition("v0_0", {x = -99.0f32, y = 512.0f32});
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("v0_0", processed);
    Assert.assertEq(expected = Game.screenW() + 100.0f32, newPos#x)

// ========================================================================
// LogPlatform process: 移動とラップ
// ========================================================================

/// LogPlatform が process で vx * dt 分移動する
@Test
def testLogProcessMoves(): Unit \ Assert =
    let scene = testScene();
    let origPos = Scene.globalPosition("l0_0", scene);
    // Lane 0: vx=120, dt=0.1 → +12px
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("l0_0", processed);
    Assert.assertEq(
        expected = (origPos#x + 12.0f32, origPos#y),
        (newPos#x, newPos#y))

// ========================================================================
// buildState: 亀配置
// ========================================================================

/// 亀レーン0の最初のグループが Y=320 に配置される
@Test
def testTurtleLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("t0_0", testScene());
    Assert.assertEq(expected = 320.0f32, pos#y)

/// 亀レーン0のグループは sections=3 なので 3 つの子スプライト
@Test
def testTurtleLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("t0_0", testScene())))

/// 亀プラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testTurtleNotMonitoring(): Unit \ Assert =
    match Scene.getEngineNode("t0_0" :: Nil, testScene()) {
        case Some(engineNode) =>
            Assert.assertEq(
                expected = (false, false),
                (CollisionObject2D.isMonitoring(engineNode), CollisionObject2D.isMonitorable(engineNode)))
        case None => bug!("turtle t0_0 not found")
    }

// ========================================================================
// TurtlePlatform process: 移動とラップ
// ========================================================================

/// TurtlePlatform が process で vx * dt 分移動する
@Test
def testTurtleProcessMoves(): Unit \ Assert =
    let scene = testScene();
    let origPos = Scene.globalPosition("t0_0", scene);
    // Lane 0: vx=100, dt=0.1 → +10px
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("t0_0", processed);
    Assert.assertEq(
        expected = (origPos#x + 10.0f32, origPos#y),
        (newPos#x, newPos#y))

// ========================================================================
// justPressedKeys: エッジ検出
// ========================================================================

/// 前フレームになかったキーだけが返る
@Test
def testJustPressedKeysEdgeDetect(): Unit \ Assert =
    let prev = Set#{Engine.Key.W};
    let curr = Set#{Engine.Key.W, Engine.Key.D};
    Assert.assertEq(
        expected = Set#{Engine.Key.D},
        Game.justPressedKeys(curr, prev))

/// 前フレームと同じキーの場合は空集合
@Test
def testJustPressedKeysNoChange(): Unit \ Assert =
    let keys = Set#{Engine.Key.W};
    Assert.assertEq(
        expected = (Set.empty(): Set[Engine.Key]),
        Game.justPressedKeys(keys, keys))

// ========================================================================
// inputDirection: キーから方向ベクトルへの変換
// ========================================================================

/// W キーで上方向 (0, -1)
@Test
def testInputDirectionUp(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.W}));
    Assert.assertEq(expected = (0.0f32, -1.0f32), vecToTuple(dir))

/// S キーで下方向 (0, 1)
@Test
def testInputDirectionDown(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.S}));
    Assert.assertEq(expected = (0.0f32, 1.0f32), vecToTuple(dir))

/// A キーで左方向 (-1, 0)
@Test
def testInputDirectionLeft(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.A}));
    Assert.assertEq(expected = (-1.0f32, 0.0f32), vecToTuple(dir))

/// D キーで右方向 (1, 0)
@Test
def testInputDirectionRight(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.D}));
    Assert.assertEq(expected = (1.0f32, 0.0f32), vecToTuple(dir))

/// 矢印キー Up も上方向を返す
@Test
def testInputDirectionArrowUp(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.Up}));
    Assert.assertEq(expected = (0.0f32, -1.0f32), vecToTuple(dir))

/// キーなしで None（sentinel 99 が返る）
@Test
def testInputDirectionNone(): Unit \ Assert =
    let sentinel: Vec2.Vec2 = {x = 99.0f32, y = 99.0f32};
    let dir = Option.getWithDefault(sentinel, Game.inputDirection(Set.empty()));
    Assert.assertEq(expected = (99.0f32, 99.0f32), vecToTuple(dir))

// ========================================================================
// directionToRotation
// ========================================================================

/// 上方向は 0 ラジアン
@Test
def testDirectionToRotationUp(): Unit \ Assert =
    Assert.assertEq(expected = 0.0, Game.directionToRotation(Vec2.up()))

/// 下方向は π ラジアン
@Test
def testDirectionToRotationDown(): Unit \ Assert =
    Assert.assertEq(expected = 3.1415926535898, Game.directionToRotation(Vec2.down()))

// ========================================================================
// checkDeath: 衝突死亡判定
// ========================================================================

/// スプライトが赤色のとき phase=Dying に変わり deathTimer が開始される
@Test
def testCheckDeathDetectsRed(): Unit \ Assert =
    let state = testState();
    let redScene = Scene.mapEngineNode("player" :: "Sprite" :: Nil,
        EngineNode.mapAnimSprite2D(sprite ->
            CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite)),
        state#scene);
    let deadState = Game.checkDeath({ scene = redScene | state });
    Assert.assertEq(expected = (GamePhase.Dying, true), (deadState#phase, Timer.isRunning(deadState#deathTimer)))

/// 通常色のスプライトでは phase は Playing のまま
@Test
def testCheckDeathNormalColor(): Unit \ Assert =
    let state = testState();
    let checkedState = Game.checkDeath(state);
    Assert.assertEq(expected = GamePhase.Playing, checkedState#phase)

// ========================================================================
// checkDrown: 溺死判定
// ========================================================================

/// 水ゾーンにいてプラットフォーム上にいないとき溺死
@Test
def testCheckDrownInWater(): Unit \ Assert =
    let state = testState();
    let waterPos: Vec2.Vec2 = {x = 384.0f32, y = 430.0f32};
    let newScene = Scene.setGlobalPosition("player", waterPos, state#scene)
        |> Scene.mapEngineNode("player" :: Nil,
            EngineNode.mapBody2D(body -> Node2D.setPosition(waterPos, body)))
        |> Scene.mapState("player" :: Nil, st -> match st {
            case GameData.PlayerData(r) =>
                GameData.PlayerData({target = waterPos | r})
            case other => other
        });
    let drownState = Game.checkDrown({ scene = newScene | state });
    Assert.assertEq(expected = GamePhase.Dying, drownState#phase)

/// 道路ゾーンにいるときは溺死しない
@Test
def testCheckDrownNotInWater(): Unit \ Assert =
    let state = testState();
    let checkedState = Game.checkDrown(state);
    Assert.assertEq(expected = GamePhase.Playing, checkedState#phase)

// ========================================================================
// buildState: ホームスロット配置
// ========================================================================

/// 5 つのホームスロットが存在する
@Test
def testHomeSlotCount(): Unit \ Assert =
    let scene = testScene();
    let exists = List.forAll(idx ->
        not Option.isEmpty(Scene.get("home${idx}", scene)),
        List.range(0, 5));
    Assert.assertTrue(exists)

/// ホームスロット 0 の位置が (64, 0)
@Test
def testHomeSlot0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home0", testScene());
    Assert.assertEq(expected = (64.0f32, 0.0f32), (pos#x, pos#y))

/// ホームスロット 2（中央）の位置が (384, 0)
@Test
def testHomeSlot2Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home2", testScene());
    Assert.assertEq(expected = (384.0f32, 0.0f32), (pos#x, pos#y))

/// 初期状態ではホームスロットは全て未充填
@Test
def testHomeSlotInitiallyUnfilled(): Unit \ Assert =
    Assert.assertFalse(Game.allHomesFilled(testScene()))

/// 各ホームスロットは子スプライトを 1 つ持つ
@Test
def testHomeSlotHasSprite(): Unit \ Assert =
    Assert.assertEq(
        expected = 1,
        List.length(Scene.getChildren("home0", testScene())))

// ========================================================================
// AreaHandler: ホームスロット充填
// ========================================================================

/// PlayerHitbox が未充填 HomeSlot に侵入すると filled=true になる
@Test
def testAreaHandlerFillsHomeSlot(): Unit \ Assert =
    let scene = testScene();
    let hitboxPath = "player" :: "Hitbox" :: Nil;
    let slotPath = "home2" :: Nil;
    match (Scene.getState(hitboxPath, scene), Scene.getState(slotPath, scene)) {
        case (Some(hitboxState), Some(slotState)) =>
            let newScene = AreaHandler.onAreaEntered(hitboxPath, hitboxState, slotPath, slotState, scene);
            match Scene.get("home2", newScene) {
                case Some(GameData.HomeSlotData(r)) => Assert.assertTrue(r#filled)
                case _ => bug!("home2 not found")
            }
        case _ => bug!("states not found")
    }

/// HomeSlot 充填後、スプライトテクスチャが HomeFrog に変わる
@Test
def testAreaHandlerFillChangesTexture(): Unit \ Assert =
    let scene = testScene();
    let hitboxPath = "player" :: "Hitbox" :: Nil;
    let slotPath = "home2" :: Nil;
    match (Scene.getState(hitboxPath, scene), Scene.getState(slotPath, scene)) {
        case (Some(hitboxState), Some(slotState)) =>
            let newScene = AreaHandler.onAreaEntered(hitboxPath, hitboxState, slotPath, slotState, scene);
            match Scene.getEngineNode("home2" :: "sprite" :: Nil, newScene) {
                case Some(EngineNode.Sprite2DWithState(sprite, _)) =>
                    let Sprite2D.Sprite2D(r) = sprite;
                    Assert.assertEq(expected = "HomeFrog", r#texture)
                case _ => bug!("home2 sprite not found")
            }
        case _ => bug!("states not found")
    }

/// HomeSlot 充填後、プレイヤーがスタート位置にリセットされる
@Test
def testAreaHandlerFillResetsPlayer(): Unit \ Assert =
    let scene = testScene();
    let hitboxPath = "player" :: "Hitbox" :: Nil;
    let slotPath = "home2" :: Nil;
    match (Scene.getState(hitboxPath, scene), Scene.getState(slotPath, scene)) {
        case (Some(hitboxState), Some(slotState)) =>
            let newScene = AreaHandler.onAreaEntered(hitboxPath, hitboxState, slotPath, slotState, scene);
            let pos = Scene.globalPosition("player", newScene);
            Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))
        case _ => bug!("states not found")
    }

/// 充填済み HomeSlot に侵入してもプレイヤー位置がリセットされない
@Test
def testAreaHandlerSkipsFilledSlot(): Unit \ Assert =
    let movedPos: Vec2.Vec2 = {x = 200.0f32, y = 100.0f32};
    let scene = testScene()
        |> Scene.mapState("home2" :: Nil, state -> match state {
            case GameData.HomeSlotData(r) => GameData.HomeSlotData({filled = true | r})
            case other => other
        })
        |> Scene.mapEngineNode("player" :: Nil,
            EngineNode.mapBody2D(body -> Node2D.setPosition(movedPos, body)));
    let hitboxPath = "player" :: "Hitbox" :: Nil;
    let slotPath = "home2" :: Nil;
    match (Scene.getState(hitboxPath, scene), Scene.getState(slotPath, scene)) {
        case (Some(hitboxState), Some(slotState)) =>
            let newScene = AreaHandler.onAreaEntered(hitboxPath, hitboxState, slotPath, slotState, scene);
            let pos = Scene.globalPosition("player", newScene);
            Assert.assertEq(expected = (200.0f32, 100.0f32), (pos#x, pos#y))
        case _ => bug!("states not found")
    }

/// 全5スロット充填で allHomesFilled が true を返す
@Test
def testAllHomesFilledWin(): Unit \ Assert =
    let scene = testScene();
    let scene1 = List.range(0, 5) |> List.foldLeft((acc, idx) ->
        Scene.mapState("home${idx}" :: Nil, state -> match state {
            case GameData.HomeSlotData(r) =>
                GameData.HomeSlotData({filled = true | r})
            case other => other
        }, acc),
        scene);
    Assert.assertTrue(Game.allHomesFilled(scene1))

// ========================================================================
// checkHomeCompletion: 充填後の後処理
// ========================================================================

/// スロットが新たに充填されるとタイマーがリスタートされる
@Test
def testCheckHomeCompletionRestartsTimer(): Unit \ Assert =
    let state = testState();
    let scene1 = Scene.mapState("home0" :: Nil, st -> match st {
        case GameData.HomeSlotData(r) =>
            GameData.HomeSlotData({filled = true | r})
        case other => other
    }, state#scene);
    let updatedState = Game.checkHomeCompletion(0, { scene = scene1 | state });
    Assert.assertTrue(Timer.isRunning(updatedState#gameTimer))

/// 充填数が変わらない場合は何もしない
@Test
def testCheckHomeCompletionNoOp(): Unit \ Assert =
    let state = testState();
    let updatedState = Game.checkHomeCompletion(0, state);
    Assert.assertEq(expected = GamePhase.Playing, updatedState#phase)

/// 最後のスロット充填時に checkHomeCompletion が phase を Win に遷移させる
@Test
def testCheckHomeCompletionWinTransition(): Unit \ Assert =
    let state = testState();
    let scene1 = List.range(0, 5) |> List.foldLeft((acc, idx) ->
        Scene.mapState("home${idx}" :: Nil, st -> match st {
            case GameData.HomeSlotData(r) =>
                GameData.HomeSlotData({filled = true | r})
            case other => other
        }, acc),
        state#scene);
    let filledState = Game.checkHomeCompletion(4, { scene = scene1 | state });
    Assert.assertEq(expected = GamePhase.Win, filledState#phase)

// ========================================================================
// handleTimerTimeouts: 死亡タイマーとリスポーン
// ========================================================================

/// 死亡中に deathTimer の process で timeLeft が減少し、タイムアウト前は Dying のまま
@Test
def testHandleTimerTimeoutsDeathTimerNotExpired(): Unit \ Assert =
    let state = testState();
    // deathTimer を手動開始して 0.5s 進める
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying | state };
    let state2 = Game.processTimers(0.5f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    Assert.assertEq(expected = GamePhase.Dying, updated#phase)

/// タイマーが 0 以下になるとリスポーンする（phase=Playing, ライフ -1）
@Test
def testHandleTimerTimeoutsDeathTimerRespawns(): Unit \ Assert =
    let state = testState();
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying | state };
    let state2 = Game.processTimers(2.1f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    Assert.assertEq(
        expected = (GamePhase.Playing, 2),
        (updated#phase, updated#lives))

/// リスポーン後にプレイヤーがスタート位置に戻る
@Test
def testRespawnResetsPosition(): Unit \ Assert =
    let state = testState();
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying | state };
    let state2 = Game.processTimers(2.1f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    let pos = Scene.globalPosition("player", updated#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// リスポーン後にスプライトが idle アニメーションに戻る
@Test
def testRespawnResetsAnimation(): Unit \ Assert =
    let state = testState();
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying | state };
    let state2 = Game.processTimers(2.1f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    match Scene.getEngineNode("player" :: "Sprite" :: Nil, updated#scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "idle", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player Sprite not found after respawn")
    }

/// タイマーがタイムアウトしていないときは handleTimerTimeouts は何もしない
@Test
def testHandleTimerTimeoutsNoOpWhenNoTimeout(): Unit \ Assert =
    let state = testState();
    let updated = Game.handleTimerTimeouts(state);
    Assert.assertEq(expected = GamePhase.Playing, updated#phase)

// ========================================================================
// processTimers / handleTimerTimeouts: ゲームタイマー
// ========================================================================

/// ゲームタイマーが processTimers で減少する
@Test
def testGameTimerDecreases(): Unit \ Assert =
    let state = testState();
    let state1 = Game.processTimers(1.0f32, state);
    Assert.assertEq(expected = 29.0f32, Timer.getTimeLeft(state1#gameTimer))

/// ゲームタイマーが 0 以下になると handleTimerTimeouts で phase=Dying になる
@Test
def testHandleTimerTimeoutsGameTimerDeath(): Unit \ Assert =
    let state = testState();
    let shortState = { gameTimer = Timer.make(0.5f32) |> Timer.setAutostart(true) |> Timer.ready | state };
    let state1 = Game.processTimers(1.0f32, shortState);
    let updated = Game.handleTimerTimeouts(state1);
    Assert.assertEq(expected = GamePhase.Dying, updated#phase)

/// 既に Dying のときゲームタイマーの timedOut は追加死亡しない
@Test
def testHandleTimerTimeoutsGameTimerSkipsWhenDead(): Unit \ Assert =
    let state = testState();
    let state1 = { phase = GamePhase.Dying | state };
    let updated = Game.handleTimerTimeouts(state1);
    Assert.assertEq(expected = GamePhase.Dying, updated#phase)

// ========================================================================
// Timer timedOut フラグ
// ========================================================================

/// Timer.process でタイムアウトすると timedOut=true になる
@Test
def testTimerTimedOutFlag(): Unit \ Assert =
    let timer = Timer.make(1.0f32) |> Timer.start;
    let processed = Timer.process(1.5f32, timer);
    Assert.assertTrue(Timer.isTimedOut(processed))

/// Timer.process でタイムアウトしなければ timedOut=false のまま
@Test
def testTimerNotTimedOut(): Unit \ Assert =
    let timer = Timer.make(2.0f32) |> Timer.start;
    let processed = Timer.process(0.5f32, timer);
    Assert.assertFalse(Timer.isTimedOut(processed))

/// Timer.clearTimedOut でフラグがクリアされる
@Test
def testTimerClearTimedOut(): Unit \ Assert =
    let timer = Timer.make(1.0f32) |> Timer.start;
    let processed = Timer.process(1.5f32, timer);
    let cleared = Timer.clearTimedOut(processed);
    Assert.assertFalse(Timer.isTimedOut(cleared))

/// handleTimerTimeouts 後に gameTimer の timedOut フラグがクリアされる
@Test
def testHandleTimeoutsClearsFlag(): Unit \ Assert =
    let state = testState();
    let shortState = { gameTimer = Timer.make(0.5f32) |> Timer.setAutostart(true) |> Timer.ready | state };
    let state1 = Game.processTimers(1.0f32, shortState);
    // processTimers 後は timedOut=true のはず
    let hasTimeout = Timer.isTimedOut(state1#gameTimer);
    // handleTimerTimeouts で処理・クリア
    let state2 = Game.handleTimerTimeouts(state1);
    let afterTimeout = Timer.isTimedOut(state2#gameTimer);
    Assert.assertEq(expected = (true, false), (hasTimeout, afterTimeout))

// ========================================================================
// GamePhase 遷移
// ========================================================================

/// deathTimer タイムアウト時、ライフ1 → GameOver に遷移
@Test
def testDeathTimerTimeoutGameOver(): Unit \ Assert =
    let state = testState();
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying, lives = 1 | state };
    let state2 = Game.processTimers(2.1f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    Assert.assertEq(expected = GamePhase.GameOver, updated#phase)

/// deathTimer タイムアウト時、ライフ2 → Playing に遷移
@Test
def testDeathTimerTimeoutRespawn(): Unit \ Assert =
    let state = testState();
    let state1 = { deathTimer = Timer.start(state#deathTimer), phase = GamePhase.Dying, lives = 2 | state };
    let state2 = Game.processTimers(2.1f32, state1);
    let updated = Game.handleTimerTimeouts(state2);
    Assert.assertEq(expected = GamePhase.Playing, updated#phase)

/// buildState で初期状態が構築される
@Test
def testBuildState(): Unit \ Assert =
    let state = testState();
    Assert.assertEq(expected = (3, GamePhase.Playing), (state#lives, state#phase))

// ========================================================================
// Timer の初期値
// ========================================================================

/// gameTimer の初期値 waitTime=30.0
@Test
def testGameTimerExists(): Unit \ Assert =
    let state = testState();
    Assert.assertEq(expected = 30.0f32, Timer.getTimeLeft(state#gameTimer))

/// deathTimer は初期状態で running=false
@Test
def testDeathTimerExists(): Unit \ Assert =
    let state = testState();
    Assert.assertFalse(Timer.isRunning(state#deathTimer))

// ========================================================================
// Label2D ノードの存在
// ========================================================================

/// timerLabel が存在する
@Test
def testTimerLabelExists(): Unit \ Assert =
    match Scene.getEngineNode("timerLabel" :: Nil, testScene()) {
        case Some(EngineNode.Label2DWithState(_, _)) => Assert.assertTrue(true)
        case _ => bug!("timerLabel not found")
    }

/// livesLabel が存在する
@Test
def testLivesLabelExists(): Unit \ Assert =
    match Scene.getEngineNode("livesLabel" :: Nil, testScene()) {
        case Some(EngineNode.Label2DWithState(_, _)) => Assert.assertTrue(true)
        case _ => bug!("livesLabel not found")
    }

// ========================================================================
// handlePlayerInput: 入力統合テスト
// ========================================================================

/// W キーが押されるとターゲットが 64px 上に移動する
@Test
def testPlayerProcessInputUp(): Unit \ Assert =
    let state = testState();
    let processed = run Game.handlePlayerInput(state) with handler Engine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016f32)
        def isKeyPressed(key, k) = k(key == Engine.Key.W)
        def getFontAtlas(_, k) = k(testFontAtlas())
    };
    let target = Game.getPlayerTarget(processed#scene);
    Assert.assertEq(expected = (384.0f32, 768.0f32), (target#x, target#y))

/// S キーが押されても下限クランプで移動しない
@Test
def testPlayerProcessInputClampDown(): Unit \ Assert =
    let state = testState();
    let processed = run Game.handlePlayerInput(state) with handler Engine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016f32)
        def isKeyPressed(key, k) = k(key == Engine.Key.S)
        def getFontAtlas(_, k) = k(testFontAtlas())
    };
    let target = Game.getPlayerTarget(processed#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (target#x, target#y))

/// キーが押されていない場合ターゲットは変わらない
@Test
def testPlayerProcessInputNone(): Unit \ Assert =
    let state = testState();
    let processed = withMockEngine(() -> Game.handlePlayerInput(state));
    let target = Game.getPlayerTarget(processed#scene);
    Assert.assertEq(
        expected = vecToTuple(Game.playerStart()),
        vecToTuple(target))

/// 死亡中は W キーが押されてもターゲットが変わらない
@Test
def testPlayerProcessInputIgnoredWhenDead(): Unit \ Assert =
    let state = testState();
    let deadState = { phase = GamePhase.Dying | state };
    let processed = run Game.handlePlayerInput(deadState) with handler Engine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016f32)
        def isKeyPressed(key, k) = k(key == Engine.Key.W)
        def getFontAtlas(_, k) = k(testFontAtlas())
    };
    let target = Game.getPlayerTarget(processed#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (target#x, target#y))
