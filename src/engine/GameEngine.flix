// GameEngine module — shared types and effects for the game engine layer

mod GameEngine {
    import java.lang.ProcessBuilder
    import java.lang.System
    import java.util.ArrayList

    /// テクスチャアセットのマニフェストエントリ
    pub type alias TextureEntry = { name = String, path = String, hasAlpha = Bool }

    /// フォントアセットのマニフェストエントリ
    pub type alias FontEntry = { name = String, path = String, fontSize = Float64 }

    /// テクスチャ情報: GPU ハンドル ID + 元画像サイズ
    pub type alias TextureInfo = { id = Int32, width = Float64, height = Float64 }

    /// テクスチャの論理名 → TextureInfo
    pub type alias TextureRegistry = Map[String, TextureInfo]

    /// エンジン初期化に必要な設定
    pub type alias EngineConfig = {
        screenWidth = Int32,
        screenHeight = Int32,
        title = String,
        textureManifest = List[TextureEntry],
        fontManifest = List[FontEntry],
        clearColor = Color
    }

    /// 描画用データ: render ハンドラに渡す
    pub type alias Drawable = {
        texture = String,
        position = Vec2.Vec2,
        scale = Vec2.Vec2,
        rotation = Float64,
        color = Color,
        centered = Bool,
        uvOffset = Vec2.Vec2,
        uvScale = Vec2.Vec2,
        zIndex = Int32
    }

    /// ノードを Drawable のリストに変換する能力を表す trait
    /// Label2D 等、1 ノードから複数 Drawable を生成するケースに対応
    pub trait Renderable[n] {
        pub def toDrawables(node: n, globalPos: Vec2.Vec2): List[Drawable]
    }

    /// キーボードキー（Frogger で使用するキーのみ）
    pub enum Key with Eq, Order, ToString {
        case W
        case A
        case S
        case D
        case Up
        case Down
        case Left
        case Right
        case Enter
        case Escape
    }

    /// ゲームエフェクト: 描画・ウィンドウ制御・時間取得・キー入力・フォント・ビューポート
    pub eff Game {
        def render(drawables: List[Drawable]): Unit
        def shouldClose(): Bool
        def getDeltaTime(): Float64
        def isKeyPressed(key: Key): Bool
        def getFontAtlas(name: String): FontAtlas
        def getViewportRect(): Rect2.Rect2
    }

    // ========================================================================
    // パイプライン — >> で合成してフレーム更新を組み立てる
    // ========================================================================
    //
    //   let updateScene =
    //       GameEngine.process(dt, false)
    //       >> GameEngine.physics(dt, false, gravity)
    //       >> GameEngine.collisions
    //       >> GameEngine.offscreen(screenWidth = 480, screenHeight = 720);
    //   GameEngine.render(updateScene(scene));

    /// 全ノードの毎フレーム処理を実行する
    pub def process(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] \ Game
            with Node[s] =
        Scene.processAll(delta, paused, scene)

    /// 物理演算（重力・ダンピング・速度積分）を適用する
    pub def physics(delta: Float64, paused: Bool, gravity: Vec2.Vec2,
                    scene: Scene[s]): Scene[s]
            with Node[s] =
        PhysicsStep.step(delta, paused, gravity, scene)

    /// エリア衝突を検出し AreaHandler で応答する
    pub def collisions(scene: Scene[s]): Scene[s]
            with AreaHandler[s] =
        AreaEvent.handleOverlaps(scene)

    /// 画面外に出たノードに ScreenNotifyHandler で通知する
    pub def offscreen(screenWidth: {screenWidth = Int32},
                      screenHeight: {screenHeight = Int32},
                      scene: Scene[s]): Scene[s]
            with ScreenNotifyHandler[s] =
        ScreenNotifyEvent.handleScreenExited(screenWidth, screenHeight, scene)

    /// シーンを描画する
    pub def render(scene: Scene[s]): Unit \ Game =
        Scene.toDrawables(scene) |> Game.render

    // ========================================================================
    // プラットフォーム
    // ========================================================================

    /// macOS では -XstartOnFirstThread 付きでプロセスを再起動する。
    /// 再起動した場合 true を返す（呼び出し元は終了すべき）。
    pub def ensureMainThread(): Bool \ IO =
        let osName = System.getProperty("os.name");
        if (Object.isNull(osName) or not String.contains({substr = "Mac"}, osName))
            false
        else if (not Object.isNull(System.getProperty("game.relaunched")))
            false
        else {
            println("Relaunching with -XstartOnFirstThread...");
            let javaHome = System.getProperty("java.home");
            let javaBin = "${javaHome}/bin/java";
            let args = new ArrayList();
            discard args.add(javaBin);
            discard args.add("-XstartOnFirstThread");
            discard args.add("-Dgame.relaunched=true");
            let projectPath = System.getProperty("projectPath");
            if (not Object.isNull(projectPath))
                discard args.add("-DprojectPath=${projectPath}")
            else ();
            discard args.add("-jar");
            discard args.add("bin/flix.jar");
            discard args.add("run");
            let pb = new ProcessBuilder(args);
            discard pb.inheritIO();
            let proc = pb.start();
            let code = proc.waitFor();
            System.exit(code);
            true
        }
}
