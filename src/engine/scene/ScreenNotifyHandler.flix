/// 画面外通知トレイト（VisibleOnScreenNotifier2D のコールバック）
///
/// ScreenNotifier2DWithState 子ノードの存在で自動検出される。
/// ゲーム固有の状態 s を受け取り、Godot の screen_exited シグナル相当を実現する。
///
/// 使い方:
///   1. 親ノードに ScreenNotifier2DWithState 子ノードを追加
///   2. onScreenExited で画面外に出たときの処理を定義
///   3. ScreenNotifyEvent.handleScreenExited がフレーム毎に自動発火

pub trait ScreenNotifyHandler[s] {

    /// ノードが画面外に出たとき呼ばれる（Godot screen_exited 相当）。
    /// Scene を書き換えて返す。
    ///
    /// path: ノードのパス（親ノードのパス）
    /// state: ノードのゲーム状態
    /// scene: 現在のシーン
    pub def onScreenExited(
        _path: NodePath,
        _state: s,
        scene: Scene[s]
    ): Scene[s] = scene
}
