# ゲームエンジン実装イメージ

入力システムは後回しにして、Scene ツリー + Sprite2D を軸にした
ゲームループの全体像を示す。

## 全体の流れ

```
main
 └─ gameLoop(scene, prevTime)
      ├─ delta = now - prevTime
      ├─ scene = Scene.processAll(delta, paused, scene)   ← ゲームロジック
      ├─ render(scene)                                     ← 描画
      └─ gameLoop(scene, now)                              ← 再帰
```

## 1. GameNode — ゲーム専用の sum type

Scene[n] の n は単一型なので、ゲームに登場する全ノードを 1 つの enum にまとめる。
各ケースが Sprite2D を内包し、ゲーム固有のデータを持つ。

```flix
enum GameNode with Eq, Order {
    case Frog(Sprite2D)
    case Car({ sprite = Sprite2D, speed = Float32 })
    case Log({ sprite = Sprite2D, speed = Float32 })
    case Goal(Sprite2D)
}
```

## 2. trait 実装 — GameNode に Node, Node2D, CanvasItem を実装

全ケースに対して match で委譲する。Sprite2D が既に Node2D と CanvasItem を
実装しているので、中身は sprite を取り出して呼ぶだけ。

```flix
instance Node2D[GameNode] {
    pub def getPosition(node: GameNode): Vec2.Vec2 = match node {
        case GameNode.Frog(s)  => Node2D.getPosition(s)
        case GameNode.Car(r)   => Node2D.getPosition(r#sprite)
        case GameNode.Log(r)   => Node2D.getPosition(r#sprite)
        case GameNode.Goal(s)  => Node2D.getPosition(s)
    }
    pub def setPosition(pos: Vec2.Vec2, node: GameNode): GameNode = match node {
        case GameNode.Frog(s)  => GameNode.Frog(Node2D.setPosition(pos, s))
        case GameNode.Car(r)   => GameNode.Car({ sprite = Node2D.setPosition(pos, r#sprite) | r })
        case GameNode.Log(r)   => GameNode.Log({ sprite = Node2D.setPosition(pos, r#sprite) | r })
        case GameNode.Goal(s)  => GameNode.Goal(Node2D.setPosition(pos, s))
    }
    // rotation, scale, skew も同様
}
```

## 3. process — ゲームロジックは各ケースの match に書く

Scene.processAll が preorder で全ノードの process を呼ぶ。
各ノードは自分の更新ロジックだけを担当する。

```flix
instance Node[GameNode] {
    pub def getSelf(name: NodeName, scene: Scene[GameNode]): Option[GameNode] =
        Scene.get(name, scene)

    pub def setSelf(name: NodeName, self: GameNode, scene: Scene[GameNode]): Scene[GameNode] =
        Scene.set(name, self, scene)

    pub def process(delta: Float64, self: GameNode, name: NodeName, scene: Scene[GameNode]): (GameNode, Scene[GameNode]) =
        match self {
            case GameNode.Car(r) =>
                // 毎フレーム横に移動
                let dx = r#speed * Float64.truncateToFloat32(delta);
                let moved = Node2D.translate({x = dx, y = 0.0f32}, r#sprite);
                (GameNode.Car({ sprite = moved | r }), scene)

            case GameNode.Log(r) =>
                // Car と同じく横に移動
                let dx = r#speed * Float64.truncateToFloat32(delta);
                let moved = Node2D.translate({x = dx, y = 0.0f32}, r#sprite);
                (GameNode.Log({ sprite = moved | r }), scene)

            case _ =>
                // Frog, Goal はここでは何もしない
                (self, scene)
        }
}
```

## 4. シーン構築 — addNode と addChild でツリーを組む

```flix
def buildScene(): Scene[GameNode] =
    Scene.empty()
        // ルートレベル（position = グローバル座標）
        |> Scene.addNode("frog",  GameNode.Frog(frogSprite))
        |> Scene.addNode("goal1", GameNode.Goal(goalSprite1))
        |> Scene.addNode("goal2", GameNode.Goal(goalSprite2))

        // 丸太: ルートレベルで横スクロール
        |> Scene.addNode("log1", GameNode.Log({
            sprite = logSprite(200.0f32, 300.0f32),
            speed  = 50.0f32
        }))

        // 車: ルートレベルで横スクロール
        |> Scene.addNode("car1", GameNode.Car({
            sprite = carSprite(100.0f32, 400.0f32),
            speed  = -80.0f32
        }))
```

### 丸太に乗る = 親子関係にする

Frog が丸太に乗ったとき、addChild で親子にすれば自動で追従する。
降りたら remove → addNode でルートに戻す。

```
【地面にいるとき】          【丸太に乗ったとき】
Scene                       Scene
 ├─ frog (100, 400)          ├─ log1 (200, 300)     ← 横スクロール中
 ├─ log1 (200, 300)          │   └─ frog (0, 0)     ← 相対座標 (0,0) = 丸太の上
 └─ car1 (100, 400)          └─ car1 (100, 400)
```

## 5. ゲームループ

```flix
def gameLoop(scene: Scene[GameNode]): Unit \ IO =
    let delta = 0.016f64;   // TODO: 実際のフレーム時間計算
    let paused = false;

    // 1. 更新: Scene.processAll が preorder で全ノードの process を呼ぶ
    let scene1 = Scene.processAll(delta, paused, scene);

    // 2. 描画
    render(scene1);

    // 3. 次のフレームへ
    gameLoop(scene1)
```

## 6. 描画 — globalPosition で座標を解決

```flix
def render(scene: Scene[GameNode]): Unit \ IO =
    Scene.preorderNames(scene)
        |> List.filterMap(name ->
            Scene.get(name, scene) |> Option.map(node -> (name, node))
        )
        |> List.sortBy(match (_, node) -> CanvasItem.getZIndex(node))
        |> List.forEach(match (name, node) ->
            if (CanvasItem.isVisible(node))
                let pos = Scene.globalPosition(name, scene);
                drawSprite(pos, node)
            else
                ()
        )
```

## 7. 全体の登場人物まとめ

```
既存（変更なし）           新規
─────────────────────     ─────────────────
Scene.flix                 GameNode.flix      ← enum + Node/Node2D/CanvasItem 実装
Node.flix                  GameLoop.flix      ← gameLoop, render
Node2D.flix                FroggerScene.flix  ← buildScene（シーン構築）
Sprite2D.flix
CanvasItem.flix
ProcessMode.flix
Vec2.flix
```

## ポイント

- **ゲームループは 3 行**: processAll → render → 再帰
- **ゲームロジックは process に分散**: ループ側はノードの種類を知らない
- **描画は globalPosition で座標解決**: ツリー構造を意識しなくていい
- **親子関係で追従**: 丸太に乗る = addChild、降りる = remove + addNode
- **Sprite2D はデータ**: GameNode が Sprite2D を内包し、trait を委譲する
