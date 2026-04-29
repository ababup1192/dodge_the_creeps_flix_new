/// タイマータイムアウトイベントの検出と応答（Godot Timer.timeout シグナル準拠）
///
/// AreaEvent / AreaHandler パターンに倣い、TimerHandler トレイトで
/// タイムアウト時のイベント駆動を実現する。
///
/// 使い方:
///   1. TimerHandler[s] を実装し onTimeout でタイムアウト応答を記述
///   2. handleTimeouts(scene) をゲームループで呼び出す

pub mod TimerEvent {

    /// タイマータイムアウトに応答するトレイト
    pub trait TimerHandler[s] {
        /// タイマーがタイムアウトしたとき呼ばれる。
        /// timerPath: タイマーノードのパス
        /// state: タイマーノードのゲーム状態
        /// scene: 現在のシーン
        pub def onTimeout(_timerPath: NodePath, _state: s, scene: Scene[s]): Scene[s] = scene
    }

    /// timedOut=true のノードパスを収集する
    pub def detectTimeoutPaths(scene: Scene[s]): List[NodePath] with Node[s] =
        let paths = Scene.preorderPaths(scene);
        List.filterMap(path ->
            match Scene.getState(path, scene) {
                case Some(state) =>
                    if (Node.isTimedOut(state)) Some(path)
                    else None
                case None => None
            }, paths)

    /// タイムアウトを処理し、フラグをクリアする
    /// 1. detectTimeoutPaths で対象パスを収集
    /// 2. 各パスに対して TimerHandler.onTimeout を呼び出し
    /// 3. 各パスの clearTimedOut を呼び出してフラグをリセット
    pub def handleTimeouts(scene: Scene[s]): Scene[s] with Node[s], TimerHandler[s] =
        let timedOutPaths = detectTimeoutPaths(scene);
        // onTimeout を呼び出し
        let sceneAfterHandlers = List.foldLeft((sc, path) ->
            match Scene.getState(path, sc) {
                case Some(state) => TimerHandler.onTimeout(path, state, sc)
                case None => sc
            },
            scene,
            timedOutPaths);
        // timedOut フラグをクリア
        List.foldLeft((sc, path) ->
            Scene.mapState(path, state -> Node.clearTimedOut(state), sc),
            sceneAfterHandlers,
            timedOutPaths)
}
