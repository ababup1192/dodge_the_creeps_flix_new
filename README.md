# Dodge the Creeps

Flix で実装した「Dodge the Creeps」ゲーム。Godot チュートリアルを参考に、Godot 風のシーンツリーアーキテクチャを Flix + LWJGL で再現。

## 必要環境

- devbox（推奨）
- JDK 21
- macOS (Apple Silicon)

## 実行方法

```bash
devbox run -- java -jar bin/flix.jar run
```

## テスト

```bash
devbox run -- java -jar bin/flix.jar test
```

## 操作方法

- **WASD** / **矢印キー** - プレイヤー移動
- **Enter** / **Space** / **Start ボタンクリック** - ゲーム開始
- **ESC** - 終了

## ゲームルール

- 画面端から次々と現れる敵（Creeps）を避け続ける
- 生存時間に応じてスコアが加算される（1秒ごとに +1）
- 敵に接触するとゲームオーバー

## プロジェクト構造

```
src/
  Main.flix                  - エントリーポイント（EngineConfig + 起動のみ）
  scenes/
    Game.flix                - NodeTag enum・trait instance・ゲームループ
    PlayerScene.flix         - プレイヤー（移動・アニメーション）
    MobScene.flix            - 敵モブ（スポーン・ランダム速度）
    HUDScene.flix            - HUD（スコア・メッセージ・Start ボタン）
  engine/
    GameEngine.flix          - エンジン更新パイプライン（process/physics/collision/timers）
    LwjglLayer.flix          - LWJGL + OpenGL レンダリング層
    Vec2.flix                - 2D ベクトル演算
    FontAtlas.flix           - フォントアトラス
    scene/
      Scene.flix             - Godot 風シーンツリー
      EngineNode.flix        - ノード enum（Sprite2D, Area2D, RigidBody2D 等）
      PhysicsStep.flix       - 物理積分（重力・線形速度）
      AreaEvent.flix         - 衝突検出
      ...
test/
  scenes/
    TestGame.flix             - ゲームロジックのテスト
    TestMobScene.flix         - モブのテスト
  engine/scene/
    TestScene.flix            - シーンツリーのテスト
    TestPhysicsStep.flix      - 物理演算のテスト
    TestAreaEvent.flix        - 衝突検出のテスト
    ...
textures/
  playerGrey_*.png           - プレイヤースプライト
  enemy{FlyingAlt,Swimming,Walking}_*.png - 敵スプライト（3種）
```

## 技術スタック

- **Flix 0.71.0** - 関数型プログラミング言語
- **LWJGL 3.3.4** - OpenGL / GLFW / STB バインディング
- **OpenGL 3.3 Core Profile** - シェーダーベースの 2D スプライトレンダリング
