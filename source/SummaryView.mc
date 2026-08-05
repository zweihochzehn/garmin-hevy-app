import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// Final screen: workout stats plus a save action that POSTs the completed
// workout to Hevy. The payload is persisted BEFORE the first attempt, so a
// failed save (phone in the locker) is never lost — the app offers to resend
// on the next launch. Demo sessions are never posted and never persisted.
class SummaryView extends WatchUi.View {
    private var mSession as WorkoutSession;
    private var mStatus as Symbol;      // :idle, :saving, :saved, :error
    private var mNote as String;
    private var mW as Number;
    private var mH as Number;
    private var mBtnX0 as Number;
    private var mBtnX1 as Number;
    private var mBtnY0 as Number;
    private var mBtnY1 as Number;
    private var mCalories as Number or Null;
    private var mGarminSaved as Boolean;
    private var mReturnTimer as Timer.Timer or Null;
    private var mVisible as Boolean;
    private var mPersisted as Boolean;
    private var mDemo as Boolean;
    private var mPayload as Dictionary or Null;   // exactly what was persisted

    function initialize(session as WorkoutSession) {
        View.initialize();
        mSession = session;
        mStatus = :idle;
        mNote = "";
        mCalories = null;
        mGarminSaved = false;
        mReturnTimer = null;
        mVisible = false;
        mPersisted = false;
        mPayload = null;
        mDemo = session.isDemo() || !HevyApi.hasKey();
        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mBtnX0 = (mW * 0.22).toNumber();
        mBtnX1 = (mW * 0.78).toNumber();
        mBtnY0 = (mH * 0.68).toNumber();
        mBtnY1 = (mH * 0.83).toNumber();
    }

    // Workout is complete: capture calories, persist the Garmin activity
    // (HR/calories/time -> Garmin Connect) and stash the Hevy payload so it
    // survives leaving this screen. onShow can re-fire after system overlays,
    // so everything here is sticky/idempotent.
    function onShow() as Void {
        mVisible = true;
        if (mCalories == null) { mCalories = Vitals.calories(); }
        if (getApp().recorder.hasData()) {
            mGarminSaved = getApp().recorder.saveAndClose() || mGarminSaved;
        } else {
            getApp().recorder.discard();
        }
        if (!mDemo && !mPersisted && mSession.totalCompleted() > 0) {
            mPayload = mSession.buildPayload();
            HevyApi.savePending(mPayload);
            mPersisted = true;
        }
    }

    function onHide() as Void {
        mVisible = false;
        if (mReturnTimer != null) { mReturnTimer.stop(); mReturnTimer = null; }
    }

    function save() as Void {
        if (mStatus == :saving || mStatus == :saved) { return; }
        if (mDemo) {
            mNote = WatchUi.loadResource(Rez.Strings.DemoNotSaved) as String;
            WatchUi.requestUpdate();
            return;
        }
        mStatus = :saving;
        mNote = "";
        WatchUi.requestUpdate();
        if (mPayload == null) { mPayload = mSession.buildPayload(); }
        HevyApi.postWorkout(mPayload, method(:onPosted));
    }

    function onPosted(code as Number, data as Dictionary or Null) as Void {
        if (code == 200 || code == 201) {
            mStatus = :saved;
            HevyApi.clearPending(mPayload);   // remove exactly this workout
            getApp().session = null;          // workout is done
            WatchUi.requestUpdate();
            // Briefly show the confirmation, then return to the routine list —
            // but only while this view is still what the user is looking at.
            if (mVisible) {
                mReturnTimer = new Timer.Timer();
                mReturnTimer.start(method(:goToList), 1200, false);
            }
        } else {
            mStatus = :error;
            mNote = HevyApi.errorText(code);
            WatchUi.requestUpdate();
        }
    }

    // The view under the summary is the routine picker — pop back to it
    // instead of stacking a fresh copy.
    function goToList() as Void {
        if (mReturnTimer != null) { mReturnTimer.stop(); mReturnTimer = null; }
        if (!mVisible) { return; }
        getApp().session = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function hitButton(x as Number, y as Number) as Boolean {
        return x >= mBtnX0 && x <= mBtnX1 && y >= mBtnY0 && y <= mBtnY1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.16).toNumber(), Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.DoneTitle) as String, Graphics.TEXT_JUSTIFY_CENTER);

        var maxW = (mW * 0.76).toNumber();
        var tf = Theme.bestFont(dc, mSession.title, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.30).toNumber(), tf, Theme.fit(dc, mSession.title, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.40).toNumber(), Graphics.FONT_TINY,
            mSession.totalCompleted() + "/" + mSession.totalSets() + " " +
                (WatchUi.loadResource(Rez.Strings.SetsWord) as String) +
                "   ·   " + Theme.mmss(mSession.elapsedSeconds()),
            Graphics.TEXT_JUSTIFY_CENTER);
        if (mGarminSaved) {
            var g = (mCalories != null) ? (mCalories + " kcal  ·  Garmin Connect") : "Garmin Connect";
            var gy = (mH * 0.53).toNumber();
            var gw = dc.getTextWidthInPixels(g, Graphics.FONT_XTINY);
            var checkW = 16;
            var gap = 8;
            var x = cx - (gw + gap + checkW) / 2;
            dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, gy, Graphics.FONT_XTINY, g, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            Theme.drawCheck(dc, x + gw + gap + checkW / 2, gy, 14, Theme.GREEN);
        }

        // Action button / status.
        var label;
        var fill;
        var labelColor = Theme.FG;
        if (mDemo) {
            label = WatchUi.loadResource(Rez.Strings.DemoOnly) as String;
            fill = Theme.BOX;
            labelColor = Theme.MUTED;
        } else if (mStatus == :saving) {
            label = WatchUi.loadResource(Rez.Strings.SavingLabel) as String;
            fill = Theme.BOX;
        } else if (mStatus == :saved) {
            label = WatchUi.loadResource(Rez.Strings.SavedLabel) as String;
            fill = Theme.GREEN;
            labelColor = Theme.BG;   // black on green for readable contrast
        } else if (mStatus == :error) {
            label = WatchUi.loadResource(Rez.Strings.RetryLabel) as String;
            fill = Theme.RED;
        } else {
            label = WatchUi.loadResource(Rez.Strings.SaveLabel) as String;
            fill = Theme.BLUE;
        }

        var h = mBtnY1 - mBtnY0;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mBtnX0, mBtnY0, mBtnX1 - mBtnX0, h, h / 2);
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mBtnY0 + mBtnY1) / 2, Graphics.FONT_TINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!mNote.equals("")) {
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 0.88).toNumber(), Graphics.FONT_XTINY,
                Theme.fit(dc, mNote, (mW * 0.62).toNumber(), Graphics.FONT_XTINY),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class SummaryDelegate extends WatchUi.InputDelegate {
    private var mView as SummaryView;

    function initialize(view as SummaryView) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        if (mView.hitButton(c[0], c[1])) { mView.save(); }
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { mView.save(); return true; }
        return false;
    }
}
