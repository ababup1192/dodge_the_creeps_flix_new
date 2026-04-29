// Game — Frogger ゲーム専用の GameData 定義とシーン構築・ゲームロジック

pub enum GamePhase with Eq, ToString {
    case Playing
    case Dying
    case GameOver
    case Win
}

pub type alias GameState = {
    scene = Scene[GameData],
    gameTimer = Timer,
    deathTimer = Timer,
    lives = Int32,
    phase = GamePhase
}

/// ゲーム固有の状態データ
/// EngineNode[GameData] がエンジンノードとゲーム状態を一体で保持する。
pub enum GameData {
    /// プレイヤー（前フレームのキー状態 + 移動先ターゲット）
    case PlayerData({prevKeys = Set[Engine.Key], target = Vec2.Vec2})
    /// 車両（水平速度）
    case VehicleData({vx = Float32})
    /// 丸太/亀プラットフォーム（水平速度 + プラットフォーム幅）
    case PlatformData({vx = Float32, platformWidth = Float32})
    /// ホームスロット（充填済みフラグ）
    case HomeSlotData({filled = Bool})
    /// プレイヤー当たり判定（データなし、AreaHandler で識別用）
    case HitboxData
    /// 静的ノード（スプライト・ラベル等、データなし）
    case StaticData
}

// ── Node 実装 ──

