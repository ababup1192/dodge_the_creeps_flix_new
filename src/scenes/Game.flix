// Game — Dodge the Creeps ゲーム専用の GameData 定義とシーン構築・ゲームループ

/// ゲーム固有の状態データ
pub enum GameData {
    case Player(PlayerScene.PlayerNode, PlayerScene.PlayerData)
    case PlayerArea
    case MobData
    case MobSprite
    case MobNotifier
}

pub type alias GameState = {
    scene = Scene[GameData],
    mobSpawnTimer = Float64,
    mobCounter = Int32
}

// ── Node 実装 ──

instance Node[GameData] {
    redef ready(node: EngineNode[GameData],
                _path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) \ GameEngine.Game =
        match node {
            case EngineNode.AnimSprite2DWithState(sprite, GameData.Player(playerNode, playerData)) =>
                let (readySprite, readyPlayerData) = PlayerScene.ready(sprite, playerData);
                (EngineNode.AnimSprite2DWithState(readySprite,
                    GameData.Player({ sprite = readySprite | playerNode }, readyPlayerData)), scene
                )
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
            case (GameData.PlayerArea, GameData.MobData) =>
                PlayerScene.mapSprite(CanvasItem.hide, scene)
            case _ => scene
        }
}

// ── ScreenNotifyHandler 実装 ──

instance ScreenNotifyHandler[GameData] {
    redef onScreenExited(path: NodePath, state: GameData,
                         scene: Scene[GameData]): Scene[GameData] =
        match state {
            case GameData.MobData => Scene.removeAt(path, scene)
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
    // 初期状態構築
    // ========================================================================

    pub def buildState(_fontAtlas: FontAtlas): GameState =
        {   scene = Scene.empty() |> PlayerScene.addPlayer,
            mobSpawnTimer = 1.0,
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
    // メインル��プ
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
            let gravity = PhysicsStep.defaultGravity();
            let updateScene =
                PlayerScene.applyInput(dir)
                >> GameEngine.process(dt, false)
                >> GameEngine.physics(dt, false, gravity)
                >> GameEngine.collisions
                >> GameEngine.offscreen(screenWidth = screenWi(), screenHeight = screenHi());
            let updatedScene = updateScene(state#scene);
            GameEngine.render(updatedScene);
            { scene = updatedScene | state }
                |> MobScene.maybeSpawnMob(dt)
                |> gameLoop(fontAtlas)
        }
}
