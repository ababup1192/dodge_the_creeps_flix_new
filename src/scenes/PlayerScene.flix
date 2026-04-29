// PlayerScene — Dodge the Creeps プレイヤーのシーン構築・移動・アニメーション

mod PlayerScene {

    // ========================================================================
    // 定数
    // ========================================================================

    /// プレイヤーノード名
    pub def playerName(): String = "player"

    /// プレイヤー初期位置（画面中央）
    pub def playerStart(): Vec2.Vec2 = {x = 240.0f32, y = 360.0f32}

    /// プレイヤー移動速度（px/秒）
    pub def playerSpeed(): Float32 = 400.0f32

    /// π（円周率）
    def pi(): Float64 = 3.14159265358979

    /// プレイヤーのアニメーション定義
    pub def playerAnimations(): Map[String, List[String]] =
        Map#{
            "walk" => ("playerGrey_walk1" :: "playerGrey_walk2" :: Nil),
            "up" => ("playerGrey_up1" :: "playerGrey_up2" :: Nil)
        }

    // ========================================================================
    // シーン構築
    // ========================================================================

    /// プレイヤーノードをシーンに追加する
    pub def addPlayer(scene: Scene[GameData]): Scene[GameData] =
        Scene.addNode(playerName(),
            EngineNode.AnimSprite2DWithState(
                AnimatedSprite2D.make(
                    playerAnimations(),
                    initialAnimation = "walk",
                    fps = 6.0f32,
                    playerStart(),
                    {x = 1.0f32, y = 1.0f32}),
                GameData.PlayerData({velocity = Vec2.zero()})),
            scene)

    // ========================================================================
    // 毎フレーム移動（Node.process から呼ばれる）
    // ========================================================================

    /// 速度に応じてプレイヤーを移動し、画面範囲にクランプする
    pub def movePlayer(dt: Float32, sprite: AnimatedSprite2D,
                       r: {velocity = Vec2.Vec2}): AnimatedSprite2D =
        let pos = Node2D.getPosition(sprite);
        let newPos = Vec2.clamp(
            Vec2.add(pos, Vec2.mul(r#velocity, dt)),
            Vec2.zero(),
            {x = Game.screenW(), y = Game.screenH()});
        Node2D.setPosition(newPos, sprite)

    // ========================================================================
    // 入力適用
    // ========================================================================

    /// 方向ベクトルに応じてプレイヤーの速度とアニメーションを更新する
    pub def applyInput(dir: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        let velocity = if (Vec2.length(dir) > 0.0f32)
                Vec2.mul(Vec2.normalized(dir), playerSpeed())
            else
                Vec2.zero();
        scene
            |> Scene.mapState(playerName() :: Nil, _ ->
                GameData.PlayerData({velocity = velocity}))
            |> Scene.mapEngineNode(playerName() :: Nil,
                EngineNode.mapAnimSprite2D(setPlayerAnimation(dir)))

    // ========================================================================
    // アニメーション制御
    // ========================================================================

    /// アニメーション名が変わった場合のみフレームをリセットして再生する
    def switchAnim(name: String, sprite: AnimatedSprite2D): AnimatedSprite2D =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        if (r#currentAnimation == name)
            AnimatedSprite2D.AnimatedSprite2D({playing = true | r})
        else
            AnimatedSprite2D.play(name, sprite)

    /// 水平反転を設定する
    def setFlipH(h: Bool, sprite: AnimatedSprite2D): AnimatedSprite2D =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        AnimatedSprite2D.AnimatedSprite2D({flipH = h | r})

    /// 垂直反転を設定する
    def setFlipV(v: Bool, sprite: AnimatedSprite2D): AnimatedSprite2D =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        AnimatedSprite2D.AnimatedSprite2D({flipV = v | r})

    /// 入力方向に応じてアニメーション・反転・回転を設定する
    /// 本家 Godot 準拠: 横移動は walk + flipH + flipV=false、縦移動は up + rotation（下向きで PI）
    pub def setPlayerAnimation(dir: Vec2.Vec2, sprite: AnimatedSprite2D): AnimatedSprite2D =
        if (dir#x != 0.0f32)
            sprite |> switchAnim("walk")
                   |> setFlipV(false)
                   |> setFlipH(dir#x < 0.0f32)
                   |> Node2D.setRotation(0.0)
        else if (dir#y != 0.0f32)
            sprite |> switchAnim("up")
                   |> Node2D.setRotation(if (dir#y > 0.0f32) pi() else 0.0)
        else
            AnimatedSprite2D.stop(sprite)
}
