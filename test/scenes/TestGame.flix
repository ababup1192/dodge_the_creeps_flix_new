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
        def getMousePosition(k) = k(Vec2.zero())
        def isMouseButtonPressed(_, k) = k(false)
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
        def getMousePosition(k) = k(Vec2.zero())
        def isMouseButtonPressed(_, k) = k(false)
        def getFontAtlas(_, k) = k(testFontAtlas())
        def getViewportRect(k) = k(Rect2.fromSize({x = 480.0, y = 720.0}))
    }

/// Audio エフェクトの記録用ハンドラ（playAudio/stopAudio の呼び出しを記録する）
def recordAudio(f: Unit -> a \ GameEngine.Audio): (a, List[String]) =
    run { (f(), Nil) } with handler GameEngine.Audio {
        def playAudio(name, k) =
            let (result, rest) = k(());
            (result, "play:${name}" :: rest)
        def stopAudio(name, k) =
            let (result, rest) = k(());
            (result, "stop:${name}" :: rest)
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

/// シーンには player(+area+trail) + background + mob_timer + mob_path + start_timer + score_timer
///   + hud(+score_label+message_label+start_button+message_timer+title_timer) = 14 ノード
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 14, Scene.nodeCount(testScene()))

/// ルートノードは 7 つ（background + player + mob_timer + mob_path + start_timer + score_timer + hud）
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 7, Map.size(Scene.states(testScene())))

// ========================================================================
// buildState: プレイヤー配置
// ========================================================================

/// プレイヤーの初期位置 (240, 450)（Godot 版準拠）
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", testScene());
    Assert.assertEq(expected = (240.0, 450.0), vecToTuple(pos))

/// プレイヤーは初期非表示（Menu フェーズ）
@Test
def testPlayerIsHidden(): Unit \ Assert =
    match Scene.getEngineNode("player" :: Nil, testScene()) {
        case Some(engineNode) => Assert.assertFalse(CanvasItem.isVisible(engineNode))
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
    Assert.assertEq(expected = (280.0, 450.0), vecToTuple(pos))

/// 速度ゼロのとき process で移動しない
@Test
def testPlayerProcessStays(): Unit \ Assert =
    let pos = withMockEngine(() -> testReadyScene() |> Scene.processAll(0.1, false)) |> Scene.globalPosition("player");
    Assert.assertEq(expected = (240.0, 450.0), vecToTuple(pos))

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
    Assert.assertEq(expected = (480.0, 450.0), vecToTuple(pos))

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
    Assert.assertEq(expected = (0.0, 450.0), vecToTuple(pos))

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

/// ready 後もプレイヤーが非表示であること（Menu フェーズ）
@Test
def testReadyKeepsPlayerHidden(): Unit \ Assert =
    let scene = testReadyScene();
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(engineNode) => Assert.assertFalse(CanvasItem.isVisible(engineNode))
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

// ========================================================================
// 衝突: プレイヤーとモブの衝突で hidden になる
// ========================================================================

/// プレイヤーとモブが同じ位置にいるとき emitCollision でプレイヤーが hidden になる
@Test
def testPlayerHiddenOnMobCollision(): Unit \ Assert =
    let scene = testReadyScene()
        |> PlayerScene.start({x = 240.0, y = 450.0})
        |> MobScene.spawnMob("mob_test", {x = 240.0, y = 450.0}, 99);
    // プレイヤーが表示されていることを事前確認
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("player not found before collision")
    };
    // 衝突検出を実行
    let collided = GameEngine.emitCollision(scene);
    // プレイヤーが非表示になっていること
    match Scene.getEngineNode("player" :: Nil, collided) {
        case Some(en) => Assert.assertFalse(CanvasItem.isVisible(en))
        case None => bug!("player not found after collision")
    }

