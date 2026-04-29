---
name: scene-pattern
description: "GameDataとシーン構築の設計パターン。enum設計・buildState・ゲームループ・テスト構成の規約 - 新しいゲームを作るとき、GameDataを拡張するとき"
user-invocable: false
---

# GameData + Scene 設計パターン

## 対象ファイル

| ファイル | 役割 |
|---|---|
| `src/scenes/Game.flix` | GameData enum + Node/AreaHandler instance + mod Game（buildState・gameLoop・全ロジック） |
| `test/scenes/TestGame.flix` | テスト |
| `src/Main.flix` | EngineConfig 定義 + LwjglLayer 起動（エントリポイント専用） |

## Game.flix の構成要素と順序

### 1. GamePhase enum（フェーズ管理）

```flix
pub enum GamePhase with Eq, ToString {
    case Playing
    case Dying
    case GameOver
    case Win
}
```

### 2. GameState type alias（ゲーム全体の状態）

scene とそれ以外のゲーム全体状態を1つのレコードにまとめる:

```flix
pub type alias GameState = {
    scene = Scene[GameData],
    gameTimer = Timer,
    deathTimer = Timer,
    lives = Int32,
    phase = GamePhase
}
```

- レコード更新: `{ scene = newScene, phase = GamePhase.Win | state }`
- scene 外のフィールドでノード横断の状態（タイマー、ライフ、フェーズ等）を持つ

### 3. GameData enum（ノード固有の状態）

**純粋な状態データのみ**。Area2D / Sprite2D をラップしない（それは EngineNode の役割）。

```flix
pub enum GameData {
    case PlayerData({prevKeys = Set[Engine.Key], target = Vec2.Vec2})
    case VehicleData({vx = Float32})
    case PlatformData({vx = Float32, platformWidth = Float32})
    case HomeSlotData({filled = Bool})
    case HitboxData       // 識別用（データなし）
    case StaticData       // 静的ノード用（データなし）
}
```

設計方針:
- 動的なゲーム状態をレコードで持つバリアント（`PlayerData`, `VehicleData` 等）
- match 識別のみに使うデータなしバリアント（`HitboxData`, `StaticData`）
- EngineNode のバリアントとの組み合わせで物理的な型が決まる

### 4. Node[GameData] instance（毎フレーム更新）

```flix
instance Node[GameData] {
    redef process(delta, node, _path, scene) =
        let dt = Float64.truncateToFloat32(delta);
        match node {
            case EngineNode.Body2DWithState(body, GameData.PlayerData(r)) =>
                let currentPos = Node2D.getPosition(body);
                let speed = CharacterBody2D.getMoveSpeed(body);
                let newPos = Vec2.moveToward(currentPos, r#target, speed * dt);
                (EngineNode.Body2DWithState(Node2D.setPosition(newPos, body),
                    GameData.PlayerData(r)), scene)
            case EngineNode.Area2DWithState(_, GameData.VehicleData(r)) =>
                let pos = Node2D.getPosition(node);
                let newX = Game.wrapX(r#vx, pos#x + r#vx * dt);
                (Node2D.setPosition({x = newX, y = pos#y}, node), scene)
            case _ => (node, scene)
        }
}
```

ポイント:
- `process` は `(EngineNode[GameData], Scene[GameData])` を返す
- EngineNode バリアント × GameData バリアントの **二重 match** で分岐
- 内部のエンジン型を変更するには `Node2D.setPosition` 等の trait 関数を使う
- EngineNode を再構築するか、`Node2D.setPosition(pos, node)` で直接操作する

### 5. AreaHandler[GameData] instance（衝突応答）

