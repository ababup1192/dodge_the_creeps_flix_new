// MobScene — 落下する Mob の生成・画面外削除（物理エンジン検証用）
//
// Mob は RigidBody2D で重力によって落下する。
// 画面外に出たら queue_free（Scene から削除）する。
//
//   RigidBody2DWithState(body, MobData)
//     └── Sprite2DWithState(sprite, MobSprite)

mod MobScene {

    /// Mob のスプライト子ノード名
    def spriteName(): String = "sprite"

    /// Mob のテクスチャ名
    def mobTexture(): String = "enemyWalking_1"

    /// Mob の衝突半��
    def mobRadius(): Float64 = 20.0

    /// Mob のスプライトスケール
    def mobScale(): Vec2.Vec2 = {x = 0.5, y = 0.5}

    /// Mob のサイズ（画面外判定用、スプライトの表示領域）
    def mobSize(): Vec2.Vec2 = {x = 64.0, y = 64.0}

    /// Mob スポーン間隔（秒）
    def spawnInterval(): Float64 = 1.5

    /// カウンタから Mob 名を生成する
    pub def mobName(counter: Int32): String = "mob_${counter}"

    // ========================================================================
    // Mob スポーン
    // ========================================================================

    /// 新しい Mob をシーンに追加する
    ///
    /// RigidBody2D（重力で落下） + 子 Sprite2D（描画用）の構成。
    /// position は画面上部（Y < 0）に指定して、重力で落下させる想定。
    pub def spawnMob(name: String, position: Vec2.Vec2,
                     scene: Scene[GameData]): Scene[GameData] =
        let shape = CollisionShape2D.CircleShape2D({radius = mobRadius()});
        let body = RigidBody2D.make(position, shape);
        let sprite = Sprite2D.make(mobTexture(), Vec2.zero(), mobScale());
        scene
            |> Scene.addNode(name,
                EngineNode.RigidBody2DWithState(body, GameData.MobData))
            |> Scene.addChild(name, spriteName(),
                EngineNode.Sprite2DWithState(sprite, GameData.MobSprite))

    // ========================================================================
    // 画面外 Mob 削除（Godot queue_free 相当）
    // ========================================================================

    /// 画面下部から出た Mob をシーンから削除する（Godot queue_free 相当）
    ///
    /// Mob は画面上部（Y < 0）から��ポーンして重力で落下するため、
    /// 画面下端を超えたもののみ削除する（上部にいるスポーン直後の Mob は残す）��
    ///
    ///   画面下端: screenHeight
    ///   Mob 上端: position.y - mobSize.y / 2
    ///   削除条件: Mob 上端 > 画面下端（Mob 全体が画面下部に消えた）
    ///
    pub def removeOffScreenMobs(scene: Scene[GameData]): Scene[GameData] =
        let screenH = Int32.toFloat64(Game.screenHi());
        let halfHeight = mobSize()#y / 2.0;
        let paths = Scene.preorderPaths(scene);
        List.foldLeft((sc, path) ->
            match Scene.getState(path, sc) {
                case Some(GameData.MobData) =>
                    match Scene.getEngineNode(path, sc) {
                        case Some(node) =>
                            let posY = Node2D.getPosition(node)#y;
                            if (posY - halfHeight > screenH)
                                Scene.removeAt(path, sc)
                            else
                                sc
                        case None => sc
                    }
                case _ => sc
            },
            scene,
            paths)

    // ========================================================================
    // スポーンタイマー
    // ========================================================================

    /// スポーン X 座標の候補リスト（画面幅 480px に対して均等配置）
    def spawnPositions(): List[Float64] =
        60.0 :: 120.0 :: 180.0 :: 240.0 :: 300.0 :: 360.0 :: 420.0 :: Nil

    /// タイマーを更新し、時間が来たら Mob を生成する
    ///
    /// スポーン位置は画面上部（Y = -50）、X はカウンタから順番に決定。
    pub def maybeSpawnMob(delta: Float64, state: GameState): GameState =
        let newTimer = state#mobSpawnTimer - delta;
        if (newTimer <= 0.0) {
            let counter = state#mobCounter;
            let positions = spawnPositions();
            let numPositions = List.length(positions);
            let idx = counter - (counter / numPositions) * numPositions;
            let spawnX = match List.nth(idx, positions) {
                case Some(x) => x
                case None    => 240.0
            };
            let spawnPos: Vec2.Vec2 = {x = spawnX, y = -50.0};
            {   scene = spawnMob(mobName(counter), spawnPos, state#scene),
                mobSpawnTimer = spawnInterval(),
                mobCounter = counter + 1
                | state }
        } else {
            { mobSpawnTimer = newTimer | state }
        }
}
