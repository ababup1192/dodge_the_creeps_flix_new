---
name: scene-pattern
description: "XxxSceneモジュールの構築・更新パターン。型定義・定数・addXxx・mapXxxSprite/mapXxxArea/mapXxxの書き方"
user-invocable: false
---

# XxxScene 設計パターン

シーンの構築と更新に関する共通パターン。

## モジュール構造

```
mod XxxScene {
    // (A) 型定義   — XxxData
    // (B) 定数     — name / path / shape / animations
    // (C) 構築     — addXxx: Scene → Scene
    // (D) ロジック — ready / process / start 等
    // (E) mapXxxSprite / mapXxxArea / mapXxx（合成）
}
```

## (A) 型定義

```flix
/// ゲーム状態（フレーム間で変化する純粋データ）
pub type alias XxxData = { velocity = Vec2.Vec2, hp = Int32 }
```

- `XxxData`: フレーム間で変化する純粋データ。レコード、Int32、Bool など用途に合わせる
- エンジン型（AnimatedSprite2D, Area2D 等）は `EngineNode` の中に1箇所だけ存在する。
  **`XxxData` にエンジン型を含めない**（二重管理を避けるため）

### NodeTag バリアント設計

親ノードの state にデータを持たせ、子ノードの state は識別タグにする:

```flix
pub enum NodeTag {
    case XxxSprite(XxxScene.XxxData)  // 親ノード: データを保持
    case XxxArea                       // 子ノード: 識別タグ（衝突判定で使用）
    case NoTag                        // その他の子: 汎用タグ
}
```

**アンチパターン: エンジン型をレコードにまとめて NodeTag に持つ**

```flix
// NG: sprite が EngineNode と XxxNode の2箇所に存在し、毎フレーム同期が必要
type alias XxxNode = { sprite = AnimatedSprite2D, area = Area2D }
case Xxx(XxxNode, XxxData)
```

## (B) 定数

```flix
def name(): String = "xxx"
def xxxPath(): NodePath = name() :: Nil
def areaName(): String = "area"
def areaPath(): NodePath = name() :: areaName() :: Nil   // 非公開
```

パスは `parentName :: childName :: Nil` 形式。定数関数で一元管理する。
`areaPath()` 等の子ノードパスは非公開にし、`mapXxxArea` 経由でアクセスさせる。

## (C) 構築 — addXxx

**原則: 親ノードが `XxxSprite(XxxData)` を持ち、子は識別タグまたは `NoTag`。**

```flix
pub def addXxx(scene: Scene[NodeTag]): Scene[NodeTag] =
    let sprite = AnimatedSprite2D.make(animations, initialAnimation = "idle",
        fps = 5.0, startPos, scale)
        |> CanvasItem.hide;
    let area = Area2D.make(Vec2.zero(), collisionShape);
    let xxxData = { velocity = Vec2.zero(), hp = 100 };
    scene
        |> Scene.addNode(name(),
            EngineNode.AnimSprite2DWithState(sprite,
                NodeTag.XxxSprite(xxxData)))           // 親: データを保持
        |> Scene.addChild(name(), areaName(),
            EngineNode.Area2DWithState(area,
                NodeTag.XxxArea))                       // 子: 識別タグ
```

動的スポーン（名前が実行時に決まる）の場合:

```flix
pub def spawnXxx(name: String, position: Vec2.Vec2,
                 scene: Scene[NodeTag]): Scene[NodeTag] =
    scene
        |> Scene.addNode(name,
            EngineNode.RigidBody2DWithState(body, NodeTag.XxxData(id)))
        |> Scene.addToGroup(name :: Nil, xxxGroup())    // グループで一括削除用
        |> Scene.addChild(name, childName(),
            EngineNode.AnimSprite2DWithState(sprite, NodeTag.NoTag))
```

構築 API:
- `Scene.addNode(name, engineNode)` — ルートに追加
- `Scene.addChild(parent, child, engineNode)` — 子を追加
- `Scene.addToGroup(path, group)` — グループに登録

## (D) ロジック

### ready / process — Node instance への委譲

XxxScene に ready / process を定義し、Game.flix の `Node[NodeTag]` instance から委譲する。
スタイルは 2 種類ある:

**純粋スタイル** — エンジン型 + データを受け取り、更新して返す。Node instance 側でラップ/アンラップ:

```flix
// XxxScene 側
pub def ready(sprite: AnimatedSprite2D, data: XxxData
             ): (AnimatedSprite2D, XxxData) \ GameEngine.Game =
    (sprite, { screenSize = GameEngine.Game.getViewportRect()#size | data })

pub def process(dt: Float64, sprite: AnimatedSprite2D,
                data: XxxData): AnimatedSprite2D =
    Node2D.setPosition(
        Vec2.add(Node2D.getPosition(sprite), Vec2.mul(data#velocity, dt)),
        sprite)

// Node[NodeTag] instance 側（エンジン型は EngineNode の中だけ — 同期コード不要）
redef ready(node, _path, scene) = match node {
    case EngineNode.AnimSprite2DWithState(sprite, NodeTag.XxxSprite(data)) =>
        let (s, d) = XxxScene.ready(sprite, data);
        (EngineNode.AnimSprite2DWithState(s, NodeTag.XxxSprite(d)), scene)
    case _ => (node, scene)
}
```

**Scene スタイル** — path + scene を受け取り、内部で mapXxx を使う。複数ノードを触る場合に適する:

