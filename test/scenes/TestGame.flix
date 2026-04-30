// Tests for Dodge the Creeps Game module

// ========================================================================
// テスト用ヘルパー
// ========================================================================

def withMockEngine(f: Unit -> a \ ef + GameEngine.Game): a \ ef =
    run f() with handler GameEngine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016)
        def isKeyPressed(_, k) = k(false)
        def getFontAtlas(_, k) = k(testFontAtlas())
        def getViewportRect(k) = k(Rect2.fromSize({x = 480.0, y = 720.0}))
    }

/// 指定キーが押されている GameEngine.Game ハンドラ
def withKeysPressed(keys: Set[GameEngine.Key], f: Unit -> a \ ef + GameEngine.Game): a \ ef =
    run f() with handler GameEngine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016)
        def isKeyPressed(key, k) = k(Set.memberOf(key, keys))
        def getFontAtlas(_, k) = k(testFontAtlas())
        def getViewportRect(k) = k(Rect2.fromSize({x = 480.0, y = 720.0}))
    }

/// テスト用のダミー FontAtlas（空のグリフマップ）
def testFontAtlas(): FontAtlas = {
    textureName = "font_test",
    fontSize = 32.0,
    textureSize = 512.0,
    glyphs = Map.empty()
}

/// テスト用ヘルパー: buildState のシーンを取得
def testScene(): Scene[GameData] = Game.buildState(testFontAtlas())#scene

/// テスト用ヘルパー: buildState を取得
def testState(): GameState = Game.buildState(testFontAtlas())

/// テスト用ヘルパー: processAll 済みのシーンを取得（screenSize が設定される）
def testReadyScene(): Scene[GameData] =
    withMockEngine(() -> Scene.processAll(0.0, false, testScene()))

/// Vec2 をタプルに変換するヘルパー
def vecToTuple(v: Vec2.Vec2): (Float64, Float64) = (v#x, v#y)

// ========================================================================
// buildState: ノード数・構造
// ========================================================================

/// シーンにはプレイヤー + Area2D + mob_timer + mob_path + background = 5 ノード
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 5, Scene.nodeCount(testScene()))

/// ルートノードは 4 つ（background + player + mob_timer + mob_path）
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 4, Map.size(Scene.states(testScene())))

// ========================================================================
// buildState: プレイヤー配置
// ========================================================================

/// プレイヤーの初期位置が画面中央 (240, 360)
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", testScene());
    Assert.assertEq(expected = (240.0, 360.0), vecToTuple(pos))

/// プレイヤーは可視状態
@Test
def testPlayerIsVisible(): Unit \ Assert =
    match Scene.getEngineNode("player" :: Nil, testScene()) {
        case Some(engineNode) => Assert.assertTrue(CanvasItem.isVisible(engineNode))
        case None => bug!("player not found")
    }

/// プレイヤーの初期アニメーションが walk で最初のフレームが playerGrey_walk1
@Test
def testPlayerWalkAnimation(): Unit \ Assert =
    match Scene.getEngineNode("player" :: Nil, testScene()) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(
                expected = ("walk", "playerGrey_walk1"),
                (AnimatedSprite2D.getCurrentAnimation(sprite),
                 AnimatedSprite2D.currentTexture(sprite)))
        case _ => bug!("player not found")
    }

/// プレイヤーの初期速度がゼロ
@Test
def testPlayerInitialVelocity(): Unit \ Assert =
    match Scene.get("player", testScene()) {
        case Some(GameData.Player(_, pd)) =>
            Assert.assertEq(expected = (0.0, 0.0), vecToTuple(pd#velocity))
        case _ => bug!("player state mismatch")
    }

// ========================================================================
// AnimatedSprite2D: フレーム進行
// ========================================================================

/// fps=6 で 0.2 秒後（frameDuration=1/6≒0.167 超過）にフレームが進む
@Test
def testAnimSpriteAdvancesFrame(): Unit \ Assert =
    match withMockEngine(() -> testScene() |> Scene.processAll(0.2, false)) |> Scene.getEngineNode("player" :: Nil) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk2", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found after process")
    }

/// 2 回の processAll でフレームが一周し、最初のフレームに戻る（ループ）
@Test
def testAnimSpriteLoops(): Unit \ Assert =
    match withMockEngine(() -> testScene() |> Scene.processAll(0.2, false) |> Scene.processAll(0.2, false)) |> Scene.getEngineNode("player" :: Nil) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk1", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found after process")
    }

// ========================================================================
// readInputDirection: キーから方向ベクトル
// ========================================================================

