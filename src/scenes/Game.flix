// Game — Dodge the Creeps ゲーム専用の GameData 定義とシーン構築・ゲームループ

/// ゲーム固有の状態データ
pub enum GameData {
    case PlayerData
    case StaticData
}

pub type alias GameState = {
    scene = Scene[GameData]
}

// ── Node 実装 ──

instance Node[GameData] {
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
    // プレイヤー定数
    // ========================================================================

    /// プレイヤー初期位置（画面中央）
    pub def playerStart(): Vec2.Vec2 = {x = 240.0f32, y = 360.0f32}

    /// プレイヤーのアニメーション定義
    pub def playerAnimations(): Map[String, List[String]] =
        Map#{
            "walk" => ("playerGrey_walk1" :: "playerGrey_walk2" :: Nil),
            "up" => ("playerGrey_up1" :: "playerGrey_up2" :: Nil)
        }

    // ========================================================================
    // 初期状態構築
    // ========================================================================

    pub def buildState(_fontAtlas: FontAtlas): GameState =
        let scene = Scene.empty()
            |> Scene.addNode("player",
                EngineNode.AnimSprite2DWithState(
                    AnimatedSprite2D.make(
                        playerAnimations(),
                        initialAnimation = "walk",
                        fps = 6.0f32,
                        playerStart(),
                        {x = 1.0f32, y = 1.0f32}),
                    GameData.PlayerData));
        { scene = scene }

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
            { scene = GameEngine.update(dt, false, state#scene) | state }
                |> gameLoop(fontAtlas)
        }
}
