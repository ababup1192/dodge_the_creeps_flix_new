// Vec2 — 2D vector operations module (Godot Vector2 inspired)

mod Vec2 {
    import java.lang.Math

    pub type alias Vec2 = {x = Float32, y = Float32}

    // ========================================================================
    // Math Helpers
    // ========================================================================

    pub def sqrt32(v: Float32): Float32 =
        Float64.truncateToFloat32(unchecked_cast(Math.sqrt(Float32.toFloat64(v)) as _ \ {}))

    pub def sin32(x: Float32): Float32 =
        Float64.truncateToFloat32(unchecked_cast(Math.sin(Float32.toFloat64(x)) as _ \ {}))

    pub def cos32(x: Float32): Float32 =
        Float64.truncateToFloat32(unchecked_cast(Math.cos(Float32.toFloat64(x)) as _ \ {}))

    def atan232(y: Float32, x: Float32): Float32 =
        Float64.truncateToFloat32(unchecked_cast(Math.atan2(Float32.toFloat64(y), Float32.toFloat64(x)) as _ \ {}))

    pub def floor32(v: Float32): Float32 =
        Float64.truncateToFloat32(Math.floor(Float32.toFloat64(v)))

    pub def floatToInt32(v: Float32): Int32 =
        Int64.truncateToInt32(unchecked_cast(Math.round(Float32.toFloat64(v)) as _ \ {}))

    def ceil32(v: Float32): Float32 =
        Float64.truncateToFloat32(Math.ceil(Float32.toFloat64(v)))

    def round32(v: Float32): Float32 =
        Float64.truncateToFloat32(Math.rint(Float32.toFloat64(v)))

    // ========================================================================
    // Constants
    // ========================================================================

    pub def zero(): Vec2 = {x = 0.0f32, y = 0.0f32}

    pub def one(): Vec2 = {x = 1.0f32, y = 1.0f32}

    pub def up(): Vec2 = {x = 0.0f32, y = -1.0f32}

    pub def down(): Vec2 = {x = 0.0f32, y = 1.0f32}

    pub def left(): Vec2 = {x = -1.0f32, y = 0.0f32}

    pub def right(): Vec2 = {x = 1.0f32, y = 0.0f32}

    // ========================================================================
    // Arithmetic
    // ========================================================================

