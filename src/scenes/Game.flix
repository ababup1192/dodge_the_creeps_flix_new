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
                _path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) \ Engine.Game =
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

// ── AreaHandler 実装 ──

instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath: NodePath, _selfState: GameData,
                          _otherPath: NodePath, _otherState: GameData,
                          scene: Scene[GameData]): Scene[GameData] = scene
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
    pub def readInputDirection(): Vec2.Vec2 \ Engine.Game =
        let xDir =
            (if (Engine.Game.isKeyPressed(Engine.Key.D))      1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Right))   1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.A))      -1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Left))   -1.0 else 0.0);
        let yDir =
            (if (Engine.Game.isKeyPressed(Engine.Key.S))      1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Down))    1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.W))      -1.0 else 0.0) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Up))     -1.0 else 0.0);
        {x = xDir, y = yDir}

    // ========================================================================
    // メインル��プ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ Engine.Game =
        let state = buildState(fontAtlas);
        let startedState: GameState = {
            scene = PlayerScene.start({x = 240.0, y = 360.0}, state#scene)
            | state };
        gameLoop(fontAtlas, startedState)

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game =
        if (Engine.Game.shouldClose()) ()
        else if (Engine.Game.isKeyPressed(Engine.Key.Escape)) ()
        else {
            let dt = Engine.Game.getDeltaTime();
            let dir = readInputDirection();
            let gravity = PhysicsStep.defaultGravity();
            let screenW = Int32.toFloat64(screenWi());
            let screenH = Int32.toFloat64(screenHi());
            { scene = state#scene
                |> PlayerScene.applyInput(dir)
                |> GameEngine.updateFull(dt, false, gravity,
                    screenWidth = screenW, screenHeight = screenH)
              | state }
                |> MobScene.maybeSpawnMob(dt)
                |> gameLoop(fontAtlas)
        }
}
