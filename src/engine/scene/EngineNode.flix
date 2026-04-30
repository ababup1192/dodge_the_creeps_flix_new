/// エンジンノード — 全ビルトインノード型を統一的に扱うための sum type
///
/// Scene[s] の各 SceneEntry は EngineNode[s]（描画・物理・衝突 + ゲーム状態）を保持する。
/// CanvasItem / Node2D / CollisionObject2D / Renderable は
/// EngineNode[s] に対して一度だけ実装され、ゲーム側のボイラープレートを排除する。
pub enum EngineNode[state] {
    /// 静的スプライト（背景・車両スプライト・丸太スプライト用）
    case Sprite2DWithState(Sprite2D, state)
    /// 衝突エリア（Area2D ベースの当たり判定）
    case Area2DWithState(Area2D, state)
    /// キャラクターボディ（プレイヤー等の物理ボディ）
    case Body2DWithState(CharacterBody2D, state)
    /// 剛体ボディ（物理エンジン駆動のボディ）
    case RigidBody2DWithState(RigidBody2D, state)
    /// アニメーション付きスプライト
    case AnimSprite2DWithState(AnimatedSprite2D, state)
    /// テキストラベル（HUD 表示）
    case Label2DWithState(Label2D, state)
    /// 位置マーカー（スポーン地点・参照点）
    case Marker2DWithState(Marker2D, state)
    /// 2D パスノード（スポーンパス等）
    case Path2DWithState(Path2D, state)
    /// 画面外通知ノード（VisibleOnScreenNotifier2D ベースの画面外検出）
    case ScreenNotifier2DWithState(VisibleOnScreenNotifier2D, state)
    /// タイマーノード（不可視・非衝突の時間カウントダウン）
    case TimerWithState(Timer, state)
}

mod EngineNode {

    /// EngineNode から state を取得する
    pub def getState(node: EngineNode[s]): s = match node {
        case EngineNode.Sprite2DWithState(_, state) => state
        case EngineNode.Area2DWithState(_, state) => state
        case EngineNode.Body2DWithState(_, state) => state
        case EngineNode.RigidBody2DWithState(_, state) => state
        case EngineNode.AnimSprite2DWithState(_, state) => state
        case EngineNode.Label2DWithState(_, state) => state
        case EngineNode.Marker2DWithState(_, state) => state
        case EngineNode.Path2DWithState(_, state) => state
        case EngineNode.ScreenNotifier2DWithState(_, state) => state
        case EngineNode.TimerWithState(_, state) => state
    }

    /// EngineNode の state を置き換える
    pub def setState(newState: s, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(inner, _) => EngineNode.Sprite2DWithState(inner, newState)
        case EngineNode.Area2DWithState(inner, _) => EngineNode.Area2DWithState(inner, newState)
        case EngineNode.Body2DWithState(inner, _) => EngineNode.Body2DWithState(inner, newState)
        case EngineNode.RigidBody2DWithState(inner, _) => EngineNode.RigidBody2DWithState(inner, newState)
        case EngineNode.AnimSprite2DWithState(inner, _) => EngineNode.AnimSprite2DWithState(inner, newState)
        case EngineNode.Label2DWithState(inner, _) => EngineNode.Label2DWithState(inner, newState)
        case EngineNode.Marker2DWithState(inner, _) => EngineNode.Marker2DWithState(inner, newState)
        case EngineNode.Path2DWithState(inner, _) => EngineNode.Path2DWithState(inner, newState)
        case EngineNode.ScreenNotifier2DWithState(inner, _) => EngineNode.ScreenNotifier2DWithState(inner, newState)
        case EngineNode.TimerWithState(inner, _) => EngineNode.TimerWithState(inner, newState)
    }

    /// EngineNode の state に関数を適用する
    pub def mapState(f: s -> s, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(inner, state) => EngineNode.Sprite2DWithState(inner, f(state))
        case EngineNode.Area2DWithState(inner, state) => EngineNode.Area2DWithState(inner, f(state))
        case EngineNode.Body2DWithState(inner, state) => EngineNode.Body2DWithState(inner, f(state))
        case EngineNode.RigidBody2DWithState(inner, state) => EngineNode.RigidBody2DWithState(inner, f(state))
        case EngineNode.AnimSprite2DWithState(inner, state) => EngineNode.AnimSprite2DWithState(inner, f(state))
        case EngineNode.Label2DWithState(inner, state) => EngineNode.Label2DWithState(inner, f(state))
        case EngineNode.Marker2DWithState(inner, state) => EngineNode.Marker2DWithState(inner, f(state))
        case EngineNode.Path2DWithState(inner, state) => EngineNode.Path2DWithState(inner, f(state))
        case EngineNode.ScreenNotifier2DWithState(inner, state) => EngineNode.ScreenNotifier2DWithState(inner, f(state))
        case EngineNode.TimerWithState(inner, state) => EngineNode.TimerWithState(inner, f(state))
    }

