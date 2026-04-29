---
name: engine-guide
description: "ゲームエンジン（Scene[s], EngineNode[s], GameEngine）のコードを書く前に参照するお作法ガイド。GameData設計、trait実装、衝突応答、動的スポーンを含む"
user-invocable: false
---

# ゲームエンジン開発のお作法

## アーキテクチャ

```
エンジン層（汎用・変更不要）           ゲーム層（開発者が書く）
─────────────────────────          ─────────────────────
EngineNode[s] — ノード包装           GameData — 状態 enum 定義
Scene[s]      — ツリー管理           Node instance — process
GameEngine    — 更新パイプライン      AreaHandler instance — 衝突応答
AreaEvent     — 衝突検出             mod Game — buildState / gameLoop
Timer         — カウントダウン        GameState — ゲーム全体の状態レコード
```

**重要な分離**: `EngineNode[s]` がノードの描画・物理を持ち、型パラメータ `s`（= GameData）がゲーム固有の状態を持つ。開発者は **GameData の設計と trait instance** だけを行い、CanvasItem/Node2D 等の trait 委譲は不要。

## 対象ファイル

| ファイル | 役割 |
|---|---|
| `src/Main.flix` | EngineConfig 定義 + LwjglLayer 起動（エントリポイント専用） |
| `src/scenes/Game.flix` | GameData enum + Node/AreaHandler instance + mod Game（状態構築・ゲームループ・ロジック） |
| `test/scenes/TestGame.flix` | テスト |
| `src/engine/**/*.flix` | エンジン層（拡張時のみ） |

## EngineNode[s] — エンジンが提供するノード型

開発者は直接定義しない。EngineNode が描画・物理・衝突を担当する。

```flix
pub enum EngineNode[state] {
    case Sprite2DWithState(Sprite2D, state)
    case Area2DWithState(Area2D, state)
    case Body2DWithState(CharacterBody2D, state)
    case AnimSprite2DWithState(AnimatedSprite2D, state)
    case Label2DWithState(Label2D, state)
    case Marker2DWithState(Marker2D, state)
}
```

**EngineNode が既に実装する trait**: `CanvasItem`, `Node2D`, `CollisionObject2D`, `Engine.Renderable`
→ ゲーム層での trait 委譲ボイラープレートは **不要**

### EngineNode の操作ヘルパー

内部のエンジン型を変換する関数:

```flix
EngineNode.mapBody2D(f: CharacterBody2D -> CharacterBody2D, node) -> EngineNode[s]
EngineNode.mapSprite2D(f: Sprite2D -> Sprite2D, node) -> EngineNode[s]
EngineNode.mapAnimSprite2D(f: AnimatedSprite2D -> AnimatedSprite2D, node) -> EngineNode[s]
EngineNode.mapArea2D(f: Area2D -> Area2D, node) -> EngineNode[s]
EngineNode.mapLabel2D(f: Label2D -> Label2D, node) -> EngineNode[s]
EngineNode.getState(node) -> s
EngineNode.setState(state, node) -> EngineNode[s]
EngineNode.mapState(f: s -> s, node) -> EngineNode[s]
```

## GameData 設計

### 基本ルール: 純粋な状態のみ

GameData は **ゲーム固有の状態データだけ** を持つ enum。Area2D や Sprite2D は含めない。

```flix
pub enum GameData {
    case PlayerData({prevKeys = Set[Engine.Key], target = Vec2.Vec2})
    case VehicleData({vx = Float32})
    case PlatformData({vx = Float32, platformWidth = Float32})
    case HomeSlotData({filled = Bool})
    case HitboxData       // データなし、match での識別用
    case StaticData       // データなし、スプライト・ラベル等
}
```

設計方針:
- バリアントごとにゲーム固有のレコードを持たせる
- データ不要なバリアントも match 識別用に定義する（`HitboxData`, `StaticData`）
- `Eq`, `ToString` を derive（必要に応じて）

## Game.flix の構成順序

1. **GamePhase enum** — ゲームフェーズ（Playing, Dying, GameOver, Win 等）
2. **GameState type alias** — ゲーム全体の状態レコード（scene + タイマー + ライフ + フェーズ）
3. **GameData enum** — ノード固有の状態データ
4. **Node[GameData] instance** — `process` で毎フレーム更新
5. **AreaHandler[GameData] instance** — 衝突応答
6. **mod Game** — `buildState`, `start`, `gameLoop`, ヘルパー、ゲーム固有ロジック

## 設計ルール

### Node instance

```flix
instance Node[GameData] {
    redef process(delta, node, _path, scene) =
        match node {
            case EngineNode.Body2DWithState(body, GameData.PlayerData(r)) =>
                // body を変更して返す
                (EngineNode.Body2DWithState(updatedBody, GameData.PlayerData(r)), scene)
            case EngineNode.Area2DWithState(_, GameData.VehicleData(r)) =>
                // Node2D.setPosition で移動
                (Node2D.setPosition(newPos, node), scene)
            case _ => (node, scene)
        }
}
```

- `process` は `(EngineNode[GameData], Scene[GameData])` を返す
- `EngineNode` のバリアントと `GameData` のバリアントの **二重 match** で分岐
- 振る舞いのないバリアントは `case _ => (node, scene)`

### AreaHandler instance

```flix
instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath, selfState, otherPath, otherState, scene) =
        match (selfState, otherState) {
            case (GameData.HitboxData, GameData.VehicleData(_)) =>
                Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                    EngineNode.mapAnimSprite2D(sprite ->
                        CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite)),
                    scene)
            case _ => scene
        }
}
```

