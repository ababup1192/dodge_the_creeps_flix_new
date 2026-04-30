pub type alias NodeName = String
pub type alias NodePath = List[NodeName]

/// ノードエントリ: エンジンノード（ゲーム状態含む） + 子ノードを再帰的に内包する
pub enum SceneEntry[s] {
    case SceneEntry({
        engineNode = EngineNode[s],
        children = Map[NodeName, SceneEntry[s]]
    })
}

/// シーン: ルートノードのみを Map で保持し、各 SceneEntry が子を再帰的に内包する
pub enum Scene[s] {
    case Scene({
        nodes = Map[NodeName, SceneEntry[s]],
        prevOverlaps = OverlapPairSet,
        prevOnScreen = Set[NodePath],
        readied = Bool
    })
}

pub mod Scene {

    // ========================================================================
    // 内部ヘルパー
    // ========================================================================

    /// Scene のルート Map を取り出す
    def roots(scene: Scene[s]): Map[NodeName, SceneEntry[s]] =
        let Scene.Scene(r) = scene;
        r#nodes

    /// 前フレームの重なりペアセットを取り出す
    pub def getPrevOverlaps(scene: Scene[s]): OverlapPairSet =
        let Scene.Scene(r) = scene;
        r#prevOverlaps

    /// 前フレームの重なりペアセットを設定する
    pub def setPrevOverlaps(overlaps: OverlapPairSet, scene: Scene[s]): Scene[s] =
        let Scene.Scene(r) = scene;
        Scene.Scene({ prevOverlaps = overlaps | r })

    /// 前フレームで画面内だったノードパスのセットを取り出す
    pub def getPrevOnScreen(scene: Scene[s]): Set[NodePath] =
        let Scene.Scene(r) = scene;
        r#prevOnScreen

    /// 前フレームの画面内ノードパスセットを設定する
    pub def setPrevOnScreen(onScreen: Set[NodePath], scene: Scene[s]): Scene[s] =
        let Scene.Scene(r) = scene;
        Scene.Scene({ prevOnScreen = onScreen | r })

    /// SceneEntry のエンジンノードを取り出す
    def entryEngineNode(entry: SceneEntry[s]): EngineNode[s] =
        let SceneEntry.SceneEntry(r) = entry;
        r#engineNode

    /// SceneEntry の children を取り出す
    def entryChildren(entry: SceneEntry[s]): Map[NodeName, SceneEntry[s]] =
        let SceneEntry.SceneEntry(r) = entry;
        r#children

    /// パスをたどって SceneEntry を取得
    def getEntryAt(path: NodePath, scene: Scene[s]): Option[SceneEntry[s]] =
        match path {
            case Nil => None
            case name :: rest =>
                Map.get(name, roots(scene))
                    |> Option.flatMap(entry -> getEntryIn(rest, entry))
        }

    /// SceneEntry 内のパスをたどって子孫の SceneEntry を取得
    def getEntryIn(path: NodePath, entry: SceneEntry[s]): Option[SceneEntry[s]] =
        match path {
            case Nil => Some(entry)
            case name :: rest =>
                Map.get(name, entryChildren(entry))
                    |> Option.flatMap(child -> getEntryIn(rest, child))
        }

    // ========================================================================
    // ツリー変換（高階関数によるパス走査の共通化）
    // ========================================================================

