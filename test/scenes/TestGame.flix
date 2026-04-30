// Tests for Dodge the Creeps Game module

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

/// 指定キーが押されている Engine.Game ハンドラ
def withKeysPressed(keys: Set[Engine.Key], f: Unit -> a \ ef + Engine.Game): a \ ef =
    run f() with handler Engine.Game {
        def render(_, k) = k(())
        def shouldClose(k) = k(false)
        def getDeltaTime(k) = k(0.016f32)
        def isKeyPressed(key, k) = k(Set.memberOf(key, keys))
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

/// Vec2 をタプルに変換するヘルパー
def vecToTuple(v: Vec2.Vec2): (Float32, Float32) = (v#x, v#y)

// ========================================================================
// buildState: ノード数・構造
// ========================================================================

/// シーンにはプレイヤーノードが 1 つだけ存在する
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 1, Scene.nodeCount(testScene()))

/// ルートノードは 1 つ
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 1, Map.size(Scene.states(testScene())))

// ========================================================================
// buildState: プレイヤー配置
// ========================================================================

/// プレイヤーの初期位置が画面中央 (240, 360)
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", testScene());
    Assert.assertEq(expected = (240.0f32, 360.0f32), vecToTuple(pos))

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
        case Some(GameData.Player(r)) =>
            Assert.assertEq(expected = (0.0f32, 0.0f32), vecToTuple(r#velocity))
        case _ => bug!("player state mismatch")
    }

// ========================================================================
// AnimatedSprite2D: フレーム進行
// ========================================================================

/// fps=6 で 0.2 秒後（frameDuration=1/6≒0.167 超過）にフレームが進む
@Test
def testAnimSpriteAdvancesFrame(): Unit \ Assert =
    match testScene() |> Scene.processAll(0.2, false) |> Scene.getEngineNode("player" :: Nil) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk2", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found after process")
    }

/// 2 回の processAll でフレームが一周し、最初のフレームに戻る（ループ）
@Test
def testAnimSpriteLoops(): Unit \ Assert =
    match testScene() |> Scene.processAll(0.2, false) |> Scene.processAll(0.2, false) |> Scene.getEngineNode("player" :: Nil) {
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
    let dir = withKeysPressed(Set#{Engine.Key.D}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (1.0f32, 0.0f32), vecToTuple(dir))

/// A キーで左方向 (-1, 0)
@Test
def testInputDirectionLeft(): Unit \ Assert =
    let dir = withKeysPressed(Set#{Engine.Key.A}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (-1.0f32, 0.0f32), vecToTuple(dir))

/// W キーで上方向 (0, -1)
@Test
def testInputDirectionUp(): Unit \ Assert =
    let dir = withKeysPressed(Set#{Engine.Key.W}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0f32, -1.0f32), vecToTuple(dir))

/// S キーで下方向 (0, 1)
@Test
def testInputDirectionDown(): Unit \ Assert =
    let dir = withKeysPressed(Set#{Engine.Key.S}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0f32, 1.0f32), vecToTuple(dir))

/// 矢印キーも対応
@Test
def testInputDirectionArrow(): Unit \ Assert =
    let dir = withKeysPressed(Set#{Engine.Key.Right}, () -> Game.readInputDirection());
    Assert.assertEq(expected = (1.0f32, 0.0f32), vecToTuple(dir))

/// キーなしでゼロベクトル
@Test
def testInputDirectionNone(): Unit \ Assert =
    let dir = withMockEngine(() -> Game.readInputDirection());
    Assert.assertEq(expected = (0.0f32, 0.0f32), vecToTuple(dir))

// ========================================================================
// applyInput: 速度・アニメーション設定
// ========================================================================

/// 右方向に速度が設定される
@Test
def testApplyInputSetsVelocity(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0f32, y = 0.0f32}, testScene());
    match Scene.get("player", scene) {
        case Some(GameData.Player(r)) =>
            Assert.assertEq(expected = (400.0f32, 0.0f32), vecToTuple(r#velocity))
        case _ => bug!("player state mismatch")
    }

/// ゼロベクトルで速度がゼロになる
@Test
def testApplyInputZeroVelocity(): Unit \ Assert =
    let scene = PlayerScene.applyInput(Vec2.zero(), testScene());
    match Scene.get("player", scene) {
        case Some(GameData.Player(r)) =>
            Assert.assertEq(expected = (0.0f32, 0.0f32), vecToTuple(r#velocity))
        case _ => bug!("player state mismatch")
    }

/// 右方向で walk アニメーションが再生される
@Test
def testApplyInputWalkAnimation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0f32, y = 0.0f32}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "walk", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player not found")
    }

/// 上方向で up アニメーションが再生される
@Test
def testApplyInputUpAnimation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0f32, y = -1.0f32}, testScene());
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
    let scene = PlayerScene.applyInput({x = -1.0f32, y = 0.0f32}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
            Assert.assertTrue(r#flipH)
        case _ => bug!("player not found")
    }

/// 右方向で rotation=0（横移動時は回転リセット）
@Test
def testApplyInputWalkRotationZero(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 1.0f32, y = 0.0f32}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) =>
            Assert.assertEq(expected = 0.0, Node2D.getRotation(engineNode))
        case None => bug!("player not found")
    }

/// 下方向で rotation=PI
@Test
def testApplyInputDownRotation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0f32, y = 1.0f32}, testScene());
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) =>
            Assert.assertEq(expected = 3.14159265358979, Node2D.getRotation(engineNode))
        case None => bug!("player not found")
    }

