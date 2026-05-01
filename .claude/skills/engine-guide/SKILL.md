---
name: engine-guide
description: "ゲームエンジン（Scene[s], EngineNode[s], GameEngine）のコードを書く前に参照するお作法ガイド。GameData設計、trait実装、衝突応答、動的スポーンを含む"
user-invocable: false
---

# ゲームエンジン お作法ガイド

## ファイル構成と責務

| ファイル | 責務 |
|---|---|
| `src/Main.flix` | EngineConfig + LwjglLayer 起動のみ |
| `src/scenes/Game.flix` | GameData enum, trait instance, mod Game（buildState・gameLoop） |
| `src/scenes/XxxScene.flix` | 個別シーンの構築・更新（scene-pattern 参照） |
| `src/engine/**` | エンジン層（通常は変更不要） |

## Main.flix — エントリポイント専用

ゲームロジックは一切書かない。EngineConfig の定義と起動だけ:

```flix
def main(): Unit \ IO =
    if (GameEngine.ensureMainThread()) ()
    else {
        let config: GameEngine.EngineConfig = {
            screenWidth = Game.screenWi(),
            screenHeight = Game.screenHi(),
            title = "My Game",
            textureManifest = {name = "hero", path = "textures/hero.png", hasAlpha = true} :: Nil,
            fontManifest = {name = "default", path = "textures/font.ttf", fontSize = 60.0} :: Nil,
            soundManifest = {name = "bgm", path = "sounds/bgm.ogg", looping = true} :: Nil,
            clearColor = {r = 0.0f32, g = 0.0f32, b = 0.0f32}
        };
        Math.Random.runWithIO(_ ->
            run { Game.start(GameEngine.Game.getFontAtlas("default")) }
            with LwjglLayer.withLwjgl(config)
        )
    }
```

## Game.flix — 構成順序

トップレベルに enum / type alias / instance、末尾に mod Game:

```
// 1. GamePhase enum
// 2. GameData enum
// 3. GameState type alias
// 4. Node[GameData] instance
// 5. AreaHandler[GameData] instance
// 6. ScreenNotifyHandler[GameData] instance（必要な場合）
// 7. TimerEvent.TimerHandler[GameData] instance（必要な場合）
// 8. mod Game { buildState, gameLoop, フェーズ遷移, ヘルパー }
```

### GameData enum

ノード固有の状態データ。エンジン型（Area2D 等）は含めない（それは EngineNode の役割）:

```flix
pub enum GameData {
    case XxxState(XxxScene.XxxNode, XxxScene.XxxData)  // 親: XxxNode + 状態を持つ
    case XxxArea                                        // 子: 識別のみ（データなし）
    case YyyData(Int32)                                 // 親: 軽量な状態
    case SpawnTimer(Int32)                              // タイマー + カウンタ
    case Marker                                         // 汎用: 状態なし
}
```

### GameState type alias

scene とゲーム全体の状態を 1 レコードにまとめる:

```flix
pub type alias GameState = { scene = Scene[GameData], phase = GamePhase, score = Int32 }
```

レコード更新: `{ scene = newScene, phase = GamePhase.GameOver | state }`

## Game.flix と XxxScene の協業

### Node instance — XxxScene への委譲

`EngineNode × GameData` の二重 match で分岐し、XxxScene の関数に委譲する:

```flix
instance Node[GameData] {
    redef ready(node, path, scene) = match node {
        // 純粋スタイル: エンジン型 + データを渡し、戻り値を再ラップ
        case EngineNode.AnimSprite2DWithState(sprite, GameData.XxxState(n, data)) =>
            let (s, d) = XxxScene.ready(sprite, data);
            (EngineNode.AnimSprite2DWithState(s, GameData.XxxState({ sprite = s | n }, d)), scene)
        // Scene スタイル: path + scene を渡し、更新済みノードを取り直す
        case EngineNode.RigidBody2DWithState(_, GameData.YyyData(_)) =>
            let newScene = YyyScene.ready(path, scene);
            match Scene.getEngineNode(path, newScene) {
                case Some(en) => (en, newScene)
                case None     => (node, newScene)
            }
        case _ => (node, scene)
    }

    redef process(delta, node, _path, scene) = match node {
        case EngineNode.AnimSprite2DWithState(sprite, GameData.XxxState(n, data)) =>
            let moved = XxxScene.process(delta, sprite, data);
            (EngineNode.AnimSprite2DWithState(moved, GameData.XxxState({ sprite = moved | n }, data)), scene)
        case _ => (node, scene)
    }
}
```

