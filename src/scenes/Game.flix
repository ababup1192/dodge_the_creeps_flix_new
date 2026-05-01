// Game — Dodge the Creeps のノードタグ定義・trait instance・シーン構築・ゲームループ

/// ゲームフェーズ
pub enum GamePhase with Eq {
    case Menu
    case GetReady
    case Playing
    case GameOver
}

/// Mob のスポーン連番 ID
pub type alias MobId = Int32

/// スコア値
pub type alias Score = Int32

/// 各ノードに付与する識別タグ（Scene[NodeTag] の型パラメータ）
pub enum NodeTag {
    case PlayerSprite(PlayerScene.PlayerData)
    case PlayerArea
    case MobBody(MobId)
    case MobTimer(MobId)
    case StartTimer
    case ScoreTimer
    case ScoreLabel(Score)
    case StartButton
    case MessageTimer
    case TitleTimer
    case NoTag
}

pub type alias GameState = {
    scene = Scene[NodeTag],
    phase = GamePhase
}

// ── Node 実装 ──

instance Node[NodeTag] {
    redef ready(node: EngineNode[NodeTag],
                _path: NodePath, scene: Scene[NodeTag]): (EngineNode[NodeTag], Scene[NodeTag]) \ {GameEngine.Game, Math.Random} =
        checked_ecast(match node {
            case EngineNode.AnimSprite2DWithState(sprite, NodeTag.PlayerSprite(playerData)) =>
                let (readySprite, readyPlayerData) = PlayerScene.ready(sprite, playerData);
                (EngineNode.AnimSprite2DWithState(readySprite,
                    NodeTag.PlayerSprite(readyPlayerData)), scene
                )
            case _ => (node, scene)
        })

    redef process(delta: Float64, node: EngineNode[NodeTag],
                    _path: NodePath, scene: Scene[NodeTag]): (EngineNode[NodeTag], Scene[NodeTag]) \ Math.Random =
        checked_ecast(match node {
            case EngineNode.AnimSprite2DWithState(sprite, NodeTag.PlayerSprite(playerData)) =>
                let movedSprite = PlayerScene.process(delta, sprite, playerData);
                (EngineNode.AnimSprite2DWithState(movedSprite,
                    NodeTag.PlayerSprite(playerData))
                , scene)
            case _ => (node, scene)
        })
}

// 衝突判定
instance AreaHandler[NodeTag] {
    pub def onAreaEntered(_selfPath: NodePath, selfState: NodeTag,
                          _otherPath: NodePath, otherState: NodeTag,
                          scene: Scene[NodeTag]): Scene[NodeTag] =
        match (selfState, otherState) {
            case (NodeTag.PlayerArea, NodeTag.MobBody(_)) =>
                scene |> PlayerScene.mapPlayer(
                    (sprite, playerData) ->
                        (CanvasItem.hide(sprite), { hit = true | playerData }),
                    Area2D.setMonitoring(false))
            case _ => scene
        }
}

// ── ScreenNotifyHandler 実装 ──

instance ScreenNotifyHandler[NodeTag] {
    redef onScreenExited(path: NodePath, state: NodeTag,
                         scene: Scene[NodeTag]): Scene[NodeTag] =
        match state {
            case NodeTag.MobBody(_) => Scene.removeAt(path, scene)
            case _ => scene
        }
}

// ── TimerHandler 実装 ──

instance TimerEvent.TimerHandler[NodeTag] {
    redef onTimeout(timerPath: NodePath, state: NodeTag,
                    scene: Scene[NodeTag]): Scene[NodeTag] \ Math.Random =
        match state {
            case NodeTag.MobTimer(counter) =>
                let newScene = Game.spawnMobFromPath(counter, scene);
                // カウンタをインクリメント
                Scene.setState(timerPath, NodeTag.MobTimer(counter + 1), newScene)
            case NodeTag.StartTimer =>
                scene
                    |> Scene.mapEngineNode(Game.mobTimerPath(), EngineNode.mapTimer(Timer.start))
                    |> Scene.mapEngineNode(Game.scoreTimerPath(), EngineNode.mapTimer(Timer.start))
                    |> HUDScene.hideMessage
            case NodeTag.ScoreTimer =>
                // スコアをインクリメントし、ラベルを更新する（Godot の _on_ScoreTimer_timeout 相当）
                HUDScene.incrementScore(scene)
            case NodeTag.MessageTimer =>
                scene
                    |> HUDScene.showMessage("Dodge the\nCreeps")
                    |> HUDScene.startTitleTimer
            case NodeTag.TitleTimer =>
                scene
                    |> HUDScene.showStartButton
            case _ => scene
        }
}

mod Game {

    // ========================================================================
    // ノード名・パス定数
    // ========================================================================

    def mobTimerName(): String = "mob_timer"
    def startTimerName(): String = "start_timer"
    def scoreTimerName(): String = "score_timer"

    pub def mobTimerPath(): NodePath = mobTimerName() :: Nil
    pub def startTimerPath(): NodePath = startTimerName() :: Nil
    pub def scoreTimerPath(): NodePath = scoreTimerName() :: Nil

    // オーディオキー
    def musicKey(): String = "music"
    def deathKey(): String = "death"

    // ========================================================================
    // 画面定数
    // ========================================================================

    pub def screenWi(): Int32 = 480
    pub def screenHi(): Int32 = 720

    // ========================================================================
    // Mob スポーン（TimerHandler から呼ばれる）
    // ========================================================================

