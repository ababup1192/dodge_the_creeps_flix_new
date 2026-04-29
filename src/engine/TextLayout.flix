// TextLayout — pure functions for text layout calculations

mod TextLayout {

    /// Convert a Char to its unsigned Unicode codepoint.
    /// Flix's Char.toBmpCodePoint returns signed Int32, so chars >= U+8000
    /// become negative. This function masks to 16-bit unsigned.
    pub def charToCodePoint(ch: Char): Int32 =
        Int32.bitwiseAnd(Char.toBmpCodePoint(ch), 0xFFFF)

    /// Line height multiplier (1.2x font size, standard for single-spaced text).
    pub def lineHeightMultiplier(): Float32 = 1.2f32

    /// Calculate the horizontal offset for centering single-line text.
    pub def centerOffset(totalAdvance: Float32, scale: Float32): Float32 =
        -1.0f32 * totalAdvance * scale / 2.0f32

    /// Sum of glyph advances (total text width in bake-scale units).
    pub def totalAdvance(advances: List[Float32]): Float32 =
        List.foldLeft((acc, a) -> acc + a, 0.0f32, advances)

    /// Compute pen positions for each character with word-wrap support.
    pub def layoutPositions(advances: List[Float32], wrapWidth: Float32,
                            scale: Float32, lineHeight: Float32): List[(Float32, Float32)] =
        if (wrapWidth <= 0.0f32) {
            let result = List.foldLeft((acc, adv) -> {
                let penX = acc#penX;
                {positions = (penX, 0.0f32) :: acc#positions, penX = penX + adv}
            }, {positions = (Nil: List[(Float32, Float32)]), penX = 0.0f32}, advances);
            List.reverse(result#positions)
        } else {
            let result = List.foldLeft((acc, adv) -> {
                let penX = acc#penX;
                let penY = acc#penY;
                let nextX = penX + adv;
                let px = if (penX > 0.0f32 and nextX * scale > wrapWidth) 0.0f32 else penX;
                let py = if (penX > 0.0f32 and nextX * scale > wrapWidth) penY + lineHeight else penY;
                {positions = (px, py) :: acc#positions, penX = px + adv, penY = py}
            }, {positions = (Nil: List[(Float32, Float32)]), penX = 0.0f32, penY = 0.0f32}, advances);
            List.reverse(result#positions)
        }

    /// Glyph metrics and atlas UV coordinates.
    pub type alias GlyphMetrics = {
        xOff = Float32, yOff = Float32,
        glyphW = Float32, glyphH = Float32,
        advance = Float32,
        s0 = Float32, t0 = Float32, s1 = Float32, t1 = Float32
    }

    /// Screen-space quad bounds for a single glyph.
    pub type alias QuadBounds = {
        x0 = Float32, y0 = Float32, x1 = Float32, y1 = Float32
    }

    /// Calculate screen-space quad bounds for a glyph at a given pen position.
    /// penPos: (penX, penY) in bake-scale coordinates from layoutPositions
    /// glyph: glyph metrics (xOff, yOff, glyphW, glyphH)
    /// scale: fontSize / fontBakeSize
    /// basePos: label's screen position
    /// offsetX: centering offset (0 if not centered)
    pub def glyphQuadBounds(penPos: (Float32, Float32), glyph: GlyphMetrics,
                            scale: Float32, basePos: Vec2.Vec2,
                            offsetX: Float32): QuadBounds =
        let (penX, penY) = penPos;
        let x0 = (penX + glyph#xOff) * scale + basePos#x + offsetX;
        let y0 = (penY + glyph#yOff) * scale + basePos#y;
        let x1 = x0 + glyph#glyphW * scale;
        let y1 = y0 + glyph#glyphH * scale;
        {x0 = x0, y0 = y0, x1 = x1, y1 = y1}

    /// Count the number of lines in a wrapped layout.
    pub def lineCount(advances: List[Float32], wrapWidth: Float32,
                      scale: Float32, lineHeight: Float32): Int32 =
        let positions = layoutPositions(advances, wrapWidth, scale, lineHeight);
        match positions {
            case Nil => 0
            case _ =>
                let ys = List.map(p -> snd(p), positions);
                let result = List.foldLeft((acc, y) -> {
                    let count = fst(acc);
                    let prevY = snd(acc);
                    if (Float32.abs(y - prevY) > 0.001f32) (count + 1, y) else (count, prevY)
                }, (1, 0.0f32), ys);
                fst(result)
        }
}
