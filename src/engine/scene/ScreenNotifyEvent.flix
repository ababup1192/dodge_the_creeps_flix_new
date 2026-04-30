/// 画面外検出とハンドラ発火（Godot VisibleOnScreenNotifier2D シグナル準拠）
///
/// ScreenNotifier2DWithState 子ノードを持つ親ノードを自動検出し、
/// 画面外に出たときに onScreenExited を発火する。
///
/// AreaEvent パターンを踏襲し、画面外に出たノードに onScreenExited を発火する。
/// Scene 内の prevOnScreen を使ってフレーム間の状態遷移を検出する。
///
///   フレーム N:   Mob は画面内 → prevOnScreen に登録
///   フレーム N+1: Mob は画面外 → prevOnScreen にあるので onScreenExited 発火
///
/// これにより、スポーン直後（まだ画面に入っていない）ノードは除外される。

pub mod ScreenNotifyEvent {

    /// パスの親パスを返す（末尾要素を除去）
    def parentPath(path: NodePath): NodePath =
        match List.reverse(path) {
            case Nil => Nil
            case _ :: rest => List.reverse(rest)
        }

    /// Scene 内の ScreenNotifier2DWithState 子ノードを検出し、
    /// その親ノードの画面内外を判定する。
    /// 前フレームに画面内だった親ノードが画面外に出た場合に
    /// ScreenNotifyHandler.onScreenExited をディスパッチする。
    ///
    /// prevOnScreen を更新して返す。
    pub def handleScreenExited(
            screenWidth: {screenWidth = Int32},
            screenHeight: {screenHeight = Int32},
            scene: Scene[s]): Scene[s] with ScreenNotifyHandler[s] =
        let prevOnScreen = Scene.getPrevOnScreen(scene);
        let paths = Scene.preorderPaths(scene);
        // Step 1: ScreenNotifier2DWithState 子ノードを検出し、親の画面内外を判定
        let currentOnScreen = List.foldLeft((acc, path) ->
            match Scene.getEngineNode(path, scene) {
                case Some(EngineNode.ScreenNotifier2DWithState(notifier, _)) =>
                    let pp = parentPath(path);
                    let pos = Scene.globalPositionAt(pp, scene);
                    if (VisibleOnScreenNotifier2D.isOnScreen(
                            pos, notifier, screenWidth, screenHeight))
                        Set.insert(pp, acc)
                    else
                        acc
                case _ => acc
            },
            Set.empty(),
            paths);
        // Step 2: 前フレーム画面内 → 今フレーム画面外の親ノードに onScreenExited を発火
        let exitedPaths = Set.difference(prevOnScreen, currentOnScreen);
        let updatedScene = Set.foldLeft((sc, path) ->
            match Scene.getState(path, sc) {
                case Some(state) =>
                    ScreenNotifyHandler.onScreenExited(path, state, sc)
                case None => sc
            },
            scene,
            exitedPaths);
        Scene.setPrevOnScreen(currentOnScreen, updatedScene)
}
