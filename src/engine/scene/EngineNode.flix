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
    /// アニメーション付きスプライト
    case AnimSprite2DWithState(AnimatedSprite2D, state)
    /// テキストラベル（HUD 表示）
    case Label2DWithState(Label2D, state)
    /// 位置マーカー（スポーン地点・参照点）
    case Marker2DWithState(Marker2D, state)
}

mod EngineNode {

    /// EngineNode から state を取得する
    pub def getState(node: EngineNode[s]): s = match node {
        case EngineNode.Sprite2DWithState(_, state) => state
        case EngineNode.Area2DWithState(_, state) => state
        case EngineNode.Body2DWithState(_, state) => state
        case EngineNode.AnimSprite2DWithState(_, state) => state
        case EngineNode.Label2DWithState(_, state) => state
        case EngineNode.Marker2DWithState(_, state) => state
    }

    /// EngineNode の state を置き換える
    pub def setState(newState: s, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(inner, _) => EngineNode.Sprite2DWithState(inner, newState)
        case EngineNode.Area2DWithState(inner, _) => EngineNode.Area2DWithState(inner, newState)
        case EngineNode.Body2DWithState(inner, _) => EngineNode.Body2DWithState(inner, newState)
        case EngineNode.AnimSprite2DWithState(inner, _) => EngineNode.AnimSprite2DWithState(inner, newState)
        case EngineNode.Label2DWithState(inner, _) => EngineNode.Label2DWithState(inner, newState)
        case EngineNode.Marker2DWithState(inner, _) => EngineNode.Marker2DWithState(inner, newState)
    }