/// 上方向で rotation=0
@Test
def testApplyInputUpRotation(): Unit \ Assert =
    let scene = PlayerScene.applyInput({x = 0.0f32, y = -1.0f32}, testScene());
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
    let scene = testScene()
        |> Scene.mapState("player" :: Nil, _ ->
            GameData.Player({velocity = {x = 400.0f32, y = 0.0f32}}));
    let pos = scene |> Scene.processAll(0.1, false) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (280.0f32, 360.0f32), vecToTuple(pos))

/// 速度ゼロのとき process で移動しない
@Test
def testPlayerProcessStays(): Unit \ Assert =
    let pos = testScene() |> Scene.processAll(0.1, false) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (240.0f32, 360.0f32), vecToTuple(pos))

/// 画面右端でクランプされる
@Test
def testPlayerClampRight(): Unit \ Assert =
    let scene = testScene()
        |> Scene.mapState("player" :: Nil, _ ->
            GameData.Player({velocity = {x = 400.0f32, y = 0.0f32}}));
    let pos = scene |> Scene.processAll(1.0, false) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (Game.screenW(), 360.0f32), vecToTuple(pos))

/// 画面左端でクランプされる
@Test
def testPlayerClampLeft(): Unit \ Assert =
    let scene = testScene()
        |> Scene.mapState("player" :: Nil, _ ->
            GameData.Player({velocity = {x = -400.0f32, y = 0.0f32}}));
    let pos = scene |> Scene.processAll(1.0, false) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (0.0f32, 360.0f32), vecToTuple(pos))

// ========================================================================
// setPlayerAnimation: アニメーション切り替え
// ========================================================================

/// 同じアニメーションの場合フレームがリセットされない
@Test
def testSwitchAnimKeepsFrame(): Unit \ Assert =
    let scene = testScene()
        |> Scene.processAll(0.2, false)
        |> PlayerScene.applyInput({x = 1.0f32, y = 0.0f32});
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk2", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found")
    }

/// アニメーションが変わるとフレームがリセットされる
@Test
def testSwitchAnimResetsFrame(): Unit \ Assert =
    let scene = testScene()
        |> Scene.processAll(0.2, false)
        |> PlayerScene.applyInput({x = 0.0f32, y = -1.0f32});
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(
                expected = ("up", "playerGrey_up1"),
                (AnimatedSprite2D.getCurrentAnimation(sprite),
                 AnimatedSprite2D.currentTexture(sprite)))
        case _ => bug!("player not found")
    }
