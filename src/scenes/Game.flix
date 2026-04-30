// Game — Dodge the Creeps ゲーム専用の GameData 定義とシーン構築・ゲームループ

/// ゲームフェーズ
pub enum GamePhase with Eq {
    case Menu
    case GetReady
    case Playing
    case GameOver
}

/// ゲーム固有の状態データ
pub enum GameData {
    case Player(PlayerScene.PlayerNode, PlayerScene.PlayerData)
    case PlayerArea
    case PlayerTrail
    case MobData(Int32)
    case MobSprite
    case MobNotifier
    case MobTimer(Int32)
    case MobPath
    case Background
    case StartTimer
    case ScoreTimer
    case ScoreLabel(Int32)
    case MessageLabel
    case HUDLayer
    case StartButton
    case MessageTimer
    case TitleTimer
}

pub type alias GameState = {
    scene = Scene[GameData],
    mobCounter = Int32,
    phase = GamePhase
}

// ── Node 実装 ──

instance Node[GameData] {
    redef ready(node: EngineNode[GameData],
                path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) \ GameEngine.Game =
        match node {
            case EngineNode.AnimSprite2DWithState(sprite, GameData.Player(playerNode, playerData)) =>
                let (readySprite, readyPlayerData) = PlayerScene.ready(sprite, playerData);
                (EngineNode.AnimSprite2DWithState(readySprite,
                    GameData.Player({ sprite = readySprite | playerNode }, readyPlayerData)), scene
                )
            case EngineNode.RigidBody2DWithState(_, GameData.MobData(_)) =>
                let rot = Node2D.getRotation(node);
                let newScene = unsafe IO { Math.Random.runWithIO(_ -> MobScene.ready(path, rot, scene)) };
                // MobScene.ready が path のノードに linearVelocity を設定するため、
                // 更新済みノードをシーンから取り直す（foldNodes の上書きを防ぐ）
                match Scene.getEngineNode(path, newScene) {
                    case Some(en) => (en, newScene)
                    case None => (node, newScene)
                }
            case _ => (node, scene)
        }

    redef process(delta: Float64, node: EngineNode[GameData],
                    _path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) =
        match node {
            case EngineNode.AnimSprite2DWithState(sprite, GameData.Player(playerNode, playerData)) =>
                let movedSprite = PlayerScene.process(delta, sprite, playerData);
                (EngineNode.AnimSprite2DWithState(movedSprite,
                    GameData.Player({ sprite = movedSprite | playerNode }, playerData))
                , scene)
            case _ => (node, scene)
        }
}

// 衝突判定
instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath: NodePath, selfState: GameData,
                          _otherPath: NodePath, otherState: GameData,
                          scene: Scene[GameData]): Scene[GameData] =
        match (selfState, otherState) {
            case (GameData.PlayerArea, GameData.MobData(_)) =>
                scene
                    |> PlayerScene.mapSprite(CanvasItem.hide)
                    |> Scene.mapEngineNode("player" :: "trail" :: Nil, CanvasItem.hide)
            case _ => scene
        }
}

// ── ScreenNotifyHandler 実装 ──

instance ScreenNotifyHandler[GameData] {
    redef onScreenExited(path: NodePath, state: GameData,
                         scene: Scene[GameData]): Scene[GameData] =
        match state {
            case GameData.MobData(_) => Scene.removeAt(path, scene)
            case _ => scene
        }
}

// ── TimerHandler 実装 ──

instance TimerEvent.TimerHandler[GameData] {
    redef onTimeout(timerPath: NodePath, state: GameData,
                    scene: Scene[GameData]): Scene[GameData] =
        match state {
            case GameData.MobTimer(counter) =>
                let newScene = unsafe IO { Math.Random.runWithIO(_ ->
                    Game.spawnMobFromPath(counter, scene)
                ) };
                // カウンタをインクリメント
                Scene.setState(timerPath, GameData.MobTimer(counter + 1), newScene)
            case GameData.StartTimer =>
                scene
                    |> Scene.mapEngineNode("mob_timer" :: Nil, EngineNode.mapTimer(Timer.start))
                    |> Scene.mapEngineNode("score_timer" :: Nil, EngineNode.mapTimer(Timer.start))
                    |> HUDScene.hideMessage
            case GameData.ScoreTimer =>
                match Scene.getState(HUDScene.scoreLabelPath(), scene) {
                    case Some(GameData.ScoreLabel(score)) =>
                        HUDScene.updateScore(score + 1, scene)
                    case _ => scene
                }
            case GameData.MessageTimer =>
                scene
                    |> HUDScene.showMessage("Dodge the\nCreeps")
                    |> HUDScene.startTitleTimer
            case GameData.TitleTimer =>
                scene
                    |> HUDScene.showStartButton
            case _ => scene
        }
}