    /// EngineNode の state に関数を適用する
    pub def mapState(f: s -> s, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(inner, state) => EngineNode.Sprite2DWithState(inner, f(state))
        case EngineNode.Area2DWithState(inner, state) => EngineNode.Area2DWithState(inner, f(state))
        case EngineNode.Body2DWithState(inner, state) => EngineNode.Body2DWithState(inner, f(state))
        case EngineNode.AnimSprite2DWithState(inner, state) => EngineNode.AnimSprite2DWithState(inner, f(state))
        case EngineNode.Label2DWithState(inner, state) => EngineNode.Label2DWithState(inner, f(state))
        case EngineNode.Marker2DWithState(inner, state) => EngineNode.Marker2DWithState(inner, f(state))
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

    /// エンジンレベルの毎フレーム処理
    /// AnimatedSprite2D のフレーム送りを自動で行う。
    pub def engineProcess(delta: Float32, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.AnimSprite2DWithState(sprite, state) =>
            EngineNode.AnimSprite2DWithState(AnimatedSprite2D.advanceFrame(delta, sprite), state)
        case _ => node
    }

    /// Sprite2D を Drawable に変換する
    /// centered=false（背景）の場合は scale を uvScale にしてタイリングする
    pub def spriteToDrawable(sprite: Sprite2D, globalPos: Vec2.Vec2): Engine.Drawable =
        let Sprite2D.Sprite2D(r) = sprite;
        let uvSc: Vec2.Vec2 = if (r#centered) {x = 1.0f32, y = 1.0f32}
                               else r#scale;
        {
            texture = r#texture,
            position = globalPos,
            scale = r#scale,
            rotation = Float64.truncateToFloat32(r#rotation),
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = uvSc,
            zIndex = r#zIndex
        }

    /// AnimatedSprite2D を Drawable に変換する
    pub def animSpriteToDrawable(sprite: AnimatedSprite2D, globalPos: Vec2.Vec2): Engine.Drawable =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        {
            texture = AnimatedSprite2D.currentTexture(sprite),
            position = globalPos,
            scale = r#scale,
            rotation = Float64.truncateToFloat32(r#rotation),
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = {x = 1.0f32, y = 1.0f32},
            zIndex = r#zIndex
        }

    /// EngineNode からフォールバック用 Drawable を組み立てる（デバッグ表示用）
    pub def fallbackDrawable(node: EngineNode[s], globalPos: Vec2.Vec2): Engine.Drawable =
        {
            texture = "white",
            position = globalPos,
            scale = Node2D.getScale(node),
            rotation = Float64.truncateToFloat32(Node2D.getRotation(node)),
            color = CanvasItem.getModulate(node),
            centered = true,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = {x = 1.0f32, y = 1.0f32},
            zIndex = CanvasItem.getZIndex(node)
        }
}

// ── CanvasItem 実装 ──

instance CanvasItem[EngineNode[s]] {
    pub def isVisible(node: EngineNode[s]): Bool = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.isVisible(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.isVisible(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.isVisible(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.isVisible(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.isVisible(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.isVisible(marker)
    }
    pub def setVisible(visible: Bool, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setVisible(visible, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setVisible(visible, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setVisible(visible, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setVisible(visible, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setVisible(visible, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setVisible(visible, marker), st)
    }
    pub def getModulate(node: EngineNode[s]): Color = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.getModulate(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.getModulate(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.getModulate(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.getModulate(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.getModulate(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.getModulate(marker)
    }
    pub def setModulate(color: Color, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setModulate(color, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setModulate(color, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setModulate(color, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setModulate(color, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setModulate(color, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setModulate(color, marker), st)
    }
    pub def getZIndex(node: EngineNode[s]): Int32 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => CanvasItem.getZIndex(sprite)
        case EngineNode.Area2DWithState(area, _) => CanvasItem.getZIndex(area)
        case EngineNode.Body2DWithState(body, _) => CanvasItem.getZIndex(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => CanvasItem.getZIndex(sprite)
        case EngineNode.Label2DWithState(label, _) => CanvasItem.getZIndex(label)
        case EngineNode.Marker2DWithState(marker, _) => CanvasItem.getZIndex(marker)
    }
    pub def setZIndex(zIndex: Int32, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(CanvasItem.setZIndex(zIndex, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(CanvasItem.setZIndex(zIndex, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(CanvasItem.setZIndex(zIndex, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(CanvasItem.setZIndex(zIndex, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(CanvasItem.setZIndex(zIndex, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(CanvasItem.setZIndex(zIndex, marker), st)
    }
}

// ── Node2D 実装 ──

instance Node2D[EngineNode[s]] {
    pub def getPosition(node: EngineNode[s]): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getPosition(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getPosition(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getPosition(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getPosition(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getPosition(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getPosition(marker)
    }
    pub def setPosition(position: Vec2.Vec2, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setPosition(position, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setPosition(position, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setPosition(position, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setPosition(position, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setPosition(position, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setPosition(position, marker), st)
    }
    pub def getRotation(node: EngineNode[s]): Float64 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getRotation(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getRotation(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getRotation(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getRotation(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getRotation(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getRotation(marker)
    }
    pub def setRotation(rotation: Float64, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setRotation(rotation, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setRotation(rotation, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setRotation(rotation, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setRotation(rotation, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setRotation(rotation, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setRotation(rotation, marker), st)
    }
    pub def getScale(node: EngineNode[s]): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getScale(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getScale(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getScale(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getScale(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getScale(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getScale(marker)
    }
    pub def setScale(scale: Vec2.Vec2, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setScale(scale, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setScale(scale, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setScale(scale, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setScale(scale, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setScale(scale, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setScale(scale, marker), st)
    }
    pub def getSkew(node: EngineNode[s]): Float64 = match node {
        case EngineNode.Sprite2DWithState(sprite, _) => Node2D.getSkew(sprite)
        case EngineNode.Area2DWithState(area, _) => Node2D.getSkew(area)
        case EngineNode.Body2DWithState(body, _) => Node2D.getSkew(body)
        case EngineNode.AnimSprite2DWithState(sprite, _) => Node2D.getSkew(sprite)
        case EngineNode.Label2DWithState(label, _) => Node2D.getSkew(label)
        case EngineNode.Marker2DWithState(marker, _) => Node2D.getSkew(marker)
    }
    pub def setSkew(skew: Float64, node: EngineNode[s]): EngineNode[s] = match node {
        case EngineNode.Sprite2DWithState(sprite, st) => EngineNode.Sprite2DWithState(Node2D.setSkew(skew, sprite), st)
        case EngineNode.Area2DWithState(area, st) => EngineNode.Area2DWithState(Node2D.setSkew(skew, area), st)
        case EngineNode.Body2DWithState(body, st) => EngineNode.Body2DWithState(Node2D.setSkew(skew, body), st)
        case EngineNode.AnimSprite2DWithState(sprite, st) => EngineNode.AnimSprite2DWithState(Node2D.setSkew(skew, sprite), st)
        case EngineNode.Label2DWithState(label, st) => EngineNode.Label2DWithState(Node2D.setSkew(skew, label), st)
        case EngineNode.Marker2DWithState(marker, st) => EngineNode.Marker2DWithState(Node2D.setSkew(skew, marker), st)
    }
}

// ── CollisionObject2D 実装 ──

instance CollisionObject2D[EngineNode[s]] {
    pub def getCollisionShape(node: EngineNode[s]): Option[CollisionShape2D] = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.getCollisionShape(area)
        case _ => None
    }
    pub def isMonitoring(node: EngineNode[s]): Bool = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.isMonitoring(area)
        case _ => false
    }
    pub def isMonitorable(node: EngineNode[s]): Bool = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.isMonitorable(area)
        case _ => false
    }
    redef getCollisionPriority(node: EngineNode[s]): Int32 = match node {
        case EngineNode.Area2DWithState(area, _) => CollisionObject2D.getCollisionPriority(area)
        case _ => 0
    }
}

// ── Renderable 実装 ──

instance Engine.Renderable[EngineNode[s]] {
    pub def toDrawables(node: EngineNode[s], globalPos: Vec2.Vec2): List[Engine.Drawable] =
        match node {
            case EngineNode.Sprite2DWithState(sprite, _) =>
                EngineNode.spriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.AnimSprite2DWithState(sprite, _) =>
                EngineNode.animSpriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.Label2DWithState(label, _) =>
                Label2D.toDrawables(label, globalPos)
            case _ =>
                EngineNode.fallbackDrawable(node, globalPos) :: Nil
        }
}
