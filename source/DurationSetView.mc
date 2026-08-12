import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// Screen 3: a time-based set (Plank) or distance-based set (Running, Farmers
// Walk), split into two swipe pages like SetView so the controls stay big and
// far away from the navigation:
//   page 0 — stopwatch with a large centered play/pause control. A chevron at
//            the bottom hints at the second page (swipe up or tap it).
//   page 1 — large Next and Back pills plus a summary of what gets logged
//            (swipe down or tap the top chevron to return).
// Duration sets count toward the planned duration; distance sets show the
// planned distance and pass it through to the Hevy log unchanged.
class DurationSetView extends WatchUi.View {
    private var mSession as WorkoutSession;
    private var mTarget as Number;          // planned duration (0 = none)
    private var mDistance as Number or Null; // planned distance_meters
    private var mElapsed as Number;
    private var mRunning as Boolean;
    private var mTimer as Timer.Timer or Null;
    private var mPage as Number;            // 0 = stopwatch, 1 = Next/Back

    private var mW as Number;
    private var mH as Number;
    // Page 0: timer box + play circle.
    private var mPlayCx as Number;
    private var mPlayCy as Number;
    private var mPlayR as Number;
    private var mHintY as Number;           // below this a tap opens page 1
    // Page 1: stacked nav pills.
    private var mPillX0 as Number;
    private var mPillX1 as Number;
    private var mNextY0 as Number;
    private var mNextY1 as Number;
    private var mBackY0 as Number;
    private var mBackY1 as Number;
    private var mTopHintY as Number;        // above this a tap returns to page 0
    private var mStrSet as String;
    private var mStrNext as String;
    private var mStrBack as String;
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
        mPage = 0;

        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mPlayCx = (mW * 0.5).toNumber();
        // The pulse row sits between the target line and the play control, so
        // the button lives lower than a plain stopwatch page would need. It
        // must stay clear of mHintY — below that, a tap pages to Next/Back.
        mPlayCy = (mH * 0.785).toNumber();
        mPlayR = (mW * 0.088).toNumber();
        mHintY = (mH * 0.90).toNumber();
        mPillX0 = (mW * 0.18).toNumber();
        mPillX1 = (mW * 0.82).toNumber();
        mNextY0 = (mH * 0.32).toNumber();
        mNextY1 = (mH * 0.50).toNumber();
        mBackY0 = (mH * 0.60).toNumber();
        mBackY1 = (mH * 0.78).toNumber();
        mTopHintY = (mH * 0.16).toNumber();
        mStrSet = WatchUi.loadResource(Rez.Strings.SetWord) as String;
        mStrNext = WatchUi.loadResource(Rez.Strings.NextLabel) as String;
        mStrBack = WatchUi.loadResource(Rez.Strings.BackLabel) as String;
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

    function showNavPage() as Void {
        if (mPage != 1) { mPage = 1; WatchUi.requestUpdate(); }
    }

    function showStepperPage() as Void {
        if (mPage != 0) { mPage = 0; WatchUi.requestUpdate(); }
    }

    function hit(x as Number, y as Number) as Symbol or Null {
        if (mPage == 0) {
            if (y >= mHintY) { return :showNav; }
            var dx = x - mPlayCx;
            var dy = y - mPlayCy;
            if ((dx * dx + dy * dy) <= (mPlayR + 8) * (mPlayR + 8)) { return :play; }
            return null;
        }
        if (y <= mTopHintY) { return :showSteppers; }
        if (x >= mPillX0 - 10 && x <= mPillX1 + 10) {
            if (y >= mNextY0 - 10 && y <= mNextY1 + 10) { return :next; }
            if (y >= mBackY0 - 10 && y <= mBackY1 + 10) { return :back; }
        }
        return null;
    }