mod Game {

    // ========================================================================
    // 画面定数
    // ========================================================================

    pub def screenWi(): Int32 = 480
    pub def screenHi(): Int32 = 720

    // ========================================================================
    // Mob スポーン（TimerHandler から呼ばれる）
    // ========================================================================

    /// Path2D ベースで Mob をスポーンする
    pub def spawnMobFromPath(counter: Int32, scene: Scene[GameData]): Scene[GameData] \ Math.Random =
        let t = Math.Random.randomFloat64();
        let sample = Path2D.sample(t, Path2D.screenEdgePath(screenWi(), screenHi()));
        let name = MobScene.mobName(counter);
        let newScene = MobScene.spawnMob(name, sample#position, counter, scene);
        // direction を RigidBody2D の rotation に仮保存（ready で使う）
        let mobPath = name :: Nil;
        newScene
            |> Scene.mapEngineNode(mobPath,
                EngineNode.mapRigidBody2D(body -> Node2D.setRotation(sample#direction, body)))

    // ========================================================================
    // 初期状態構築
    // ========================================================================

    pub def buildState(fontAtlas: FontAtlas): GameState =
        let mobTimer = Timer.make(0.5) |> Timer.setOneShot(false);
        let startTimer = Timer.make(2.0);
        let scoreTimer = Timer.make(1.0) |> Timer.setOneShot(false);
        let mobPath = Path2D.screenEdgePath(screenWi(), screenHi());
        let bg = ColorRect.make(
            {x = 480.0, y = 720.0},
            {r = 0.219608f32, g = 0.372549f32, b = 0.380392f32}
        );
        let bgNode = EngineNode.ColorRectWithState(
            CanvasItem.setZIndex(-100, bg),
            GameData.Background
        );
        {   scene = Scene.empty()
                |> Scene.addNode("background", bgNode)
                |> PlayerScene.addPlayer
                |> Scene.addNode("mob_timer",
                    EngineNode.TimerWithState(mobTimer, GameData.MobTimer(0)))
                |> Scene.addNode("mob_path",
                    EngineNode.Path2DWithState(mobPath, GameData.MobPath))
                |> Scene.addNode("start_timer",
                    EngineNode.TimerWithState(startTimer, GameData.StartTimer))
                |> Scene.addNode("score_timer",
                    EngineNode.TimerWithState(scoreTimer, GameData.ScoreTimer))
                |> HUDScene.addHUD(fontAtlas),
            mobCounter = 0,
            phase = GamePhase.Menu
        }

    // ========================================================================
    // 入力
    // ========================================================================

    /// WASD / 矢印キーから方向ベクトルを返す
    pub def readInputDirection(): Vec2.Vec2 \ GameEngine.Game =
        let xDir =
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.D))      1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.Right))   1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.A))      -1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.Left))   -1.0 else 0.0);
        let yDir =
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.S))      1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.Down))    1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.W))      -1.0 else 0.0) +
            (if (GameEngine.Game.isKeyPressed(GameEngine.Key.Up))     -1.0 else 0.0);
        {x = xDir, y = yDir}

    // ========================================================================
    // フェーズ遷移
    // ========================================================================

    /// Menu/GameOver → GetReady: プレイヤー表示、スコアリセット、GetReady メッセージ、BGM 再生
    pub def newGame(state: GameState): GameState \ GameEngine.Audio =
        AudioStreamPlayer.play("music");
        let s0 = state#scene
            |> Scene.removeGroup(MobScene.mobGroup())
            |> PlayerScene.start({x = 240.0, y = 450.0});
        let pd = PlayerScene.extractPlayerData(s0);
        let scene = s0
            |> PlayerScene.setPlayerData({velocity = Vec2.zero() | pd})
            |> HUDScene.showMessage("Get Ready")
            |> HUDScene.updateScore(0)
            |> HUDScene.hideStartButton
            |> Scene.mapEngineNode("start_timer" :: Nil, EngineNode.mapTimer(Timer.start));
        { scene = scene, mobCounter = 0, phase = GamePhase.GetReady }

    /// Playing → GameOver: タイマー停止、GameOver メッセージ、MessageTimer 開始、BGM 停止 + 死亡 SE 再生
    pub def gameOver(state: GameState): GameState \ GameEngine.Audio =
        AudioStreamPlayer.stop("music");
        AudioStreamPlayer.play("death");
        let scene = state#scene
            |> Scene.mapEngineNode("mob_timer" :: Nil, EngineNode.mapTimer(Timer.stop))
            |> Scene.mapEngineNode("score_timer" :: Nil, EngineNode.mapTimer(Timer.stop))
            |> HUDScene.showMessage("Game Over")
            |> HUDScene.hideStartButton
            |> HUDScene.startMessageTimer;
        { scene = scene, phase = GamePhase.GameOver | state }

    // ========================================================================
    // 共通パイプライン
    // ========================================================================

    /// エンジン更新パイプライン（process → physics → collision → screen → timers）
    def engineUpdate(dt: Float64, scene: Scene[GameData]): Scene[GameData] \ GameEngine.Game =
        (GameEngine.process(dt, false)
        >> GameEngine.physicsProcess(dt, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision
        >> GameEngine.emitScreenNotify(screenWidth = screenWi(), screenHeight = screenHi())
        >> GameEngine.emitTimers)(scene)

    /// 入力読み取り + エンジン更新
    def inputAndUpdate(dt: Float64, scene: Scene[GameData]): Scene[GameData] \ GameEngine.Game =
        let dir = readInputDirection();
        engineUpdate(dt, PlayerScene.applyInput(dir)(scene))

    // ========================================================================
    // メインループ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ GameEngine.Game + GameEngine.Audio =
        let state = buildState(fontAtlas);
        gameLoop(fontAtlas, state)

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ GameEngine.Game + GameEngine.Audio =
        if (GameEngine.Game.shouldClose()) ()
        else if (GameEngine.Game.isKeyPressed(GameEngine.Key.Escape)) ()
        else {
            let dt = GameEngine.Game.getDeltaTime();
            let nextState: GameState = match state#phase {
                case GamePhase.Menu =>
                    let updatedScene = ButtonEvent.updateButtons(state#scene);
                    let enterPressed = GameEngine.Game.isKeyPressed(GameEngine.Key.Enter);
                    let startPressed = HUDScene.isStartButtonJustPressed(updatedScene) or enterPressed;
                    if (startPressed)
                        newGame({ scene = HUDScene.clearStartButtonPress(updatedScene) | state })
                    else
                        { scene = updatedScene | state }
                case GamePhase.GetReady =>
                    let updatedScene = inputAndUpdate(dt, state#scene);
                    let nextPhase = match Scene.getEngineNode("mob_timer" :: Nil, updatedScene) {
                        case Some(EngineNode.TimerWithState(timer, _)) =>
                            if (Timer.isRunning(timer)) GamePhase.Playing else GamePhase.GetReady
                        case _ => GamePhase.GetReady
                    };
                    { scene = updatedScene, phase = nextPhase | state }
                case GamePhase.Playing =>
                    let updatedScene = inputAndUpdate(dt, state#scene);
                    match Scene.getEngineNode("player" :: Nil, updatedScene) {
                        case Some(en) =>
                            if (not CanvasItem.isVisible(en))
                                gameOver({ scene = updatedScene | state })
                            else
                                { scene = updatedScene | state }
                        case None => { scene = updatedScene | state }
                    }
                case GamePhase.GameOver =>
                    let updatedScene = engineUpdate(dt, state#scene);
                    if (HUDScene.isStartButtonVisible(updatedScene))
                        { scene = updatedScene, phase = GamePhase.Menu | state }
                    else
                        { scene = updatedScene | state }
            };
            GameEngine.render(nextState#scene);
            gameLoop(fontAtlas, nextState)
        }
}