```flix
instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath, selfState, otherPath, otherState, scene) =
        match (selfState, otherState) {
            case (GameData.HitboxData, GameData.VehicleData(_)) =>
                // プレイヤーの Hitbox が車両と衝突 → スプライト色を変更
                Scene.mapEngineNode("player" :: "Sprite" :: Nil,
                    EngineNode.mapAnimSprite2D(sprite ->
                        CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite)),
                    scene)
            case (GameData.HitboxData, GameData.HomeSlotData(r)) =>
                if (r#filled) scene  // 充填済み → 無視
                else scene
                    |> Scene.mapState(otherPath, st -> match st {
                        case GameData.HomeSlotData(hr) =>
                            GameData.HomeSlotData({filled = true | hr})
                        case other => other
                    })
                    |> Game.resetPlayerPosition
            case _ => scene
        }
}
```

ポイント:
- 引数は **GameData の値**（EngineNode ではない）
- scene の変更には `Scene.mapEngineNode(path, f, scene)` や `Scene.mapState(path, f, scene)` を使う
- `onAreaExited` はデフォルトが no-op。必要な場合のみ `redef`

### 6. mod Game — ゲームロジック

```flix
mod Game {
    // ── 初期状態構築 ──
    pub def buildState(fontAtlas: FontAtlas): GameState = ...

    // ── メインループ ──
    pub def start(fontAtlas: FontAtlas): Unit \ Engine.Game = ...
    def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game = ...

    // ── 入力処理 ──
    pub def handlePlayerInput(state: GameState): GameState \ Engine.Game = ...

    // ── 定数 ──
    pub def screenW(): Float32 = ...
    pub def tileSize(): Float32 = ...

    // ── ヘルパー ──
    pub def wrapX(vx: Float32, newX: Float32): Float32 = ...

    // ── 判定ロジック ──
    pub def checkDeath(state: GameState): GameState = ...
    pub def checkDrown(state: GameState): GameState = ...

    // ── タイマー・HUD ──
    pub def processTimers(dt: Float32, state: GameState): GameState = ...
    def updateHUD(state: GameState): GameState = ...
}
```

## buildState のパターン

```flix
pub def buildState(fontAtlas: FontAtlas): GameState =
    let scene = Scene.empty()
        // ── 背景 ──
        |> addSolidBg("bgHome", green, pos, w, h, -10)
        |> addTiledBg("bgWater", "Water", pos, w, h, -10)
        // ── プレイヤー (CharacterBody2D + AnimatedSprite2D + Hitbox) ──
        |> Scene.addNode("player",
            EngineNode.Body2DWithState(
                CharacterBody2D.make(playerStart(), moveSpeed = moveSpeed()),
                GameData.PlayerData({prevKeys = Set.empty(), target = playerStart()})))
        |> Scene.addChild("player", "Sprite",
            EngineNode.AnimSprite2DWithState(
                AnimatedSprite2D.make(animations, ...),
                GameData.StaticData))
        |> Scene.addChildAt("player" :: Nil, "Hitbox",
            EngineNode.Area2DWithState(
                CanvasItem.hide(Area2D.make(pos, shape)),
                GameData.HitboxData))
        // ── 動的オブジェクト ──
        |> addAllVehicles
        |> addAllLogs
        // ── HUD ──
        |> Scene.addNode("timerLabel",
            EngineNode.Label2DWithState(
                Label2D.make("TIME: 30", fontAtlas, 24.0f32) |> Node2D.setPosition(pos),
                GameData.StaticData));
    {
        scene = scene,
        gameTimer = Timer.make(30.0f32) |> Timer.setAutostart(true) |> Timer.ready,
        deathTimer = Timer.make(2.0f32),
        lives = 3,
        phase = GamePhase.Playing
    }
```

規約:
- EngineNode の第1引数がエンジン型（描画・物理）、第2引数が GameData（状態）
- Area2D は `CanvasItem.hide` で非表示にする（センサー専用）
- 子の Sprite2D / AnimatedSprite2D が描画を担当
- 座標はローカル座標（親からの相対位置）
- `|>` パイプでチェーンする
- GameState レコードで scene とゲーム全体状態をまとめて返す
- Timer は `Timer.make(seconds) |> Timer.setAutostart(true) |> Timer.ready` で初期化

## ゲームループのパターン