    function handle(zone as Symbol) as Void {
        switch (zone) {
            case :play:         togglePlay();       break;
            case :next:         confirm();          break;
            case :back:         goBackToList();     break;
            case :showNav:      showNavPage();      break;
            case :showSteppers: showStepperPage();  break;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        if (mPage == 0) {
            drawStopwatchPage(dc);
        } else {
            drawNavPage(dc);
        }
    }

    function drawStopwatchPage(dc as Graphics.Dc) as Void {
        var cx = mW / 2;

        // Elapsed workout time up top; the pulse gets its own prominent row
        // below, since on rowing/plank work it is the metric you glance at.
        Theme.drawHeader(dc, mW, mH, Theme.mmss(mSession.elapsedSeconds()), null);

        var maxW = (mW * 0.66).toNumber();
        var exTitle = mSession.currentTitle();
        var tf = Theme.bestFont(dc, exTitle, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.165).toNumber(), tf, Theme.fit(dc, exTitle, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.255).toNumber(), Graphics.FONT_XTINY,
            mStrSet + " " + (mSession.setIndex + 1) + " / " + mSession.setCount(mSession.exIndex) + "  ·  " + mTag,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Timer box.
        var boxW = (mW * 0.5).toNumber();
        var boxH = (mH * 0.19).toNumber();
        var bx = cx - boxW / 2;
        var by = (mH * 0.30).toNumber();
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
            dc.drawText(cx, by + boxH + 18, Graphics.FONT_XTINY, target,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Live pulse, large enough to read mid-effort.
        Theme.drawHeartRate(dc, cx, (mH * 0.63).toNumber(), Vitals.heartRate(),
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

        // Hint: Next/Back live one swipe below.
        Theme.drawDownChevron(dc, cx, (mH * 0.92).toNumber(), (mW * 0.06).toNumber(), Theme.MUTED);
    }

    function drawNavPage(dc as Graphics.Dc) as Void {
        var cx = mW / 2;

        // Hint: the stopwatch lives one swipe above.
        Theme.drawUpChevron(dc, cx, (mH * 0.085).toNumber(), (mW * 0.06).toNumber(), Theme.MUTED);

        // Context: which set is confirmed with which values.
        var maxW = (mW * 0.60).toNumber();
        var exTitle = mSession.currentTitle();
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.15).toNumber(), Graphics.FONT_XTINY,
            Theme.fit(dc, exTitle, maxW, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER);
        var summary = "";
        var secs = (mElapsed > 0) ? mElapsed : mTarget;
        if (secs > 0) { summary = Theme.mmss(secs); }
        if (mDistance != null) {
            summary = (summary.length() > 0) ? summary + " · " + mDistance + " m" : mDistance + " m";
        }
        if (summary.length() == 0) { summary = Theme.mmss(0); }
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.215).toNumber(), Graphics.FONT_SMALL, summary,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Next pill (primary).
        var nh = mNextY1 - mNextY0;
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mPillX0, mNextY0, mPillX1 - mPillX0, nh, nh / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, mNextY0 + nh / 2, Graphics.FONT_MEDIUM, mStrNext,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Back pill (secondary): chevron + label.
        var bh = mBackY1 - mBackY0;
        var bcy = mBackY0 + bh / 2;
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mPillX0, mBackY0, mPillX1 - mPillX0, bh, bh / 2);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(mPillX0, mBackY0, mPillX1 - mPillX0, bh, bh / 2);
        var bw = dc.getTextWidthInPixels(mStrBack, Graphics.FONT_SMALL);
        var left = cx - (bw + 26) / 2;
        Theme.drawBackChevron(dc, left + 8, bcy, 16, Theme.FG);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + 26, bcy, Graphics.FONT_SMALL, mStrBack,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // The system back-swipe must go through the same exit path as the physical
    // back key — otherwise the session and the recording would be orphaned.
    // Up/down swipes page between the stopwatch and the Next/Back pills.
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_RIGHT) {
            mView.goBackToList();
            return true;
        }
        if (dir == WatchUi.SWIPE_UP) { mView.showNavPage(); return true; }
        if (dir == WatchUi.SWIPE_DOWN) { mView.showStepperPage(); return true; }
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { mView.goBackToList(); return true; }
        if (k == WatchUi.KEY_ENTER) { mView.confirm(); return true; }
        return false;
    }
}