/// フルパイプライン (process >> physicsProcess >> emitCollision) でプレイヤーが hidden になる
@Test
def testPlayerHiddenFullPipeline(): Unit \ Assert =
    let scene = withMockEngine(() -> {
        let s0 = testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 240.0, y = 450.0}, 99);
        let pipeline =
            GameEngine.process(0.016, false)
            >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity())
            >> GameEngine.emitCollision
            >> GameEngine.emitScreenNotify(screenWidth = Game.screenWi(), screenHeight = Game.screenHi())
            >> GameEngine.emitTimers;
        pipeline(s0)
    });
    match Scene.getEngineNode("player" :: Nil, scene) {
        case Some(en) => Assert.assertFalse(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// detectOverlaps でプレイヤーとモブの重なりが検出される
@Test
def testDetectOverlapsPlayerMob(): Unit \ Assert =
    let scene = testReadyScene()
        |> PlayerScene.start({x = 240.0, y = 450.0})
        |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertTrue(not List.isEmpty(overlaps))

// ========================================================================
// Start ボタン: 座標・サイズ・配置
// ========================================================================

/// HUD CanvasLayer が存在し、状態が HUDLayer であること
@Test
def testHUDCanvasLayerExists(): Unit \ Assert =
    match Scene.getState(HUDScene.hudName() :: Nil, testScene()) {
        case Some(GameData.HUDLayer) => Assert.assertTrue(true)
        case _ => bug!("hud not found or wrong state")
    }

/// スタートボタンが存在し、状態が StartButton であること
@Test
def testStartButtonExists(): Unit \ Assert =
    match Scene.getState(HUDScene.startButtonPath(), testScene()) {
        case Some(GameData.StartButton) => Assert.assertTrue(true)
        case _ => bug!("start_button not found or wrong state")
    }

/// スタートボタンの位置
@Test
def testStartButtonPosition(): Unit \ Assert =
    let pos = Scene.globalPositionAt(HUDScene.startButtonPath(), testScene());
    Assert.assertEq(expected = (150.0, 520.0), vecToTuple(pos))

/// スタートボタンのサイズ
@Test
def testStartButtonSize(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.startButtonPath(), testScene()) {
        case Some(EngineNode.ButtonWithState(btn, _)) =>
            let size = Button.getSize(btn);
            Assert.assertEq(expected = (180.0, 100.0), vecToTuple(size))
        case _ => bug!("start_button not found")
    }

/// スタートボタンの水平中心が画面中央 (240) に一致すること
@Test
def testStartButtonCenteredHorizontally(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.startButtonPath(), testScene()) {
        case Some(EngineNode.ButtonWithState(btn, _)) =>
            let pos = Scene.globalPositionAt(HUDScene.startButtonPath(), testScene());
            let size = Button.getSize(btn);
            let centerX = pos#x + size#x / 2.0;
            Assert.assertEq(expected = 240.0, centerX)
        case _ => bug!("start_button not found")
    }

/// メッセージラベルの位置（センタリング基準点）
@Test
def testMessageLabelPosition(): Unit \ Assert =
    let pos = Scene.globalPositionAt(HUDScene.messageLabelPath(), testScene());
    Assert.assertEq(expected = (240.0, 320.0), vecToTuple(pos))

/// メッセージラベルの初期テキストが "Dodge the\nCreeps" であること
@Test
def testMessageLabelInitialText(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.messageLabelPath(), testScene()) {
        case Some(EngineNode.Label2DWithState(label, _)) =>
            Assert.assertEq(expected = "Dodge the\nCreeps", Label2D.getText(label))
        case _ => bug!("message_label not found")
    }

/// メッセージラベルとスタートボタンの水平中心が揃っていること
@Test
def testLabelAndButtonAlignedHorizontally(): Unit \ Assert =
    let labelPos = Scene.globalPositionAt(HUDScene.messageLabelPath(), testScene());
    let labelCenterX = labelPos#x;  // centered=true なので position.x が中心
    match Scene.getEngineNode(HUDScene.startButtonPath(), testScene()) {
        case Some(EngineNode.ButtonWithState(btn, _)) =>
            let btnPos = Scene.globalPositionAt(HUDScene.startButtonPath(), testScene());
            let btnSize = Button.getSize(btn);
            let btnCenterX = btnPos#x + btnSize#x / 2.0;
            Assert.assertEq(expected = labelCenterX, btnCenterX)
        case _ => bug!("start_button not found")
    }

/// スタートボタンがメッセージラベルの下に配置されていること
@Test
def testStartButtonBelowMessageLabel(): Unit \ Assert =
    let labelPos = Scene.globalPositionAt(HUDScene.messageLabelPath(), testScene());
    let btnPos = Scene.globalPositionAt(HUDScene.startButtonPath(), testScene());
    Assert.assertTrue(btnPos#y > labelPos#y)

/// スタートボタンが初期表示状態であること（Menu フェーズ）
@Test
def testStartButtonVisibleOnMenu(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.startButtonPath(), testScene()) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("start_button not found")
    }

/// ScoreLabel が初期表示状態であること（Godot 準拠: 常時表示）
@Test
def testScoreLabelVisibleInitially(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.scoreLabelPath(), testScene()) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("score_label not found")
    }

/// ScoreLabel の初期テキストが "0" であること
@Test
def testScoreLabelInitialText(): Unit \ Assert =
    match Scene.getEngineNode(HUDScene.scoreLabelPath(), testScene()) {
        case Some(EngineNode.Label2DWithState(label, _)) =>
            Assert.assertEq(expected = "0", Label2D.getText(label))
        case _ => bug!("score_label not found")
    }

/// MessageTimer が存在し、状態が MessageTimer であること
@Test
def testMessageTimerExists(): Unit \ Assert =
    match Scene.getState(HUDScene.messageTimerPath(), testScene()) {
        case Some(GameData.MessageTimer) => Assert.assertTrue(true)
        case _ => bug!("message_timer not found or wrong state")
    }

/// TitleTimer が存在し、状態が TitleTimer であること
@Test
def testTitleTimerExists(): Unit \ Assert =
    match Scene.getState(HUDScene.titleTimerPath(), testScene()) {
        case Some(GameData.TitleTimer) => Assert.assertTrue(true)
        case _ => bug!("title_timer not found or wrong state")
    }

// ========================================================================
// パイプライン各ステップでの衝突追跡
// ========================================================================

/// applyInput 後もプレイヤーが表示されていること（衝突前）
@Test
def testPipelineStep1_applyInputKeepsVisible(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterInput = PlayerScene.applyInput({x = 1.0, y = 0.0}, scene);
    match Scene.getEngineNode("player" :: Nil, afterInput) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// process 後もプレイヤーが表示されていること
@Test
def testPipelineStep2_processKeepsVisible(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterProcess = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false))(scene));
    match Scene.getEngineNode("player" :: Nil, afterProcess) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// physicsProcess 後もプレイヤーが表示されていること