/// D キーで右方向 (1, 0)
@Test
def testInputDirectionRight(): Unit \ Assert =
    let dir = withKeysPressed(Set#{GameEngine.Key.D}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (1.0, 0.0), vecToTuple(dir))

/// A キーで左方向 (-1, 0)
@Test
def testInputDirectionLeft(): Unit \ Assert =
    let dir = withKeysPressed(Set#{GameEngine.Key.A}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (-1.0, 0.0), vecToTuple(dir))

/// W キーで上方向 (0, -1)
@Test
def testInputDirectionUp(): Unit \ Assert =
    let dir = withKeysPressed(Set#{GameEngine.Key.W}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0, -1.0), vecToTuple(dir))

/// S キーで下方向 (0, 1)
@Test
def testInputDirectionDown(): Unit \ Assert =
    let dir = withKeysPressed(Set#{GameEngine.Key.S}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0, 1.0), vecToTuple(dir))

/// 矢印キーも対応
@Test
def testInputDirectionArrow(): Unit \ Assert =
    let dir = withKeysPressed(Set#{GameEngine.Key.Right}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (1.0, 0.0), vecToTuple(dir))

/// キーなしでゼロベクトル
@Test
def testInputDirectionNone(): Unit \ Assert =
    let dir = withMockEngine(() -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0, 0.0), vecToTuple(dir))

// ========================================================================
// applyInput: 速度・アニメーション設定
// ========================================================================

/// 右方向に速度が設定される
@Test
def testApplyInputSetsVelocity(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0, y = 0.0}, testScene());
    match Scene.get("player", scene) {
        case Some(GameData.Player(_, pd)) =>
            Assert.assertEq(expected = (400.0, 0.0), vecToTuple(pd#velocity))
        case _ => bug!("player state mismatch")
    }

/// ゼロベクトルで速度がゼロになる
@Test
def testApplyInputZeroVelocity(): Unit \ Assert =
    let scene = PlayerScene.applyInput(Vec2.zero(), testScene());
    match Scene.get("player", scene) {
        case Some(GameData.Player(_, pd)) =>
            Assert.assertEq(expected = (0.0, 0.0), vecToTuple(pd#velocity))
        case _ => bug!("player state mismatch")
    }

/// 右方向で walk アニメーションが再生される
@Test
def testApplyInputWalkAnimation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0, y = 0.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "walk", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player not found")
    }

/// 上方向で up アニメーションが再生される
@Test
def testApplyInputUpAnimation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0, y = -1.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "up", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player not found")
    }

/// ゼロベクトルでアニメーションが停止する
@Test
def testApplyInputStopsAnimation(): Unit \ Assert =
    let scene = PlayerScene.applyInput(Vec2.zero(), testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
            Assert.assertFalse(r#playing)
        case _ => bug!("player not found")
    }

/// 左方向で flipH=true になる
@Test
def testApplyInputFlipH(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = -1.0, y = 0.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
            Assert.assertTrue(r#flipH)
        case _ => bug!("player not found")
    }

/// 右方向で rotation=0（横移動時は回転リセット）
@Test
def testApplyInputWalkRotationZero(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0, y = 0.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) =>
            Assert.assertEq(expected = 0.0, Node2D.getRotation(engineNode))
        case None => bug!("player not found")
    }

/// 下方向で rotation=PI
@Test
def testApplyInputDownRotation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0, y = 1.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) =>
            Assert.assertEq(expected = 3.14159265358979, Node2D.getRotation(engineNode))
        case None => bug!("player not found")
    }

/// 上方向で rotation=0
@Test
def testApplyInputUpRotation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0, y = -1.0}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) =>
            Assert.assertEq(expected = 0.0, Node2D.getRotation(engineNode))
        case None => bug!("player not found")
    }

// ========================================================================
// process: プレイヤー移動
// ========================================================================

/// 速度が設定されているとき process で移動する
///   speed=400, dt=0.1 → 右に40px 移動: 240+40=280
@Test
def testPlayerProcessMoves(): Unit \ Assert =
    let scene = testReadyScene()
        |> Scene.mapState("player" :: Nil, state ->
            match state {
                case GameData.Player(pn, pd) =>
                    GameData.Player(pn, {velocity = {x = 400.0, y = 0.0} | pd})
                case other => other
            });
    let pos = withMockEngine(() -> scene |> Scene.processAll(0.1, false)) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (280.0, 360.0), vecToTuple(pos))

