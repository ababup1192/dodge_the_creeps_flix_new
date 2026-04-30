/// 物理ステップ — Node.physicsProcess + RigidBody2D の重力・ダンピング・速度積分
///
/// Godot の physics_process に相当する物理更新。
/// 衝突応答（分離・反発）は今回のスコープ外。
///
/// 使い方:
///   PhysicsStep.step(delta, paused, gravity, scene)
///
/// 処理順序:
///   1. Node.physicsProcess（全ノード）— 力の適用・速度変更などカスタム物理ロジック
///   2. 重力加速: linearVelocity += gravity * gravityScale * delta
///   3. ダンピング: linearVelocity /= (1 + linearDamp * delta)
///   4. 速度積分: position += linearVelocity * delta, rotation += angularVelocity * delta
///
pub mod PhysicsStep {

    /// デフォルト重力（Godot 準拠: 980 pixels/sec² 下向き）
    pub def defaultGravity(): Vec2.Vec2 = {x = 0.0, y = 980.0}

    /// 物理ステップ: physicsProcess → 重力適用 → ダンピング → 速度積分
    /// 全ノードの physicsProcess を呼んだ後、RigidBody2D に物理更新を適用する。
    pub def step(delta: Float64, paused: Bool, gravity: Vec2.Vec2, scene: Scene[s]): Scene[s] with Node[s] =
        let afterPhysicsProcess = Scene.physicsProcessAll(delta, paused, scene);
        integrate(delta, gravity, afterPhysicsProcess)

    /// RigidBody2D への重力・ダンピング・速度積分のみ行う（physicsProcess なし）
    pub def integrate(delta: Float64, gravity: Vec2.Vec2, scene: Scene[s]): Scene[s] =
        let paths = Scene.preorderPaths(scene);
        List.foldLeft((sc, path) ->
            Scene.mapEngineNode(path, engineNode ->
                EngineNode.mapRigidBody2D(body ->
                    integrateBody(delta, gravity, body),
                    engineNode),
                sc),
            scene,
            paths)

    /// 単体の RigidBody2D に重力・ダンピング・速度積分を適用する
    def integrateBody(delta: Float64, gravity: Vec2.Vec2, body: RigidBody2D): RigidBody2D =
        let RigidBody2D.RigidBody2D(r) = body;
        // 1. 重力加速
        let gravAccel = Vec2.mul(gravity, r#gravityScale * delta);
        let velAfterGravity = Vec2.add(r#linearVelocity, gravAccel);
        // 2. ダンピング
        let linearDampFactor = 1.0 + r#linearDamp * delta;
        let velAfterDamp = Vec2.div(velAfterGravity, linearDampFactor);
        let angularDampFactor = 1.0 + r#angularDamp * delta;
        let angVelAfterDamp = r#angularVelocity / angularDampFactor;
        // 3. 速度積分
        let newPosition = Vec2.add(r#position, Vec2.mul(velAfterDamp, delta));
        let newRotation = r#rotation + angVelAfterDamp * delta;
        RigidBody2D.RigidBody2D({
            linearVelocity = velAfterDamp,
            angularVelocity = angVelAfterDamp,
            position = newPosition,
            rotation = newRotation
            | r
        })
}
