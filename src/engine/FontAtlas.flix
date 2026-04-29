// FontAtlas — フォントアトラス型定義
// STBTruetype で焼き込んだフォントビットマップのメタデータを保持する

/// フォントアトラス: テクスチャ名 + グリフメトリクスマップ
pub type alias FontAtlas = {
    textureName = String,
    fontSize = Float32,
    textureSize = Float32,
    glyphs = Map[Int32, TextLayout.GlyphMetrics]
}
