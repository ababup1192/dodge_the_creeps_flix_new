/// ボタンノード（Godot Button 準拠）
/// see: https://docs.godotengine.org/ja/4.x/classes/class_button.html
///
/// 背景矩形 + テキスト + マウス操作を持つ UI ボタン。
///
///   Button
///     +-- CanvasItem: visible, zIndex, modulate
///     +-- Node2D: position, rotation, scale, skew

/// ボタンのビジュアル状態
pub enum ButtonVisualState with Eq, ToString {
    case Normal
    case Hovered
    case Pressed
}

pub enum Button {
    case Button({
        position = Vec2.Vec2,
        rotation = Float64,
        scale = Vec2.Vec2,
        skew = Float64,
        visible = Bool,
        zIndex = Int32,
        modulate = Color,
        size = Vec2.Vec2,
        text = String,
        fontAtlas = FontAtlas,
        fontSize = Float64,
        disabled = Bool,
        visualState = ButtonVisualState,
        justPressed = Bool
    })
}

mod Button {
    /// デフォルト値で Button を生成する
    pub def make(text: String, fontAtlas: FontAtlas, fontSize: Float64, size: Vec2.Vec2): Button =
        Button.Button({
            position = Vec2.zero(),
            rotation = 0.0,
            scale = {x = 1.0, y = 1.0},
            skew = 0.0,
            visible = true,
            zIndex = 0,
            modulate = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            size = size,
            text = text,
            fontAtlas = fontAtlas,
            fontSize = fontSize,
            disabled = false,
            visualState = ButtonVisualState.Normal,
            justPressed = false
        })

    /// テキストを取得する
    pub def getText(btn: Button): String =
        let Button.Button(r) = btn;
        r#text

