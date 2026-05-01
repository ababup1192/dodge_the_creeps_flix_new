// HUDScene — Godot HUD.gd/HUD.tscn 準拠の HUD シーン構築・操作
//
// CanvasLayer に ScoreLabel / MessageLabel / StartButton / MessageTimer / TitleTimer を配置し
// Godot デモの HUD と同等の機能を提供する。
//
//   hud (CanvasLayer, drawLayer=1)
//     +-- score_label (Label2D, centered, 常時表示, "0")
//     +-- message_label (Label2D, centered, "Dodge the\nCreeps")
//     +-- start_button (Button, "Start")
//     +-- message_timer (Timer, one_shot, 1.0s)
//     +-- title_timer (Timer, one_shot, 1.0s)

mod HUDScene {

    // ========================================================================
    // ノード名・パス定数
    // ========================================================================

    pub def hudName(): String = "hud"
    def scoreLabelName(): String = "score_label"
    def messageLabelName(): String = "message_label"
    def startButtonName(): String = "start_button"
    def messageTimerName(): String = "message_timer"
    def titleTimerName(): String = "title_timer"

    pub def scoreLabelPath(): NodePath = hudName() :: scoreLabelName() :: Nil
    pub def messageLabelPath(): NodePath = hudName() :: messageLabelName() :: Nil
    pub def startButtonPath(): NodePath = hudName() :: startButtonName() :: Nil
    pub def messageTimerPath(): NodePath = hudName() :: messageTimerName() :: Nil
    pub def titleTimerPath(): NodePath = hudName() :: titleTimerName() :: Nil

    // ========================================================================
    // シーン構築
    // ========================================================================

    /// CanvasLayer + 子ノード5個をシーンに追加する
    pub def addHUD(fontAtlas: FontAtlas, scene: Scene[NodeTag]): Scene[NodeTag] =
        let hud = CanvasLayer.make(1);
        let scoreLabel = Label2D.make("0", fontAtlas, 60.0)
            |> Label2D.setCentered(true)
            |> Node2D.setPosition({x = 240.0, y = 0.0});
        let messageLabel = Label2D.make("Dodge the\nCreeps", fontAtlas, 60.0)
            |> Label2D.setCentered(true)
            |> Node2D.setPosition({x = 240.0, y = 281.0});
        let startButton = Button.make("Start", fontAtlas, 60.0, {x = 180.0, y = 100.0})
            |> Node2D.setPosition({x = 150.0, y = 520.0});
        let messageTimer = Timer.make(1.0);
        let titleTimer = Timer.make(1.0);
        scene
            |> Scene.addNode(hudName(),
                EngineNode.CanvasLayerWithState(hud, NodeTag.NoTag))
            |> Scene.addChild(hudName(), scoreLabelName(),
                EngineNode.Label2DWithState(scoreLabel, NodeTag.ScoreLabel(0)))
            |> Scene.addChild(hudName(), messageLabelName(),
                EngineNode.Label2DWithState(messageLabel, NodeTag.NoTag))
            |> Scene.addChild(hudName(), startButtonName(),
                EngineNode.ButtonWithState(startButton, NodeTag.StartButton))
            |> Scene.addChild(hudName(), messageTimerName(),
                EngineNode.TimerWithState(messageTimer, NodeTag.MessageTimer))
            |> Scene.addChild(hudName(), titleTimerName(),
                EngineNode.TimerWithState(titleTimer, NodeTag.TitleTimer))

    // ========================================================================
    // HUD API（Godot HUD.gd メソッド対応）
    // ========================================================================

    /// message_label のテキスト変更 + 表示
    pub def showMessage(text: String, scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(messageLabelPath(), en ->
            en |> EngineNode.mapLabel2D(Label2D.setText(text)) |> CanvasItem.show)

    /// message_label 非表示
    pub def hideMessage(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(messageLabelPath(), en -> CanvasItem.setVisible(false, en))

    /// score_label のテキストと ScoreLabel 状態を更新する
    pub def updateScore(score: Int32, scene: Scene[NodeTag]): Scene[NodeTag] =
        scene
            |> Scene.mapEngineNode(scoreLabelPath(),
                EngineNode.mapLabel2D(Label2D.setText(Int32.toString(score))))
            |> Scene.setState(scoreLabelPath(), NodeTag.ScoreLabel(score))

    /// スコアを 1 加算し、ラベルを更新する（ScoreTimer タイムアウト時に呼ばれる）
    pub def incrementScore(scene: Scene[NodeTag]): Scene[NodeTag] =
        let current = match Scene.getState(scoreLabelPath(), scene) {
            case Some(NodeTag.ScoreLabel(s)) => s
            case _ => 0
        };
        updateScore(current + 1, scene)

    /// start_button 表示
    pub def showStartButton(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(startButtonPath(), CanvasItem.show)

    /// start_button 非表示
    pub def hideStartButton(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(startButtonPath(), en -> CanvasItem.setVisible(false, en))

    /// message_timer 開始
    pub def startMessageTimer(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(messageTimerPath(), EngineNode.mapTimer(Timer.start))

    /// title_timer 開始
    pub def startTitleTimer(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(titleTimerPath(), EngineNode.mapTimer(Timer.start))

    // ========================================================================
    // クエリ
    // ========================================================================

    /// start_button が表示されているか
    pub def isStartButtonVisible(scene: Scene[NodeTag]): Bool =
        match Scene.getEngineNode(startButtonPath(), scene) {
            case Some(en) => CanvasItem.isVisible(en)
            case None => false
        }

    /// start_button が押されたか
    pub def isStartButtonJustPressed(scene: Scene[NodeTag]): Bool =
        match Scene.getEngineNode(startButtonPath(), scene) {
            case Some(EngineNode.ButtonWithState(btn, _)) => Button.isJustPressed(btn)
            case _ => false
        }

    /// justPressed フラグクリア
    pub def clearStartButtonPress(scene: Scene[NodeTag]): Scene[NodeTag] =
        scene |> Scene.mapEngineNode(startButtonPath(),
            EngineNode.mapButton(Button.clearJustPressed))
}