### AreaHandler — 衝突応答

引数は GameData の値（EngineNode ではない）。scene を XxxScene の関数で変換:

```flix
instance AreaHandler[GameData] {
    pub def onAreaEntered(_selfPath, selfState, _otherPath, otherState, scene) =
        match (selfState, otherState) {
            case (GameData.XxxArea, GameData.YyyData(_)) =>
                scene |> XxxScene.mapXxx((node, data) ->
                    ({ sprite = CanvasItem.hide(node#sprite) | node },
                     { hit = true | data }))
            case _ => scene
        }
}
```

### TimerHandler — タイマーイベント

GameData バリアントで分岐。XxxScene の構築・操作関数を呼ぶ:

```flix
instance TimerEvent.TimerHandler[GameData] {
    redef onTimeout(timerPath, state, scene) = match state {
        case GameData.SpawnTimer(counter) =>
            let newScene = Game.spawnFromPath(counter, scene);
            Scene.setState(timerPath, GameData.SpawnTimer(counter + 1), newScene)
        case _ => scene
    }
}
```

### ScreenNotifyHandler — 画面外通知

```flix
instance ScreenNotifyHandler[GameData] {
    redef onScreenExited(path, state, scene) = match state {
        case GameData.YyyData(_) => Scene.removeAt(path, scene)
        case _ => scene
    }
}
```

## mod Game — buildState と gameLoop

### buildState

`Scene.empty()` に各 XxxScene.addXxx をパイプで繋ぎ、GameState を返す:

```flix
pub def buildState(fontAtlas: FontAtlas): GameState =
    { scene = Scene.empty()
          |> XxxScene.addXxx
          |> YyyScene.addYyy
          |> Scene.addNode("timer", EngineNode.TimerWithState(timer, GameData.SpawnTimer(0))),
      phase = GamePhase.Menu, score = 0 }
```

### エンジン更新パイプライン

GameEngine の関数を `>>` で連結:

```flix
def engineUpdate(dt: Float64, scene: Scene[GameData]): Scene[GameData] \ {...} =
    (GameEngine.process(dt, false)
    >> GameEngine.physicsProcess(dt, false, PhysicsStep.defaultGravity())
    >> GameEngine.emitCollision
    >> GameEngine.emitScreenNotify(screenWidth = screenWi(), screenHeight = screenHi())
    >> GameEngine.emitTimers)(scene)
```

### gameLoop

フェーズごとに match で処理を切り替え、末尾再帰:

```flix
def gameLoop(fontAtlas: FontAtlas, state: GameState): Unit \ {...} =
    if (GameEngine.Game.shouldClose()) ()
    else {
        let dt = GameEngine.Game.getDeltaTime();
        let nextState = match state#phase {
            case GamePhase.Playing =>
                let updatedScene = engineUpdate(dt, state#scene);
                { scene = updatedScene | state }
            case GamePhase.GameOver => ...
        };
        GameEngine.render(nextState#scene);
        gameLoop(fontAtlas, nextState)
    }
```

### フェーズ遷移

`GameState -> GameState` の関数として定義。XxxScene の操作関数をパイプで繋ぐ:

```flix
pub def newGame(state: GameState): GameState \ GameEngine.Audio =
    AudioStreamPlayer.play(bgmKey());
    let scene = state#scene
        |> Scene.removeGroup(YyyScene.yyyGroup())
        |> XxxScene.start(startPos)
        |> HudScene.showMessage("Get Ready");
    { scene = scene, phase = GamePhase.Playing, score = 0 }
```

## 注意事項

- GameData にエンジン型（Area2D, Sprite2D 等）をラップしない
- Main.flix にゲームロジックを書かない
- 動的スポーンの名前はカウンタ等でユニークにする
- 同一フレームで追加したノードの process は次フレームから
- Scene スタイルの ready では `Scene.getEngineNode` で取り直す（foldNodes の上書き防止）
