// PlayerScene — Dodge the Creeps プレイヤーのシーン構築・移動・アニメーション

mod PlayerScene {
    use Node2D.setPosition
    use NodeBuilder.{position, rotation, show, hide}

    /// velocity: 現在の移動速度
    /// screenSize: ビューポートサイズ（クランプ用）
    /// hit: モブに衝突したかどうか（Godot の hit シグナル相当）
    pub type alias PlayerData = {velocity = Vec2.Vec2, screenSize = Vec2.Vec2, hit = Bool}

    pub type alias PlayerNode = { sprite = AnimatedSprite2D, area = Area2D }

    // ========================================================================
    // 定数
    // ========================================================================

    /// プレイヤーノード名
    def name(): String = "player"

    /// プレイヤーノードのパス
    def playerPath(): NodePath = name() :: Nil

    /// Area2D 子ノード名
    def areaName(): String = "area"

    /// Area2D 子ノードのパス
    def areaPath(): NodePath = name() :: areaName() :: Nil

    /// プレイヤー初期位置（Godot 版準拠）
    def startPosition(): Vec2.Vec2 = {x = 240.0, y = 450.0}

    /// プレイヤー移動速度（px/秒）
    def speed(): Float64 = 400.0

    /// π（円周率）
    def pi(): Float64 = 3.14159265358979

    def walkAnimation(): String = "walk"
    def upAnimation(): String = "up"

    /// プレイヤーの衝突形状（Godot: CapsuleShape2D radius=27, height=68）
    def playerCollisionShape(): CollisionShape2D =
        CollisionShape2D.CapsuleShape2D({radius = 27.0, height = 68.0, vertical = true})

