import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;

// Screen 2: one working set of a rep/weight exercise, split into two swipe
// pages so the stepper targets stay big and far away from the navigation:
//   page 0 — full-width REPS and weight rows; tap the left zone to decrease,
//            the right zone to increase. A chevron at the bottom hints at
//            the second page (swipe up or tap it).
//   page 1 — large Next and Back pills, stacked with plenty of air between
//            them (swipe down or tap the top chevron to return).
// Weight is shown in the device unit (kg or lbs) and always logged to Hevy in
// kg. Bodyweight sets (null weight_kg) get a reps-only layout and never log a
// weight; weight_kg 0 counts as a weighted exercise (no weight entered yet)
// and keeps its stepper.
class SetView extends WatchUi.View {
    const LB_PER_KG = 2.2046226f;

    private var mSession as WorkoutSession;
    private var mReps as Number;
    private var mVal as Float;          // weight in DISPLAY units (kg or lb)
    private var mOrigKg as Float or Null;  // planned weight, logged verbatim
    private var mIsLb as Boolean;
    private var mHasWeight as Boolean;  // routine defined a weight
    private var mTouchedW as Boolean;   // user adjusted the weight
    private var mTimer as Timer.Timer or Null;
    private var mPage as Number;        // 0 = steppers, 1 = Next/Back

    private var mW as Number;
    private var mH as Number;
    // Page 0: two full-width stepper rows.
    private var mRowX0 as Number;
    private var mRowX1 as Number;
    private var mZoneW as Number;       // width of the -/+ tap zones
    private var mRepsTop as Number;
    private var mRepsBot as Number;
    private var mWgtTop as Number;
    private var mWgtBot as Number;
    private var mHintY as Number;       // below this a tap opens page 1
    // Page 1: stacked nav pills.
    private var mPillX0 as Number;
    private var mPillX1 as Number;
    private var mNextY0 as Number;
    private var mNextY1 as Number;
    private var mBackY0 as Number;
    private var mBackY1 as Number;
    private var mTopHintY as Number;    // above this a tap returns to page 0
    private var mStrSet as String;
    private var mStrNext as String;
    private var mStrBack as String;
    private var mWeightLabel as String;
    private var mStrReps as String;

    function initialize(session as WorkoutSession) {
        View.initialize();
        mSession = session;
        var set = session.currentSet();
        var planned = (set != null) ? WorkoutSession.plannedReps(set) : null;
        mReps = (planned != null) ? planned : 10;

        var d = System.getDeviceSettings();
        mIsLb = d.weightUnits == System.UNIT_STATUTE;
        mWeightLabel = mIsLb ? "LBS" : "KG";
        var kg = (set != null && set["weight_kg"] != null) ? set["weight_kg"].toFloat() : null;
        mHasWeight = kg != null;
        mOrigKg = kg;
        mTouchedW = false;
        if (kg == null) {
            mVal = 0.0;
        } else if (mIsLb) {
            mVal = quantize(kg * LB_PER_KG, 0.5);   // plate-friendly 0.5 lb
        } else {
            mVal = quantize(kg, 0.25);              // 0.25 kg micro plates
        }

        mW = d.screenWidth;
        mH = d.screenHeight;
        mPage = 0;
        mRowX0 = (mW * 0.10).toNumber();
        mRowX1 = (mW * 0.90).toNumber();
        mZoneW = ((mRowX1 - mRowX0) * 0.30).toNumber();
        if (mHasWeight) {
            mRepsTop = (mH * 0.29).toNumber();
            mRepsBot = (mH * 0.52).toNumber();
        } else {
            // Bodyweight exercise (weight_kg null in the routine): no weight
            // row at all, just one extra-large centered reps row. Note the
            // distinction: weight_kg 0 is a weighted exercise with no weight
            // entered yet and keeps its stepper.
            mRepsTop = (mH * 0.34).toNumber();
            mRepsBot = (mH * 0.64).toNumber();
        }
        mWgtTop = (mH * 0.57).toNumber();
        mWgtBot = (mH * 0.80).toNumber();
        mHintY = (mH * 0.84).toNumber();
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
        mStrReps = WatchUi.loadResource(Rez.Strings.RepsLabel) as String;
    }

