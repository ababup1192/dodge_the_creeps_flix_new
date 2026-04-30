// Tests for AreaEvent module

/// テスト用ヘルパー: 矩形 Area2D を EngineNode[Unit] として作る
def rectAreaNode(x: Float64, y: Float64, w: Float64, h: Float64): EngineNode[Unit] =
    EngineNode.Area2DWithState(Area2D.make({x = x, y = y}, CollisionShape2D.RectShape2D({width = w, height = h})), ())

/// テスト用ヘルパー: 矩形 Area2D の EngineNode[Unit] を設定付きで作る
def rectAreaNodeWith(x: Float64, y: Float64, w: Float64, h: Float64,
                     monitoring: Bool, monitorable: Bool): EngineNode[Unit] =
    EngineNode.Area2DWithState(
        Area2D.make({x = x, y = y}, CollisionShape2D.RectShape2D({width = w, height = h}))
            |> Area2D.setMonitoring(monitoring)
            |> Area2D.setMonitorable(monitorable), ())

/// テスト用ヘルパー: 衝突形状なしの Area2D EngineNode[Unit] を作る
def noShapeAreaNode(x: Float64, y: Float64): EngineNode[Unit] =
    EngineNode.Area2DWithState(
        Area2D.make({x = x, y = y}, CollisionShape2D.RectShape2D({width = 10.0, height = 10.0}))
            |> Area2D.setCollisionShape(None), ())

// ── processAndEmitHandled テスト用の状態型 ──

enum TestAreaState with Eq {
    case RedState
    case BlueState
}

instance Node[TestAreaState] {}

/// テスト用ヘルパー: TestAreaState 用の矩形 Area2D EngineNode を作る
def testStateAreaNode(x: Float64, y: Float64, w: Float64, h: Float64, state: TestAreaState): EngineNode[TestAreaState] =
    EngineNode.Area2DWithState(Area2D.make({x = x, y = y}, CollisionShape2D.RectShape2D({width = w, height = h})), state)

instance AreaHandler[TestAreaState] {
    pub def onAreaEntered(selfPath: NodePath, selfState: TestAreaState,
                          _otherPath: NodePath, otherState: TestAreaState,
                          scene: Scene[TestAreaState]): Scene[TestAreaState] =
        match (selfState, otherState) {
            case (TestAreaState.RedState, TestAreaState.BlueState) =>
                Scene.mapEngineNode(selfPath, engineNode ->
                    CanvasItem.setModulate({r = 1.0f32, g = 0.0f32, b = 0.0f32}, engineNode), scene)
            case _ => scene
        }
    redef onAreaExited(selfPath: NodePath, selfState: TestAreaState,
                       _otherPath: NodePath, otherState: TestAreaState,
                       scene: Scene[TestAreaState]): Scene[TestAreaState] =
        match (selfState, otherState) {
            case (TestAreaState.RedState, TestAreaState.BlueState) =>
                Scene.mapEngineNode(selfPath, engineNode ->
                    CanvasItem.setModulate({r = 1.0f32, g = 1.0f32, b = 1.0f32}, engineNode), scene)
            case _ => scene
        }
}

// ========================================================================
// detectOverlaps（Unit 状態で衝突検出のみテスト）
// ========================================================================

instance Node[Unit] {}