@Test
def testPipelineStep3_physicsKeepsVisible(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterPhysics = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity()))(scene));
    match Scene.getEngineNode("player" :: Nil, afterPhysics) {
        case Some(en) => Assert.assertTrue(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// emitCollision 後にプレイヤーが非表示になること（衝突で hide される）
@Test
def testPipelineStep4_collisionHidesPlayer(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterCollision = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision)(scene));
    match Scene.getEngineNode("player" :: Nil, afterCollision) {
        case Some(en) => Assert.assertFalse(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// emitCollision 直前の detectOverlaps で重なりが検出されること
@Test
def testPipelineStep4_overlapsDetected(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterPhysics = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity()))(scene));
    let overlaps = AreaEvent.detectOverlaps(afterPhysics);
    Assert.assertTrue(not List.isEmpty(overlaps))

/// 完全パイプライン後もプレイヤーが非表示のままであること
@Test
def testPipelineStep5_fullPipelineKeepsHidden(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    let afterFull = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision
        >> GameEngine.emitScreenNotify(screenWidth = Game.screenWi(), screenHeight = Game.screenHi())
        >> GameEngine.emitTimers)(scene));
    match Scene.getEngineNode("player" :: Nil, afterFull) {
        case Some(en) => Assert.assertFalse(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

/// 2フレーム目: GameOver フェーズの engineUpdate 後もプレイヤーが非表示のままであること
@Test
def testPipelineStep6_gameOverProcessKeepsHidden(): Unit \ Assert =
    let scene = withMockEngine(() ->
        Scene.processAll(0.0, false, testScene()
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> MobScene.spawnMob("mob_test", {x = 260.0, y = 450.0}, 99)));
    // Frame 1: collision hides player
    let afterFrame1 = withMockEngine(() ->
        (PlayerScene.applyInput({x = 1.0, y = 0.0})
        >> GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision
        >> GameEngine.emitScreenNotify(screenWidth = Game.screenWi(), screenHeight = Game.screenHi())
        >> GameEngine.emitTimers)(scene));
    // Frame 2: GameOver phase — engineUpdate のみ（applyInput なし）
    let afterFrame2 = withMockEngine(() ->
        (GameEngine.process(0.016, false)
        >> GameEngine.physicsProcess(0.016, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision
        >> GameEngine.emitScreenNotify(screenWidth = Game.screenWi(), screenHeight = Game.screenHi())
        >> GameEngine.emitTimers)(afterFrame1));
    match Scene.getEngineNode("player" :: Nil, afterFrame2) {
        case Some(en) => Assert.assertFalse(CanvasItem.isVisible(en))
        case None => bug!("player not found")
    }

// ========================================================================
// AudioStreamPlayer: オーディオエフェクト呼び出し
// ========================================================================

/// newGame で BGM が再生される
@Test
def testNewGamePlaysMusic(): Unit \ Assert =
    let (_, calls) = recordAudio(() -> {
        discard Game.newGame(testState())
    });
    Assert.assertEq(expected = "play:music" :: Nil, calls)

/// gameOver で BGM 停止 + 死亡 SE 再生
@Test
def testGameOverStopsMusicAndPlaysDeath(): Unit \ Assert =
    let (_, calls) = recordAudio(() -> {
        discard Game.gameOver(testState())
    });
    Assert.assertEq(expected = "stop:music" :: "play:death" :: Nil, calls)
