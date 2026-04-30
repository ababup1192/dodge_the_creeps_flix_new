/// エリア重なり検出とイベント発火（Godot Area2D シグナル準拠）
/// see: https://docs.godotengine.org/ja/4.x/classes/class_area2d.html#signals
///
/// 旧 Frogger エンジンの OnCollision エフェクトパターンを踏襲し、
/// Flix の代数的エフェクトで area_entered シグナルを実現する。
///
/// 使い方:
///   1. detectOverlaps で重なりペアを検出（純粋関数）
///   2. fireAreaEnteredAll でイベントを発火（OnAreaEvent エフェクト）
///   3. run { ... } with handler OnAreaEvent { ... } でハンドリング
///
/// emitOverlapEvents は 1 + 2 を一括実行するショートカット。

/// 有向オーバーラップペア (selfPath, otherPath) の集合。
/// 前フレームの重なり状態を保持し、離脱イベントの検出に使う。
pub type alias OverlapPairSet = Set[(NodePath, NodePath)]

/// エリア間の接触情報
pub type alias AreaContact = {
    path = NodePath,
    position = Vec2.Vec2
}

/// 検出された重なり 1 件分。
/// selfPath 側の areaEntered が発火される。
pub type alias AreaOverlap = {
    selfPath = NodePath,
    selfPos = Vec2.Vec2,
    other = AreaContact
}

/// エリア検知イベント（Godot area_entered シグナル相当）
pub eff OnAreaEvent {
    def areaEntered(selfPath: NodePath, selfPos: Vec2.Vec2, other: AreaContact): Unit
}

pub mod AreaEvent {

    // ========================================================================
    // 重なり検出（純粋関数 — EngineNode の CollisionObject2D を直接使用）
    // ========================================================================

    /// Scene 内の全 CollisionObject2D ペアの重なりを検出する。
    /// monitoring / monitorable フラグを考慮し、有効なペアのみ返す。
    pub def detectOverlaps(scene: Scene[s]): List[AreaOverlap] =
        let paths = Scene.preorderPaths(scene);
        let areas = List.filterMap(path ->
            Scene.getEngineNode(path, scene) |> Option.flatMap(engineNode ->
                CollisionObject2D.getCollisionShape(engineNode) |> Option.map(shape ->
                    (path, Scene.globalPositionAt(path, scene), shape,
                     CollisionObject2D.isMonitoring(engineNode),
                     CollisionObject2D.isMonitorable(engineNode))
                )
            ), paths);
        collectPairs(areas)

    /// 内部ヘルパー: 全ペアを総当たりで比較し、重なりイベントを収集する。
    def collectPairs(areas: List[(NodePath, Vec2.Vec2, CollisionShape2D, Bool, Bool)]): List[AreaOverlap] =
        match areas {
            case Nil => Nil
            case (pathA, posA, shapeA, monitoringA, monitorableA) :: tail =>
                let pairsFromA = List.flatMap(entry ->
                    let (pathB, posB, shapeB, monitoringB, monitorableB) = entry;
                    if (CollisionShape2D.checkOverlap(posA, shapeA, posB, shapeB))
                        let forward: List[AreaOverlap] =
                            if (monitoringA and monitorableB)
                                {selfPath = pathA, selfPos = posA,
                                 other = {path = pathB, position = posB}} :: Nil
                            else Nil;
                        let reverse: List[AreaOverlap] =
                            if (monitoringB and monitorableA)
                                {selfPath = pathB, selfPos = posB,
                                 other = {path = pathA, position = posA}} :: Nil
                            else Nil;
                        List.append(forward, reverse)
                    else Nil
                , tail);
                List.append(pairsFromA, collectPairs(tail))
        }

    // ========================================================================
    // イベント発火
    // ========================================================================

    /// 検出された重なりリストから OnAreaEvent.areaEntered を発火する。
    pub def fireAreaEnteredAll(overlaps: List[AreaOverlap]): Unit \ OnAreaEvent =
        List.forEach(ov ->
            OnAreaEvent.areaEntered(ov#selfPath, ov#selfPos, ov#other),
            overlaps)

    /// 検出 + 発火を一括で行うショートカット。
    pub def emitOverlapEvents(scene: Scene[s]): Unit \ OnAreaEvent =
        detectOverlaps(scene) |> fireAreaEnteredAll

    // ========================================================================
    // Scene 統合（旧エンジン stepAndCollide 相当）
    // ========================================================================

    /// Scene.processAll + 重なりイベント発火を一括で行う。
    pub def processAndEmit(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] \ {OnAreaEvent, GameEngine.Game} with Node[s] =
        let updated = Scene.processAll(delta, paused, scene);
        emitOverlapEvents(updated);
        updated

    // ========================================================================
    // AreaHandler 統合（ノード主導の衝突応答）
    // ========================================================================

    /// AreaOverlap リストから有向ペアセットに変換する
    pub def toOverlapPairSet(overlaps: List[AreaOverlap]): OverlapPairSet =
        List.foldLeft((acc, ov) ->
            Set.insert((ov#selfPath, ov#other#path), acc),
            Set.empty(),
            overlaps)

    /// processAll 済みの Scene に対してエリアイベントを検出・ハンドリングする。
    /// AreaHandler.onAreaEntered / onAreaExited をディスパッチし、
    /// prevOverlaps を更新して返す。
    pub def handleOverlaps(scene: Scene[s]): Scene[s] with AreaHandler[s] =
        let prevOverlaps = Scene.getPrevOverlaps(scene);
        let overlaps = detectOverlaps(scene);
        let currentPairs = toOverlapPairSet(overlaps);
        // 現在重なっているペアに onAreaEntered を発火
        let sceneAfterEnter = List.foldLeft((sc, ov) ->
            match (Scene.getState(ov#selfPath, sc), Scene.getState(ov#other#path, sc)) {
                case (Some(selfState), Some(otherState)) =>
                    AreaHandler.onAreaEntered(ov#selfPath, selfState, ov#other#path, otherState, sc)
                case _ => sc
            },
            scene,
            overlaps);
        // 前フレームにあって今フレームにないペアに onAreaExited を発火
        let exitedPairs = Set.difference(prevOverlaps, currentPairs);
        let sceneAfterExit = Set.foldLeft((sc, pair) ->
            let (selfPath, otherPath) = pair;
            match (Scene.getState(selfPath, sc), Scene.getState(otherPath, sc)) {
                case (Some(selfState), Some(otherState)) =>
                    AreaHandler.onAreaExited(selfPath, selfState, otherPath, otherState, sc)
                case _ => sc
            },
            sceneAfterEnter,
            exitedPairs);
        Scene.setPrevOverlaps(currentPairs, sceneAfterExit)

    /// Scene.processAll + 重なり検出 + AreaHandler.onAreaEntered / onAreaExited ディスパッチ。
    /// Scene 内の prevOverlaps を読み書きし、離脱したペアに onAreaExited を発火する。
    pub def processAndEmitHandled(delta: Float64, paused: Bool,
                                  scene: Scene[s]): Scene[s] \ GameEngine.Game
            with Node[s], AreaHandler[s] =
        Scene.processAll(delta, paused, scene) |> handleOverlaps

    // ========================================================================
    // ヘルパー
    // ========================================================================

    /// OnAreaEvent を無視して実行する。
    pub def runWithNoopAreaEvent(f: Unit -> a \ ef + OnAreaEvent): a \ ef =
        run f() with handler OnAreaEvent {
            def areaEntered(_selfPath, _selfPos, _other, k) = k(())
        }
}