```flix
def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ Engine.Game =
    if (Engine.Game.shouldClose()) ()
    else if (Engine.Game.isKeyPressed(Engine.Key.Escape)) ()
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

ポイント:
- `GameEngine.updateWithAreaHandler(dt, paused, scene)` → `Scene[s]` を返す
  - prevOverlaps は Scene 内部管理（手動追跡不要）
  - `Scene.readyAll` は不要（processAll が初回に自動実行）
- フェーズごとに処理パイプラインを切り替える
- `paused = true` で process を停止しつつ描画のみ行う
- `buildState` を再呼び出しでリスタート
- 各処理は `GameState -> GameState` の純粋な関数パイプライン

## Main.flix のパターン

```flix
def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = Game.screenWi(),
            screenHeight = Game.screenHi(),
            title = "Frogger",
            textureManifest =
                {name = "white", path = "textures/white_1x1.png", hasAlpha = true} ::
                {name = "FroggerIdle", path = "textures/FroggerIdle.png", hasAlpha = true} ::
                Nil,
            fontManifest =
                {name = "default", path = "textures/Xolonium-Regular.ttf", fontSize = 32.0f32} ::
                Nil,
            clearColor = {r = 0.1f32, g = 0.1f32, b = 0.1f32}
        };
        LwjglLayer.withLwjgl(config, () -> {
            let fontAtlas = Engine.Game.getFontAtlas("default");
            Game.start(fontAtlas)
        })
    }
```

- Main.flix は **EngineConfig + LwjglLayer 起動のみ**
- ゲームループ・状態管理は `Game.start` に委譲
- テクスチャ・フォントのマニフェストをここで宣言

## オブジェクト量産パターン（レーン設定）

```flix
type alias VehicleLaneConfig = {
    texture = String, y = Float32, vx = Float32,
    count = Int32, spacing = Float32
}

def vehicleLanes(): List[VehicleLaneConfig] =
    {texture = "Car1", y = 512.0f32, vx = -200.0f32, count = 3, spacing = 100.0f32} :: Nil

def addAllVehicles(scene: Scene[GameData]): Scene[GameData] =
    vehicleLanes()
        |> List.zipWithIndex
        |> List.foldLeft((acc, pair) -> {
            let (idx, config) = pair;
            addVehicleLane(idx, config, acc)
        }, scene)
```

- LaneConfig type alias で設定を宣言的に管理
- `List.zipWithIndex |> List.foldLeft` で scene にノードを追加
- 名前は `"v${laneIdx}_${vehicleIdx}"` のようにユニークにする

## テスト構成

### シーン構築テスト（必須）

```flix
@Test
def testBuildStateNodeCount(): Bool =
    let state = Game.buildState(fontAtlas);
    Scene.nodeCount(state#scene) == expectedCount

@Test
def testBuildStatePlayerExists(): Bool =
    let state = Game.buildState(fontAtlas);
    Option.isSome(Scene.get("player", state#scene))
```

### 振る舞いテスト

```flix
@Test
def testProcessUpdatesPosition(): Bool =
    let state = Game.buildState(fontAtlas);
    let processed = Scene.processAll(0.016, false, state#scene);
    // 位置が更新されていることを検証
    ...
```

### 衝突応答テスト

```flix
@Test
def testHitboxVehicleCollision(): Bool =
    let state = Game.buildState(fontAtlas);
    let result = AreaHandler.onAreaEntered(
        "player" :: "Hitbox" :: Nil, GameData.HitboxData,
        "v0_0" :: Nil, GameData.VehicleData({vx = -200.0f32}),
        state#scene);
    // sprite の modulate が赤になっていることを検証
    ...
```

### ゲームロジックテスト（純粋関数）

```flix
@Test
def testWrapXLeftEdge(): Bool =
    Game.wrapX(-100.0f32, -101.0f32) == Game.screenW() + 100.0f32

@Test
def testInputDirectionUp(): Bool =
    let keys = Set#{Engine.Key.W};
    Game.inputDirection(keys) == Some(Vec2.up())
```
