// Game — Dodge the Creeps ゲーム専用の GameData 定義とシーン構築・ゲームループ

/// ゲーム固有の状態データ
pub enum GameData {
    case Player(PlayerScene.PlayerNode, PlayerScene.PlayerData)
    case PlayerArea
    case MobData(Int32)
    case MobSprite
    case MobNotifier
    case MobTimer(Int32)
    case MobPath
}

pub type alias GameState = {
    scene = Scene[GameData],
    mobCounter = Int32
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
            case EngineNode.TimerWithState(timer, GameData.MobTimer(counter)) =>
                (EngineNode.TimerWithState(Timer.start(timer), GameData.MobTimer(counter)), scene)
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
                PlayerScene.mapSprite(CanvasItem.hide, scene)
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

    pub def buildState(_fontAtlas: FontAtlas): GameState =
        let timer = Timer.make(0.5) |> Timer.setOneShot(false);
        let mobPath = Path2D.screenEdgePath(screenWi(), screenHi());
        {   scene = Scene.empty()
                |> PlayerScene.addPlayer
                |> Scene.addNode("mob_timer",
                    EngineNode.TimerWithState(timer, GameData.MobTimer(0)))
                |> Scene.addNode("mob_path",
                    EngineNode.Path2DWithState(mobPath, GameData.MobPath)),
            mobCounter = 0
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
    // メインループ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ GameEngine.Game =
        let state = buildState(fontAtlas);
        let startedState: GameState = {
            scene = PlayerScene.start({x = 240.0, y = 360.0}, state#scene)
            | state };
        gameLoop(fontAtlas, startedState)

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ GameEngine.Game =
        if (GameEngine.Game.shouldClose()) ()
        else if (GameEngine.Game.isKeyPressed(GameEngine.Key.Escape)) ()
        else {
            let dt = GameEngine.Game.getDeltaTime();
            let dir = readInputDirection();
            let updateScene =
                PlayerScene.applyInput(dir)
                >> GameEngine.process(dt, false)
                >> GameEngine.physicsProcess(dt, false,  PhysicsStep.defaultGravity())
                >> GameEngine.emitCollision
                >> GameEngine.emitScreenNotify(screenWidth = screenWi(), screenHeight = screenHi())
                >> GameEngine.emitTimers;
            let updatedScene = updateScene(state#scene);
            GameEngine.render(updatedScene);
            { scene = updatedScene | state }
                |> gameLoop(fontAtlas)
        }
}