/// 2 つの重なっている Area2D を検出する
@Test
def testDetectOverlapsTwoOverlapping(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", rectAreaNode(5.0, 0.0, 10.0, 10.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 2, List.length(overlaps))

/// 離れている Area2D は検出されない
@Test
def testDetectOverlapsNoOverlap(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 4.0, 4.0))
        |> Scene.addNode("b", rectAreaNode(100.0, 100.0, 4.0, 4.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// monitoring=false の場合、その側のイベントは生成されない
@Test
def testDetectOverlapsMonitoringOff(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNodeWith(0.0, 0.0, 10.0, 10.0, false, true))
        |> Scene.addNode("b", rectAreaNode(5.0, 0.0, 10.0, 10.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 1, List.length(overlaps))

/// monitorable=false の場合、相手からの検出対象にならない
@Test
def testDetectOverlapsMonitorableOff(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", rectAreaNodeWith(5.0, 0.0, 10.0, 10.0, true, false));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 1, List.length(overlaps))

/// 両方 monitoring=false, monitorable=false なら検出ゼロ
@Test
def testDetectOverlapsBothOff(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNodeWith(0.0, 0.0, 10.0, 10.0, false, false))
        |> Scene.addNode("b", rectAreaNodeWith(5.0, 0.0, 10.0, 10.0, false, false));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// 3 ノードで A-B 重なり、A-C 重なり、B-C 離れの場合
@Test
def testDetectOverlapsThreeNodes(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", rectAreaNode(5.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("c", rectAreaNode(3.0, 0.0, 4.0, 4.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 6, List.length(overlaps))

/// 衝突形状なしの Area2D は検出に参加しない
@Test
def testDetectOverlapsNoShape(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", noShapeAreaNode(5.0, 0.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// 親子配置で globalPosition が考慮される
@Test
def testDetectOverlapsWithParentChild(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("parent", rectAreaNode(100.0, 0.0, 4.0, 4.0))
        |> Scene.addChild("parent", "child", rectAreaNode(0.0, 0.0, 4.0, 4.0))
        |> Scene.addNode("other", rectAreaNode(101.0, 0.0, 4.0, 4.0));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertTrue(List.length(overlaps) > 0)

// ========================================================================
// fireAreaEnteredAll（イベント発火カウント）
// ========================================================================

/// 発火されるイベント数を継続で数える
@Test
def testFireAreaEnteredAllCount(): Unit \ Assert =
    let overlaps: List[AreaOverlap] =
        {selfPath = "a" :: Nil, selfPos = Vec2.zero(), other = {path = "b" :: Nil, position = Vec2.zero()}} ::
        {selfPath = "b" :: Nil, selfPos = Vec2.zero(), other = {path = "a" :: Nil, position = Vec2.zero()}} :: Nil;
    let count = run {
        AreaEvent.fireAreaEnteredAll(overlaps);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 空リストでは発火なし
@Test
def testFireAreaEnteredAllEmpty(): Unit \ Assert =
    let count = run {
        AreaEvent.fireAreaEnteredAll(Nil);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

// ========================================================================
// runWithNoopAreaEvent
// ========================================================================

/// noop ハンドラでイベントが無視される
@Test
def testRunWithNoopAreaEvent(): Unit \ Assert =
    let result = AreaEvent.runWithNoopAreaEvent(() -> {
        OnAreaEvent.areaEntered("a" :: Nil, Vec2.zero(), {path = "b" :: Nil, position = Vec2.zero()});
        42
    });
    Assert.assertEq(expected = 42, result)

// ========================================================================
// emitOverlapEvents（統合テスト）
// ========================================================================

/// 検出 + 発火の統合テスト
@Test
def testEmitOverlapEventsIntegration(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", rectAreaNode(5.0, 0.0, 10.0, 10.0));
    let count = run {
        AreaEvent.emitOverlapEvents(scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 重なりのない Scene では発火なし
@Test
def testEmitOverlapEventsNoOverlap(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 4.0, 4.0))
        |> Scene.addNode("b", rectAreaNode(100.0, 0.0, 4.0, 4.0));
    let count = run {
        AreaEvent.emitOverlapEvents(scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

// ========================================================================
// processAndEmit（エンジン統合テスト）
// ========================================================================

/// processAll + イベント発火が一括で行われる
@Test
def testProcessAndEmitFiresEvents(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("b", rectAreaNode(5.0, 0.0, 10.0, 10.0));
    let count = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 重なりがなければ processAndEmit でもイベント発火なし
@Test
def testProcessAndEmitNoEvents(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("a", rectAreaNode(0.0, 0.0, 4.0, 4.0))
        |> Scene.addNode("b", rectAreaNode(100.0, 0.0, 4.0, 4.0));
    let count = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

/// ハンドラで戻り値を変換するパターン（旧エンジン stepAndCollide 相当）
@Test
def testProcessAndEmitHandlerTransform(): Unit \ Assert =
    let scene: Scene[Unit] = Scene.empty()
        |> Scene.addNode("player", rectAreaNode(0.0, 0.0, 10.0, 10.0))
        |> Scene.addNode("enemy", rectAreaNode(5.0, 0.0, 10.0, 10.0));
    let hitPaths: List[NodePath] = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        Nil
    } with handler OnAreaEvent {
        def areaEntered(selfPath, _selfPos, _other, k) =
            selfPath :: k(())
    };
    Assert.assertEq(expected = 2, List.length(hitPaths))

// ========================================================================
// processAndEmitHandled（AreaHandler 統合テスト）
// ========================================================================

/// RedState が BlueState と衝突すると modulate が赤になる
@Test
def testProcessAndEmitHandledChangesModulate(): Unit \ Assert =
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 10.0, 10.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(5.0, 0.0, 10.0, 10.0, TestAreaState.BlueState));
    let result = AreaEvent.processAndEmitHandled(0.016, false, scene);
    match Scene.getEngineNode("red" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = (1.0f32, 0.0f32, 0.0f32), (c#r, c#g, c#b))
        case None => bug!("red node missing")
    }

/// BlueState 側は AreaHandler で何もしないので modulate は白のまま
@Test
def testProcessAndEmitHandledBlueUnchanged(): Unit \ Assert =
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 10.0, 10.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(5.0, 0.0, 10.0, 10.0, TestAreaState.BlueState));
    let result = AreaEvent.processAndEmitHandled(0.016, false, scene);
    match Scene.getEngineNode("blue" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = (1.0f32, 1.0f32, 1.0f32), (c#r, c#g, c#b))
        case None => bug!("blue node missing")
    }

/// 重なりがなければ processAndEmitHandled でも変更なし
@Test
def testProcessAndEmitHandledNoOverlap(): Unit \ Assert =
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 4.0, 4.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(100.0, 0.0, 4.0, 4.0, TestAreaState.BlueState));
    let result = AreaEvent.processAndEmitHandled(0.016, false, scene);
    match Scene.getEngineNode("red" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => bug!("red node missing")
    }

/// 同じバリアント同士 (RedState vs RedState) では AreaHandler は何もしない
@Test
def testProcessAndEmitHandledSameVariant(): Unit \ Assert =
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("r1", testStateAreaNode(0.0, 0.0, 10.0, 10.0, TestAreaState.RedState))
        |> Scene.addNode("r2", testStateAreaNode(5.0, 0.0, 10.0, 10.0, TestAreaState.RedState));
    let result = AreaEvent.processAndEmitHandled(0.016, false, scene);
    match Scene.getEngineNode("r1" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => bug!("r1 missing")
    }

// ========================================================================
// onAreaExited（離脱イベントテスト）
// ========================================================================

/// 前フレームで重なっていたペアが離れると onAreaExited が発火される
///
///  フレーム1:  [red]<--重なり-->[blue]  → 赤くなる
///  フレーム2:  [red]          [blue]    → 離脱 → modulate は白に戻る
@Test
def testProcessAndEmitHandledFiresExitOnSeparation(): Unit \ Assert =
    // フレーム1: 重なりあり → prevOverlaps を取得
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 10.0, 10.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(5.0, 0.0, 10.0, 10.0, TestAreaState.BlueState));
    let sceneAfterEnter = AreaEvent.processAndEmitHandled(0.016, false, scene);
    // フレーム2: 離す → 前フレームの prevOverlaps は Scene 内に保持されている
    let separatedScene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 4.0, 4.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(100.0, 0.0, 4.0, 4.0, TestAreaState.BlueState))
        |> Scene.setPrevOverlaps(Scene.getPrevOverlaps(sceneAfterEnter));
    let result = AreaEvent.processAndEmitHandled(0.016, false, separatedScene);
    // 離脱後のペアセットは空
    Assert.assertEq(expected = 0, Set.size(Scene.getPrevOverlaps(result)));
    // RedState の modulate が白に戻っている（onAreaExited で戻した）
    match Scene.getEngineNode("red" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = (1.0f32, 1.0f32, 1.0f32), (c#r, c#g, c#b))
        case None => bug!("red node missing")
    }

/// prevOverlaps が空なら離脱イベントは発火しない
@Test
def testProcessAndEmitHandledNoExitWithEmptyPrev(): Unit \ Assert =
    let scene: Scene[TestAreaState] = Scene.empty()
        |> Scene.addNode("red", testStateAreaNode(0.0, 0.0, 4.0, 4.0, TestAreaState.RedState))
        |> Scene.addNode("blue", testStateAreaNode(100.0, 0.0, 4.0, 4.0, TestAreaState.BlueState));
    let result = AreaEvent.processAndEmitHandled(0.016, false, scene);
    Assert.assertEq(expected = 0, Set.size(Scene.getPrevOverlaps(result)));
    match Scene.getEngineNode("red" :: Nil, result) {
        case Some(engineNode) =>
            let c = CanvasItem.getModulate(engineNode);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => bug!("red node missing")
    }