    /// テキストを設定する
    pub def setText(text: String, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ text = text | r })

    /// サイズを取得する
    pub def getSize(btn: Button): Vec2.Vec2 =
        let Button.Button(r) = btn;
        r#size

    /// サイズを設定する
    pub def setSize(size: Vec2.Vec2, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ size = size | r })

    /// disabled を取得する
    pub def isDisabled(btn: Button): Bool =
        let Button.Button(r) = btn;
        r#disabled

    /// disabled を設定する
    pub def setDisabled(disabled: Bool, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ disabled = disabled | r })

    /// visualState を取得する
    pub def getVisualState(btn: Button): ButtonVisualState =
        let Button.Button(r) = btn;
        r#visualState

    /// justPressed を取得する
    pub def isJustPressed(btn: Button): Bool =
        let Button.Button(r) = btn;
        r#justPressed

    /// justPressed フラグをクリアする
    pub def clearJustPressed(btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ justPressed = false | r })

    /// マウス状態からボタンのインタラクションを更新する
    /// mousePos: デザイン座標でのマウス位置
    /// mousePressed: マウスボタンが押されているか
    /// globalPos: ボタンのグローバル座標
    pub def updateInteraction(mousePos: Vec2.Vec2, mousePressed: Bool,
                              globalPos: Vec2.Vec2, btn: Button): Button =
        let Button.Button(r) = btn;
        if (r#disabled)
            btn
        else {
            let inBounds =
                mousePos#x >= globalPos#x and
                mousePos#x <= globalPos#x + r#size#x and
                mousePos#y >= globalPos#y and
                mousePos#y <= globalPos#y + r#size#y;
            if (not inBounds)
                Button.Button({ visualState = ButtonVisualState.Normal, justPressed = false | r })
            else if (mousePressed)
                Button.Button({ visualState = ButtonVisualState.Pressed, justPressed = false | r })
            else if (r#visualState == ButtonVisualState.Pressed)
                // マウスボタンが離された → justPressed
                Button.Button({ visualState = ButtonVisualState.Hovered, justPressed = true | r })
            else
                Button.Button({ visualState = ButtonVisualState.Hovered, justPressed = false | r })
        }

    /// ビジュアル状態に応じた背景色を返す（Godot 4 デフォルトテーマ準拠）
    def bgColor(state: ButtonVisualState): Color = match state {
        case ButtonVisualState.Normal  => {r = 0.1f32, g = 0.1f32, b = 0.1f32}
        case ButtonVisualState.Hovered => {r = 0.225f32, g = 0.225f32, b = 0.225f32}
        case ButtonVisualState.Pressed => {r = 0.0f32, g = 0.0f32, b = 0.0f32}
    }

    /// ビジュアル状態に応じた背景アルファを返す（Godot 4 デフォルトテーマ準拠）
    def bgAlpha(_state: ButtonVisualState): Float32 = 0.6f32

    /// ビジュアル状態に応じたフォント色を返す（Godot 4 デフォルトテーマ準拠）
    def fontColor(state: ButtonVisualState): Color = match state {
        case ButtonVisualState.Normal  => {r = 0.875f32, g = 0.875f32, b = 0.875f32}
        case ButtonVisualState.Hovered => {r = 0.95f32, g = 0.95f32, b = 0.95f32}
        case ButtonVisualState.Pressed => {r = 1.0f32, g = 1.0f32, b = 1.0f32}
    }

    /// Button を Drawable のリストに変換する（背景矩形 + テキスト）
    pub def toDrawables(btn: Button, globalPos: Vec2.Vec2): List[GameEngine.Drawable] =
        let Button.Button(r) = btn;
        // 背景矩形
        let bgDrawable: GameEngine.Drawable = {
            texture = "",
            position = globalPos,
            scale = r#size,
            rotation = r#rotation,
            color = bgColor(r#visualState),
            alpha = bgAlpha(r#visualState),
            centered = false,
            uvOffset = {x = 0.0, y = 0.0},
            uvScale = {x = 1.0, y = 1.0},
            zIndex = r#zIndex
        };
        // テキスト（ボタン中央配置）
        let atlas = r#fontAtlas;
        let scale = r#fontSize / atlas#fontSize;
        let chars = String.toList(r#text);
        let advances = List.map(ch -> {
            let cp = TextLayout.charToCodePoint(ch);
            match Map.get(cp, atlas#glyphs) {
                case Some(gm) => gm#advance
                case None => 0.0
            }
        }, chars);
        let textWidth = TextLayout.totalAdvance(advances) * scale;
        // グリフの視覚的 Y 範囲を計算（yOff が負の場合を考慮）
        let yBounds = List.foldLeft((acc, ch) -> {
            let cp = TextLayout.charToCodePoint(ch);
            match Map.get(cp, atlas#glyphs) {
                case Some(gm) =>
                    let top = gm#yOff;
                    let bottom = gm#yOff + gm#glyphH;
                    { minY = Float64.min(acc#minY, top), maxY = Float64.max(acc#maxY, bottom) }
                case None => acc
            }
        }, { minY = 0.0, maxY = 0.0 }, chars);
        let visualHeight = (yBounds#maxY - yBounds#minY) * scale;
        // テキスト開始位置（視覚的バウンディングボックスをボタン中央にセンタリング）
        let textX = globalPos#x + (r#size#x - textWidth) / 2.0;
        let textY = globalPos#y + (r#size#y - visualHeight) / 2.0 - yBounds#minY * scale;
        let textBasePos: Vec2.Vec2 = {x = textX, y = textY};
        let positions = TextLayout.layoutPositions(advances, 0.0, scale, r#fontSize * TextLayout.lineHeightMultiplier());
        let textDrawables = List.filterMap(pair -> {
            let (ch, penPos) = pair;
            let cp = TextLayout.charToCodePoint(ch);
            match Map.get(cp, atlas#glyphs) {
                case Some(gm) =>
                    let qb = TextLayout.glyphQuadBounds(penPos, gm, scale, textBasePos, 0.0);
                    let w = qb#x1 - qb#x0;
                    let h = qb#y1 - qb#y0;
                    if (w <= 0.0 or h <= 0.0) None
                    else Some({
                        texture = atlas#textureName,
                        position = {x = qb#x0, y = qb#y0},
                        scale = {x = w / atlas#textureSize, y = h / atlas#textureSize},
                        rotation = 0.0,
                        color = fontColor(r#visualState),
                        alpha = 1.0f32,
                        centered = false,
                        uvOffset = {x = gm#s0, y = gm#t0},
                        uvScale = {x = gm#s1 - gm#s0, y = gm#t1 - gm#t0},
                        zIndex = r#zIndex + 1
                    })
                case None => None
            }
        }, List.zip(chars, positions));
        bgDrawable :: textDrawables
}

// -- CanvasItem 実装 --

instance CanvasItem[Button] {
    pub def isVisible(btn: Button): Bool =
        let Button.Button(r) = btn;
        r#visible
    pub def setVisible(visible: Bool, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ visible = visible | r })
    pub def getModulate(btn: Button): Color =
        let Button.Button(r) = btn;
        r#modulate
    pub def setModulate(color: Color, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ modulate = color | r })
    pub def getZIndex(btn: Button): Int32 =
        let Button.Button(r) = btn;
        r#zIndex
    pub def setZIndex(zIndex: Int32, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ zIndex = zIndex | r })
}

// -- Node2D 実装 --

instance Node2D[Button] {
    pub def getPosition(btn: Button): Vec2.Vec2 =
        let Button.Button(r) = btn;
        r#position
    pub def setPosition(position: Vec2.Vec2, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ position = position | r })
    pub def getRotation(btn: Button): Float64 =
        let Button.Button(r) = btn;
        r#rotation
    pub def setRotation(rotation: Float64, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ rotation = rotation | r })
    pub def getScale(btn: Button): Vec2.Vec2 =
        let Button.Button(r) = btn;
        r#scale
    pub def setScale(scale: Vec2.Vec2, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ scale = scale | r })
    pub def getSkew(btn: Button): Float64 =
        let Button.Button(r) = btn;
        r#skew
    pub def setSkew(skew: Float64, btn: Button): Button =
        let Button.Button(r) = btn;
        Button.Button({ skew = skew | r })
}