    /// Timer の inner node に関数を適用する
    pub def mapTimer(f: Timer -> Timer, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.TimerWithState(inner, st) => EngineNode.TimerWithState(f(inner), st)
        case _ => node
    }

    /// Sprite2D の inner node に関数を適用する（他バリアントは変更なし）
    pub def mapSprite2D(f: Sprite2D -> Sprite2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(inner, st) => EngineNode.Sprite2DWithState(f(inner), st)
        case _ => node
    }

    /// AnimatedSprite2D の inner node に関数を適用する
    pub def mapAnimSprite2D(f: AnimatedSprite2D -> AnimatedSprite2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.AnimSprite2DWithState(inner, st) => EngineNode.AnimSprite2DWithState(f(inner), st)
        case _ => node
    }

    /// CharacterBody2D の inner node に関数を適用する
    pub def mapBody2D(f: CharacterBody2D -> CharacterBody2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Body2DWithState(inner, st) => EngineNode.Body2DWithState(f(inner), st)
        case _ => node
    }

    /// RigidBody2D の inner node に関数を適用する
    pub def mapRigidBody2D(f: RigidBody2D -> RigidBody2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.RigidBody2DWithState(inner, st) => EngineNode.RigidBody2DWithState(f(inner), st)
        case _ => node
    }

    /// Area2D の inner node に関数を適用する
    pub def mapArea2D(f: Area2D -> Area2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Area2DWithState(inner, st) => EngineNode.Area2DWithState(f(inner), st)
        case _ => node
    }

    /// Label2D の inner node に関数を適用する
    pub def mapLabel2D(f: Label2D -> Label2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Label2DWithState(inner, st) => EngineNode.Label2DWithState(f(inner), st)
        case _ => node
    }

    /// Path2D の inner node に関数を適用する
    pub def mapPath2D(f: Path2D -> Path2D, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Path2DWithState(inner, st) => EngineNode.Path2DWithState(f(inner), st)
        case _ => node
    }

    /// エンジンレベルの毎フレーム処理
    /// AnimatedSprite2D のフレーム送りを自動で行う。
    /// RigidBody2D は PhysicsStep が担当するため no-op。
    pub def engineProcess(delta: Float64, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.AnimSprite2DWithState(sprite, state) =>
            EngineNode.AnimSprite2DWithState(AnimatedSprite2D.advanceFrame(delta, sprite), state)
        case EngineNode.TimerWithState(timer, state) =>
            EngineNode.TimerWithState(Timer.process(delta, timer), state)
        case _ => node
    }

    /// Sprite2D を Drawable に変換する
    /// centered=false（背景）の場合は scale を uvScale にしてタイリングする
    pub def spriteToDrawable(sprite: Sprite2D, globalPos: Vec2.Vec2): GameEngine.Drawable =
        let Sprite2D.Sprite2D(r) = sprite;
        let uvSc: Vec2.Vec2 = if (r#centered) {x = 1.0, y = 1.0}
                               else r#scale;
        {
            texture = r#texture,
            position = globalPos,
            scale = r#scale,
            rotation = r#rotation,
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0, y = 0.0},
            uvScale = uvSc,
            zIndex = r#zIndex
        }

    /// AnimatedSprite2D を Drawable に変換する
    pub def animSpriteToDrawable(sprite: AnimatedSprite2D, globalPos: Vec2.Vec2): GameEngine.Drawable =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        {
            texture = AnimatedSprite2D.currentTexture(sprite),
            position = globalPos,
            scale = r#scale,
            rotation = r#rotation,
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0, y = 0.0},
            uvScale = {x = 1.0, y = 1.0},
            zIndex = r#zIndex
        }

    /// EngineNode からフォールバック用 Drawable を組み立てる（デバッグ表示用）
    pub def fallbackDrawable(node: EngineNode[s], globalPos: Vec2.Vec2): GameEngine.Drawable =
        {
            texture = "white",
            position = globalPos,
            scale = Node2D.getScale(node),
            rotation = Node2D.getRotation(node),
            color = CanvasItem.getModulate(node),
            centered = true,
            uvOffset = {x = 0.0, y = 0.0},
            uvScale = {x = 1.0, y = 1.0},
            zIndex = CanvasItem.getZIndex(node)
        }
}