```flix
// XxxScene 側
pub def ready(path: NodePath, direction: Float64,
              scene: Scene[NodeTag]): Scene[NodeTag] \ Math.Random =
    scene |> mapXxx(path, (body, data) ->
        (RigidBody2D.setLinearVelocity(vel, body), data))

// Node[NodeTag] instance 側
redef ready(node, path, scene) = match node {
    case EngineNode.RigidBody2DWithState(_, NodeTag.XxxData(_)) =>
        let newScene = XxxScene.ready(path, direction, scene);
        // mapXxx が path のノードを更新済みなので、シーンから取り直す
        match Scene.getEngineNode(path, newScene) {
            case Some(en) => (en, newScene)
            case None     => (node, newScene)
        }
    case _ => (node, scene)
}
```

Scene スタイルでは、XxxScene.ready が scene 内のノードを更新するため、
Node instance 側は `Scene.getEngineNode` で取り直す（foldNodes の上書きを防ぐ）。

### その他のロジック

`mapXxxSprite` を使って scene を変換する:

```flix
pub def applyInput(dir: Vec2.Vec2, scene: Scene[NodeTag]): Scene[NodeTag] =
    scene |> mapXxxSprite((sprite, data) ->
        (updateAnimation(dir, sprite),
         { velocity = computeVelocity(dir) | data }))
```

sprite と area の両方を操作する場合は `mapXxx` を使う:

```flix
pub def start(pos: Vec2.Vec2, scene: Scene[NodeTag]): Scene[NodeTag] =
    scene |> mapXxx(
        (sprite, data) ->
            (sprite |> position(pos) |> show, { hit = false | data }),
        Area2D.setMonitoring(true))
```

単一ノードだけ操作する場合は `Scene.mapEngineNode` で十分:

```flix
pub def setText(text: String, scene: Scene[NodeTag]): Scene[NodeTag] =
    scene |> Scene.mapEngineNode(labelPath(),
        EngineNode.mapLabel2D(Label2D.setText(text)))
```

## (E) mapXxxSprite / mapXxxArea / mapXxx

コンポーネントごとに map 関数を用意し、合成で `mapXxx` を作る。

```
mapXxxSprite  ── sprite + XxxData を変換（親ノード操作）
mapXxxArea    ── Area2D を変換（子ノード操作）
mapXxx        ── mapXxxSprite >> mapXxxArea の合成
```

```flix
/// 親ノードの sprite と XxxData を変換する
pub def mapXxxSprite(f: (AnimatedSprite2D, XxxData) -> (AnimatedSprite2D, XxxData),
                     scene: Scene[NodeTag]): Scene[NodeTag] =
    Scene.mapEngineNode(xxxPath(), engineNode -> match engineNode {
        case EngineNode.AnimSprite2DWithState(sprite, NodeTag.XxxSprite(data)) =>
            let (newSprite, newData) = f(sprite, data);
            EngineNode.AnimSprite2DWithState(newSprite, NodeTag.XxxSprite(newData))
        case other => other
    }, scene)

/// 子ノードの Area2D を変換する
pub def mapXxxArea(f: Area2D -> Area2D, scene: Scene[NodeTag]): Scene[NodeTag] =
    Scene.mapEngineNode(areaPath(), EngineNode.mapArea2D(f), scene)

/// sprite・XxxData・Area2D をまとめて変換する（mapXxxSprite と mapXxxArea の合成）
pub def mapXxx(spriteF: (AnimatedSprite2D, XxxData) -> (AnimatedSprite2D, XxxData),
               areaF: Area2D -> Area2D,
               scene: Scene[NodeTag]): Scene[NodeTag] =
    scene |> mapXxxSprite(spriteF) |> mapXxxArea(areaF)

/// Scene から XxxData を取り出す
pub def getXxxData(scene: Scene[NodeTag]): XxxData =
    match Scene.getState(xxxPath(), scene) {
        case Some(NodeTag.XxxSprite(data)) => data
        case _ => bug!("xxx not found")
    }
```

### 設計の要点

1. **エンジン型の正本は EngineNode の中だけ** — `mapXxxSprite` は `Scene.mapEngineNode` 経由で操作するため、
   エンジン型のコピーが複数箇所に存在しない
2. **子ノードのパスを公開しない** — `mapXxxArea` が `areaPath()` をカプセル化する
3. **合成で拡張** — コンポーネントが増えたら `mapXxxNewChild` を追加し、`mapXxx` の合成に1段足すだけ

### 動的パス（実行時に名前が決まるノード）の場合

`path: NodePath` を引数に取る:

```flix
pub def mapXxxBody(path: NodePath,
                   f: (RigidBody2D, XxxData) -> (RigidBody2D, XxxData),
                   scene: Scene[NodeTag]): Scene[NodeTag] =
    Scene.mapEngineNode(path, engineNode -> match engineNode {
        case EngineNode.RigidBody2DWithState(body, NodeTag.XxxData(data)) =>
            let (newBody, newData) = f(body, data);
            EngineNode.RigidBody2DWithState(newBody, NodeTag.XxxData(newData))
        case other => other
    }, scene)
```

## 使い分け早見表

| やりたいこと | 手段 |
|---|---|
| sprite + data を変換 | `mapXxxSprite` |
| 子ノード（Area2D 等）を変換 | `mapXxxArea` |
| sprite + data + 子ノードを一括変換 | `mapXxx`（合成） |
| 単一ノードの見た目変更 | `Scene.mapEngineNode(path, f)` |
| 状態のみ変更 | `Scene.setState(path, newState)` / `Scene.mapState(path, f)` |
| ノード追加 | `Scene.addNode` / `Scene.addChild` |
| ノード削除 | `Scene.removeAt(path)` / `Scene.removeGroup(group)` |
| グループ一括削除 | `Scene.addToGroup` → `Scene.removeGroup` |
