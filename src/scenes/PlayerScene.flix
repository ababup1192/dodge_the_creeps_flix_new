// PlayerScene — Dodge the Creeps プレイヤーのシーン構築・移動・アニメーション

mod PlayerScene {
    use NodeBuilder.{position, rotation, show, hide}

    pub type alias PlayerData = {velocity = Vec2.Vec2, screenSize = Vec2.Vec2}

    pub type alias PlayerNode = { sprite = AnimatedSprite2D, area = Area2D }

    // ========================================================================
    // 定数
    // ========================================================================

    /// プレイヤーノード名
    def name(): String = "player"

    /// Area2D 子ノード名
    def areaName(): String = "area"

    /// プレイヤー初期位置（画面中央）
    def startPosition(): Vec2.Vec2 = {x = 240.0f32, y = 360.0f32}

    /// プレイヤー移動速度（px/秒）
    def speed(): Float32 = 400.0f32

    /// π（円周率）
    def pi(): Float64 = 3.14159265358979

    def walkAnimation(): String = "walk"
    def upAnimation(): String = "up"

    /// プレイヤーの衝突形状（半径 30 の円）
    def playerCollisionShape(): CollisionShape2D =
        CollisionShape2D.CircleShape2D({radius = 30.0f32})

    /// プレイヤーのアニメーション定義
    def playerAnimations(): Map[String, List[String]] =
        Map#{
            walkAnimation() => ("playerGrey_walk1" :: "playerGrey_walk2" :: Nil),
            upAnimation() => ("playerGrey_up1" :: "playerGrey_up2" :: Nil)
        }

    // ========================================================================
    // シーン構築
    // ========================================================================

    /// プレイヤーノードをシーンに追加する（Area2D 子ノード付き）
    pub def addPlayer(scene: Scene[GameData]): Scene[GameData] =
        let sprite = AnimatedSprite2D.make(
            playerAnimations(),
            initialAnimation = walkAnimation(),
            fps = 6.0f32,
            startPosition(),
            {x = 1.0f32, y = 1.0f32});
        let area = Area2D.make(Vec2.zero(), playerCollisionShape());
        let pn: PlayerNode = { sprite = sprite, area = area };
        scene
            |> Scene.addNode(name(),
                EngineNode.AnimSprite2DWithState(sprite,
                    GameData.Player(pn, {velocity = Vec2.zero(), screenSize = Vec2.zero()})))
            |> Scene.addChild(name(), areaName(),
                EngineNode.Area2DWithState(area, GameData.PlayerArea))

    // ========================================================================
    // ready: ビューポートサイズ取得
    // ========================================================================

    /// プレイヤーの ready 処理: ビューポートサイズを取得して PlayerData に保存する
    pub def ready(sprite: AnimatedSprite2D, pn: PlayerNode, pd: PlayerData,
                  scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) \ Engine.Game =
        let viewportSize = Engine.Game.getViewportRect()#size;
        let hiddenSprite = hide(sprite);
        let pn1 = { sprite = hiddenSprite | pn };
        (EngineNode.AnimSprite2DWithState(
            hiddenSprite,
            GameData.Player(pn1, {screenSize = viewportSize | pd})),
            scene
        )

    // ========================================================================
    // 毎フレーム処理（Node.process から委譲される）
    // ========================================================================

    /// プレイヤーノードの毎フレーム処理
    pub def process(delta: Float64, sprite: AnimatedSprite2D,
                    pn: PlayerNode, pd: PlayerData,
                    scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) =
        let pn1 = { sprite = sprite | pn };
        let dt = Float64.truncateToFloat32(delta);
        let moved = movePlayer(dt, pd#screenSize, pn1#sprite, {velocity = pd#velocity});
        let pn2 = { sprite = moved | pn1 };
        (EngineNode.AnimSprite2DWithState(moved, GameData.Player(pn2, pd)), scene)

    // ========================================================================
    // 移動
    // ========================================================================

    /// 速度に応じてプレイヤーを移動し、画面範囲にクランプする
    pub def movePlayer(dt: Float32, screenSize: Vec2.Vec2,
                       sprite: AnimatedSprite2D,
                       r: {velocity = Vec2.Vec2}): AnimatedSprite2D =
        let pos = Node2D.getPosition(sprite);
        let newPos = Vec2.clamp(
            Vec2.add(pos, Vec2.mul(r#velocity, dt)),
            Vec2.zero(),
            screenSize
        );
        position(newPos, sprite)

    // ========================================================================
    // ゲーム開始: 位置リセット + 表示
    // ========================================================================

    /// Godot の start(pos) を再現: 位置設定 + 回転リセット + show
    pub def start(pos: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        scene |> Scene.mapEngineNode(name() :: Nil,
            mapPlayerSprite(sprite ->
                sprite
                    |> position(pos)
                    |> rotation(0.0)
                    |> show))

    // ========================================================================
    // 入力適用
    // ========================================================================

    /// 方向ベクトルに応じてプレイヤーの速度とアニメーションを更新する
    pub def applyInput(dir: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        let velocity = if (Vec2.length(dir) > 0.0f32)
                Vec2.mul(Vec2.normalized(dir), speed())
            else
                Vec2.zero();
        scene
            |> Scene.mapState(name() :: Nil, state ->
                match state {
                    case GameData.Player(pn, pd) =>
                        GameData.Player(pn, {velocity = velocity | pd})
                    case other => other
                })
            |> Scene.mapEngineNode(name() :: Nil,
                mapPlayerSprite(setPlayerAnimation(dir)))

    // ========================================================================
    // PlayerNode ヘルパー
    // ========================================================================

    /// EngineNode の sprite と pn#sprite を同時更新するヘルパー
    def mapPlayerSprite(f: AnimatedSprite2D -> AnimatedSprite2D,
                        en: EngineNode[GameData]): EngineNode[GameData] =
        match en {
            case EngineNode.AnimSprite2DWithState(sprite, GameData.Player(pn, pd)) =>
                let newSprite = f(sprite);
                EngineNode.AnimSprite2DWithState(newSprite, GameData.Player({sprite = newSprite | pn}, pd))
            case other => other
        }

    /// pn の area を Scene の子ノードに書き戻す（シリアライザ）
    pub def syncChildren(pn: PlayerNode, scene: Scene[GameData]): Scene[GameData] =
        scene |> Scene.mapEngineNode(name() :: areaName() :: Nil,
            EngineNode.mapArea2D(_ -> pn#area))

    /// Scene から PlayerNode を構築する（デシリアライザ）
    pub def extractPlayerNode(scene: Scene[GameData]): PlayerNode =
        let sprite = match Scene.getEngineNode(name() :: Nil, scene) {
            case Some(EngineNode.AnimSprite2DWithState(s, _)) => s
            case _ => bug!("player sprite not found")
        };
        let area = match Scene.getEngineNode(name() :: areaName() :: Nil, scene) {
            case Some(EngineNode.Area2DWithState(a, _)) => a
            case _ => bug!("player area not found")
        };
        { sprite = sprite, area = area }

    // ========================================================================
    // アニメーション制御
    // ========================================================================

    /// 入力方向に応じてアニメーション・反転・回転を設定する
    /// 本家 Godot 準拠: 横移動は walk + flipH + flipV=false、縦移動は up + rotation（下向きで PI）
    pub def setPlayerAnimation(dir: Vec2.Vec2, sprite: AnimatedSprite2D): AnimatedSprite2D =
        if (dir#x != 0.0f32)
            sprite |> AnimatedSprite2D.play(walkAnimation())
                   |> AnimatedSprite2D.setFlipV(false)
                   |> AnimatedSprite2D.setFlipH(dir#x < 0.0f32)
                   |> rotation(0.0)
        else if (dir#y != 0.0f32)
            sprite |> AnimatedSprite2D.play(upAnimation())
                   |> rotation(if (dir#y > 0.0f32) pi() else 0.0)
        else
            AnimatedSprite2D.stop(sprite)
}
