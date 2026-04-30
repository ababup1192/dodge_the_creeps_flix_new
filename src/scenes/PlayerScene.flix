// PlayerScene — Dodge the Creeps プレイヤーのシーン構築・移動・アニメーション

mod PlayerScene {
    use Node2D.setPosition
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
    def startPosition(): Vec2.Vec2 = {x = 240.0, y = 360.0}

    /// プレイヤー移動速度（px/秒）
    def speed(): Float64 = 400.0

    /// π（円周率）
    def pi(): Float64 = 3.14159265358979

    def walkAnimation(): String = "walk"
    def upAnimation(): String = "up"

    /// プレイヤーの衝突形状（半径 30 の円）
    def playerCollisionShape(): CollisionShape2D =
        CollisionShape2D.CircleShape2D({radius = 30.0})

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
            fps = 6.0,
            startPosition(),
            {x = 1.0, y = 1.0});
        let area = Area2D.make(Vec2.zero(), playerCollisionShape());
        let playerNode: PlayerNode = { sprite = sprite, area = area };
        scene
            |> Scene.addNode(name(),
                EngineNode.AnimSprite2DWithState(sprite,
                    GameData.Player(playerNode, {velocity = Vec2.zero(), screenSize = Vec2.zero()})))
            |> Scene.addChild(name(), areaName(),
                EngineNode.Area2DWithState(area, GameData.PlayerArea))

    // ========================================================================
    // ready: ビューポートサイズ取得
    // ========================================================================

    /// プレイヤーの ready 処理: ビューポートサイズを取得し、非表示にした sprite と更新済み PlayerData を返す
    pub def ready(sprite: AnimatedSprite2D, playerData: PlayerData): (AnimatedSprite2D, PlayerData) \ Engine.Game =
        // (hide(sprite), ...) — スタート画面実装時に復活させる
        (sprite, {screenSize = Engine.Game.getViewportRect()#size | playerData})

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

    /// Godot の start(pos) を再現: 位置設定 + 回転リセット + show
    pub def start(pos: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        scene |> mapSprite(sprite ->
            sprite
                |> position(pos)
                |> rotation(0.0)
                |> show)

    // ========================================================================
    // 入力適用
    // ========================================================================

    /// 方向ベクトルに応じてプレイヤーの速度とアニメーションを更新する
    pub def applyInput(dir: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
        let velocity = if (Vec2.length(dir) > 0.0)
                Vec2.mul(Vec2.normalized(dir), speed())
            else
                Vec2.zero();
        let playerData = extractPlayerData(scene);
        scene
            |> setPlayerData({velocity = velocity | playerData})
            |> mapSprite(setPlayerAnimation(dir))

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

    // ========================================================================
    // PlayerNode ヘルパー
    // ========================================================================

    /// プレイヤーの sprite を変換する（EngineNode と playerNode#sprite を同時更新）
    pub def mapSprite(f: AnimatedSprite2D -> AnimatedSprite2D,
                      scene: Scene[GameData]): Scene[GameData] =
        scene |> Scene.mapEngineNode(name() :: Nil, en ->
            match en {
                case EngineNode.AnimSprite2DWithState(sprite, GameData.Player(playerNode, playerData)) =>
                    let newSprite = f(sprite);
                    EngineNode.AnimSprite2DWithState(newSprite, GameData.Player({sprite = newSprite | playerNode}, playerData))
                case other => other
            })

    /// playerNode の area を Scene の子ノードに書き戻す（シリアライザ）
    pub def syncChildren(playerNode: PlayerNode, scene: Scene[GameData]): Scene[GameData] =
        scene |> Scene.mapEngineNode(name() :: areaName() :: Nil,
            EngineNode.mapArea2D(_ -> playerNode#area))

    /// Scene から PlayerData を取り出す
    pub def extractPlayerData(scene: Scene[GameData]): PlayerData =
        match Scene.getState(name() :: Nil, scene) {
            case Some(GameData.Player(_, playerData)) => playerData
            case _ => bug!("player data not found")
        }

    /// PlayerData を Scene に書き戻す
    pub def setPlayerData(playerData: PlayerData, scene: Scene[GameData]): Scene[GameData] =
        scene |> Scene.mapState(name() :: Nil, state ->
            match state {
                case GameData.Player(playerNode, _) => GameData.Player(playerNode, playerData)
                case other => other
            })

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

}