    /// プレイヤーのアニメーション定義
    def playerAnimations(): Map[String, List[String]] =
        Map#{
            walkAnimation() => ("playerGrey_walk1" :: "playerGrey_walk2" :: Nil),
            upAnimation() => ("playerGrey_up1" :: "playerGrey_up2" :: Nil)
        }

    // ========================================================================
    // シーン構築
    // ========================================================================

    /// プレイヤーノードをシーンに追加する（Area2D 子ノード付き、初期非表示）
    pub def addPlayer(scene: Scene[GameData]): Scene[GameData] =
        let sprite = AnimatedSprite2D.make(
            playerAnimations(),
            initialAnimation = walkAnimation(),
            fps = 5.0,
            startPosition(),
            {x = 0.5, y = 0.5})
            |> CanvasItem.setZIndex(10);
        let area = Area2D.make(Vec2.zero(), playerCollisionShape());
        let playerNode: PlayerNode = { sprite = sprite, area = area };
        scene
            |> Scene.addNode(name(),
                EngineNode.AnimSprite2DWithState(sprite,
                    GameData.Player(playerNode, {velocity = Vec2.zero(), screenSize = Vec2.zero(), hit = false})))
            |> Scene.addChild(name(), areaName(),
                EngineNode.Area2DWithState(area, GameData.PlayerArea))
            |> Scene.addChild(name(), "trail",
                EngineNode.GPUParticles2DWithState(
                    GPUParticles2D.make({
                        texture = "playerGrey_walk1",
                        amount = 10, lifetime = 1.0, speedScale = 2.0,
                        startAlpha = 0.5f32, endAlpha = 0.0f32,
                        startScale = 0.5, endScale = 0.324
                    }) |> CanvasItem.setZIndex(-1),
                    GameData.Marker))
            |> mapPlayer((pn, pd) ->
                ({ sprite = CanvasItem.hide(pn#sprite) | pn }, pd))

    // ========================================================================
    // ready: ビューポートサイズ取得
    // ========================================================================

    /// プレイヤーの ready 処理: ビューポートサイズを取得し、非表示にした sprite と更新済み PlayerData を返す
    pub def ready(sprite: AnimatedSprite2D, playerData: PlayerData): (AnimatedSprite2D, PlayerData) \ GameEngine.Game =
        // (hide(sprite), ...) — スタート画面実装時に復活させる
        (sprite, {screenSize = GameEngine.Game.getViewportRect()#size | playerData})

    // ========================================================================
    // 毎フレーム処理（Node.process から委譲される）
    // ========================================================================

    /// プレイヤーノードの毎フレーム処理: 速度に応じて移動しクランプした sprite を返す
    pub def process(dt: Float64, sprite: AnimatedSprite2D,
                    playerData: PlayerData): AnimatedSprite2D =
        let newPosition = Vec2.clamp(
            Vec2.add(Node2D.getPosition(sprite), Vec2.mul(playerData#velocity, dt)),
            Vec2.zero(),
            playerData#screenSize
        );
        setPosition(newPosition, sprite)

    // ========================================================================
    // ゲーム開始: 位置リセット + 表示
    // ========================================================================

    /// Godot の start(pos) を再現: 位置設定 + 回転リセット + show + 衝突再有効化
    /// trail は visible 伝播により親（player）の表示に自動追従する
    pub def start(pos: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        scene |> mapPlayer((playerNode, playerData) ->
            ({ sprite = playerNode#sprite |> position(pos) |> rotation(0.0) |> show,
               area = Area2D.setMonitoring(true, playerNode#area) },
             { hit = false | playerData }))

    // ========================================================================
    // 入力適用
    // ========================================================================

    /// 方向ベクトルに応じてプレイヤーの速度とアニメーションを更新する
    pub def applyInput(dir: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        let velocity = if (Vec2.length(dir) > 0.0)
                Vec2.mul(Vec2.normalized(dir), speed())
            else
                Vec2.zero();
        scene |> mapPlayer((playerNode, playerData) ->
            ({ sprite = setPlayerAnimation(dir, playerNode#sprite) | playerNode },
             { velocity = velocity | playerData }))

    // ========================================================================
    // アニメーション制御
    // ========================================================================

    /// 入力方向に応じてアニメーション・反転・回転を設定する
    /// 本家 Godot 準拠: 横移動は walk + flipH + flipV=false、縦移動は up + rotation（下向きで PI）
    pub def setPlayerAnimation(dir: Vec2.Vec2, sprite: AnimatedSprite2D): AnimatedSprite2D =
        if (dir#x != 0.0)
            sprite |> AnimatedSprite2D.play(walkAnimation())
                   |> AnimatedSprite2D.setFlipV(false)
                   |> AnimatedSprite2D.setFlipH(dir#x < 0.0)
                   |> rotation(0.0)
        else if (dir#y != 0.0)
            sprite |> AnimatedSprite2D.play(upAnimation())
                   |> rotation(if (dir#y > 0.0) pi() else 0.0)
        else
            AnimatedSprite2D.stop(sprite)

    /// PlayerNode と PlayerData を一括で変換する（sprite・area・データを同時に更新）
    pub def mapPlayer(f: (PlayerNode, PlayerData) -> (PlayerNode, PlayerData),
                      scene: Scene[GameData]): Scene[GameData] =
        let opt = forA(
            parent <- Scene.getEngineNode(playerPath(), scene);
            child  <- Scene.getEngineNode(areaPath(), scene)
        ) yield (parent, child);
        let (playerNode, playerData) = match opt {
            case Some((EngineNode.AnimSprite2DWithState(s, GameData.Player(_, pd)),
                       EngineNode.Area2DWithState(a, _))) => ({ sprite = s, area = a }, pd)
            case _ => bug!("player not found")
        };
        let (newNode, newData) = f(playerNode, playerData);
        scene
            |> Scene.mapEngineNode(playerPath(), en ->
                match en {
                    case EngineNode.AnimSprite2DWithState(_, GameData.Player(_, _)) =>
                        EngineNode.AnimSprite2DWithState(newNode#sprite,
                            GameData.Player(newNode, newData))
                    case other => other
                })
            |> Scene.mapEngineNode(areaPath(),
                EngineNode.mapArea2D(_ -> newNode#area))

    /// Scene から PlayerData を取り出す
    pub def getPlayerData(scene: Scene[GameData]): PlayerData =
        match Scene.getState(playerPath(), scene) {
            case Some(GameData.Player(_, playerData)) => playerData
            case _ => bug!("player data not found")
        }

}