// ── CanvasItem 実装 ──

instance CanvasItem[EngineNode[s]] {
    pub def isVisible(node: EngineNode[s]): Bool = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.isVisible(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.isVisible(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.isVisible(body)
        case EngineNode.RigidBody2DWithState(body, _) => CanvasItem.isVisible(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.isVisible(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.isVisible(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.isVisible(marker)
        case EngineNode.Path2DWithState(path, _) => CanvasItem.isVisible(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => true
        case EngineNode.TimerWithState(timer, _) => CanvasItem.isVisible(timer)
    }
    pub def setVisible(visible: Bool, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setVisible(visible, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setVisible(visible, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setVisible(visible, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(CanvasItem.setVisible(visible, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setVisible(visible, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setVisible(visible, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setVisible(visible, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(CanvasItem.setVisible(visible, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(CanvasItem.setVisible(visible, timer), st)
    }
    pub def getModulate(node: EngineNode[s]): Color = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.getModulate(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.getModulate(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.getModulate(body)
        case EngineNode.RigidBody2DWithState(body, _) => CanvasItem.getModulate(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.getModulate(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.getModulate(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.getModulate(marker)
        case EngineNode.Path2DWithState(path, _) => CanvasItem.getModulate(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => {r = 1.0f32, g = 1.0f32, b = 1.0f32}
        case EngineNode.TimerWithState(timer, _) => CanvasItem.getModulate(timer)
    }
    pub def setModulate(color: Color, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setModulate(color, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setModulate(color, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setModulate(color, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(CanvasItem.setModulate(color, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setModulate(color, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setModulate(color, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setModulate(color, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(CanvasItem.setModulate(color, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(CanvasItem.setModulate(color, timer), st)
    }
    pub def getZIndex(node: EngineNode[s]): Int32 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.getZIndex(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.getZIndex(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.getZIndex(body)
        case EngineNode.RigidBody2DWithState(body, _) => CanvasItem.getZIndex(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.getZIndex(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.getZIndex(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.getZIndex(marker)
        case EngineNode.Path2DWithState(path, _) => CanvasItem.getZIndex(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => 0
        case EngineNode.TimerWithState(timer, _) => CanvasItem.getZIndex(timer)
    }
    pub def setZIndex(zIndex: Int32, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setZIndex(zIndex, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setZIndex(zIndex, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setZIndex(zIndex, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(CanvasItem.setZIndex(zIndex, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setZIndex(zIndex, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setZIndex(zIndex, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setZIndex(zIndex, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(CanvasItem.setZIndex(zIndex, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(CanvasItem.setZIndex(zIndex, timer), st)
    }
}

// ── Node2D 実装 ──

instance Node2D[EngineNode[s]] {
    pub def getPosition(node: EngineNode[s]): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getPosition(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getPosition(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getPosition(body)
        case EngineNode.RigidBody2DWithState(body, _) => Node2D.getPosition(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getPosition(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getPosition(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getPosition(marker)
        case EngineNode.Path2DWithState(path, _) => Node2D.getPosition(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => Vec2.zero()
        case EngineNode.TimerWithState(timer, _) => Node2D.getPosition(timer)
    }
    pub def setPosition(position: Vec2.Vec2, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setPosition(position, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setPosition(position, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setPosition(position, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(Node2D.setPosition(position, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setPosition(position, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setPosition(position, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setPosition(position, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(Node2D.setPosition(position, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(Node2D.setPosition(position, timer), st)
    }
    pub def getRotation(node: EngineNode[s]): Float64 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getRotation(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getRotation(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getRotation(body)
        case EngineNode.RigidBody2DWithState(body, _) => Node2D.getRotation(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getRotation(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getRotation(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getRotation(marker)
        case EngineNode.Path2DWithState(path, _) => Node2D.getRotation(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => 0.0
        case EngineNode.TimerWithState(timer, _) => Node2D.getRotation(timer)
    }
    pub def setRotation(rotation: Float64, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setRotation(rotation, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setRotation(rotation, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setRotation(rotation, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(Node2D.setRotation(rotation, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setRotation(rotation, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setRotation(rotation, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setRotation(rotation, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(Node2D.setRotation(rotation, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(Node2D.setRotation(rotation, timer), st)
    }
    pub def getScale(node: EngineNode[s]): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getScale(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getScale(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getScale(body)
        case EngineNode.RigidBody2DWithState(body, _) => Node2D.getScale(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getScale(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getScale(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getScale(marker)
        case EngineNode.Path2DWithState(path, _) => Node2D.getScale(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => {x = 1.0, y = 1.0}
        case EngineNode.TimerWithState(timer, _) => Node2D.getScale(timer)
    }
    pub def setScale(scale: Vec2.Vec2, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setScale(scale, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setScale(scale, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setScale(scale, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(Node2D.setScale(scale, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setScale(scale, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setScale(scale, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setScale(scale, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(Node2D.setScale(scale, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(Node2D.setScale(scale, timer), st)
    }
    pub def getSkew(node: EngineNode[s]): Float64 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getSkew(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getSkew(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getSkew(body)
        case EngineNode.RigidBody2DWithState(body, _) => Node2D.getSkew(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getSkew(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getSkew(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getSkew(marker)
        case EngineNode.Path2DWithState(path, _) => Node2D.getSkew(path)
        case EngineNode.ScreenNotifier2DWithState(_, _) => 0.0
        case EngineNode.TimerWithState(timer, _) => Node2D.getSkew(timer)
    }
    pub def setSkew(skew: Float64, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setSkew(skew, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setSkew(skew, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setSkew(skew, body), st)
        case EngineNode.RigidBody2DWithState(body, st) => EngineNode.RigidBody2DWithState(Node2D.setSkew(skew, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setSkew(skew, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setSkew(skew, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setSkew(skew, marker), st)
        case EngineNode.Path2DWithState(path, st) => EngineNode.Path2DWithState(Node2D.setSkew(skew, path), st)
        case EngineNode.ScreenNotifier2DWithState(_, _) => node
        case EngineNode.TimerWithState(timer, st) => EngineNode.TimerWithState(Node2D.setSkew(skew, timer), st)
    }
}

// ── CollisionObject2D 実装 ──

instance CollisionObject2D[EngineNode[s]] {
    pub def getCollisionShape(node: EngineNode[s]): Option[CollisionShape2D] = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.getCollisionShape(area)
        case EngineNode.Body2DWithState(body, _) => CollisionObject2D.getCollisionShape(body)
        case EngineNode.RigidBody2DWithState(body, _) => CollisionObject2D.getCollisionShape(body)
        case _ => None
    }
    pub def isMonitoring(node: EngineNode[s]): Bool = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.isMonitoring(area)
        case EngineNode.Body2DWithState(body, _) => CollisionObject2D.isMonitoring(body)
        case EngineNode.RigidBody2DWithState(body, _) => CollisionObject2D.isMonitoring(body)
        case _ => false
    }
    pub def isMonitorable(node: EngineNode[s]): Bool = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.isMonitorable(area)
        case EngineNode.Body2DWithState(body, _) => CollisionObject2D.isMonitorable(body)
        case EngineNode.RigidBody2DWithState(body, _) => CollisionObject2D.isMonitorable(body)
        case _ => false
    }
    redef getCollisionPriority(node: EngineNode[s]): Int32 = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.getCollisionPriority(area)
        case EngineNode.Body2DWithState(body, _) => CollisionObject2D.getCollisionPriority(body)
        case EngineNode.RigidBody2DWithState(body, _) => CollisionObject2D.getCollisionPriority(body)
        case _ => 0
    }
}

// ── Renderable 実装 ──

instance GameEngine.Renderable[EngineNode[s]] {
    pub def toDrawables(node: EngineNode[s], globalPos: Vec2.Vec2): List[GameEngine.Drawable] =
        match node {
            case EngineNode.Sprite2DWithState(sprite, _) =>
                EngineNode.spriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.AnimSprite2DWithState(sprite, _) =>
                EngineNode.animSpriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.Label2DWithState(label, _) =>
                Label2D.toDrawables(label, globalPos)
            case EngineNode.Path2DWithState(_, _) => Nil
            case EngineNode.ScreenNotifier2DWithState(_, _) => Nil
            case EngineNode.TimerWithState(_, _) => Nil
            case _ =>
                EngineNode.fallbackDrawable(node, globalPos) :: Nil
        }
}
