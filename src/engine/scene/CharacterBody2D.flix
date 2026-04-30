/// 2D キャラクター物理ボディ（Godot CharacterBody2D 準拠）
/// see: https://docs.godotengine.org/ja/4.x/classes/class_characterbody2d.html
///
/// 速度ベースの移動を提供するノード。衝突形状は子の Area2D に委譲する。
///
///   CharacterBody2D
///     +-- CanvasItem: visible, zIndex, modulate
///     +-- Node2D: position, rotation, scale, skew
///     +-- velocity: 現在の速度ベクトル
///     +-- moveSpeed: 最大移動速度（ピクセル/秒）
pub enum CharacterBody2D {
    case CharacterBody2D({
        visible = Bool,       // 表示フラグ
        zIndex = Int32,       // 描画順
        modulate = Color,     // 色変調
        position = Vec2.Vec2, // 位置
        rotation = Float64,   // 回転（ラジアン）
        scale = Vec2.Vec2,    // スケール
        skew = Float64,       // スキュー
        velocity = Vec2.Vec2, // 現在の速度ベクトル
        moveSpeed = Float64   // 最大移動速度
    })
}

mod CharacterBody2D {

    /// デフォルト値で CharacterBody2D を生成する
    pub def make(position: Vec2.Vec2, moveSpeed: {moveSpeed = Float64}): CharacterBody2D =
        CharacterBody2D.CharacterBody2D({
            visible = true,
            zIndex = 0,
            modulate = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            position = position,
            rotation = 0.0,
            scale = {x = 1.0, y = 1.0},
            skew = 0.0,
            velocity = Vec2.zero(),
            moveSpeed = moveSpeed#moveSpeed
        })

    /// 速度ベクトルを取得する
    pub def getVelocity(body: CharacterBody2D): Vec2.Vec2 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#velocity

    /// 速度ベクトルを設定する
    pub def setVelocity(velocity: Vec2.Vec2, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({velocity = velocity | r})

    /// 最大移動速度を取得する
    pub def getMoveSpeed(body: CharacterBody2D): Float64 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#moveSpeed
}

// ── CanvasItem 実装 ──

instance CanvasItem[CharacterBody2D] {
    pub def isVisible(body: CharacterBody2D): Bool =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#visible
    pub def setVisible(visible: Bool, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({visible = visible | r})
    pub def getModulate(body: CharacterBody2D): Color =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#modulate
    pub def setModulate(color: Color, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({modulate = color | r})
    pub def getZIndex(body: CharacterBody2D): Int32 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#zIndex
    pub def setZIndex(zIndex: Int32, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({zIndex = zIndex | r})
}

// ── Node2D 実装 ──

instance Node2D[CharacterBody2D] {
    pub def getPosition(body: CharacterBody2D): Vec2.Vec2 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#position
    pub def setPosition(position: Vec2.Vec2, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({position = position | r})
    pub def getRotation(body: CharacterBody2D): Float64 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#rotation
    pub def setRotation(rotation: Float64, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({rotation = rotation | r})
    pub def getScale(body: CharacterBody2D): Vec2.Vec2 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#scale
    pub def setScale(scale: Vec2.Vec2, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({scale = scale | r})
    pub def getSkew(body: CharacterBody2D): Float64 =
        let CharacterBody2D.CharacterBody2D(r) = body;
        r#skew
    pub def setSkew(skew: Float64, body: CharacterBody2D): CharacterBody2D =
        let CharacterBody2D.CharacterBody2D(r) = body;
        CharacterBody2D.CharacterBody2D({skew = skew | r})
}
