type alias Color = {r = Float32, g = Float32, b = Float32}

pub trait CanvasItem[a] {
    // 可視性
    pub def isVisible(node: a): Bool
    pub def setVisible(v: Bool, node: a): a

    // 重なり順
    pub def getZIndex(node: a): Int32
    pub def setZIndex(z: Int32, node: a): a

    // 描画色（乗算）
    pub def getModulate(node: a): Color
    pub def setModulate(color: Color, node: a): a

    // ビューポート

    /// 所属する Viewport の矩形を返す（Godot CanvasItem.get_viewport_rect 準拠）
    /// 現在は常にルート Viewport（デザイン解像度）を返す。
    /// SubViewport 導入時はエフェクトハンドラのスコープで切り替わる。
    pub def getViewportRect(_node: a): Rect2.Rect2 \ Engine.Game =
        Engine.Game.getViewportRect()

    // デフォルト実装
    pub def show(node: a): a = CanvasItem.setVisible(true, node)
    pub def hide(node: a): a = CanvasItem.setVisible(false, node)
}