- 引数は **GameData の値**（EngineNode ではない）
- scene の変更には `Scene.mapEngineNode` / `Scene.mapState` を使う

### Scene 操作 API

```flix
// ノード追加
Scene.addNode(name, engineNode, scene)
Scene.addChild(parentName, childName, engineNode, scene)
Scene.addChildAt(parentPath, childName, engineNode, scene)

// 状態の取得・変更
Scene.get(name, scene) -> Option[s]                    // ルートノードの状態
Scene.getState(path, scene) -> Option[s]               // 任意パスの状態
Scene.getEngineNode(path, scene) -> Option[EngineNode[s]]
Scene.mapEngineNode(path, f: EngineNode[s] -> EngineNode[s], scene)
Scene.mapState(path, f: s -> s, scene)

// 位置
Scene.globalPosition(name, scene) -> Vec2.Vec2
Scene.globalPositionAt(path, scene) -> Vec2.Vec2

// 全状態マップ（検索用）
Scene.states(scene) -> Map[NodeName, s]
```

**パスの型**: `NodePath = List[NodeName]`（例: `"player" :: "Sprite" :: Nil`）

### シーン構築

```flix
Scene.empty()
    |> Scene.addNode("player",
        EngineNode.Body2DWithState(
            CharacterBody2D.make(pos, moveSpeed = 512.0f32),
            GameData.PlayerData({prevKeys = Set.empty(), target = pos})))
    |> Scene.addChild("player", "Sprite",
        EngineNode.AnimSprite2DWithState(
            AnimatedSprite2D.make(animations, ...),
            GameData.StaticData))
```

- Area2D ノードは `CanvasItem.hide` で非表示にする（センサー専用）
- 子の Sprite2D / AnimatedSprite2D が描画を担当
- 座標はローカル座標（親からの相対位置）

### GameState レコードパターン

ゲーム全体の状態を1つのレコードで管理する:

```flix
pub type alias GameState = {
    scene = Scene[GameData],
    gameTimer = Timer,
    deathTimer = Timer,
    lives = Int32,
    phase = GamePhase
}
```

- `scene` 以外のフィールドでゲーム全体の状態を持つ
- レコード更新: `{ scene = newScene, phase = GamePhase.Win | state }`

### ゲームループ（Game.flix 内）

```flix
pub def start(fontAtlas: FontAtlas): Unit \ Engine.Game =
    gameLoop(fontAtlas, buildState(fontAtlas))

def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game =
    if (Engine.Game.shouldClose()) ()
    else {
        let dt = Engine.Game.getDeltaTime();
        match state#phase {
            case GamePhase.Playing =>
                { scene = GameEngine.updateWithAreaHandler(dt, false, state#scene) | state }
                    |> handlePlayerInput
                    |> processTimers(dt)
                    |> checkDeath
                    |> updateHUD
                    |> gameLoop(fontAtlas)
            case GamePhase.GameOver =>
                if (Engine.Game.isKeyPressed(Engine.Key.Enter))
                    gameLoop(fontAtlas, buildState(fontAtlas))
                else
                    { scene = GameEngine.updateWithAreaHandler(dt, true, state#scene) | state }
                        |> updateHUD
                        |> gameLoop(fontAtlas)
        }
    }
```

- `GameEngine.updateWithAreaHandler` は `Scene[s]` を返す（prevOverlaps は Scene 内部管理）
- フェーズごとに `match` で処理パイプラインを切り替える
- `paused = true` で process を停止しつつ描画のみ行う
- 末尾再帰で `gameLoop` を呼ぶ
- `Scene.readyAll` は **不要**（`processAll` が初回に自動実行）

### Main.flix の役割（エントリポイント専用）

```flix
def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = 784,
            screenHeight = 1000,
            title = "Frogger",
            textureManifest = {name = "...", path = "...", hasAlpha = true} :: Nil,
            fontManifest = {name = "default", path = "...", fontSize = 32.0f32} :: Nil,
            clearColor = {r = 0.1f32, g = 0.1f32, b = 0.1f32}
        };
        LwjglLayer.withLwjgl(config, () -> {
            let fontAtlas = Engine.Game.getFontAtlas("default");
            Game.start(fontAtlas)
        })
    }
```

- Main.flix は **EngineConfig の定義と LwjglLayer 起動のみ**
- ゲームループや状態管理は `Game.start` に委譲する
- テクスチャ・フォントのマニフェストをここで宣言する

### 衝突応答

- **AreaHandler 方式（推奨）**: `GameEngine.updateWithAreaHandler` で使う
- prevOverlaps は Scene が内部管理（手動追跡不要）

### 動的スポーン / デスポーン

- `process` や `onAreaEntered` 内で `Scene.addNode` / `Scene.removeAt` を呼ぶ
- 同一フレームで追加したノードの `process` は **次フレームから**
- 走査中の削除は安全（`getAt` が `None` を返す）
- 名前はユニークにすること（カウンタ等を使う）

## やってはいけないこと

- エンジン層に GameData 固有のロジックを入れない
- GameData に Area2D / Sprite2D 等のエンジン型をラップしない（EngineNode の役割）
- `bug!()` を到達不能パス以外に使わない — `match` の網羅性に任せる
- Main.flix にゲームロジックを書かない（EngineConfig と起動のみ）

## テスト

- **構築テスト（必須）**: `buildState` の結果のノード数・存在確認
- **振る舞いテスト**: `Scene.processAll` 後の状態検証
- **衝突応答テスト**: `AreaHandler.onAreaEntered` を直接呼び出して検証
- **ゲームロジックテスト**: 純粋関数（`wrapX`, `inputDirection` 等）を個別テスト
