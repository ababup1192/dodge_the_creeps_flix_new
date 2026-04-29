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
    Assert.assertEq(expected = (240.0f32, 360.0f32), (pos#x, pos#y))

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

/// プレイヤーの状態が PlayerData
@Test
def testPlayerState(): Unit \ Assert =
    match Scene.get("player", testScene()) {
        case Some(GameData.PlayerData) => Assert.assertTrue(true)
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
/// advanceFrame は 1 呼び出しで 1 フレームしか進まないため 2 回呼ぶ
@Test
def testAnimSpriteLoops(): Unit \ Assert =
    match testScene() |> Scene.processAll(0.2, false) |> Scene.processAll(0.2, false) |> Scene.getEngineNode("player" :: Nil) {
        case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
            Assert.assertEq(expected = "playerGrey_walk1", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player not found after process")
    }