    function quantize(v as Float, step as Float) as Float {
        return Math.round(v / step) * step;
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

    function onTick() as Void { WatchUi.requestUpdate(); }

    function bumpReps(delta as Number) as Void {
        mReps += delta;
        if (mReps < 0) { mReps = 0; }
        WatchUi.requestUpdate();
    }

    function bumpWeight(delta as Float) as Void {
        mVal += delta;
        if (mVal < 0) { mVal = 0.0; }
        mTouchedW = true;
        WatchUi.requestUpdate();
    }

    function confirm() as Void {
        // Only a real user edit may change the logged weight — otherwise the
        // planned value is passed through untouched (a kg->lb->kg round trip
        // would silently rewrite 20.0 kg as 19.96 kg on statute devices).
        var kg = null;
        if (mTouchedW) {
            var raw = mIsLb ? (mVal / LB_PER_KG) : mVal;
            kg = Math.round(raw * 100) / 100.0;    // 2 decimals for Hevy
        } else if (mHasWeight) {
            kg = mOrigKg;
        }
        mSession.logCurrent(kg, mReps, null, null);
        Flow.afterSetConfirmed(mSession);
    }

    function goBackToList() as Void {
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

    // Returns the tapped zone symbol, or null.
    function hit(x as Number, y as Number) as Symbol or Null {
        if (mPage == 0) {
            if (y >= mHintY) { return :showNav; }
            var inReps = y >= mRepsTop - 8 && y <= mRepsBot + 8;
            var inWgt = mHasWeight && y >= mWgtTop - 8 && y <= mWgtBot + 8;
            if (inReps || inWgt) {
                if (x <= mRowX0 + mZoneW) { return inReps ? :repsDown : :kgDown; }
                if (x >= mRowX1 - mZoneW) { return inReps ? :repsUp : :kgUp; }
            }
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
            case :repsUp:       bumpReps(1);        break;
            case :repsDown:     bumpReps(-1);       break;
            case :kgUp:         bumpWeight(2.5);    break;
            case :kgDown:       bumpWeight(-2.5);   break;
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
            drawStepperPage(dc);
        } else {
            drawNavPage(dc);
        }
    }

    function drawStepperPage(dc as Graphics.Dc) as Void {
        var cx = mW / 2;

        // Header: elapsed + heart rate.
        Theme.drawHeader(dc, mW, mH, Theme.mmss(mSession.elapsedSeconds()), Vitals.heartRate());

        // Title (auto-sized) + set counter.
        var maxW = (mW * 0.64).toNumber();
        var exTitle = mSession.currentTitle();
        var tf = Theme.bestFont(dc, exTitle, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.145).toNumber(), tf, Theme.fit(dc, exTitle, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.21).toNumber(), Graphics.FONT_XTINY,
            mStrSet + " " + (mSession.setIndex + 1) + " / " + mSession.setCount(mSession.exIndex),
            Graphics.TEXT_JUSTIFY_CENTER);

        drawRow(dc, mRepsTop, mRepsBot, mStrReps, mReps.format("%d"));
        if (mHasWeight) {
            drawRow(dc, mWgtTop, mWgtBot, mWeightLabel, Theme.weight(mVal));
        }

        // Hint: Next/Back live one swipe below.
        Theme.drawDownChevron(dc, cx, (mH * 0.90).toNumber(), (mW * 0.06).toNumber(), Theme.MUTED);
    }

    // One full-width stepper row: [ − | label/value | + ].
    function drawRow(dc as Graphics.Dc, top as Number, bot as Number, label as String, value as String) as Void {
        var cx = mW / 2;
        var w = mRowX1 - mRowX0;
        var h = bot - top;
        var cy = top + h / 2;
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mRowX0, top, w, h, 16);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(mRowX0, top, w, h, 16);
        // Dividers make the tap zones visible.
        dc.drawLine(mRowX0 + mZoneW, top + 10, mRowX0 + mZoneW, bot - 10);
        dc.drawLine(mRowX1 - mZoneW, top + 10, mRowX1 - mZoneW, bot - 10);

        // − / + fill the side zones (blue = tappable).
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mRowX0 + mZoneW / 2, cy, Graphics.FONT_LARGE, "–",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mRowX1 - mZoneW / 2, cy, Graphics.FONT_LARGE, "+",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Label above the value in the middle zone.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + 16, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var maxW = w - 2 * mZoneW - 12;
        var vf = Theme.bestFont(dc, value, maxW,
            [Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + (h * 0.62).toNumber(), vf, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawNavPage(dc as Graphics.Dc) as Void {
        var cx = mW / 2;

        // Hint: the steppers live one swipe above.
        Theme.drawUpChevron(dc, cx, (mH * 0.085).toNumber(), (mW * 0.06).toNumber(), Theme.MUTED);

        // Context: which set is confirmed with which values.
        var maxW = (mW * 0.60).toNumber();
        var exTitle = mSession.currentTitle();
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.15).toNumber(), Graphics.FONT_XTINY,
            Theme.fit(dc, exTitle, maxW, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER);
        var summary = "";
        if (mHasWeight || mTouchedW) {
            summary = mReps.format("%d") + " × " + Theme.weight(mVal) + " " + mWeightLabel;
        } else {
            summary = mReps.format("%d") + " " + mStrReps;
        }
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

class SetDelegate extends WatchUi.InputDelegate {
    private var mView as SetView;

    function initialize(view as SetView) {
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
    // Up/down swipes page between the steppers and the Next/Back pills.
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
