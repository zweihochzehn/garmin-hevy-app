import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Dark, blue-accented scrollable list built on CustomMenu so it keeps native
// smooth scrolling while matching the look of the workout screens. Used for
// both the routine picker and the exercise list.
class CardMenu extends WatchUi.CustomMenu {
    private var mLabel as String;

    function initialize(title as String) {
        CustomMenu.initialize(104, Theme.BG, {
            :titleItemHeight => 64,
            :focusItemHeight => 112
        });
        mLabel = title;
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY,
            Theme.fit(dc, mLabel, (dc.getWidth() * 0.7).toNumber(), Graphics.FONT_TINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// One card: bold title with a muted sub-line and a blue accent bar.
class CardMenuItem extends WatchUi.CustomMenuItem {
    private var mCardTitle as String;
    private var mCardSub as String;
    private var mAccent as Number;
    private var mDone as Boolean;

    function initialize(id as Object, title as String, sub as String, accent as Number, done as Boolean) {
        CustomMenuItem.initialize(id, {});
        mCardTitle = title;
        mCardSub = sub;
        mAccent = accent;
        mDone = done;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var pad = (w * 0.11).toNumber();
        var cardX = pad;
        var cardW = w - 2 * pad;
        var top = 6;
        var ch = h - 12;

        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, top, cardW, ch, 16);
        // Accent bar on the left (green once the exercise is complete).
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, top, 8, ch, 4);

        // Leave room on the right for a check mark when done.
        var textW = mDone ? cardW - 88 : cardW - 40;
        var tx = mDone ? (cardX + 24 + textW / 2) : w / 2;
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, top + ch / 2 - 15, Graphics.FONT_SMALL,
            Theme.fit(dc, mCardTitle, textW, Graphics.FONT_SMALL),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, top + ch / 2 + 20, Graphics.FONT_XTINY,
            Theme.fit(dc, mCardSub, textW, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (mDone) {
            Theme.drawCheck(dc, cardX + cardW - 34, top + ch / 2, 22, Theme.GREEN);
        }
    }
}
