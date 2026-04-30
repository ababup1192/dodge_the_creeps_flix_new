// MobScene — Godot チュートリアル準拠の Mob シーン
//
// Mob は RigidBody2D（gravity_scale = 0）で直線移動する。
// 画面外に出たら ScreenNotifyHandler.onScreenExited で自動削除される。
//
//   RigidBody2DWithState(body, MobData)
//     ├── AnimSprite2DWithState(sprite, MobSprite)
//     └── ScreenNotifier2DWithState(notifier, MobNotifier)

mod MobScene {
    import java.lang.Math

    /// 円周率
    def pi(): Float64 = 3.14159265358979

    /// sin（pure キャスト）
    def sin(x: Float64): Float64 =
        unchecked_cast(Math.sin(x) as _ \ {})

    /// cos（pure キャスト）
    def cos(x: Float64): Float64 =
        unchecked_cast(Math.cos(x) as _ \ {})

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
        CollisionShape2D.CapsuleShape2D({radius = 37.0, height = 100.0, vertical = true})

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
    // Mob スポーン
    // ========================================================================

    /// 新しい Mob をシーンに追加する（Godot mob.tscn 相当）
    ///
    /// RigidBody2D（gravity_scale = 0） + 子 AnimatedSprite2D（walk デフォルト）の構成。
    /// アニメーション選択・velocity 設定は ready で行う（Godot _ready 準拠）。
    pub def spawnMob(name: String, position: Vec2.Vec2, counter: Int32,
                     scene: Scene[GameData]): Scene[GameData] =
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
                EngineNode.RigidBody2DWithState(body, GameData.MobData(counter)))
            |> Scene.addToGroup(name :: Nil, mobGroup())
            |> Scene.addChild(name, spriteName(),
                EngineNode.AnimSprite2DWithState(sprite, GameData.MobSprite))
            |> Scene.addChild(name, notifierName(),
                EngineNode.ScreenNotifier2DWithState(notifier, GameData.MobNotifier))

    // ========================================================================
    // ready: アニメーション選択 + linearVelocity 設定（Godot _ready 準拠）
    // ========================================================================

    /// Mob の ready 処理: ランダムにアニメーション（fly/swim/walk）を選択し、
    /// ランダムな方向・速度で linearVelocity を設定する。
    ///
    /// direction は spawnMob 時に設定された direction に ±π/4 のランダム偏差を加え、
    /// speed は 150〜250 の範囲でランダムに決定する。
    pub def ready(path: NodePath, direction: Float64, scene: Scene[GameData]): Scene[GameData] \ Math.Random =
        let animation = pickAnimation();
        let spritePath = List.append(path, spriteName() :: Nil);
        let pi = pi();
        let dirOffset = RandomUtil.randomRange(0.0 - pi / 4.0, pi / 4.0);
        let finalDir = direction + dirOffset;
        let speed = RandomUtil.randomRange(150.0, 250.0);
        let vx = cos(finalDir) * speed;
        let vy = sin(finalDir) * speed;
        scene
            |> Scene.mapEngineNode(spritePath,
                EngineNode.mapAnimSprite2D(sprite ->
                    sprite
                        |> AnimatedSprite2D.play(animation)
                        |> Node2D.setRotation(finalDir)))
            |> Scene.mapEngineNode(path,
                EngineNode.mapRigidBody2D(RigidBody2D.setLinearVelocity({x = vx, y = vy})))

}
