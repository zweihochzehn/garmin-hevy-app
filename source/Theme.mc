import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Colors and small drawing helpers shared across the guided-workout screens,
// tuned to resemble the Hevy Apple Watch app on a black AMOLED background.
module Theme {
    const BG      = 0x000000;
    const FG      = 0xFFFFFF;
    const MUTED   = 0x9AA0A6;
    const BLUE    = 0x1273FF;  // Hevy accent / primary action
    const GREEN   = 0x30D158;  // play / start
    const RED     = 0xFF453A;
    const BOX     = 0x1C1C1E;  // field background
    const LINE    = 0x48484A;  // field border

    // Format a duration in seconds as M:SS (or MM:SS).
    function mmss(totalSec as Number) as String {
        if (totalSec < 0) { totalSec = 0; }
        var m = totalSec / 60;
        var s = totalSec % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }

    // Format a weight without fake precision: 20 -> "20", 22.5 -> "22.5",
    // 22.25 -> "22.25" — what is shown is exactly what gets logged.
    function weight(kg as Float or Number or Null) as String {
        if (kg == null) { return "–"; }
        var f = kg.toFloat();
        var cents = Math.round(f * 100).toNumber();
        if (cents % 100 == 0) { return (cents / 100).format("%d"); }
        if (cents % 10 == 0) { return f.format("%.1f"); }
        return f.format("%.2f");
    }

    // Truncate a string with an ellipsis so it fits within maxW pixels.
    function fit(dc as Graphics.Dc, text as String, maxW as Number, font as Graphics.FontType) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) { return text; }
        var s = text;
        while (s.length() > 1 && dc.getTextWidthInPixels(s + "…", font) > maxW) {
            s = s.substring(0, s.length() - 1);
        }
        return s + "…";
    }

    // Pick the largest font from a list that renders text within maxW; falls
    // back to the smallest.
    function bestFont(dc as Graphics.Dc, text as String, maxW as Number, fonts as Array<Graphics.FontType>) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxW) { return fonts[i]; }
        }
        return fonts[fonts.size() - 1];
    }

    // Drawn heart (font heart glyphs don't render on-device).
    function drawHeart(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = (s * 0.30);
        var yTop = cy - s * 0.12;
        dc.fillCircle(cx - r * 0.85, yTop, r);
        dc.fillCircle(cx + r * 0.85, yTop, r);
        dc.fillPolygon([
            [cx - s * 0.48, cy - s * 0.02],
            [cx + s * 0.48, cy - s * 0.02],
            [cx, cy + s * 0.5]
        ]);
    }

    // Left-pointing chevron (back).
    function drawBackChevron(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx + s * 0.35, cy - s * 0.55, cx - s * 0.35, cy);
        dc.drawLine(cx - s * 0.35, cy, cx + s * 0.35, cy + s * 0.55);
    }

    // Downward-pointing chevron (hints at content one swipe below).
    function drawDownChevron(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx - s * 0.55, cy - s * 0.35, cx, cy + s * 0.35);
        dc.drawLine(cx, cy + s * 0.35, cx + s * 0.55, cy - s * 0.35);
    }

    // Upward-pointing chevron (hints at content one swipe above).
    function drawUpChevron(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx - s * 0.55, cy + s * 0.35, cx, cy - s * 0.35);
        dc.drawLine(cx, cy - s * 0.35, cx + s * 0.55, cy + s * 0.35);
    }

    // Check mark.
    function drawCheck(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx - s * 0.45, cy + s * 0.05, cx - s * 0.08, cy + s * 0.4);
        dc.drawLine(cx - s * 0.08, cy + s * 0.4, cx + s * 0.5, cy - s * 0.4);
    }

    // Top header: elapsed time centered, with a heart + HR when available.
    function drawHeader(dc as Graphics.Dc, w as Number, h as Number, elapsed as String, hr as Number or Null) as Void {
        var y = (h * 0.10).toNumber();
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        if (hr == null) {
            dc.drawText(w / 2, y, Graphics.FONT_XTINY, elapsed, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var hrs = hr.format("%d");
        var ew = dc.getTextWidthInPixels(elapsed, Graphics.FONT_XTINY);
        var hw = dc.getTextWidthInPixels(hrs, Graphics.FONT_XTINY);
        var heartW = 15;
        var gap = 12;
        var total = ew + gap + heartW + 5 + hw;
        var x = w / 2 - total / 2;
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, elapsed, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var hx = x + ew + gap;
        drawHeart(dc, hx + heartW / 2, y, 14, RED);
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hx + heartW + 5, y, Graphics.FONT_XTINY, hrs, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Filled circle button with a centered glyph string.
    function circleButton(dc as Graphics.Dc, cx as Number, cy as Number, r as Number,
                          fill as Number, fg as Number, glyph as String, font as Graphics.FontType) as Void {
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, font, glyph, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
