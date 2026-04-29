/// シーンツリーの基本ノード（Godot Node 準拠）
/// see: https://docs.godotengine.org/en/stable/classes/class_node.html
///
/// ライフサイクル:
///   addNode → [毎フレーム] process(delta)
///
/// 全メソッドにデフォルト実装があり、必要なものだけオーバーライドすればよい。
/// 型パラメータ s はゲーム固有の状態を表す。
/// EngineNode[s] がエンジンノードとゲーム状態を一体で保持する。
pub trait Node[s] {

    // ── ライフサイクル ──

    /// 毎フレーム呼ばれる更新コールバック
    /// delta: 前フレームからの経過秒数（Float64）
    pub def process(_delta: Float64, node: EngineNode[s], _path: NodePath, scene: Scene[s]): (EngineNode[s], Scene[s]) =
            (node, scene)

    // ── タイムアウト検出 ──

    /// timeout イベントが保留中か
    pub def isTimedOut(_state: s): Bool = false

    /// timeout フラグをクリア
    pub def clearTimedOut(state: s): s = state

    // ── ポーズ制御 ──

    /// このノードの ProcessMode を返す（デフォルト: Pausable）
    /// Scene.processAll がポーズ中に呼ぶかどうかの判定に使われる
    pub def getProcessMode(_state: s): ProcessMode =
            ProcessMode.Pausable
}
