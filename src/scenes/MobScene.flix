// MobScene — Godot チュートリアル準拠の Mob シーン
//
// Mob は RigidBody2D（gravity_scale = 0）で直線移動する。
// 画面外に出たら ScreenNotifyHandler.onScreenExited で自動削除される。
//
//   RigidBody2DWithState(body, MobBody)
//     ├── AnimSprite2DWithState(sprite, MobSprite)
//     └── ScreenNotifier2DWithState(notifier, MobNotifier)

mod MobScene {

    /// body: Mob の物理ボディ（RigidBody2D）
    /// sprite: Mob のアニメーションスプライト
    pub type alias MobNode = { body = RigidBody2D, sprite = AnimatedSprite2D }

    /// Mob のスプライト子ノード名
    def spriteName(): String = "sprite"

    /// Mob の画面外通知子ノード名
    def notifierName(): String = "notifier"

    /// Mob のグループ名
    pub def mobGroup(): String = "mobs"

    // ========================================================================
    // アニメーション定義（Godot mob.tscn 準拠: fly / swim / walk）
    // ========================================================================

    def flyAnimation(): String = "fly"
    def swimAnimation(): String = "swim"
    def walkAnimation(): String = "walk"

    /// Mob のアニメーション定義（各2フレーム、Godot mob.tscn 準拠）
    def mobAnimations(): Map[String, List[String]] =
        Map#{
            flyAnimation()  => ("enemyFlyingAlt_1" :: "enemyFlyingAlt_2" :: Nil),
            swimAnimation() => ("enemySwimming_1" :: "enemySwimming_2" :: Nil),
            walkAnimation() => ("enemyWalking_1" :: "enemyWalking_2" :: Nil)
        }

    /// アニメーション名をランダムに決定する（Godot の pick_random 相当）
    def pickAnimation(): String \ Math.Random =
        let animations = flyAnimation() :: swimAnimation() :: walkAnimation() :: Nil;
        match RandomUtil.pick(animations) {
            case Some(a) => a
            case None    => walkAnimation()
        }

    /// Mob の衝突形状（Godot チュートリアル準拠の CapsuleShape2D）
    def mobCollisionShape(): CollisionShape2D =
        CollisionShape2D.CapsuleShape2D({radius = 37.0, height = 100.0, vertical = false})

    /// Mob のスプライトスケール（Godot mob.tscn: 0.75）
    def mobScale(): Vec2.Vec2 = {x = 0.75, y = 0.75}

    /// Mob のサイズ（画面外判定用、スプライトの表示領域）
    def mobSize(): Vec2.Vec2 = {x = 64.0, y = 64.0}

    /// Mob の VisibleOnScreenNotifier2D（画面外検出用）
    pub def mobNotifier(): VisibleOnScreenNotifier2D =
        VisibleOnScreenNotifier2D.make(mobSize())

    /// カウンタから Mob 名を生成する
    pub def mobName(counter: Int32): String = "mob_${counter}"

    // ========================================================================
    // ready: アニメーション選択 + linearVelocity 設定（Godot _ready 準拠）
    // ========================================================================

    /// アニメーション名に応じた FPS を返す（Godot mob.tscn 準拠: fly=3, swim=4, walk=4）
    def fpsForAnimation(animation: String): Float64 =
        if (animation == flyAnimation()) 3.0
        else 4.0

    /// Mob の ready 処理: ランダムにアニメーション（fly/swim/walk）を選択し、
    /// ランダムな方向・速度で linearVelocity を設定する。
    ///
    /// direction は spawnMob 時に設定された direction に ±π/4 のランダム偏差を加え、
    /// speed は 150〜250 の範囲でランダムに決定する。
    pub def ready(path: NodePath, direction: Float64, scene: Scene[NodeTag]): Scene[NodeTag] \ Math.Random =
        let animation = pickAnimation();
        let dirOffset = RandomUtil.randomRange(0.0 - Vec2.pi() / 4.0, Vec2.pi() / 4.0);
        let finalDir = direction + dirOffset;
        let speed = RandomUtil.randomRange(150.0, 250.0);
        let vx = Vec2.cos(finalDir) * speed;
        let vy = Vec2.sin(finalDir) * speed;
        scene |> mapMob(path, (mobNode, counter) ->
            ({ body = RigidBody2D.setLinearVelocity({x = vx, y = vy}, mobNode#body),
               sprite = mobNode#sprite
                   |> AnimatedSprite2D.play(animation)
                   |> AnimatedSprite2D.setFps(fpsForAnimation(animation))
                   |> Node2D.setRotation(finalDir) },
             counter))

    // ========================================================================
    // Mob スポーン
    // ========================================================================

    /// 新しい Mob をシーンに追加する（Godot mob.tscn 相当）
    ///
    /// RigidBody2D（gravity_scale = 0） + 子 AnimatedSprite2D（walk デフォルト）の構成。
    /// アニメーション選択・velocity 設定は ready で行う（Godot _ready 準拠）。
    pub def spawnMob(name: String, position: Vec2.Vec2, counter: Int32,
                     scene: Scene[NodeTag]): Scene[NodeTag] =
        let body = RigidBody2D.make(position, mobCollisionShape())
            |> RigidBody2D.setGravityScale(0.0);
        let sprite = AnimatedSprite2D.make(
            mobAnimations(),
            initialAnimation = walkAnimation(),
            fps = 3.0,
            Vec2.zero(),
            mobScale());
        let notifier = MobScene.mobNotifier();
        scene
            |> Scene.addNode(name,
                EngineNode.RigidBody2DWithState(body, NodeTag.MobBody(counter)))
            |> Scene.addToGroup(name :: Nil, mobGroup())
            |> Scene.addChild(name, spriteName(),
                EngineNode.AnimSprite2DWithState(sprite, NodeTag.NoTag))
            |> Scene.addChild(name, notifierName(),
                EngineNode.ScreenNotifier2DWithState(notifier, NodeTag.NoTag))

    // ========================================================================
    // ボイラープレート: MobNode の取り出し・書き戻し・変換
    // ========================================================================
    // XxxNode にフィールドを追加する場合:
    //   1. extractXxx の forA に1行、yield と match パターンに1フィールド追加
    //   2. commitXxx にパイプラインを1段追加して書き戻す
    //   3. mapXxx は変更不要

    /// MobNode（body + sprite）と MobBody（counter）を一括で変換する
    pub def mapMob(mobPath: NodePath, f: (MobNode, Int32) -> (MobNode, Int32),
                   scene: Scene[NodeTag]): Scene[NodeTag] =
        let (mobNode, counter) = extractMob(mobPath, scene);
        let (newNode, newCounter) = f(mobNode, counter);
        commitMob(mobPath, newNode, newCounter, scene)

    /// シーンから XxxNode と XxxData を取り出す
    /// フィールド追加時: forA に1行、yield と match パターンに1フィールド追加
    def extractMob(mobPath: NodePath, scene: Scene[NodeTag]): (MobNode, Int32) =
        let spritePath = List.append(mobPath, spriteName() :: Nil);
        let mobNodeOpt = forA(
            body   <- Scene.getEngineNode(mobPath, scene);
            sprite <- Scene.getEngineNode(spritePath, scene)
        ) yield { body = body, sprite = sprite };
        match mobNodeOpt {
            case Some({ body = EngineNode.RigidBody2DWithState(body, NodeTag.MobBody(counter)),
                        sprite = EngineNode.AnimSprite2DWithState(sprite, _) }) =>
                ({ body = body, sprite = sprite }, counter)
            case _ => bug!("mob not found")
        }

    /// XxxNode と XxxData をシーンに書き戻す
    /// フィールド追加時: パスと EngineNode バリアントの組を1段追加する
    def commitMob(mobPath: NodePath, mobNode: MobNode, counter: Int32,
                  scene: Scene[NodeTag]): Scene[NodeTag] =
        let spritePath = List.append(mobPath, spriteName() :: Nil);
        scene
            |> Scene.setEngineNode(mobPath,
                EngineNode.RigidBody2DWithState(mobNode#body, NodeTag.MobBody(counter)))
            |> Scene.setEngineNode(spritePath,
                EngineNode.AnimSprite2DWithState(mobNode#sprite, NodeTag.NoTag))

}
