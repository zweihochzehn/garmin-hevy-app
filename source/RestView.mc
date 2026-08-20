import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.Attention;

// Rest screen shown between sets: a countdown that auto-advances to the next
// set at zero, an explicit "+15 s" pill, and a skip pill. (Adding time is a
// visible control, not a hidden tap-anywhere gesture.)
class RestView extends WatchUi.View {
    private var mSession as WorkoutSession;
    private var mRemaining as Number;
    private var mTimer as Timer.Timer or Null;
    private var mW as Number;
    private var mH as Number;
    private var mPlusX0 as Number;
    private var mPlusX1 as Number;
    private var mSkipX0 as Number;
    private var mSkipX1 as Number;
    private var mBtnY0 as Number;
    private var mBtnY1 as Number;
    private var mStrRest as String;
    private var mStrSet as String;
    private var mStrSkip as String;
    private var mStrPlus as String;

    function initialize(session as WorkoutSession, restSeconds as Number) {
        View.initialize();
        mSession = session;
        mRemaining = restSeconds;
        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mPlusX0 = (mW * 0.13).toNumber();
        mPlusX1 = (mW * 0.42).toNumber();
        mSkipX0 = (mW * 0.48).toNumber();
        mSkipX1 = (mW * 0.87).toNumber();
        mBtnY0 = (mH * 0.745).toNumber();
        mBtnY1 = (mH * 0.86).toNumber();
        mStrRest = WatchUi.loadResource(Rez.Strings.Rest) as String;
        mStrSet = WatchUi.loadResource(Rez.Strings.SetWord) as String;
        mStrSkip = WatchUi.loadResource(Rez.Strings.SkipLabel) as String;
        mStrPlus = WatchUi.loadResource(Rez.Strings.Plus15) as String;
    }

    function onShow() as Void {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
            mTimer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() as Void {
        if (mTimer != null) { mTimer.stop(); mTimer = null; }
    }

    function onTick() as Void {
        mRemaining -= 1;
        if (mRemaining <= 0) {
            // One short buzz so the user notices the rest is over without
            // watching the screen. Only on the natural end of the countdown —
            // a manual skip needs no cue. (Guarded: not every device/setting
            // allows vibration.)
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(80, 300)]);
            }
            skip();
        } else {
            WatchUi.requestUpdate();
        }
    }

    function skip() as Void {
        if (mTimer != null) { mTimer.stop(); mTimer = null; }
        Flow.showCurrentSet(mSession);
    }

    function addTime(secs as Number) as Void {
        mRemaining += secs;
        WatchUi.requestUpdate();
    }

    function hit(x as Number, y as Number) as Symbol or Null {
        if (y >= mBtnY0 && y <= mBtnY1) {
            if (x >= mPlusX0 && x <= mPlusX1) { return :plus; }
            if (x >= mSkipX0 && x <= mSkipX1) { return :skip; }
        }
        return null;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.155).toNumber(), Graphics.FONT_XTINY, mStrRest,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.35).toNumber(), Graphics.FONT_NUMBER_HOT, Theme.mmss(mRemaining),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Preview of the upcoming set: exercise name, then set counter.
        var maxW = (mW * 0.78).toNumber();
        var exTitle = mSession.currentTitle();
        var pf = Theme.bestFont(dc, exTitle, maxW, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.55).toNumber(), pf, Theme.fit(dc, exTitle, maxW, pf),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.635).toNumber(), Graphics.FONT_XTINY,
            mStrSet + " " + (mSession.setIndex + 1) + " / " + mSession.setCount(mSession.exIndex),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // +15s pill (box) and skip pill (blue).
        var h = mBtnY1 - mBtnY0;
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mPlusX0, mBtnY0, mPlusX1 - mPlusX0, h, h / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText((mPlusX0 + mPlusX1) / 2, (mBtnY0 + mBtnY1) / 2, Graphics.FONT_TINY, mStrPlus,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mSkipX0, mBtnY0, mSkipX1 - mSkipX0, h, h / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText((mSkipX0 + mSkipX1) / 2, (mBtnY0 + mBtnY1) / 2, Graphics.FONT_TINY, mStrSkip,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function goBackToList() as Void {
        if (mTimer != null) { mTimer.stop(); mTimer = null; }
        WatchUi.switchToView(
            new ExerciseListView(mSession),
            new ExerciseListDelegate(mSession),
            WatchUi.SLIDE_RIGHT);
    }
}

class RestDelegate extends WatchUi.InputDelegate {
    private var mView as RestView;

    function initialize(view as RestView, restSeconds as Number) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var zone = mView.hit(c[0], c[1]);
        if (zone == :skip) { mView.skip(); }
        else if (zone == :plus) { mView.addTime(15); }
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        if (evt.getDirection() == WatchUi.SWIPE_RIGHT) {
            mView.goBackToList();
            return true;
        }
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { mView.goBackToList(); return true; }
        if (k == WatchUi.KEY_ENTER) { mView.skip(); return true; }
        return false;
    }
}
