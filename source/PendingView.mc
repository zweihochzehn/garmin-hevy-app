import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Shown at launch when finished workouts could not be sent to Hevy (phone was
// away, Hevy down, app closed on the summary). Offers to send or discard them
// one at a time — the workout data lives in Storage until one of the two.
// Discarding is destructive and unrecoverable, so it needs a second tap.
class PendingView extends WatchUi.View {
    private var mStatus as Symbol;   // :idle, :sending, :error, :confirmDiscard
    private var mNote as String;
    private var mTitle as String;
    private var mPayload as Dictionary or Null;
    private var mRemaining as Number;
    private var mW as Number;
    private var mH as Number;
    private var mBtnX0 as Number;
    private var mBtnX1 as Number;
    private var mBtnY0 as Number;
    private var mBtnY1 as Number;
    private var mSecY0 as Number;
    private var mSecY1 as Number;
    private var mSecHalfW as Number;

    function initialize() {
        View.initialize();
        mStatus = :idle;
        mNote = "";
        mTitle = "";
        mPayload = null;
        mRemaining = 0;
        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mBtnX0 = (mW * 0.22).toNumber();
        mBtnX1 = (mW * 0.78).toNumber();
        mBtnY0 = (mH * 0.55).toNumber();
        mBtnY1 = (mH * 0.70).toNumber();
        mSecY0 = (mH * 0.80).toNumber();
        mSecY1 = (mH * 0.92).toNumber();
        mSecHalfW = (mW * 0.24).toNumber();
        loadNext();
    }

    function loadNext() as Void {
        mStatus = :idle;
        mNote = "";
        mTitle = "";
        mPayload = HevyApi.loadPending();
        mRemaining = HevyApi.pendingCount();
        if (mPayload != null) {
            var w = mPayload["workout"];
            if (w instanceof Lang.Dictionary && w["title"] != null) {
                mTitle = w["title"];
            }
        }
    }

    function send() as Void {
        if (mStatus == :sending) { return; }
        if (mPayload == null) { goOn(); return; }
        mStatus = :sending;
        mNote = "";
        WatchUi.requestUpdate();
        HevyApi.postWorkout(mPayload, method(:onPosted));
    }

    function onPosted(code as Number, data as Dictionary or Null) as Void {
        if (code == 200 || code == 201) {
            HevyApi.clearPending(mPayload);
            advance();
        } else {
            mStatus = :error;
            mNote = HevyApi.errorText(code);
            WatchUi.requestUpdate();
        }
    }

    // Destructive: first tap arms, second tap deletes.
    function discard() as Void {
        if (mStatus == :sending) { return; }
        if (mStatus != :confirmDiscard) {
            mStatus = :confirmDiscard;
            WatchUi.requestUpdate();
            return;
        }
        HevyApi.clearPending(mPayload);
        advance();
    }

    // Move to the next unsent workout, or on to the routine list.
    function advance() as Void {
        if (HevyApi.loadPending() != null) {
            loadNext();
            WatchUi.requestUpdate();
            return;
        }
        goOn();
    }

    function goOn() as Void {
        var v = new RoutineListView();
        WatchUi.switchToView(v, new RoutineListDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function hit(x as Number, y as Number) as Symbol or Null {
        if (x >= mBtnX0 && x <= mBtnX1 && y >= mBtnY0 && y <= mBtnY1) { return :send; }
        var cx = mW / 2;
        if (y >= mSecY0 && y <= mSecY1 &&
            x >= cx - mSecHalfW && x <= cx + mSecHalfW) { return :discard; }
        return null;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        var header = WatchUi.loadResource(Rez.Strings.PendingTitle) as String;
        if (mRemaining > 1) { header = header + " (" + mRemaining + ")"; }
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.16).toNumber(), Graphics.FONT_XTINY,
            Theme.fit(dc, header, (mW * 0.8).toNumber(), Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var maxW = (mW * 0.76).toNumber();
        var tf = Theme.bestFont(dc, mTitle, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.30).toNumber(), tf, Theme.fit(dc, mTitle, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!mNote.equals("")) {
            dc.setColor(Theme.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 0.42).toNumber(), Graphics.FONT_XTINY,
                Theme.fit(dc, mNote, (mW * 0.78).toNumber(), Graphics.FONT_XTINY),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Send pill.
        var label = WatchUi.loadResource(
            (mStatus == :sending) ? Rez.Strings.SavingLabel :
            (mStatus == :error) ? Rez.Strings.RetryLabel : Rez.Strings.SendNow) as String;
        var h = mBtnY1 - mBtnY0;
        dc.setColor((mStatus == :sending) ? Theme.BOX : Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mBtnX0, mBtnY0, mBtnX1 - mBtnX0, h, h / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mBtnY0 + mBtnY1) / 2, Graphics.FONT_TINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Discard link — armed state is red and asks for a second tap.
        var armed = mStatus == :confirmDiscard;
        var dLabel = WatchUi.loadResource(
            armed ? Rez.Strings.DiscardConfirm : Rez.Strings.DiscardLabel) as String;
        dc.setColor(armed ? Theme.RED : Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mSecY0 + mSecY1) / 2, Graphics.FONT_XTINY,
            Theme.fit(dc, dLabel, mSecHalfW * 2, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class PendingDelegate extends WatchUi.InputDelegate {
    private var mView as PendingView;

    function initialize(view as PendingView) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var zone = mView.hit(c[0], c[1]);
        if (zone == :send) { mView.send(); }
        else if (zone == :discard) { mView.discard(); }
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { mView.send(); return true; }
        return false;
    }
}
