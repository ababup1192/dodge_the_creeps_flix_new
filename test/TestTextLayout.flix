mod TestTextLayout {

    def approx(a: Float32, b: Float32): Bool =
        Float32.abs(a - b) < 0.001f32

    // ========================================================================
    // charToCodePoint
    // ========================================================================

    @Test
    def testCodePointAscii(): Unit \ Assert =
        Assert.assertTrue(TextLayout.charToCodePoint('A') == 65)

    @Test
    def testCodePointHiragana(): Unit \ Assert =
        Assert.assertTrue(TextLayout.charToCodePoint('\u306e') == 12398)

    @Test
    def testCodePointKanjiAbove8000(): Unit \ Assert =
        Assert.assertTrue(TextLayout.charToCodePoint('\u8868') == 34920)

    @Test
    def testCodePointKanjiHigh(): Unit \ Assert =
        Assert.assertTrue(TextLayout.charToCodePoint('\u8a9e') == 35486)

    @Test
    def testCodePointSpace(): Unit \ Assert =
        Assert.assertTrue(TextLayout.charToCodePoint(' ') == 32)

    // ========================================================================
    // centerOffset
    // ========================================================================

    @Test
    def testCenterOffsetZero(): Unit \ Assert =
        Assert.assertTrue(approx(TextLayout.centerOffset(0.0f32, 1.0f32), 0.0f32))

    @Test
    def testCenterOffset(): Unit \ Assert =
        Assert.assertTrue(approx(TextLayout.centerOffset(100.0f32, 1.0f32), -50.0f32))

    @Test
    def testCenterOffsetWithScale(): Unit \ Assert =
        Assert.assertTrue(approx(TextLayout.centerOffset(100.0f32, 0.5f32), -25.0f32))

    // ========================================================================
    // totalAdvance
    // ========================================================================

    @Test
    def testTotalAdvanceEmpty(): Unit \ Assert =
        Assert.assertTrue(approx(TextLayout.totalAdvance(Nil), 0.0f32))

    @Test
    def testTotalAdvance(): Unit \ Assert =
        let advances = 10.0f32 :: 20.0f32 :: 30.0f32 :: Nil;
        Assert.assertTrue(approx(TextLayout.totalAdvance(advances), 60.0f32))

    // ========================================================================
    // layoutPositions — no wrap
    // ========================================================================

    @Test
    def testLayoutNoWrapEmpty(): Unit \ Assert =
        let result = TextLayout.layoutPositions(Nil, 0.0f32, 1.0f32, 10.0f32);
        Assert.assertTrue(List.length(result) == 0)

    @Test
    def testLayoutNoWrapSingleChar(): Unit \ Assert =
        let result = TextLayout.layoutPositions(10.0f32 :: Nil, 0.0f32, 1.0f32, 10.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (x, y) = Array.get(0, r);
            Assert.assertTrue(approx(x, 0.0f32) and approx(y, 0.0f32))
        }

    @Test
    def testLayoutNoWrapPenAdvances(): Unit \ Assert =
        let advances = 10.0f32 :: 20.0f32 :: 15.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 0.0f32, 1.0f32, 10.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (x0, _) = Array.get(0, r);
            let (x1, _) = Array.get(1, r);
            let (x2, _) = Array.get(2, r);
            Assert.assertTrue(approx(x0, 0.0f32));
            Assert.assertTrue(approx(x1, 10.0f32));
            Assert.assertTrue(approx(x2, 30.0f32))
        }

    @Test
    def testLayoutNoWrapAllOnLine0(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 0.0f32, 1.0f32, 10.0f32);
        Assert.assertTrue(List.forAll(match (_, y) -> approx(y, 0.0f32), result))

    // ========================================================================
    // layoutPositions — with wrap
    // ========================================================================

    @Test
    def testLayoutWrapNoBreakNeeded(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 100.0f32, 1.0f32, 20.0f32);
        Assert.assertTrue(List.forAll(match (_, y) -> approx(y, 0.0f32), result))

    @Test
    def testLayoutWrapBreaksAtWidth(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 25.0f32, 1.0f32, 20.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (x0, y0) = Array.get(0, r);
            let (x1, y1) = Array.get(1, r);
            let (x2, y2) = Array.get(2, r);
            Assert.assertTrue(approx(x0, 0.0f32) and approx(y0, 0.0f32));
            Assert.assertTrue(approx(x1, 10.0f32) and approx(y1, 0.0f32));
            Assert.assertTrue(approx(x2, 0.0f32) and approx(y2, 20.0f32))
        }

    @Test
    def testLayoutWrapScaleAffectsBreak(): Unit \ Assert =
        // scale 2.0: each char advance=10, effective=20. wrapWidth=35.
        // char 0: penX=0, next=10, 10*2=20<35 => stays. penX=10
        // char 1: penX=10, next=20, 20*2=40>35 => wraps to y=20. penX=10
        // char 2: penX=10, next=20, 20*2=40>35 => wraps to y=40. penX=10
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 35.0f32, 2.0f32, 20.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (x0, y0) = Array.get(0, r);
            let (x1, y1) = Array.get(1, r);
            let (x2, y2) = Array.get(2, r);
            Assert.assertTrue(approx(x0, 0.0f32) and approx(y0, 0.0f32));
            Assert.assertTrue(approx(x1, 0.0f32) and approx(y1, 20.0f32));
            Assert.assertTrue(approx(x2, 0.0f32) and approx(y2, 40.0f32))
        }

    @Test
    def testLayoutWrapMultipleLines(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 25.0f32, 1.0f32, 20.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (_, y0) = Array.get(0, r);
            let (_, y1) = Array.get(1, r);
            let (_, y2) = Array.get(2, r);
            let (_, y3) = Array.get(3, r);
            let (_, y4) = Array.get(4, r);
            Assert.assertTrue(approx(y0, 0.0f32) and approx(y1, 0.0f32));
            Assert.assertTrue(approx(y2, 20.0f32) and approx(y3, 20.0f32));
            Assert.assertTrue(approx(y4, 40.0f32))
        }

    @Test
    def testLayoutWrapFirstCharNeverWraps(): Unit \ Assert =
        let advances = 100.0f32 :: Nil;
        let result = TextLayout.layoutPositions(advances, 50.0f32, 1.0f32, 20.0f32);
        region rc {
            let r = List.toArray(rc, result);
            let (_, y) = Array.get(0, r);
            Assert.assertTrue(approx(y, 0.0f32))
        }

    // ========================================================================
    // lineCount
    // ========================================================================

    @Test
    def testLineCountEmpty(): Unit \ Assert =
        Assert.assertTrue(TextLayout.lineCount(Nil, 100.0f32, 1.0f32, 20.0f32) == 0)

    @Test
    def testLineCountSingleLine(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        Assert.assertTrue(TextLayout.lineCount(advances, 100.0f32, 1.0f32, 20.0f32) == 1)

    @Test
    def testLineCountTwoLines(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        Assert.assertTrue(TextLayout.lineCount(advances, 25.0f32, 1.0f32, 20.0f32) == 2)

    @Test
    def testLineCountThreeLines(): Unit \ Assert =
        let advances = 10.0f32 :: 10.0f32 :: 10.0f32 :: 10.0f32 :: 10.0f32 :: Nil;
        Assert.assertTrue(TextLayout.lineCount(advances, 25.0f32, 1.0f32, 20.0f32) == 3)

    // ========================================================================
    // glyphQuadBounds
    // ========================================================================

    @Test
    def testGlyphQuadBoundsBasic(): Unit \ Assert =
        let gm: TextLayout.GlyphMetrics = {xOff = 2.0f32, yOff = -10.0f32, glyphW = 8.0f32, glyphH = 12.0f32, advance = 10.0f32, s0 = 0.0f32, t0 = 0.0f32, s1 = 0.0f32, t1 = 0.0f32};
        let q = TextLayout.glyphQuadBounds((0.0f32, 0.0f32), gm, 1.0f32, {x = 100.0f32, y = 200.0f32}, 0.0f32);
        Assert.assertTrue(approx(q#x0, 102.0f32));
        Assert.assertTrue(approx(q#y0, 190.0f32));
        Assert.assertTrue(approx(q#x1, 110.0f32));
        Assert.assertTrue(approx(q#y1, 202.0f32))

    @Test
    def testGlyphQuadBoundsWithScale(): Unit \ Assert =
        let gm: TextLayout.GlyphMetrics = {xOff = 0.0f32, yOff = 0.0f32, glyphW = 10.0f32, glyphH = 20.0f32, advance = 12.0f32, s0 = 0.0f32, t0 = 0.0f32, s1 = 0.0f32, t1 = 0.0f32};
        let q = TextLayout.glyphQuadBounds((5.0f32, 0.0f32), gm, 0.5f32, {x = 0.0f32, y = 0.0f32}, 0.0f32);
        // x0 = (5+0)*0.5 = 2.5, y0 = 0, x1 = 2.5+10*0.5 = 7.5, y1 = 0+20*0.5 = 10
        Assert.assertTrue(approx(q#x0, 2.5f32));
        Assert.assertTrue(approx(q#y0, 0.0f32));
        Assert.assertTrue(approx(q#x1, 7.5f32));
        Assert.assertTrue(approx(q#y1, 10.0f32))

    @Test
    def testGlyphQuadBoundsWithCenterOffset(): Unit \ Assert =
        let gm: TextLayout.GlyphMetrics = {xOff = 0.0f32, yOff = 0.0f32, glyphW = 10.0f32, glyphH = 10.0f32, advance = 10.0f32, s0 = 0.0f32, t0 = 0.0f32, s1 = 0.0f32, t1 = 0.0f32};
        let q = TextLayout.glyphQuadBounds((0.0f32, 0.0f32), gm, 1.0f32, {x = 100.0f32, y = 50.0f32}, -20.0f32);
        Assert.assertTrue(approx(q#x0, 80.0f32));
        Assert.assertTrue(approx(q#y0, 50.0f32))

    @Test
    def testGlyphQuadBoundsWrappedLine(): Unit \ Assert =
        let gm: TextLayout.GlyphMetrics = {xOff = 1.0f32, yOff = -8.0f32, glyphW = 10.0f32, glyphH = 10.0f32, advance = 12.0f32, s0 = 0.0f32, t0 = 0.0f32, s1 = 0.0f32, t1 = 0.0f32};
        // penPos on second line
        let q = TextLayout.glyphQuadBounds((0.0f32, 20.0f32), gm, 2.0f32, {x = 10.0f32, y = 10.0f32}, 0.0f32);
        // x0 = (0+1)*2 + 10 = 12, y0 = (20-8)*2 + 10 = 34
        Assert.assertTrue(approx(q#x0, 12.0f32));
        Assert.assertTrue(approx(q#y0, 34.0f32));
        Assert.assertTrue(approx(q#x1, 32.0f32));
        Assert.assertTrue(approx(q#y1, 54.0f32))
}