instance Node[GameData] {
    redef process(delta: Float64, node: EngineNode[GameData],
                    _path: NodePath, scene: Scene[GameData]): (EngineNode[GameData], Scene[GameData]) =
        let dt = Float64.truncateToFloat32(delta);
        match node {
            case EngineNode.Body2DWithState(body, GameData.PlayerData(r)) =>
                let currentPos = Node2D.getPosition(body);
                let speed = CharacterBody2D.getMoveSpeed(body);
                let newPos = Vec2.moveToward(currentPos, r#target, speed * dt);
                (EngineNode.Body2DWithState(Node2D.setPosition(newPos, body), GameData.PlayerData(r)), scene)
            case EngineNode.Area2DWithState(_, GameData.VehicleData(r)) =>
                let pos = Node2D.getPosition(node);
                let wrappedX = Game.wrapX(r#vx, pos#x + r#vx * dt);
                (Node2D.setPosition({x = wrappedX, y = pos#y}, node), scene)
            case EngineNode.Area2DWithState(_, GameData.PlatformData(r)) =>
                let pos = Node2D.getPosition(node);
                let wrappedX = Game.wrapX(r#vx, pos#x + r#vx * dt);
                (Node2D.setPosition({x = wrappedX, y = pos#y}, node), scene)
            case _ => (node, scene)
        }
}

// ── AreaHandler 実装 ──

instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath: NodePath, selfState: GameData,
                          otherPath: NodePath, otherState: GameData,
                          scene: Scene[GameData]): Scene[GameData] =
        match (selfState, otherState) {
            // プレイヤーの Hitbox が Vehicle と衝突 → スプライトを赤にする
            case (GameData.HitboxData, GameData.VehicleData(_)) =>
                Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                    EngineNode.mapAnimSprite2D(sprite ->
                        CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite)),
                    scene)
            // プレイヤーの Hitbox が HomeSlot と衝突
            case (GameData.HitboxData, GameData.HomeSlotData(r)) =>
                // 充填済みスロットに入ったら死亡（スプライトを赤にして checkDeath で処理）
                if (r#filled)
                    Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                        EngineNode.mapAnimSprite2D(sprite ->
                            CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite)),
                        scene)
                else
                    scene
                        |> Scene.mapState(otherPath, st -> match st {
                            case GameData.HomeSlotData(hr) =>
                                GameData.HomeSlotData({filled = true | hr})
                            case other2 => other2
                        })
                        |> Scene.mapEngineNode(List.append(otherPath, "sprite" :: Nil),
                            EngineNode.mapSprite2D(sprite -> Sprite2D.setTexture("HomeFrog", sprite)))
                        |> Game.resetPlayerPosition
            case _ => scene
        }
}

mod Game {

    // ========================================================================
    // 初期状態構築
    // ========================================================================

    /// Frogger の初期状態を構築する
    pub def buildState(fontAtlas: FontAtlas): GameState =
        let green: Color = {r = 0.2f32, g = 0.55f32, b = 0.15f32};
        let sw = screenW();
        let scene = Scene.empty()
            // ── 背景ゾーン (zIndex=-10: 最背面) ──
            |> addSolidBg("bgHome", green, {x = 0.0f32, y = homeZoneY()},
                sw, homeZoneH(), -10)
            |> addTiledBg("bgWater", "Water", {x = 0.0f32, y = waterZoneY()},
                sw, waterZoneH(), -10)
            |> addTiledBg("bgMedian", "Median", {x = 0.0f32, y = medianZoneY()},
                sw, medianZoneH(), -10)
            |> addTiledBg("bgRoad", "Road", {x = 0.0f32, y = roadZoneY()},
                sw, roadZoneH(), -10)
            |> addSolidBg("bgStart", green, {x = 0.0f32, y = startZoneY()},
                sw, startZoneH(), -10)
            // ── ホームスロット ──
            |> addAllHomeSlots
            // ── プレイヤー (CharacterBody2D + AnimatedSprite2D + Hitbox) ──
            |> Scene.addNode("player",
                EngineNode.Body2DWithState(
                    CanvasItem.hide(CharacterBody2D.make(playerStart(), moveSpeed = moveSpeed())),
                    GameData.PlayerData({
                        prevKeys = Set.empty(),
                        target = playerStart()
                    })))
            |> Scene.addChild("player", "Sprite",
                EngineNode.AnimSprite2DWithState(
                    AnimatedSprite2D.make(
                        Map#{
                            "idle" => ("FroggerIdle" :: "FroggerLeap" :: Nil),
                            "dead" => ("FroggerDead" :: Nil)
                        },
                        initialAnimation = "idle",
                        fps = 4.0f32,
                        {x = 0.0f32, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32}),
                    GameData.StaticData))
            |> Scene.addChildAt("player" :: Nil, "Hitbox",
                EngineNode.Area2DWithState(
                    CanvasItem.hide(
                        Area2D.make({x = 16.0f32, y = 20.0f32},
                            CollisionShape2D.RectShape2D({width = 32.0f32, height = 24.0f32}))),
                    GameData.HitboxData))
            // ── 車両 ──
            |> addAllVehicles
            // ── 丸太 ──
            |> addAllLogs
            // ── 亀 ──
            |> addAllTurtles
            // ── HUD Label ──
            |> Scene.addNode("timerLabel",
                EngineNode.Label2DWithState(
                    Label2D.make("TIME: 30", fontAtlas, 24.0f32)
                        |> Node2D.setPosition({x = 10.0f32, y = 900.0f32})
                        |> CanvasItem.setZIndex(10),
                    GameData.StaticData))
            |> Scene.addNode("livesLabel",
                EngineNode.Label2DWithState(
                    Label2D.make("LIVES: 3", fontAtlas, 24.0f32)
                        |> Node2D.setPosition({x = 10.0f32, y = 940.0f32})
                        |> CanvasItem.setZIndex(10),
                    GameData.StaticData));
        {
            scene = scene,
            gameTimer = Timer.make(30.0f32) |> Timer.setAutostart(true) |> Timer.ready,
            deathTimer = Timer.make(2.0f32),
            lives = 3,
            phase = GamePhase.Playing
        }

    // ========================================================================
    // メインループ
    // ========================================================================

    pub def start(fontAtlas: FontAtlas): Unit \ Engine.Game =
        gameLoop(fontAtlas, buildState(fontAtlas))

    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game =
        if (Engine.Game.shouldClose()) ()
        else if (Engine.Game.isKeyPressed(Engine.Key.Escape)) ()
        else {
            let dt = Engine.Game.getDeltaTime();
            match state#phase {
                case GamePhase.Playing =>
                    let prevFilled = countFilledHomes(state#scene);
                    { scene = GameEngine.updateWithAreaHandler(dt, false, state#scene) | state }
                        |> handlePlayerInput
                        |> processTimers(dt)
                        |> applyPlatformRiding(dt)
                        |> checkHomeCompletion(prevFilled)
                        |> checkDeath
                        |> checkDrown
                        |> handleTimerTimeouts
                        |> updateHUD
                        |> gameLoop(fontAtlas)
                case GamePhase.Dying =>
                    { scene = GameEngine.updateWithAreaHandler(dt, false, state#scene) | state }
                        |> processTimers(dt)
                        |> handleTimerTimeouts
                        |> updateHUD
                        |> gameLoop(fontAtlas)
                case GamePhase.GameOver =>
                    if (Engine.Game.isKeyPressed(Engine.Key.Enter))
                        gameLoop(fontAtlas, buildState(fontAtlas))
                    else
                        { scene = GameEngine.updateWithAreaHandler(dt, true, state#scene) | state }
                            |> updateHUD
                            |> gameLoop(fontAtlas)
                case GamePhase.Win =>
                    if (Engine.Game.isKeyPressed(Engine.Key.Enter))
                        gameLoop(fontAtlas, buildState(fontAtlas))
                    else
                        { scene = GameEngine.updateWithAreaHandler(dt, true, state#scene) | state }
                            |> updateHUD
                            |> gameLoop(fontAtlas)
            }
        }

    // ========================================================================
    // キーボード入力
    // ========================================================================

    pub def collectPressedKeys(): Set[Engine.Key] \ Engine.Game =
        let keys = Engine.Key.W :: Engine.Key.A :: Engine.Key.S :: Engine.Key.D ::
                   Engine.Key.Up :: Engine.Key.Down :: Engine.Key.Left :: Engine.Key.Right ::
                   Engine.Key.Enter :: Engine.Key.Escape :: Nil;
        List.foldLeft((acc, key) ->
            if (Engine.Game.isKeyPressed(key)) Set.insert(key, acc) else acc,
            Set.empty(), keys)

    pub def justPressedKeys(current: Set[Engine.Key], previous: Set[Engine.Key]): Set[Engine.Key] =
        Set.difference(current, previous)

    pub def inputDirection(justPressed: Set[Engine.Key]): Option[Vec2.Vec2] =
        if (Set.memberOf(Engine.Key.W, justPressed) or Set.memberOf(Engine.Key.Up, justPressed))
            Some(Vec2.up())
        else if (Set.memberOf(Engine.Key.S, justPressed) or Set.memberOf(Engine.Key.Down, justPressed))
            Some(Vec2.down())
        else if (Set.memberOf(Engine.Key.A, justPressed) or Set.memberOf(Engine.Key.Left, justPressed))
            Some(Vec2.left())
        else if (Set.memberOf(Engine.Key.D, justPressed) or Set.memberOf(Engine.Key.Right, justPressed))
            Some(Vec2.right())
        else
            None

    // ========================================================================
    // プレイヤー操作
    // ========================================================================

    pub def directionToRotation(direction: Vec2.Vec2): Float64 =
        if (direction#y < 0.0f32) 0.0
        else if (direction#x > 0.0f32) 1.5707963267949
        else if (direction#y > 0.0f32) 3.1415926535898
        else -1.5707963267949

    pub def getPlayerTarget(scene: Scene[GameData]): Vec2.Vec2 =
        match Scene.get("player", scene) {
            case Some(GameData.PlayerData(r)) => r#target
            case _ => playerStart()
        }

    // ========================================================================
    // プレイヤー入力処理
    // ========================================================================

    pub def handlePlayerInput(state: GameState): GameState \ Engine.Game =
        match Scene.get("player", state#scene) {
            case Some(GameData.PlayerData(r)) =>
                let currKeys = collectPressedKeys();
                if (state#phase != GamePhase.Playing)
                    { scene = Scene.mapState("player" :: Nil, st -> match st {
                        case GameData.PlayerData(pr) => GameData.PlayerData({prevKeys = currKeys | pr})
                        case other => other
                    }, state#scene) | state }
                else {
                    let justPressed = justPressedKeys(currKeys, r#prevKeys);
                    match inputDirection(justPressed) {
                        case None =>
                            { scene = Scene.mapState("player" :: Nil, st -> match st {
                                case GameData.PlayerData(pr) => GameData.PlayerData({prevKeys = currKeys | pr})
                                case other => other
                            }, state#scene) | state }
                        case Some(dir) =>
                            let nt = Vec2.clamp(
                                Vec2.add(r#target, Vec2.mul(dir, tileSize())),
                                playerMin(), playerMax());
                            { scene = state#scene
                                |> Scene.mapState("player" :: Nil, st -> match st {
                                    case GameData.PlayerData(pr) =>
                                        GameData.PlayerData({prevKeys = currKeys, target = nt | pr})
                                    case other => other
                                })
                                |> Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                                    EngineNode.mapAnimSprite2D(sprite ->
                                        Node2D.setRotation(directionToRotation(dir), sprite)))
                              | state }
                    }
                }
            case _ => state
        }

    // ========================================================================
    // 画面・タイル定数
    // ========================================================================

    /// 画面幅（ピクセル）
    pub def screenW(): Float32 = 784.0f32

    /// 画面高さ（ピクセル）
    pub def screenH(): Float32 = 1000.0f32

    /// 画面幅（整数、EngineConfig 用）
    pub def screenWi(): Int32 = 784

    /// 画面高さ（整数、EngineConfig 用）
    pub def screenHi(): Int32 = 1000

    /// 1 タイルのサイズ（16px テクスチャを 4 倍表示）
    pub def tileSize(): Float32 = 64.0f32

    // ========================================================================
    // プレイヤー定数
    // ========================================================================

    /// プレイヤー初期位置（スタートゾーン中央）
    pub def playerStart(): Vec2.Vec2 = {x = 384.0f32, y = 832.0f32}

    /// プレイヤー移動速度（ピクセル/秒）
    pub def moveSpeed(): Float32 = 512.0f32

    /// プレイヤー位置クランプ範囲（左上）
    pub def playerMin(): Vec2.Vec2 = {x = 0.0f32, y = 0.0f32}

    /// プレイヤー位置クランプ範囲（右下: screenW - tileSize, スタートゾーン Y）
    pub def playerMax(): Vec2.Vec2 = {x = 720.0f32, y = 832.0f32}

    // ========================================================================
    // ゾーン Y 座標・高さ
    // ========================================================================

    def homeZoneY(): Float32 = 0.0f32
    def homeZoneH(): Float32 = 64.0f32

    pub def waterZoneY(): Float32 = 64.0f32
    pub def waterZoneH(): Float32 = 384.0f32

    def medianZoneY(): Float32 = 448.0f32
    def medianZoneH(): Float32 = 64.0f32

    def roadZoneY(): Float32 = 512.0f32
    def roadZoneH(): Float32 = 320.0f32

    def startZoneY(): Float32 = 832.0f32
    def startZoneH(): Float32 = 64.0f32

    // ========================================================================
    // スプライト生成ヘルパー
    // ========================================================================

    /// タイリング背景スプライトをシーンに追加する
    def addTiledBg(name: NodeName, texture: String, position: Vec2.Vec2,
                    width: Float32, height: Float32,
                    zIndex: Int32, scene: Scene[GameData]): Scene[GameData] =
        let texSize = 16.0f32;
        Scene.addNode(name,
            EngineNode.Sprite2DWithState(Sprite2D.Sprite2D({
                position = position,
                rotation = 0.0,
                scale = {x = width / texSize, y = height / texSize},
                skew = 0.0,
                visible = true,
                zIndex = zIndex,
                modulate = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
                texture = texture,
                centered = false,
                offset = {x = 0.0f32, y = 0.0f32},
                flipH = false,
                flipV = false
            }), GameData.StaticData),
            scene)

    /// 単色の矩形背景をシーンに追加する
    def addSolidBg(name: NodeName, color: Color, position: Vec2.Vec2,
                    width: Float32, height: Float32,
                    zIndex: Int32, scene: Scene[GameData]): Scene[GameData] =
        Scene.addNode(name,
            EngineNode.Sprite2DWithState(Sprite2D.Sprite2D({
                position = position,
                rotation = 0.0,
                scale = {x = width, y = height},
                skew = 0.0,
                visible = true,
                zIndex = zIndex,
                modulate = color,
                texture = "white",
                centered = false,
                offset = {x = 0.0f32, y = 0.0f32},
                flipH = false,
                flipV = false
            }), GameData.StaticData),
            scene)

    // ========================================================================
    // 移動ヘルパー
    // ========================================================================

    /// 水平方向に移動した X 座標を画面外でラップする
    pub def wrapX(vx: Float32, newX: Float32): Float32 =
        if (vx < 0.0f32 and newX < -100.0f32)
            screenW() + 100.0f32
        else if (vx > 0.0f32 and newX > screenW() + 100.0f32)
            -100.0f32
        else
            newX

    // ========================================================================
    // 車両生成
    // ========================================================================

    /// 車両レーンの設定
    type alias VehicleLaneConfig = {
        texture = String,    // テクスチャ名
        y = Float32,         // レーン Y 座標
        vx = Float32,        // 速度（px/s, 負で左向き）
        count = Int32,       // 台数
        spacing = Float32    // 車両間の間隔
    }

    /// 5 レーン分の車両設定（旧 Frogger 準拠）
    def vehicleLanes(): List[VehicleLaneConfig] =
        {texture = "Car1", y = 512.0f32, vx = -200.0f32, count = 3, spacing = 100.0f32} ::
        {texture = "Car2", y = 576.0f32, vx = 250.0f32,  count = 4, spacing = 150.0f32} ::
        {texture = "Car3", y = 640.0f32, vx = -200.0f32, count = 2, spacing = 300.0f32} ::
        {texture = "Car4", y = 704.0f32, vx = 200.0f32,  count = 4, spacing = 300.0f32} ::
        {texture = "Car5", y = 768.0f32, vx = -160.0f32, count = 2, spacing = 230.0f32} ::
        Nil

    /// 1 レーン分の Vehicle ノードをシーンに追加する
    def addVehicleLane(laneIdx: Int32, config: VehicleLaneConfig,
                       scene: Scene[GameData]): Scene[GameData] =
        List.range(0, config#count) |> List.foldLeft((acc, vehicleIdx) -> {
            let name = "v${laneIdx}_${vehicleIdx}";
            let startX = Int32.toFloat32(vehicleIdx) * (tileSize() + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = 64.0f32, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(true);
            acc
                |> Scene.addNode(name,
                    EngineNode.Area2DWithState(area, GameData.VehicleData({vx = config#vx})))
                |> Scene.addChild(name, "sprite",
                    EngineNode.Sprite2DWithState(
                        Sprite2D.make(config#texture, {x = 0.0f32, y = 0.0f32},
                            {x = 4.0f32, y = 4.0f32}),
                        GameData.StaticData))
        }, scene)

    /// 全車両レーンをシーンに追加する
    def addAllVehicles(scene: Scene[GameData]): Scene[GameData] =
        vehicleLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addVehicleLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // 丸太生成
    // ========================================================================

    /// 丸太レーンの設定
    /// middles: 中間セグメント数（合計ピース数 = middles + 2）
    type alias LogLaneConfig = {
        y = Float32,         // レーン Y 座標
        vx = Float32,        // 速度（px/s）
        middles = Int32,     // 中間セグメント数
        count = Int32,       // 丸太の本数
        spacing = Float32    // 丸太間の間隔
    }

    /// 4 レーン分の丸太設定（旧 Frogger 準拠）
    def logLanes(): List[LogLaneConfig] =
        {y =  64.0f32, vx =  120.0f32, middles = 1, count = 3, spacing = 250.0f32} ::
        {y = 128.0f32, vx =  -80.0f32, middles = 2, count = 2, spacing = 350.0f32} ::
        {y = 192.0f32, vx =  150.0f32, middles = 0, count = 4, spacing = 200.0f32} ::
        {y = 256.0f32, vx = -100.0f32, middles = 1, count = 3, spacing = 280.0f32} ::
        Nil

    /// 丸太のプラットフォーム幅を計算する（middles + 2 ピース × tileSize）
    def logWidth(middles: Int32): Float32 =
        Int32.toFloat32(middles + 2) * tileSize()

    /// 1 本の丸太にスプライト子ノードを追加する
    def addLogSprites(logName: String, middles: Int32,
                      scene: Scene[GameData]): Scene[GameData] =
        let totalPieces = middles + 2;
        let totalWidth = logWidth(middles);
        List.range(0, totalPieces) |> List.foldLeft((acc, pieceIdx) -> {
            let texture =
                if (pieceIdx == 0) "LogStart"
                else if (pieceIdx == totalPieces - 1) "LogEnd"
                else "LogMiddle";
            let offsetX = -1.0f32 * totalWidth / 2.0f32 + 32.0f32 + Int32.toFloat32(pieceIdx) * tileSize();
            Scene.addChild(logName, "s${pieceIdx}",
                EngineNode.Sprite2DWithState(
                    Sprite2D.make(texture, {x = offsetX, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32}),
                    GameData.StaticData),
                acc)
        }, scene)

    /// 1 レーン分の LogPlatform ノードをシーンに追加する
    def addLogLane(laneIdx: Int32, config: LogLaneConfig,
                   scene: Scene[GameData]): Scene[GameData] =
        let platformWidth = logWidth(config#middles);
        List.range(0, config#count) |> List.foldLeft((acc, logIdx) -> {
            let name = "l${laneIdx}_${logIdx}";
            let startX = Int32.toFloat32(logIdx) * (platformWidth + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = platformWidth, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> CanvasItem.hide
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(false);
            acc
                |> Scene.addNode(name,
                    EngineNode.Area2DWithState(area, GameData.PlatformData({vx = config#vx, platformWidth = platformWidth})))
                |> addLogSprites(name, config#middles)
        }, scene)

    /// 全丸太レーンをシーンに追加する
    def addAllLogs(scene: Scene[GameData]): Scene[GameData] =
        logLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addLogLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // 亀生成
    // ========================================================================

    type alias TurtleLaneConfig = {
        y = Float32,
        vx = Float32,
        sections = Int32,
        count = Int32,
        spacing = Float32
    }

    def turtleLanes(): List[TurtleLaneConfig] =
        {y = 320.0f32, vx =  100.0f32, sections = 3, count = 3, spacing = 250.0f32} ::
        {y = 384.0f32, vx = -130.0f32, sections = 4, count = 2, spacing = 200.0f32} ::
        Nil

    def turtleWidth(sections: Int32): Float32 =
        Int32.toFloat32(sections) * tileSize()

    def addTurtleSprites(turtleName: String, sections: Int32,
                         scene: Scene[GameData]): Scene[GameData] =
        let totalWidth = turtleWidth(sections);
        List.range(0, sections) |> List.foldLeft((acc, sectionIdx) -> {
            let offsetX = -1.0f32 * totalWidth / 2.0f32 + 32.0f32 + Int32.toFloat32(sectionIdx) * tileSize();
            Scene.addChild(turtleName, "s${sectionIdx}",
                EngineNode.Sprite2DWithState(
                    Sprite2D.make("Turtle_01", {x = offsetX, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32}),
                    GameData.StaticData),
                acc)
        }, scene)

    def addTurtleLane(laneIdx: Int32, config: TurtleLaneConfig,
                      scene: Scene[GameData]): Scene[GameData] =
        let platformWidth = turtleWidth(config#sections);
        List.range(0, config#count) |> List.foldLeft((acc, turtleIdx) -> {
            let name = "t${laneIdx}_${turtleIdx}";
            let startX = Int32.toFloat32(turtleIdx) * (platformWidth + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = platformWidth, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> CanvasItem.hide
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(false);
            acc
                |> Scene.addNode(name,
                    EngineNode.Area2DWithState(area, GameData.PlatformData({vx = config#vx, platformWidth = platformWidth})))
                |> addTurtleSprites(name, config#sections)
        }, scene)

    def addAllTurtles(scene: Scene[GameData]): Scene[GameData] =
        turtleLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addTurtleLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // ホームスロット生成
    // ========================================================================

    def homeSlotXPositions(): List[Float32] =
        64.0f32 :: 192.0f32 :: 384.0f32 :: 512.0f32 :: 704.0f32 :: Nil

    def addAllHomeSlots(scene: Scene[GameData]): Scene[GameData] =
        homeSlotXPositions()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, slotX) = pair;
                let name = "home${idx}";
                let shape = CollisionShape2D.RectShape2D({width = 64.0f32, height = 64.0f32});
                let area = Area2D.make({x = slotX, y = homeZoneY()}, shape)
                    |> CanvasItem.hide
                    |> Area2D.setMonitoring(false)
                    |> Area2D.setMonitorable(true);
                acc
                    |> Scene.addNode(name,
                        EngineNode.Area2DWithState(area, GameData.HomeSlotData({filled = false})))
                    |> Scene.addChild(name, "sprite",
                        EngineNode.Sprite2DWithState(
                            Sprite2D.make("Home", {x = 0.0f32, y = 0.0f32},
                                {x = 4.0f32, y = 4.0f32}),
                            GameData.StaticData))
            }, scene)

    // ========================================================================
    // ホームスロット判定
    // ========================================================================

    /// 充填済みホームスロットの数を返す
    pub def countFilledHomes(scene: Scene[GameData]): Int32 =
        homeSlotXPositions()
            |> List.zipWithIndex
            |> List.foldLeft((count, pair) -> {
                let (idx, _) = pair;
                match Scene.get("home${idx}", scene) {
                    case Some(GameData.HomeSlotData(r)) => if (r#filled) count + 1 else count
                    case _ => count
                }
            }, 0)

    /// 全ホームスロットが充填済みかを返す
    pub def allHomesFilled(scene: Scene[GameData]): Bool =
        countFilledHomes(scene) == List.length(homeSlotXPositions())

    /// AreaHandler によるスロット充填後の後処理。
    /// 充填数が増えていたらタイマーをリセットし、全充填なら Win に遷移する。
    pub def checkHomeCompletion(prevFilledCount: Int32, state: GameState): GameState =
        let currentCount = countFilledHomes(state#scene);
        if (currentCount > prevFilledCount) {
            let newPhase = if (allHomesFilled(state#scene)) GamePhase.Win else state#phase;
            { gameTimer = Timer.start(state#gameTimer), phase = newPhase | state }
        } else state

    // ========================================================================
    // プラットフォーム乗り
    // ========================================================================

    def isOnPlatform(playerPos: Vec2.Vec2, logPos: Vec2.Vec2,
                     platformWidth: Float32): Bool =
        let halfW = platformWidth / 2.0f32;
        let halfH = 32.0f32;
        playerPos#x >= logPos#x - halfW and playerPos#x <= logPos#x + halfW and
        playerPos#y >= logPos#y - halfH and playerPos#y <= logPos#y + halfH

    pub def findPlatformVelocity(scene: Scene[GameData]): Option[Float32] =
        let playerPos = Scene.globalPosition("player", scene);
        Map.foldLeftWithKey((acc, name, state) ->
            match acc {
                case Some(_) => acc
                case None =>
                    match state {
                        case GameData.PlatformData(r) =>
                            let platformPos = Scene.globalPosition(name, scene);
                            if (isOnPlatform(playerPos, platformPos, r#platformWidth))
                                Some(r#vx)
                            else
                                None
                        case _ => None
                    }
            },
            None, Scene.states(scene))

    def applyPlatformRiding(dt: Float32, state: GameState): GameState =
        match findPlatformVelocity(state#scene) {
            case None => state
            case Some(platformVx) =>
                let shift: Vec2.Vec2 = {x = platformVx * dt, y = 0.0f32};
                { scene = state#scene
                    |> Scene.mapEngineNode("player" :: Nil,
                        EngineNode.mapBody2D(body ->
                            Node2D.setPosition(Vec2.add(Node2D.getPosition(body), shift), body)))
                    |> Scene.mapState("player" :: Nil, st -> match st {
                        case GameData.PlayerData(r) =>
                            GameData.PlayerData({target = Vec2.add(r#target, shift) | r})
                        case other => other
                    })
                  | state }
        }

    // ========================================================================
    // 死亡判定
    // ========================================================================

    /// 死亡演出を開始する（アニメーション変更 + deathTimer 開始 + phase を Dying に遷移）
    pub def triggerDeath(color: Color, state: GameState): GameState =
        { scene = playDeathAnim(color, state#scene),
          deathTimer = Timer.start(state#deathTimer),
          phase = GamePhase.Dying | state }

    pub def playDeathAnim(color: Color, scene: Scene[GameData]): Scene[GameData] =
        Scene.mapEngineNode("player" :: "Sprite" :: Nil,
            EngineNode.mapAnimSprite2D(sprite ->
                sprite |> AnimatedSprite2D.play("dead") |> CanvasItem.setModulate(color)),
            scene)

    pub def checkDeath(state: GameState): GameState =
        match Scene.getEngineNode("player" :: "Sprite" :: Nil, state#scene) {
            case Some(EngineNode.AnimSprite2DWithState(sprite, _)) =>
                let color = CanvasItem.getModulate(sprite);
                if (color#g < 0.5f32 and state#phase == GamePhase.Playing)
                    triggerDeath({r = 1.0f32, g = 0.2f32, b = 0.2f32}, state)
                else
                    state
            case _ => state
        }

    pub def checkDrown(state: GameState): GameState =
        if (state#phase != GamePhase.Playing) state
        else {
            let target = getPlayerTarget(state#scene);
            let playerPos = Scene.globalPosition("player", state#scene);
            let arrived = Vec2.distanceTo(playerPos, target) < 2.0f32;
            let inWater = target#y >= waterZoneY() and target#y < waterZoneY() + waterZoneH();
            if (arrived and inWater) {
                match findPlatformVelocity(state#scene) {
                    case Some(_) => state
                    case None =>
                        triggerDeath({r = 0.2f32, g = 0.2f32, b = 1.0f32}, state)
                }
            } else
                state
        }

    // ========================================================================
    // タイマー処理・リスポーン
    // ========================================================================

    /// プレイヤーとターゲットの位置をスタート地点にリセットする
    pub def resetPlayerPosition(scene: Scene[GameData]): Scene[GameData] =
        scene
            |> Scene.mapEngineNode("player" :: Nil,
                EngineNode.mapBody2D(body -> Node2D.setPosition(playerStart(), body)))
            |> Scene.mapState("player" :: Nil, st -> match st {
                case GameData.PlayerData(r) =>
                    GameData.PlayerData({target = playerStart() | r})
                case other => other
            })

    /// タイマーのカウントダウンを進める
    pub def processTimers(dt: Float32, state: GameState): GameState =
        { gameTimer = Timer.process(dt, state#gameTimer),
          deathTimer = Timer.process(dt, state#deathTimer) | state }

    /// タイムアウトを検出して処理する
    pub def handleTimerTimeouts(state: GameState): GameState =
        // gameTimer タイムアウト: deathTimer 動作中でなければ死亡演出 + deathTimer 開始
        let state1 = if (Timer.isTimedOut(state#gameTimer)) {
            let cleared = { gameTimer = Timer.clearTimedOut(state#gameTimer) | state };
            if (Timer.isRunning(state#deathTimer)) cleared
            else if (state#phase != GamePhase.Playing) cleared
            else triggerDeath({r = 1.0f32, g = 1.0f32, b = 0.2f32}, cleared)
        } else state;
        // deathTimer タイムアウト: リスポーン + lives-1
        if (Timer.isTimedOut(state1#deathTimer)) {
            let newLives = state1#lives - 1;
            let newScene = resetPlayerPosition(state1#scene)
                |> Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                    EngineNode.mapAnimSprite2D(sprite ->
                        sprite
                            |> AnimatedSprite2D.play("idle")
                            |> CanvasItem.setModulate({r = 1.0f32, g = 1.0f32, b = 1.0f32})
                            |> Node2D.setRotation(0.0)));
            let newPhase = if (newLives <= 0) GamePhase.GameOver else GamePhase.Playing;
            { scene = newScene,
              deathTimer = Timer.clearTimedOut(state1#deathTimer),
              gameTimer = Timer.start(state1#gameTimer),
              phase = newPhase,
              lives = newLives }
        } else state1


    // ========================================================================
    // HUD 更新
    // ========================================================================

    /// Timer / lives の値を Label2D テキストに反映する
    def updateHUD(state: GameState): GameState =
        let timeInt = Float64.truncateToInt32(
            Float32.toFloat64(Float32.max(0.0f32, Timer.getTimeLeft(state#gameTimer))));
        { scene = state#scene
            |> Scene.mapEngineNode("timerLabel" :: Nil,
                EngineNode.mapLabel2D(label -> Label2D.setText("TIME: ${timeInt}", label)))
            |> Scene.mapEngineNode("livesLabel" :: Nil,
                EngineNode.mapLabel2D(label -> Label2D.setText("LIVES: ${state#lives}", label)))
          | state }

}