/// 速度ゼロのとき process で移動しない
@Test
def testPlayerProcessStays(): Unit \ Assert =
    let pos = withMockEngine(() -> testReadyScene() |> Scene.processAll(0.1, false)) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (240.0, 360.0), vecToTuple(pos))

/// 画面右端でクランプされる
@Test
def testPlayerClampRight(): Unit \ Assert =
    let scene = testReadyScene()
        |> Scene.mapState("player" :: Nil, state ->
            match state {
                case GameData.Player(pn, pd) =>
                    GameData.Player(pn, {velocity = {x = 400.0, y = 0.0} | pd})
                case other => other
            });
    let pos = withMockEngine(() -> scene |> Scene.processAll(1.0, false)) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (480.0, 360.0), vecToTuple(pos))

/// 画面左端でクランプされる
@Test
def testPlayerClampLeft(): Unit \ Assert =
    let scene = testReadyScene()
        |> Scene.mapState("player" :: Nil, state ->
            match state {
                case GameData.Player(pn, pd) =>
                    GameData.Player(pn, {velocity = {x = -400.0, y = 0.0} | pd})
                case other => other
            });
    let pos = withMockEngine(() -> scene |> Scene.processAll(1.0, false)) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (0.0, 360.0), vecToTuple(pos))

// ========================================================================
// setPlayerAnimation: アニメーション切り替え
// ========================================================================

/// 同じアニメーションの場合フレームがリセットされない
@Test
def testSwitchAnimKeepsFrame(): Unit \ Assert =
    let scene = withMockEngine(() -> testScene() |> Scene.processAll(0.2, false))
        |> PlayerScene.applyInput({x = 1.0, y = 0.0});
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk2", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found")
    }

/// アニメーションが変わるとフレームがリセットされる
@Test
def testSwitchAnimResetsFrame(): Unit \ Assert =
    let scene = withMockEngine(() -> testScene() |> Scene.processAll(0.2, false))
        |> PlayerScene.applyInput({x = 0.0, y = -1.0});
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(
                expected = ("up", "playerGrey_up1"),
                (AnimatedSprite2D.getCurrentAnimation(sprite),
                 AnimatedSprite2D.currentTexture(sprite)))
        case _ => bug!("player not found")
    }

// ========================================================================
// ready: ビューポートサイズ取得
// ========================================================================

/// readyAll 後に screenSize がモックのビューポートサイズ (480x720) に設定される
@Test
def testReadySetsScreenSize(): Unit \ Assert =
    let scene = withMockEngine(() -> Scene.processAll(0.0, false, testScene()));
    match Scene.get("player", scene) {
        case Some(GameData.Player(_, pd)) =>
            Assert.assertEq(expected = (480.0, 720.0), vecToTuple(pd#screenSize))
        case _ => bug!("player state mismatch")
    }

// ========================================================================
// ready → hide / start → show ライフサイクル
// ========================================================================

/// ready 後もプレイヤーが表示状態であること（hide はスタート画面実装時に復活）
@Test
def testReadyKeepsPlayerVisible(): Unit \ Assert =
    let scene = testReadyScene();
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) => Assert.assertTrue(CanvasItem.isVisible(engineNode))
        case None => bug!("player not found")
    }

/// start 後にプレイヤーが表示されること
@Test
def testStartShowsPlayer(): Unit \ Assert =
    let scene = testReadyScene()
        |> PlayerScene.start({x = 100.0, y = 200.0});
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) => Assert.assertTrue(CanvasItem.isVisible(engineNode))
        case None => bug!("player not found")
    }

/// start で指定位置に配置されること
@Test
def testStartSetsPosition(): Unit \ Assert =
    let scene = testReadyScene()
        |> PlayerScene.start({x = 100.0, y = 200.0});
    let pos = Scene.globalPosition("player", scene);
    Assert.assertEq(expected = (100.0, 200.0), vecToTuple(pos))

// ========================================================================
// Area2D 子ノード
// ========================================================================

/// プレイヤーに Area2D 子ノードが存在すること
@Test
def testPlayerAreaChildExists(): Unit \ Assert =
    match Scene.getEngineNode("player" :: "area" :: Nil, testScene()) {
        case Some(_) => Assert.assertTrue(true)
        case None => bug!("player area child not found")
    }

/// Area2D 子ノードの状態が PlayerArea であること
@Test
def testPlayerAreaChildState(): Unit \ Assert =
    match Scene.getState("player" :: "area" :: Nil, testScene()) {
        case Some(GameData.PlayerArea) => Assert.assertTrue(true)
        case _ => bug!("player area state mismatch")
    }
