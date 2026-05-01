---
name: scene-pattern
description: "XxxSceneモジュールの構築・更新パターン。型定義・定数・addXxx・extract/commit/mapの書き方"
user-invocable: false
---

# XxxScene 設計パターン

シーンの構築と更新に関する共通パターン。

## モジュール構造

```
mod XxxScene {
    // (A) 型定義   — XxxNode + XxxData
    // (B) 定数     — name / path / shape / animations
    // (C) 構築     — addXxx: Scene → Scene
    // (D) ロジック — ready / process / start 等
    // (E) extract / commit / map
}
```

## (A) 型定義

```flix
/// エンジン型のレコード（そのシーンが管理する描画・物理の実体）
pub type alias XxxNode = { sprite = AnimatedSprite2D, area = Area2D }

/// ゲーム状態（フレーム間で変化する純粋データ）
pub type alias XxxData = { velocity = Vec2.Vec2, hp = Int32 }
```

- `XxxNode`: エンジン型をまとめたレコード。フィールド数はノード構成に応じて増減
- `XxxData`: 型は自由。レコード、Int32、Bool など用途に合わせる

## (B) 定数

```flix
def name(): String = "xxx"
def xxxPath(): NodePath = name() :: Nil
def childName(): String = "child"
def childPath(): NodePath = name() :: childName() :: Nil
```

パスは `parentName :: childName :: Nil` 形式。定数関数で一元管理する。

## (C) 構築 — addXxx

**原則: 親ノードが GameData を持ち、子は `GameData.Marker` または識別用バリアント。**

```flix
pub def addXxx(scene: Scene[GameData]): Scene[GameData] =
    let sprite = AnimatedSprite2D.make(animations, initialAnimation = "idle",
        fps = 5.0, startPos, scale);
    let area = Area2D.make(Vec2.zero(), collisionShape);
    scene
        |> Scene.addNode(name(),
            EngineNode.AnimSprite2DWithState(sprite,
                GameData.XxxState(xxxNode, xxxData)))   // 親: 状態を持つ
        |> Scene.addChild(name(), childName(),
            EngineNode.Area2DWithState(area, GameData.Marker))  // 子: Marker
```

動的スポーン（名前が実行時に決まる）の場合:

```flix
pub def spawnXxx(name: String, position: Vec2.Vec2,
                 scene: Scene[GameData]): Scene[GameData] =
    scene
        |> Scene.addNode(name,
            EngineNode.RigidBody2DWithState(body, GameData.XxxData(id)))
        |> Scene.addToGroup(name :: Nil, xxxGroup())    // グループで一括削除用
        |> Scene.addChild(name, childName(),
            EngineNode.AnimSprite2DWithState(sprite, GameData.Marker))
```

構築 API:
- `Scene.addNode(name, engineNode)` — ルートに追加
- `Scene.addChild(parent, child, engineNode)` — 子を追加
- `Scene.addToGroup(path, group)` — グループに登録

## (D) ロジック

### ready / process — Node instance への委譲

XxxScene に ready / process を定義し、Game.flix の `Node[GameData]` instance から委譲する。
スタイルは 2 種類ある:

**純粋スタイル** — エンジン型 + データを受け取り、更新して返す。Node instance 側でラップ/アンラップ:

```flix
// XxxScene 側
pub def ready(sprite: AnimatedSprite2D, data: XxxData
             ): (AnimatedSprite2D, XxxData) \ GameEngine.Game =
    (sprite, { screenSize = GameEngine.Game.getViewportRect()#size | data })

pub def process(dt: Float64, sprite: AnimatedSprite2D,
                data: XxxData): AnimatedSprite2D =
    Node2D.setPosition(Vec2.add(Node2D.getPosition(sprite), Vec2.mul(data#velocity, dt)), sprite)

// Node[GameData] instance 側
redef ready(node, _path, scene) = match node {
    case EngineNode.AnimSprite2DWithState(sprite, GameData.XxxState(n, data)) =>
        let (s, d) = XxxScene.ready(sprite, data);
        (EngineNode.AnimSprite2DWithState(s, GameData.XxxState({ sprite = s | n }, d)), scene)
    case _ => (node, scene)
}
```

