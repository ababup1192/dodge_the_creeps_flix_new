# Dodge the Creeps

Flix で実装した「Dodge the Creeps」ゲーム。Godot チュートリアルを参考に、Godot 風のシーンツリーアーキテクチャを Flix + LWJGL で再現。

## 必要環境

- devbox（推奨）
- JDK 21
- macOS (Apple Silicon)

## 実行方法

```bash
./run.sh
```

## テスト

```bash
flix test
```

## 操作方法

- **WASD** / **矢印キー** - プレイヤー移動
- **ESC** - 終了

## ゲームルール

- 画面端から次々と現れる敵（Creeps）を避け続ける
- 生存時間に応じてスコアが加算される（1秒ごとに +1）
- 敵に接触するとゲームオーバー

## プロジェクト構造

```
src/
  Main.flix              - エントリーポイント
  Game.flix              - ゲーム状態・ゲームループ
  SceneTree.flix         - Godot 風シーンツリー・物理・衝突判定
  NodeBuilders.flix      - ノード生成用ビルダー
  LwjglLayer.flix        - LWJGL + OpenGL レンダリング層
  Vec2D.flix             - 2D ベクトル演算
  scene/
    MainScene.flix       - メインシーン（敵スポーン・スコア管理）
    PlayerScene.flix     - プレイヤー（移動・アニメーション）
    MobScene.flix        - 敵モブ（ランダム生成・衝突形状）
test/
  TestMainScene.flix     - メインシーンのテスト
  TestScene.flix         - シーンツリーのテスト
  TestGame.flix          - ゲームロジックのテスト
  TestMob.flix           - モブのテスト
  TestTimer.flix         - タイマーのテスト
  TestVec2D.flix         - ベクトル演算のテスト
textures/
  playerGrey_*.png       - プレイヤースプライト
  enemyFlyingAlt_*.png   - 飛行型の敵
  enemySwimming_*.png    - 水泳型の敵
  enemyWalking_*.png     - 歩行型の敵
```

## 技術スタック

- **Flix 0.71.0** - 関数型プログラミング言語
- **LWJGL 3.3.4** - OpenGL / GLFW / STB バインディング
- **OpenGL 3.3 Core Profile** - シェーダーベースの 2D スプライトレンダリング
