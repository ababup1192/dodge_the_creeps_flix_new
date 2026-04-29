// Game — Dodge the Creeps ゲーム専用の GameData 定義とシーン構築・ゲームループ

/// ゲーム固有の状態データ
pub enum GameData {
    case PlayerData({velocity = Vec2.Vec2})
    case StaticData
}

pub type alias GameState = {
    scene = Scene[GameData]
}

// ── Node 実装 ──

instance Node[GameData] {
    redef process(delta: Float64, node: EngineNode[GameData],
                    _path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) =
        let dt = Float64.truncateToFloat32(delta);
        match node {
            case EngineNode.AnimSprite2DWithState(sprite, GameData.PlayerData(r)) =>
                let moved = PlayerScene.movePlayer(dt, sprite, r);
                (EngineNode.AnimSprite2DWithState(moved, GameData.PlayerData(r)), scene)
            case _ => (node, scene)
        }
}

// ── AreaHandler 実装 ──

instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath: NodePath, _selfState: GameData,
                          _otherPath: NodePath, _otherState: GameData,
                          scene: Scene[GameData]): Scene[GameData] = scene
}

mod Game {

    // ========================================================================
    // 画面定数
    // ========================================================================

    pub def screenW(): Float32 = 480.0f32
    pub def screenH(): Float32 = 720.0f32
    pub def screenWi(): Int32 = 480
    pub def screenHi(): Int32 = 720

    // ========================================================================
    // 初期状態構築
    // ========================================================================

    pub def buildState(_fontAtlas: FontAtlas): GameState =
        { scene = Scene.empty() |> PlayerScene.addPlayer }

    // ========================================================================
    // 入力
    // ========================================================================

    /// WASD / 矢印キーから方向ベクトルを返す
    pub def readInputDirection(): Vec2.Vec2 \ Engine.Game =
        let xDir =
            (if (Engine.Game.isKeyPressed(Engine.Key.D))      1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Right))   1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.A))      -1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Left))   -1.0f32 else 0.0f32);
        let yDir =
            (if (Engine.Game.isKeyPressed(Engine.Key.S))      1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Down))    1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.W))      -1.0f32 else 0.0f32) +
            (if (Engine.Game.isKeyPressed(Engine.Key.Up))     -1.0f32 else 0.0f32);
        {x = xDir, y = yDir}

    // ========================================================================
    // メインループ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ Engine.Game =
        gameLoop(fontAtlas, buildState(fontAtlas))

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game =
        if (Engine.Game.shouldClose()) ()
        else if (Engine.Game.isKeyPressed(Engine.Key.Escape)) ()
        else {
            let dt = Engine.Game.getDeltaTime();
            let dir = readInputDirection();
            { scene = state#scene
                |> PlayerScene.applyInput(dir)
                |> GameEngine.update(dt, false)
              | state }
                |> gameLoop(fontAtlas)
        }
}