    pub def add(a: Vec2, b: Vec2): Vec2 =
        {x = a#x + b#x, y = a#y + b#y}

    pub def sub(a: Vec2, b: Vec2): Vec2 =
        {x = a#x - b#x, y = a#y - b#y}

    pub def mul(v: Vec2, s: Float32): Vec2 =
        {x = v#x * s, y = v#y * s}

    pub def div(v: Vec2, s: Float32): Vec2 =
        {x = v#x / s, y = v#y / s}

    pub def neg(v: Vec2): Vec2 =
        {x = -1.0f32 * v#x, y = -1.0f32 * v#y}

    // ========================================================================
    // Length & Distance
    // ========================================================================

    pub def lengthSquared(v: Vec2): Float32 =
        v#x * v#x + v#y * v#y

    pub def length(v: Vec2): Float32 =
        sqrt32(lengthSquared(v))

    pub def distanceSquaredTo(a: Vec2, b: Vec2): Float32 =
        lengthSquared(sub(a, b))

    pub def distanceTo(a: Vec2, b: Vec2): Float32 =
        length(sub(a, b))

    // ========================================================================
    // Normalization & Dot/Cross
    // ========================================================================

    pub def normalized(v: Vec2): Vec2 =
        let len = length(v);
        if (len > 0.0f32) div(v, len) else zero()

    pub def dot(a: Vec2, b: Vec2): Float32 =
        a#x * b#x + a#y * b#y

    pub def cross(a: Vec2, b: Vec2): Float32 =
        a#x * b#y - a#y * b#x

    // ========================================================================
    // Reflect & Bounce
    // ========================================================================

    /// Reflect v off a surface with normal n: v - 2 * dot(v, n) * n
    pub def reflect(v: Vec2, n: Vec2): Vec2 =
        let d = dot(v, n);
        sub(v, mul(n, 2.0f32 * d))

    /// Bounce v off a surface with normal n: -reflect(v, n)
    pub def bounce(v: Vec2, n: Vec2): Vec2 =
        neg(reflect(v, n))

    // ========================================================================
    // Angle & Rotation
    // ========================================================================

    pub def angle(v: Vec2): Float32 =
        atan232(v#y, v#x)

    pub def angleTo(a: Vec2, b: Vec2): Float32 =
        atan232(cross(a, b), dot(a, b))

    pub def rotated(v: Vec2, phi: Float32): Vec2 =
        let c = cos32(phi);
        let s = sin32(phi);
        {x = v#x * c - v#y * s, y = v#x * s + v#y * c}

    pub def directionTo(a: Vec2, b: Vec2): Vec2 =
        normalized(sub(b, a))

    // ========================================================================
    // Clamp & Interpolation
    // ========================================================================

    pub def clamp(v: Vec2, minV: Vec2, maxV: Vec2): Vec2 =
        {x = Float32.max(minV#x, Float32.min(maxV#x, v#x)),
         y = Float32.max(minV#y, Float32.min(maxV#y, v#y))}

    pub def clampSymmetric(v: Vec2, halfExtents: Vec2): Vec2 =
        clamp(v, neg(halfExtents), halfExtents)

    pub def moveToward(origin: Vec2, target: Vec2, delta: Float32): Vec2 =
        let diff = sub(target, origin);
        let dist = length(diff);
        if (dist <= delta or dist <= 0.0f32) target
        else add(origin, mul(div(diff, dist), delta))

    pub def lerp(a: Vec2, b: Vec2, t: Float32): Vec2 =
        {x = a#x + (b#x - a#x) * t, y = a#y + (b#y - a#y) * t}

    // ========================================================================
    // Component Operations
    // ========================================================================

    pub def abs(v: Vec2): Vec2 =
        {x = Float32.abs(v#x), y = Float32.abs(v#y)}

    pub def sign(v: Vec2): Vec2 =
        let sx = if (v#x > 0.0f32) 1.0f32 else if (v#x < 0.0f32) -1.0f32 else 0.0f32;
        let sy = if (v#y > 0.0f32) 1.0f32 else if (v#y < 0.0f32) -1.0f32 else 0.0f32;
        {x = sx, y = sy}

    pub def min(a: Vec2, b: Vec2): Vec2 =
        {x = Float32.min(a#x, b#x), y = Float32.min(a#y, b#y)}

    pub def max(a: Vec2, b: Vec2): Vec2 =
        {x = Float32.max(a#x, b#x), y = Float32.max(a#y, b#y)}

    pub def floor(v: Vec2): Vec2 =
        {x = floor32(v#x), y = floor32(v#y)}

    pub def ceil(v: Vec2): Vec2 =
        {x = ceil32(v#x), y = ceil32(v#y)}

    pub def round(v: Vec2): Vec2 =
        {x = round32(v#x), y = round32(v#y)}

    // ========================================================================
    // Utility
    // ========================================================================

    pub def isNormalized(v: Vec2): Bool =
        let lsq = lengthSquared(v);
        Float32.abs(lsq - 1.0f32) < 0.0001f32

    pub def isZeroApprox(v: Vec2): Bool =
        Float32.abs(v#x) < 0.0001f32 and Float32.abs(v#y) < 0.0001f32

    pub def limitLength(v: Vec2, maxLen: Float32): Vec2 =
        let lsq = lengthSquared(v);
        if (lsq > maxLen * maxLen)
            mul(normalized(v), maxLen)
        else v

    pub def projected(v: Vec2, onto: Vec2): Vec2 =
        let d = dot(onto, onto);
        if (d > 0.0f32) mul(onto, dot(v, onto) / d) else zero()

    pub def slide(v: Vec2, n: Vec2): Vec2 =
        sub(v, mul(n, dot(v, n)))
}