**Scene スタイル** — path + scene を受け取り、内部で mapXxx を使う。複数ノードを触る場合に適する:

```flix
// XxxScene 側
pub def ready(path: NodePath, direction: Float64,
              scene: Scene[GameData]): Scene[GameData] \ Math.Random =
    scene |> mapXxx(path, (node, data) ->
        ({ body = RigidBody2D.setLinearVelocity(vel, node#body) | node }, data))

// Node[GameData] instance 側
redef ready(node, path, scene) = match node {
    case EngineNode.RigidBody2DWithState(_, GameData.XxxData(_)) =>
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

`mapXxx` を使って scene を変換する:

```flix
pub def applyInput(dir: Vec2.Vec2, scene: Scene[GameData]): Scene[GameData] =
    scene |> mapXxx((node, data) ->
        ({ sprite = updateAnimation(dir, node#sprite) | node },
         { velocity = computeVelocity(dir) | data }))
```

単一ノードだけ操作する場合は `Scene.mapEngineNode` で十分:

```flix
pub def setText(text: String, scene: Scene[GameData]): Scene[GameData] =
    scene |> Scene.mapEngineNode(labelPath(),
        EngineNode.mapLabel2D(Label2D.setText(text)))
```

## (E) extract / commit / map

複数ノードを一括変換するための **3 関数セット**。

```flix
/// 変換の入口（公開）— 利用者はこれだけ使う
pub def mapXxx(f: (XxxNode, XxxData) -> (XxxNode, XxxData),
               scene: Scene[GameData]): Scene[GameData] =
    let (node, data) = extractXxx(scene);
    let (newNode, newData) = f(node, data);
    commitXxx(newNode, newData, scene)

/// 取り出し: forA で複数ノード取得 → match でアンラップ
def extractXxx(scene: Scene[GameData]): (XxxNode, XxxData) =
    let opt = forA(
        sprite <- Scene.getEngineNode(xxxPath(), scene);
        child  <- Scene.getEngineNode(childPath(), scene)
    ) yield { sprite = sprite, child = child };
    match opt {
        case Some({ sprite = EngineNode.AnimSprite2DWithState(s, GameData.XxxState(_, data)),
                    child = EngineNode.Area2DWithState(a, _) }) =>
            ({ sprite = s, area = a }, data)
        case _ => bug!("xxx not found")
    }

/// 書き戻し: Scene.setEngineNode のパイプライン
def commitXxx(node: XxxNode, data: XxxData,
              scene: Scene[GameData]): Scene[GameData] =
    scene
        |> Scene.setEngineNode(xxxPath(),
            EngineNode.AnimSprite2DWithState(node#sprite,
                GameData.XxxState(node, data)))
        |> Scene.setEngineNode(childPath(),
            EngineNode.Area2DWithState(node#area, GameData.Marker))
```

動的パス（実行時に名前が決まるノード）の場合は `path: NodePath` を引数に取る:

```flix
pub def mapXxx(path: NodePath, f: ..., scene): Scene[GameData] =
    let childPath = List.append(path, childName() :: Nil);
    ...
```

**フィールド追加時の手順:**
1. `extractXxx` — forA に 1 行、match パターンに 1 フィールド追加
2. `commitXxx` — `Scene.setEngineNode` を 1 段追加
3. `mapXxx` — 変更不要

## 使い分け早見表

| やりたいこと | 手段 |
|---|---|
| 複数ノードを一括変換 | `mapXxx` (extract/commit/map) |
| 単一ノードの見た目変更 | `Scene.mapEngineNode(path, f)` |
| 状態のみ変更 | `Scene.setState(path, newState)` |
| ノード追加 | `Scene.addNode` / `Scene.addChild` |
| ノード削除 | `Scene.removeAt(path)` / `Scene.removeGroup(group)` |
| グループ一括削除 | `Scene.addToGroup` → `Scene.removeGroup` |
