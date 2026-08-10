import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// Screen 3: a time-based set (Plank) or distance-based set (Running, Farmers
// Walk). Shows a stopwatch with a green play/pause control and a Next pill.
// Duration sets count toward the planned duration; distance sets show the
// planned distance and pass it through to the Hevy log unchanged.
class DurationSetView extends WatchUi.View {
    private var mSession as WorkoutSession;
    private var mTarget as Number;          // planned duration (0 = none)
    private var mDistance as Number or Null; // planned distance_meters
    private var mElapsed as Number;
    private var mRunning as Boolean;
    private var mTimer as Timer.Timer or Null;

    private var mW as Number;
    private var mH as Number;
    private var mPlayCx as Number;
    private var mPlayCy as Number;
    private var mPlayR as Number;
    private var mNextX0 as Number;
    private var mNextX1 as Number;
    private var mNextY0 as Number;
    private var mNextY1 as Number;
    private var mStrSet as String;
    private var mStrNext as String;
    private var mStrTarget as String;
    private var mTag as String;

    function initialize(session as WorkoutSession) {
        View.initialize();
        mSession = session;
        var set = session.currentSet();
        var dur = (set != null) ? set["duration_seconds"] : null;
        mTarget = (dur != null) ? dur : 0;
        mDistance = (set != null) ? set["distance_meters"] : null;
        mElapsed = 0;
        mRunning = false;

        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mPlayCx = (mW * 0.29).toNumber();
        mPlayCy = (mH * 0.795).toNumber();
        mPlayR = (mW * 0.082).toNumber();
        mNextX0 = (mW * 0.42).toNumber();
        mNextX1 = (mW * 0.82).toNumber();
        mNextY0 = (mH * 0.745).toNumber();
        mNextY1 = (mH * 0.86).toNumber();
        mStrSet = WatchUi.loadResource(Rez.Strings.SetWord) as String;
        mStrNext = WatchUi.loadResource(Rez.Strings.NextLabel) as String;
        mStrTarget = WatchUi.loadResource(Rez.Strings.TargetWord) as String;
        mTag = WatchUi.loadResource(
            (mDistance != null) ? Rez.Strings.DistanceTag : Rez.Strings.DurationTag) as String;
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
        if (mRunning) {
            mElapsed += 1;
            if (mTarget > 0 && mElapsed >= mTarget) { mRunning = false; }
        }
        WatchUi.requestUpdate();
    }

    function togglePlay() as Void {
        mRunning = !mRunning;
        WatchUi.requestUpdate();
    }

    function confirm() as Void {
        var set = mSession.currentSet();
        if (set == null) { return; }
        var secs = null;
        if (mElapsed > 0) { secs = mElapsed; }
        else if (mTarget > 0) { secs = mTarget; }
        mSession.logCurrent(set["weight_kg"], null, secs, mDistance);
        Flow.afterSetConfirmed(mSession);
    }

    function goBackToList() as Void {
        if (mTimer != null) { mTimer.stop(); mTimer = null; }
        WatchUi.switchToView(
            new ExerciseListView(mSession),
            new ExerciseListDelegate(mSession),
            WatchUi.SLIDE_RIGHT);
    }

    function hit(x as Number, y as Number) as Symbol or Null {
        var dx = x - mPlayCx;
        var dy = y - mPlayCy;
        if ((dx * dx + dy * dy) <= (mPlayR + 8) * (mPlayR + 8)) { return :play; }
        if (x >= mNextX0 && x <= mNextX1 && y >= mNextY0 && y <= mNextY1) { return :next; }
        return null;
    }

    function handle(zone as Symbol) as Void {
        if (zone == :play) { togglePlay(); }
        else if (zone == :next) { confirm(); }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        // Elapsed workout time up top; the pulse gets its own prominent row
        // below, since on rowing/plank work it is the metric you glance at.
        Theme.drawHeader(dc, mW, mH, Theme.mmss(mSession.elapsedSeconds()), null);

        var maxW = (mW * 0.66).toNumber();
        var exTitle = mSession.currentTitle();
        var tf = Theme.bestFont(dc, exTitle, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.18).toNumber(), tf, Theme.fit(dc, exTitle, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.25).toNumber(), Graphics.FONT_XTINY,
            mStrSet + " " + (mSession.setIndex + 1) + " / " + mSession.setCount(mSession.exIndex) + "  ·  " + mTag,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Timer box.
        var boxW = (mW * 0.5).toNumber();
        var boxH = (mH * 0.19).toNumber();
        var bx = cx - boxW / 2;
        var by = (mH * 0.31).toNumber();
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, boxW, boxH, 14);
        dc.setColor(mRunning ? Theme.GREEN : Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(bx, by, boxW, boxH, 14);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + boxH / 2, Graphics.FONT_NUMBER_MEDIUM, Theme.mmss(mElapsed),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Target line: planned distance for distance sets, else planned time.
        var target = null;
        if (mDistance != null) {
            target = mStrTarget + " " + mDistance + " m";
        } else if (mTarget > 0) {
            target = mStrTarget + " " + Theme.mmss(mTarget);
        }
        if (target != null) {
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + boxH + 22, Graphics.FONT_XTINY, target,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Live pulse, large enough to read mid-effort.
        Theme.drawHeartRate(dc, cx, (mH * 0.655).toNumber(), Vitals.heartRate(),
            Graphics.FONT_NUMBER_MILD);

        // Play / pause circle with a drawn glyph (font arrows don't render).
        dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mPlayCx, mPlayCy, mPlayR);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        if (mRunning) {
            var bw = (mPlayR * 0.28).toNumber();
            var bh = (mPlayR * 0.9).toNumber();
            dc.fillRectangle(mPlayCx - bw - 3, mPlayCy - bh / 2, bw, bh);
            dc.fillRectangle(mPlayCx + 3, mPlayCy - bh / 2, bw, bh);
        } else {
            var s = (mPlayR * 0.55).toNumber();
            dc.fillPolygon([
                [mPlayCx - s / 2, mPlayCy - s],
                [mPlayCx - s / 2, mPlayCy + s],
                [mPlayCx + s, mPlayCy]
            ]);
        }

        // Next pill.
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        var nh = mNextY1 - mNextY0;
        dc.fillRoundedRectangle(mNextX0, mNextY0, mNextX1 - mNextX0, nh, nh / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText((mNextX0 + mNextX1) / 2, (mNextY0 + mNextY1) / 2, Graphics.FONT_SMALL, mStrNext,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class DurationSetDelegate extends WatchUi.InputDelegate {
    private var mView as DurationSetView;

    function initialize(view as DurationSetView) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var zone = mView.hit(c[0], c[1]);
        if (zone != null) { mView.handle(zone); }
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
        if (k == WatchUi.KEY_ENTER) { mView.confirm(); return true; }
        return false;
    }
}
