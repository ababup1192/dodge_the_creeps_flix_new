// GameEngine — 汎用描画パイプライン
// Scene[s] の s がジェネリクスなので、ゲーム固有の状態型に依存しない。

mod GameEngine {

    /// 1 フレーム分の更新: processAll → render
    pub def update(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] \ Engine.Game
            with Node[s] =
        let processedScene = Scene.processAll(delta, paused, scene);
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（Area2D 衝突検出付き）:
    /// processAndEmit → OnAreaEvent → render
    ///
    /// OnAreaEvent ハンドラは呼び出し元で提供する。
    pub def updateWithAreaEvents(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] \ {Engine.Game, OnAreaEvent}
            with Node[s] =
        let processedScene = AreaEvent.processAndEmit(delta, paused, scene);
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（AreaHandler 方式）:
    /// processAndEmitHandled → render
    ///
    /// OnAreaEvent ハンドラ不要。ノード型の AreaHandler instance で衝突応答する。
    /// Scene 内の prevOverlaps を使って離脱イベントも発火される。
    pub def updateWithAreaHandler(delta: Float64, paused: Bool,
                                  scene: Scene[s]): Scene[s] \ Engine.Game
            with Node[s], AreaHandler[s] =
        let processedScene = AreaEvent.processAndEmitHandled(delta, paused, scene);
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（物理 + AreaHandler 方式）:
    /// processAll → PhysicsStep → AreaEvent → render
    ///
    /// RigidBody2D の重力・ダンピング・速度積分を行い、
    /// その後エリアイベントを検出・ハンドリングする。
    pub def updateWithPhysicsAndAreaHandler(
            delta: Float64, paused: Bool, gravity: Vec2.Vec2,
            scene: Scene[s]): Scene[s] \ Engine.Game
            with Node[s], AreaHandler[s] =
        let processedScene = Scene.processAll(delta, paused, scene)
            |> PhysicsStep.step(delta, paused, gravity)
            |> AreaEvent.handleOverlaps;
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（物理 + AreaHandler + ScreenNotifyHandler 方式）:
    /// processAll → PhysicsStep → AreaEvent → ScreenNotifyEvent → render
    ///
    /// 画面外に出たノードに ScreenNotifyHandler.onScreenExited を自動発火する。
    pub def updateFull(
            delta: Float64, paused: Bool, gravity: Vec2.Vec2,
            screenWidth: {screenWidth = Float64},
            screenHeight: {screenHeight = Float64},
            scene: Scene[s]): Scene[s] \ Engine.Game
            with Node[s], AreaHandler[s], ScreenNotifyHandler[s] =
        let processedScene = Scene.processAll(delta, paused, scene)
            |> PhysicsStep.step(delta, paused, gravity)
            |> AreaEvent.handleOverlaps
            |> ScreenNotifyEvent.handleScreenExited(screenWidth, screenHeight);
        render(processedScene);
        processedScene

    /// 描画: Scene.toDrawables で Drawable リストを取得し、描画する
    pub def render(scene: Scene[s]): Unit \ Engine.Game =
        Scene.toDrawables(scene) |> Engine.Game.render
}
