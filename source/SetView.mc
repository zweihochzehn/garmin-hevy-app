import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;

// Screen 2: one working set of a rep/weight exercise. Two boxes for REPS and
// weight — tap the upper third to increase, the lower third to decrease — plus
// a back circle and a blue "Next" pill. Laid out to stay inside the round
// bezel. Weight is shown in the device unit (kg or lbs) and always logged to
// Hevy in kg; bodyweight sets (null weight) stay weight-less unless the user
// touches the stepper.
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

    private var mW as Number;
    private var mH as Number;
    private var mRepsCx as Number;
    private var mKgCx as Number;
    private var mBoxTop as Number;
    private var mBoxBot as Number;
    private var mBoxHalfW as Number;
    private var mThird as Number;
    private var mBackCx as Number;
    private var mBackCy as Number;
    private var mBackR as Number;
    private var mNextX0 as Number;
    private var mNextX1 as Number;
    private var mNextY0 as Number;
    private var mNextY1 as Number;
    private var mStrSet as String;
    private var mStrNext as String;
    private var mWeightLabel as String;
    private var mStrReps as String;

    function initialize(session as WorkoutSession) {
        View.initialize();
        mSession = session;
        var set = session.currentSet();
        mReps = (set != null && set["reps"] != null) ? set["reps"] : 10;

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
        mBoxHalfW = (mW * 0.175).toNumber();
        mRepsCx = (mW * 0.29).toNumber();
        mKgCx = (mW * 0.71).toNumber();
        mBoxTop = (mH * 0.36).toNumber();
        mBoxBot = (mH * 0.70).toNumber();
        mThird = (mBoxBot - mBoxTop) / 3;
        mBackCx = (mW * 0.29).toNumber();
        mBackCy = (mH * 0.795).toNumber();
        mBackR = (mW * 0.082).toNumber();
        mNextX0 = (mW * 0.42).toNumber();
        mNextX1 = (mW * 0.82).toNumber();
        mNextY0 = (mH * 0.745).toNumber();
        mNextY1 = (mH * 0.86).toNumber();
        mStrSet = WatchUi.loadResource(Rez.Strings.SetWord) as String;
        mStrNext = WatchUi.loadResource(Rez.Strings.NextLabel) as String;
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

    // Returns the tapped zone symbol, or null.
    function hit(x as Number, y as Number) as Symbol or Null {
        var dxb = x - mBackCx;
        var dyb = y - mBackCy;
        if ((dxb * dxb + dyb * dyb) <= (mBackR + 8) * (mBackR + 8)) { return :back; }
        if (x >= mNextX0 && x <= mNextX1 && y >= mNextY0 && y <= mNextY1) { return :next; }
        if (y >= mBoxTop && y <= mBoxBot) {
            var top = y < mBoxTop + mThird;
            var bot = y > mBoxBot - mThird;
            if (x >= mRepsCx - mBoxHalfW && x <= mRepsCx + mBoxHalfW) {
                if (top) { return :repsUp; }
                if (bot) { return :repsDown; }
            }
            if (x >= mKgCx - mBoxHalfW && x <= mKgCx + mBoxHalfW) {
                if (top) { return :kgUp; }
                if (bot) { return :kgDown; }
            }
        }
        return null;
    }

    function handle(zone as Symbol) as Void {
        switch (zone) {
            case :repsUp:   bumpReps(1);        break;
            case :repsDown: bumpReps(-1);       break;
            case :kgUp:     bumpWeight(2.5);    break;
            case :kgDown:   bumpWeight(-2.5);   break;
            case :next:     confirm();          break;
            case :back:     goBackToList();     break;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        // Header: elapsed + heart rate.
        Theme.drawHeader(dc, mW, mH, Theme.mmss(mSession.elapsedSeconds()), Vitals.heartRate());

        // Title (auto-sized) + set counter.
        var maxW = (mW * 0.64).toNumber();
        var exTitle = mSession.currentTitle();
        var tf = Theme.bestFont(dc, exTitle, maxW,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.155).toNumber(), tf, Theme.fit(dc, exTitle, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.22).toNumber(), Graphics.FONT_XTINY,
            mStrSet + " " + (mSession.setIndex + 1) + " / " + mSession.setCount(mSession.exIndex),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Field labels just above the boxes.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mRepsCx, (mH * 0.315).toNumber(), Graphics.FONT_XTINY, mStrReps, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mKgCx, (mH * 0.315).toNumber(), Graphics.FONT_XTINY, mWeightLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawBox(dc, mRepsCx, mReps.format("%d"));
        drawBox(dc, mKgCx, (mHasWeight || mTouchedW) ? Theme.weight(mVal) : "–");

        // Back circle.
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mBackCx, mBackCy, mBackR);
        Theme.drawBackChevron(dc, mBackCx + 2, mBackCy, (mBackR * 0.7).toNumber(), Theme.FG);
        // Next pill.
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        var nh = mNextY1 - mNextY0;
        dc.fillRoundedRectangle(mNextX0, mNextY0, mNextX1 - mNextX0, nh, nh / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText((mNextX0 + mNextX1) / 2, (mNextY0 + mNextY1) / 2, Graphics.FONT_SMALL, mStrNext,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawBox(dc as Graphics.Dc, cx as Number, value as String) as Void {
        var x = cx - mBoxHalfW;
        var w = mBoxHalfW * 2;
        var h = mBoxBot - mBoxTop;
        dc.setColor(Theme.BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, mBoxTop, w, h, 16);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, mBoxTop, w, h, 16);

        // + / - pinned to the top and bottom edges of the box (blue = tappable).
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, mBoxTop + 20, Graphics.FONT_SMALL, "+", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, mBoxBot - 20, Graphics.FONT_SMALL, "–", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Value centered, auto-shrinking so 102.5 etc. never clips the box.
        var vf = Theme.bestFont(dc, value, w - 14,
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mBoxTop + mBoxBot) / 2, vf, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
