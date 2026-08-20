import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Dark, blue-accented scrollable list built on CustomMenu so it keeps native
// smooth scrolling while matching the look of the workout screens. Used for
// both the routine picker and the exercise list.
//
// Titles are user data from Hevy and are often long ("Bench Press (Barbell)"),
// so they are rendered with WatchUi.TextArea, which wraps to as many lines as
// fit and picks the largest font from a list — dc.drawText neither wraps nor
// shrinks. The card is inset far enough to stay clear of the round bezel.
class CardMenu extends WatchUi.CustomMenu {
    private var mLabel as String;

    function initialize(title as String) {
        var h = System.getDeviceSettings().screenHeight;
        CustomMenu.initialize((h * 0.31).toNumber(), Theme.BG, {
            :titleItemHeight => (h * 0.16).toNumber(),
            :focusItemHeight => (h * 0.34).toNumber()
        });
        mLabel = title;
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        // The header sits at the very top of the round screen, where the
        // usable chord is narrow — keep it well inside.
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY,
            Theme.fit(dc, mLabel, (dc.getWidth() * 0.62).toNumber(), Graphics.FONT_TINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// One card: wrapped title with a muted sub-line and a coloured accent bar.
class CardMenuItem extends WatchUi.CustomMenuItem {
    private var mCardTitle as String;
    private var mCardSub as String;
    private var mAccent as Number;
    private var mDone as Boolean;
    private var mArea as WatchUi.TextArea or Null;
    private var mAreaH as Number;   // height the cached area was built for

    function initialize(id as Object, title as String, sub as String, accent as Number, done as Boolean) {
        CustomMenuItem.initialize(id, {});
        mCardTitle = title;
        mCardSub = sub;
        mAccent = accent;
        mDone = done;
        mArea = null;
        mAreaH = -1;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        // Generous inset: a list item can scroll to the top/bottom of the round
        // display, where the visible chord is much narrower than the full width.
        var pad = (w * 0.13).toNumber();
        var cardX = pad;
        var cardW = w - 2 * pad;
        var top = 5;
        var ch = h - 10;

        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, top, cardW, ch, 16);
        // Accent bar on the left (green once the exercise is complete).
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, top, 8, ch, 4);

        // Text column: leave room on the right for the check mark when done.
        var inset = 18;
        var rightGap = mDone ? 52 : inset;
        var textX = cardX + 8 + inset;
        var textW = cardW - 8 - inset - rightGap;

        // Sub-line sits at the bottom of the card; the title gets what is left.
        var subH = 26;
        var titleH = ch - subH - 12;

        // The focused item is drawn taller than the rest, so the cached area is
        // rebuilt whenever this item's height changes.
        if (mArea == null || mAreaH != h) {
            mAreaH = h;
            mArea = new WatchUi.TextArea({
                :text => mCardTitle,
                :color => Theme.FG,
                :font => [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
                :justification => Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER,
                :locX => textX,
                :locY => top + 6,
                :width => textW,
                :height => titleH
            });
        }
        mArea.draw(dc);

        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX + textW / 2, top + ch - subH / 2 - 6, Graphics.FONT_XTINY,
            Theme.fit(dc, mCardSub, textW, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (mDone) {
            Theme.drawCheck(dc, cardX + cardW - 30, top + ch / 2, 22, Theme.GREEN);
        }
    }
}