    /// SceneEntry 内のパスをたどり、末端のエントリに f を適用して再構築する
    def modifyEntryIn(path: NodePath, f: SceneEntry[s] -> SceneEntry[s],
                      entry: SceneEntry[s]): SceneEntry[s] =
        let SceneEntry.SceneEntry(r) = entry;
        match path {
            case Nil => f(entry)
            case name :: rest =>
                match Map.get(name, r#children) {
                    case None => entry
                    case Some(child) =>
                        let updatedChild = modifyEntryIn(rest, f, child);
                        SceneEntry.SceneEntry({ children = Map.insert(name, updatedChild, r#children) | r })
                }
        }

    /// パスで指定されたエントリに f を適用し、Scene を再構築する
    def modifyAt(path: NodePath, f: SceneEntry[s] -> SceneEntry[s],
                 scene: Scene[s]): Scene[s] =
        match path {
            case Nil => scene
            case rootName :: rest =>
                let Scene.Scene(r) = scene;
                match Map.get(rootName, r#nodes) {
                    case None => scene
                    case Some(rootEntry) =>
                        let updated = modifyEntryIn(rest, f, rootEntry);
                        Scene.Scene({ nodes = Map.insert(rootName, updated, r#nodes) | r })
                }
        }

    /// パスの末尾を除いた親パスを返す（List.dropRight(1) の代替）
    def initPath(path: NodePath): NodePath =
        match List.reverse(path) {
            case Nil => Nil
            case _ :: rest => List.reverse(rest)
        }

    /// SceneEntry から深さ優先（preorder）でパスリストを返す
    def preorderFromEntry(prefix: NodePath, entry: SceneEntry[s]): List[NodePath] =
        let myPath = prefix;
        let childPaths = Map.foldLeftWithKey((acc, childName, childEntry) ->
            List.append(acc, preorderFromEntry(List.append(prefix, childName :: Nil), childEntry)),
            Nil,
            entryChildren(entry));
        myPath :: childPaths

    // ========================================================================
    // 基本操作
    // ========================================================================

    /// 空のシーンを返す
    pub def empty(): Scene[s] =
        Scene.Scene({ nodes = Map.empty(), prevOverlaps = Set.empty(), prevOnScreen = Set.empty(), readied = false })

    /// ルートノードとして追加する（state は EngineNode[s] 内に含まれる）
    pub def addNode(name: NodeName, engineNode: EngineNode[s], scene: Scene[s]): Scene[s] =
        let Scene.Scene(r) = scene;
        let entry = SceneEntry.SceneEntry({ engineNode = engineNode, children = Map.empty() });
        Scene.Scene({ nodes = Map.insert(name, entry, r#nodes) | r })

    /// 親がルートの子追加
    pub def addChild(parentName: NodeName, childName: NodeName, engineNode: EngineNode[s], scene: Scene[s]): Scene[s] =
        addChildAt(parentName :: Nil, childName, engineNode, scene)

    /// 任意深さの子追加
    pub def addChildAt(parentPath: NodePath, childName: NodeName, engineNode: EngineNode[s], scene: Scene[s]): Scene[s] =
        match getEntryAt(parentPath, scene) {
            case None => scene
            case Some(_) =>
                let childEntry = SceneEntry.SceneEntry({ engineNode = engineNode, children = Map.empty() });
                modifyAt(parentPath, entry ->
                    let SceneEntry.SceneEntry(r) = entry;
                    SceneEntry.SceneEntry({ children = Map.insert(childName, childEntry, r#children) | r }),
                    scene)
        }

    // ========================================================================
    // 取得
    // ========================================================================

    /// パスをたどってゲーム状態を取得
    pub def getState(path: NodePath, scene: Scene[s]): Option[s] =
        getEntryAt(path, scene) |> Option.map(entry -> EngineNode.getState(entryEngineNode(entry)))

    /// パスをたどってエンジンノードを取得
    pub def getEngineNode(path: NodePath, scene: Scene[s]): Option[EngineNode[s]] =
        getEntryAt(path, scene) |> Option.map(entryEngineNode)

    /// ルートのゲーム状態を取得（後方互換）
    pub def get(name: NodeName, scene: Scene[s]): Option[s] =
        getState(name :: Nil, scene)

    // ========================================================================
    // 更新
    // ========================================================================

    /// パスをたどってゲーム状態を更新
    pub def setState(path: NodePath, state: s, scene: Scene[s]): Scene[s] =
        mapEngineNode(path, en -> EngineNode.setState(state, en), scene)

    /// パスをたどってエンジンノードを更新
    pub def setEngineNode(path: NodePath, engineNode: EngineNode[s], scene: Scene[s]): Scene[s] =
        modifyAt(path, entry ->
            let SceneEntry.SceneEntry(r) = entry;
            SceneEntry.SceneEntry({ engineNode = engineNode | r }),
            scene)

    /// ルート更新（後方互換）— 状態のみ更新
    pub def set(name: NodeName, state: s, scene: Scene[s]): Scene[s] =
        setState(name :: Nil, state, scene)

    // ========================================================================
    // マップ（変換関数の適用）
    // ========================================================================

    /// パスで指定されたノードのゲーム状態に関数を適用する
    pub def mapState(path: NodePath, f: s -> s, scene: Scene[s]): Scene[s] =
        mapEngineNode(path, en -> EngineNode.mapState(f, en), scene)

    /// パスで指定されたノードのエンジンノードに関数を適用する
    pub def mapEngineNode(path: NodePath, f: EngineNode[s] -> EngineNode[s], scene: Scene[s]): Scene[s] =
        modifyAt(path, entry ->
            let SceneEntry.SceneEntry(r) = entry;
            SceneEntry.SceneEntry({ engineNode = f(r#engineNode) | r }),
            scene)

    // ========================================================================
    // 削除
    // ========================================================================

    /// ルート削除
    pub def remove(name: NodeName, scene: Scene[s]): Scene[s] =
        removeAt(name :: Nil, scene)

    /// パスで削除
    pub def removeAt(path: NodePath, scene: Scene[s]): Scene[s] =
        let Scene.Scene(sr) = scene;
        match List.reverse(path) {
            case Nil => scene
            case childName :: Nil =>
                Scene.Scene({ nodes = Map.remove(childName, sr#nodes) | sr })
            case childName :: parentRev =>
                modifyAt(List.reverse(parentRev), entry ->
                    let SceneEntry.SceneEntry(r) = entry;
                    SceneEntry.SceneEntry({ children = Map.remove(childName, r#children) | r }),
                    scene)
        }

    // ========================================================================
    // ルートノード一覧
    // ========================================================================

    /// ルートノードのゲーム状態を Map で返す
    pub def states(scene: Scene[s]): Map[NodeName, s] =
        Map.map(entry -> EngineNode.getState(entryEngineNode(entry)), roots(scene))

    /// ルートノードの EngineNode を Map で返す
    pub def nodes(scene: Scene[s]): Map[NodeName, EngineNode[s]] =
        Map.map(entryEngineNode, roots(scene))

    /// 全ノード数（ツリー全体の再帰カウント）
    pub def nodeCount(scene: Scene[s]): Int32 =
        Map.foldLeft((acc, entry) -> acc + countEntry(entry), 0, roots(scene))

    /// SceneEntry のノード数（自分 + 子孫）
    def countEntry(entry: SceneEntry[s]): Int32 =
        1 + Map.foldLeft((acc, child) -> acc + countEntry(child), 0, entryChildren(entry))

    // ========================================================================
    // ツリー操作
    // ========================================================================

    /// ルートの子名リスト
    pub def getChildren(name: NodeName, scene: Scene[s]): List[NodeName] =
        getChildrenAt(name :: Nil, scene)

    /// 任意ノードの子名リスト
    pub def getChildrenAt(path: NodePath, scene: Scene[s]): List[NodeName] =
        match getEntryAt(path, scene) {
            case None => Nil
            case Some(entry) => Map.keysOf(entryChildren(entry)) |> Set.toList
        }

    /// パスから親パスを返す
    pub def getParent(path: NodePath, scene: Scene[s]): Option[NodePath] =
        match path {
            case Nil => None
            case _ :: Nil =>
                match getEntryAt(path, scene) {
                    case None => None
                    case Some(_) => None
                }
            case _ =>
                let pp = initPath(path);
                match getEntryAt(pp, scene) {
                    case None => None
                    case Some(_) => Some(pp)
                }
        }

    // ========================================================================
    // 走査順序
    // ========================================================================

    /// 全ノードのパスを深さ優先順（preorder）で返す
    pub def preorderPaths(scene: Scene[s]): List[NodePath] =
        Map.foldLeftWithKey((acc, name, entry) ->
            List.append(acc, preorderFromEntry(name :: Nil, entry)),
            Nil,
            roots(scene))

    // ========================================================================
    // 座標（制約なし — EngineNode の Node2D を直接使用）
    // ========================================================================

    /// パスでグローバル座標を計算
    pub def globalPositionAt(path: NodePath, scene: Scene[s]): Vec2.Vec2 =
        match path {
            case Nil => Vec2.zero()
            case name :: Nil =>
                match getEngineNode(name :: Nil, scene) {
                    case None => Vec2.zero()
                    case Some(engineNode) => Node2D.getPosition(engineNode)
                }
            case _ =>
                match getEngineNode(path, scene) {
                    case None => Vec2.zero()
                    case Some(engineNode) =>
                        let localPos = Node2D.getPosition(engineNode);
                        Vec2.add(localPos, globalPositionAt(initPath(path), scene))
                }
        }

    /// ルートのグローバル座標（後方互換）
    pub def globalPosition(name: NodeName, scene: Scene[s]): Vec2.Vec2 =
        globalPositionAt(name :: Nil, scene)

    /// パスでグローバル座標を設定（ローカル座標を逆算）
    pub def setGlobalPositionAt(path: NodePath, globalPos: Vec2.Vec2, scene: Scene[s]): Scene[s] =
        match getEngineNode(path, scene) {
            case None => scene
            case Some(engineNode) =>
                let pp = initPath(path);
                let parentGlobal = if (List.length(pp) == 0)
                                       Vec2.zero()
                                   else
                                       globalPositionAt(pp, scene);
                let newLocal = Vec2.sub(globalPos, parentGlobal);
                let updatedNode = Node2D.setPosition(newLocal, engineNode);
                setEngineNode(path, updatedNode, scene)
        }

    /// ルートノードのグローバル座標設定（後方互換）
    pub def setGlobalPosition(name: NodeName, globalPos: Vec2.Vec2, scene: Scene[s]): Scene[s] =
        setGlobalPositionAt(name :: Nil, globalPos, scene)

    // ========================================================================
    // ライフサイクル
    // ========================================================================

    /// 全ノードを preorder で走査し、変換関数を順次適用する（Region で状態をスレッドする）
    def foldNodes(f: (EngineNode[s], NodePath, Scene[s]) -> (EngineNode[s], Scene[s]) \ ef,
                  scene: Scene[s]): Scene[s] \ ef =
        let paths = preorderPaths(scene);
        region rc {
            let sceneRef = Ref.fresh(rc, scene);
            List.forEach(path -> {
                match getEngineNode(path, Ref.get(sceneRef)) {
                    case None => ()
                    case Some(engineNode) =>
                        let (newEn, s1) = f(engineNode, path, Ref.get(sceneRef));
                        Ref.put(setEngineNode(path, newEn, s1), sceneRef)
                }
            }, paths);
            Ref.get(sceneRef)
        }

    /// 全ノードの ready を preorder で一度だけ呼び出し、readied フラグを設定する（エンジン内部用）
    def readyAll(scene: Scene[s]): Scene[s] \ GameEngine.Game with Node[s] =
        let Scene.Scene(r) = scene;
        foldNodes((engineNode, path, sc) ->
            Node.ready(engineNode, path, sc),
            Scene.Scene({ readied = true | r }))

    /// 全ノードの process を preorder（親→子）の順で呼び出す
    /// EngineNode.engineProcess（AnimSprite2D のフレーム送り等）も自動実行される
    /// 初回呼び出し時に readyAll を自動実行する
    pub def processAll(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] \ GameEngine.Game with Node[s] =
        let Scene.Scene(r) = scene;
        let readiedScene = if (not r#readied) readyAll(scene) else scene;
        foldNodes((engineNode, path, sc) ->
            if (ProcessMode.shouldProcess(paused, Node.getProcessMode(EngineNode.getState(engineNode)))) {
                let newEn = EngineNode.engineProcess(delta, engineNode);
                Node.process(delta, newEn, path, sc)
            } else
                (engineNode, sc),
            readiedScene)

    /// 全ノードの physicsProcess を preorder で呼び出す。
    /// PhysicsStep.step が重力・積分を適用する前に実行される。
    pub def physicsProcessAll(delta: Float64, paused: Bool, scene: Scene[s]): Scene[s] with Node[s] =
        foldNodes((engineNode, path, sc) ->
            if (ProcessMode.shouldProcess(paused, Node.getProcessMode(EngineNode.getState(engineNode))))
                Node.physicsProcess(delta, engineNode, path, sc)
            else
                (engineNode, sc),
            scene)

    // ========================================================================
    // 描画（制約なし — EngineNode の Renderable を直接使用）
    // ========================================================================

    /// EngineNode のプロパティから Drawable を組み立てる（フォールバック用）
    pub def toDrawable(texture: String, engineNode: EngineNode[s], globalPos: Vec2.Vec2): GameEngine.Drawable =
        {
            texture = texture,
            position = globalPos,
            scale = Node2D.getScale(engineNode),
            rotation = Node2D.getRotation(engineNode),
            color = CanvasItem.getModulate(engineNode),
            centered = true,
            uvOffset = {x = 0.0, y = 0.0},
            uvScale = {x = 1.0, y = 1.0},
            zIndex = CanvasItem.getZIndex(engineNode)
        }

    /// 可視ノードを Drawable のリストに変換する
    /// 各ノードが複数 Drawable を返せるよう flatMap ベースで処理する
    pub def toDrawables(scene: Scene[s]): List[GameEngine.Drawable] =
        preorderPaths(scene)
            |> List.flatMap(path ->
                match getEngineNode(path, scene) {
                    case Some(engineNode) =>
                        if (CanvasItem.isVisible(engineNode))
                            GameEngine.Renderable.toDrawables(engineNode, globalPositionAt(path, scene))
                        else Nil
                    case None => Nil
                }
            )
            |> List.sortBy(d -> d#zIndex)
}
