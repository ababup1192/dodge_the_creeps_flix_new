// MobScene — 落下する Mob の生成（物理エンジン検証用）
//
// Mob は RigidBody2D で重力によって落下する。
// 画面外に出たら ScreenNotifyHandler.onScreenExited で自動削除される。
//
//   RigidBody2DWithState(body, MobData)
//     └── Sprite2DWithState(sprite, MobSprite)

mod MobScene {

    /// Mob のスプライト子ノード名
    def spriteName(): String = "sprite"

    /// Mob の画面外通知子ノード名
    def notifierName(): String = "notifier"

    /// Mob のテクスチャ名
    def mobTexture(): String = "enemyWalking_1"

    /// Mob の衝突形状（Godot チュートリアル準拠の CapsuleShape2D）
    def mobCollisionShape(): CollisionShape2D =
        CollisionShape2D.CapsuleShape2D({radius = 37.0, height = 100.0, vertical = true})

    /// Mob のスプライトスケール
    def mobScale(): Vec2.Vec2 = {x = 0.5, y = 0.5}

    /// Mob のサイズ（画面外判定用、スプライトの表示領域）
    def mobSize(): Vec2.Vec2 = {x = 64.0, y = 64.0}

    /// Mob の VisibleOnScreenNotifier2D（画面外検出用）
    pub def mobNotifier(): VisibleOnScreenNotifier2D =
        VisibleOnScreenNotifier2D.make(mobSize())

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
        let body = RigidBody2D.make(position, mobCollisionShape());
        let sprite = Sprite2D.make(mobTexture(), Vec2.zero(), mobScale());
        let notifier = MobScene.mobNotifier();
        scene
            |> Scene.addNode(name,
                EngineNode.RigidBody2DWithState(body, GameData.MobData))
            |> Scene.addChild(name, spriteName(),
                EngineNode.Sprite2DWithState(sprite, GameData.MobSprite))
            |> Scene.addChild(name, notifierName(),
                EngineNode.ScreenNotifier2DWithState(notifier, GameData.MobNotifier))

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