    /// Path2D ベースで Mob をスポーンする
    pub def spawnMobFromPath(counter: Int32, scene: Scene[NodeTag]): Scene[NodeTag] \ Math.Random =
        let t = Math.Random.randomFloat64();
        let sample = Path2D.sample(t, Path2D.screenEdgePath(screenWi(), screenHi()));
        let name = MobScene.mobName(counter);
        MobScene.spawnMob(name, sample#position, sample#direction, counter, scene)

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
            NodeTag.NoTag
        );
        {   scene = Scene.empty()
                |> Scene.addNode("background", bgNode)
                |> PlayerScene.addPlayer
                |> Scene.addNode(mobTimerName(), EngineNode.TimerWithState(mobTimer, NodeTag.MobTimer(0)))
                |> Scene.addNode("mob_path", EngineNode.Path2DWithState(mobPath, NodeTag.NoTag))
                |> Scene.addNode(startTimerName(), EngineNode.TimerWithState(startTimer, NodeTag.StartTimer))
                |> Scene.addNode(scoreTimerName(), EngineNode.TimerWithState(scoreTimer, NodeTag.ScoreTimer))
                |> HUDScene.addHUD(fontAtlas),
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
        AudioStreamPlayer.play(musicKey());
        let scene = state#scene
            |> Scene.removeGroup(MobScene.mobGroup())
            |> PlayerScene.start({x = 240.0, y = 450.0})
            |> PlayerScene.mapPlayerSprite((sprite, playerData) ->
                (sprite, {velocity = Vec2.zero() | playerData}))
            |> HUDScene.showMessage("Get Ready")
            |> HUDScene.updateScore(0)
            |> HUDScene.hideStartButton
            |> Scene.mapEngineNode(startTimerPath(), EngineNode.mapTimer(Timer.start));
        { scene = scene, phase = GamePhase.GetReady }

    /// Playing → GameOver: タイマー停止、GameOver メッセージ、MessageTimer 開始、BGM 停止 + 死亡 SE 再生
    pub def gameOver(state: GameState): GameState \ GameEngine.Audio =
        AudioStreamPlayer.stop(musicKey());
        AudioStreamPlayer.play(deathKey());
        let scene = state#scene
            |> Scene.mapEngineNode(mobTimerPath(), EngineNode.mapTimer(Timer.stop))
            |> Scene.mapEngineNode(scoreTimerPath(), EngineNode.mapTimer(Timer.stop))
            |> HUDScene.showMessage("Game Over")
            |> HUDScene.hideStartButton
            |> HUDScene.startMessageTimer;
        { scene = scene, phase = GamePhase.GameOver | state }

    // ========================================================================
    // 共通パイプライン
    // ========================================================================

    /// エンジン更新パイプライン（process → physics → collision → screen → timers）
    def engineUpdate(dt: Float64, scene: Scene[NodeTag]): Scene[NodeTag] \ {GameEngine.Game, Math.Random} =
        (GameEngine.process(dt, false)
        >> GameEngine.physicsProcess(dt, false, PhysicsStep.defaultGravity())
        >> GameEngine.emitCollision
        >> GameEngine.emitScreenNotify(screenWidth = screenWi(), screenHeight = screenHi())
        >> GameEngine.emitTimers)(scene)

    /// 入力読み取り + エンジン更新
    def inputAndUpdate(dt: Float64, scene: Scene[NodeTag]): Scene[NodeTag] \ {GameEngine.Game, Math.Random} =
        let dir = readInputDirection();
        engineUpdate(dt, PlayerScene.applyInput(dir)(scene))

    // ========================================================================
    // メインループ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ {GameEngine.Game, GameEngine.Audio, Math.Random} =
        let state = buildState(fontAtlas);
        gameLoop(fontAtlas, state)

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ {GameEngine.Game, GameEngine.Audio, Math.Random} =
        if (GameEngine.Game.shouldClose()) ()
        else if (GameEngine.Game.isKeyPressed(GameEngine.Key.Escape)) ()
        else {
            let dt = GameEngine.Game.getDeltaTime();
            let nextState: GameState = match state#phase {
                case GamePhase.Menu =>
                    let updatedScene = ButtonEvent.updateButtons(state#scene);
                    let enterPressed = GameEngine.Game.isKeyPressed(GameEngine.Key.Enter);
                    let spacePressed = GameEngine.Game.isKeyPressed(GameEngine.Key.Space);
                    let startPressed = HUDScene.isStartButtonJustPressed(updatedScene) or enterPressed or spacePressed;
                    if (startPressed)
                        newGame({ scene = HUDScene.clearStartButtonPress(updatedScene) | state })
                    else
                        { scene = updatedScene | state }
                case GamePhase.GetReady =>
                    let updatedScene = inputAndUpdate(dt, state#scene);
                    let nextPhase = match Scene.getEngineNode(mobTimerPath(), updatedScene) {
                        case Some(EngineNode.TimerWithState(timer, _)) =>
                            if (Timer.isRunning(timer)) GamePhase.Playing else GamePhase.GetReady
                        case _ => GamePhase.GetReady
                    };
                    { scene = updatedScene, phase = nextPhase | state }
                case GamePhase.Playing =>
                    let updatedScene = inputAndUpdate(dt, state#scene);
                    if (PlayerScene.getPlayerData(updatedScene)#hit)
                        gameOver({ scene = updatedScene | state })
                    else
                        { scene = updatedScene | state }
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
