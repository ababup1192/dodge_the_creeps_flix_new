/// 2D 衝突形状（Godot Shape2D 準拠）
/// see: https://docs.godotengine.org/ja/4.x/classes/class_shape2d.html
///
/// 衝突判定に使う幾何形状。
/// Area2D の collisionShape フィールドに設定して使う。
///
///   CollisionShape2D
///     +-- RectShape2D: 軸平行の矩形（AABB）
///     +-- CircleShape2D: 円
///
/// すべての判定関数は形状の **中心座標** を基準として受け取る。
pub enum CollisionShape2D {
    case RectShape2D({width = Float32, height = Float32})
    case CircleShape2D({radius = Float32})
}

mod CollisionShape2D {

    // ========================================================================
    // 汎用オーバーラップ判定
    // ========================================================================

    /// 2 つの形状が重なっているか判定する。
    /// posA / posB は各形状の中心座標。
    pub def checkOverlap(posA: Vec2.Vec2, shapeA: CollisionShape2D,
                          posB: Vec2.Vec2, shapeB: CollisionShape2D): Bool =
        match (shapeA, shapeB) {
            case (CollisionShape2D.RectShape2D(ra), CollisionShape2D.RectShape2D(rb)) =>
                checkRectRect(posA, {x = ra#width, y = ra#height},
                              posB, {x = rb#width, y = rb#height})
            case (CollisionShape2D.CircleShape2D(ca), CollisionShape2D.CircleShape2D(cb)) =>
                checkCircleCircle(posA, ca#radius, posB, cb#radius)
            case (CollisionShape2D.CircleShape2D(ca), CollisionShape2D.RectShape2D(rb)) =>
                checkCircleRect(posA, ca#radius, posB, {x = rb#width, y = rb#height})
            case (CollisionShape2D.RectShape2D(ra), CollisionShape2D.CircleShape2D(cb)) =>
                checkCircleRect(posB, cb#radius, posA, {x = ra#width, y = ra#height})
        }

    // ========================================================================
    // 個別形状ペアの判定
    // ========================================================================

    /// AABB 矩形同士の重なり判定。
    /// pos は矩形の中心、size は幅と高さ。
    ///
    ///   posA          posB
    ///    +--+          +--+
    ///    |  |   <-->   |  |
    ///    +--+          +--+
    ///
    pub def checkRectRect(posA: Vec2.Vec2, sizeA: Vec2.Vec2,
                           posB: Vec2.Vec2, sizeB: Vec2.Vec2): Bool =
        let halfA = Vec2.div(sizeA, 2.0f32);
        let halfB = Vec2.div(sizeB, 2.0f32);
        (posA#x + halfA#x > posB#x - halfB#x) and
        (posB#x + halfB#x > posA#x - halfA#x) and
        (posA#y + halfA#y > posB#y - halfB#y) and
        (posB#y + halfB#y > posA#y - halfA#y)

    /// 円同士の重なり判定。
    /// pos は円の中心。
    ///
    ///    (A)  <-->  (B)
    ///
    pub def checkCircleCircle(posA: Vec2.Vec2, radiusA: Float32,
                               posB: Vec2.Vec2, radiusB: Float32): Bool =
        let distSq = Vec2.distanceSquaredTo(posA, posB);
        let sumR = radiusA + radiusB;
        distSq < sumR * sumR

    /// 円と矩形の重なり判定。
    /// circlePos は円の中心、rectPos は矩形の中心、rectSize は幅と高さ。
    ///
    ///    (C)     +----+
    ///            |    |
    ///            +----+
    ///
    pub def checkCircleRect(circlePos: Vec2.Vec2, radius: Float32,
                             rectPos: Vec2.Vec2, rectSize: Vec2.Vec2): Bool =
        let halfW = rectSize#x / 2.0f32;
        let halfH = rectSize#y / 2.0f32;
        let dx = Float32.abs(circlePos#x - rectPos#x);
        let dy = Float32.abs(circlePos#y - rectPos#y);
        if (dx >= halfW + radius) false
        else if (dy >= halfH + radius) false
        else if (dx <= halfW or dy <= halfH) true
        else
            let cornerDx = dx - halfW;
            let cornerDy = dy - halfH;
            cornerDx * cornerDx + cornerDy * cornerDy < radius * radius
}
