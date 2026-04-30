// Tests for CollisionShape2D module

// ========================================================================
// checkRectRect
// ========================================================================

/// 重なっている矩形
@Test
def testRectRectOverlapping(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 3.0, y = 0.0};
    let sizeA = {x = 4.0, y = 4.0};
    let sizeB = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkRectRect(posA, sizeA, posB, sizeB))

/// 離れている矩形
@Test
def testRectRectNotOverlapping(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 10.0, y = 0.0};
    let sizeA = {x = 4.0, y = 4.0};
    let sizeB = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkRectRect(posA, sizeA, posB, sizeB))

/// 辺が接触（タンジェント）は重ならない
@Test
def testRectRectTouching(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 4.0, y = 0.0};
    let sizeA = {x = 4.0, y = 4.0};
    let sizeB = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkRectRect(posA, sizeA, posB, sizeB))

/// 完全に包含
@Test
def testRectRectContained(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 0.0, y = 0.0};
    let sizeA = {x = 10.0, y = 10.0};
    let sizeB = {x = 2.0, y = 2.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkRectRect(posA, sizeA, posB, sizeB))

// ========================================================================
// checkCircleCircle
// ========================================================================

/// 重なっている円
@Test
def testCircleCircleOverlapping(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 3.0, y = 0.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkCircleCircle(posA, 2.0, posB, 2.0))

/// 離れている円
@Test
def testCircleCircleNotOverlapping(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 10.0, y = 0.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkCircleCircle(posA, 2.0, posB, 2.0))

/// 接触（タンジェント）は重ならない
@Test
def testCircleCircleTouching(): Unit \ Assert =
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 4.0, y = 0.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkCircleCircle(posA, 2.0, posB, 2.0))

// ========================================================================
// checkCircleRect
// ========================================================================

/// 円が矩形の辺に重なる
@Test
def testCircleRectOverlappingSide(): Unit \ Assert =
    let circlePos = {x = 0.0, y = 3.0};
    let rectPos = {x = 0.0, y = 0.0};
    let rectSize = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkCircleRect(circlePos, 2.0, rectPos, rectSize))

/// 円が矩形から離れている
@Test
def testCircleRectNotOverlapping(): Unit \ Assert =
    let circlePos = {x = 10.0, y = 10.0};
    let rectPos = {x = 0.0, y = 0.0};
    let rectSize = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkCircleRect(circlePos, 2.0, rectPos, rectSize))

/// 円が矩形のコーナーに重なる
@Test
def testCircleRectCornerOverlap(): Unit \ Assert =
    let circlePos = {x = 3.0, y = 3.0};
    let rectPos = {x = 0.0, y = 0.0};
    let rectSize = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkCircleRect(circlePos, 2.0, rectPos, rectSize))

/// 円が矩形のコーナー外側で離れている
@Test
def testCircleRectCornerMiss(): Unit \ Assert =
    let circlePos = {x = 4.0, y = 4.0};
    let rectPos = {x = 0.0, y = 0.0};
    let rectSize = {x = 4.0, y = 4.0};
    Assert.assertEq(expected = false, CollisionShape2D.checkCircleRect(circlePos, 1.0, rectPos, rectSize))

/// 円の中心が矩形の内部にある
@Test
def testCircleRectCircleInsideRect(): Unit \ Assert =
    let circlePos = {x = 0.5, y = 0.5};
    let rectPos = {x = 0.0, y = 0.0};
    let rectSize = {x = 10.0, y = 10.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkCircleRect(circlePos, 1.0, rectPos, rectSize))

// ========================================================================
// checkOverlap（汎用ディスパッチ）
// ========================================================================

/// RectShape2D 同士のディスパッチ
@Test
def testCheckOverlapRectRect(): Unit \ Assert =
    let shapeA = CollisionShape2D.RectShape2D({width = 4.0, height = 4.0});
    let shapeB = CollisionShape2D.RectShape2D({width = 4.0, height = 4.0});
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 3.0, y = 0.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkOverlap(posA, shapeA, posB, shapeB))

/// CircleShape2D 同士のディスパッチ
@Test
def testCheckOverlapCircleCircle(): Unit \ Assert =
    let shapeA = CollisionShape2D.CircleShape2D({radius = 2.0});
    let shapeB = CollisionShape2D.CircleShape2D({radius = 2.0});
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 3.0, y = 0.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkOverlap(posA, shapeA, posB, shapeB))

/// Circle vs Rect のディスパッチ
@Test
def testCheckOverlapCircleRect(): Unit \ Assert =
    let shapeA = CollisionShape2D.CircleShape2D({radius = 2.0});
    let shapeB = CollisionShape2D.RectShape2D({width = 4.0, height = 4.0});
    let posA = {x = 0.0, y = 3.0};
    let posB = {x = 0.0, y = 0.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkOverlap(posA, shapeA, posB, shapeB))

/// Rect vs Circle のディスパッチ（逆順）
@Test
def testCheckOverlapRectCircle(): Unit \ Assert =
    let shapeA = CollisionShape2D.RectShape2D({width = 4.0, height = 4.0});
    let shapeB = CollisionShape2D.CircleShape2D({radius = 2.0});
    let posA = {x = 0.0, y = 0.0};
    let posB = {x = 0.0, y = 3.0};
    Assert.assertEq(expected = true, CollisionShape2D.checkOverlap(posA, shapeA, posB, shapeB))
