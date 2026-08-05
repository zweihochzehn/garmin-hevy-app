import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Shown at startup when no API key is configured. The watch keyboard caps how
// many characters can be entered at once, so the key is collected in chunks:
// each keyboard round appends its letters/digits until 32 are gathered, then
// the hyphens are inserted automatically, the key is stored, and we continue.
// A key entered in the Garmin Connect phone app is picked up automatically
// (onSettingsChanged / onShow re-check).
class SetupView extends WatchUi.View {
    private var mBuffer as String;   // accumulated letters/digits
    private var mError as String;
    private var mPendingGo as Boolean;
    private var mForce as Boolean;   // opened via "Change key": never auto-skip
    private var mW as Number;
    private var mH as Number;
    private var mBtnX0 as Number;
    private var mBtnX1 as Number;
    private var mBtnY0 as Number;
    private var mBtnY1 as Number;
    private var mSecY0 as Number;
    private var mSecY1 as Number;

    function initialize(force as Boolean) {
        View.initialize();
        mBuffer = "";
        mError = "";
        mPendingGo = false;
        mForce = force;
        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mBtnX0 = (mW * 0.22).toNumber();
        mBtnX1 = (mW * 0.78).toNumber();
        mBtnY0 = (mH * 0.55).toNumber();
        mBtnY1 = (mH * 0.69).toNumber();
        mSecY0 = (mH * 0.83).toNumber();
        mSecY1 = (mH * 0.93).toNumber();
    }

    // Continue when the key arrived — typed on the watch (mPendingGo) or
    // entered on the phone while this screen was showing. In force mode (the
    // user came here to replace a rejected key) only a fresh entry advances.
    function onShow() as Void {
        if (mPendingGo || (!mForce && HevyApi.hasKey())) {
            mPendingGo = false;
            var v = new RoutineListView();
            WatchUi.switchToView(v, new RoutineListDelegate(v), WatchUi.SLIDE_LEFT);
        }
    }

    function openKeyboard() as Void {
        if (WatchUi has :TextPicker) {
            WatchUi.pushView(new WatchUi.TextPicker(""),
                new KeyPickerDelegate(self), WatchUi.SLIDE_LEFT);
        } else {
            mError = WatchUi.loadResource(Rez.Strings.SetupNoKb) as String;
            WatchUi.requestUpdate();
        }
    }

    // Append one keyboard round's letters/digits; finish once 32 are collected.
    function appendEntry(text as String) as Void {
        mBuffer += HevyApi.stripAlnum(text);
        mError = "";
        if (mBuffer.length() >= 32) {
            var key = HevyApi.normalizeKey(mBuffer.substring(0, 32));
            if (key != null) {
                HevyApi.saveKey(key);
                mPendingGo = true;   // onShow navigates after the picker pops
            } else {
                mError = WatchUi.loadResource(Rez.Strings.SetupInvalid) as String;
                mBuffer = "";
            }
        }
    }

    function reset() as Void {
        mBuffer = "";
        mError = "";
        WatchUi.requestUpdate();
    }

    function startDemo() as Void {
        var v = new RoutineListView();
        WatchUi.switchToView(v, new RoutineListDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // The secondary zone always matches its drawn label (demo/reset).
    function hit(x as Number, y as Number) as Symbol or Null {
        if (x >= mBtnX0 && x <= mBtnX1 && y >= mBtnY0 && y <= mBtnY1) { return :key; }
        if (y >= mSecY0 && y <= mSecY1) { return (mBuffer.length() == 0) ? :demo : :reset; }
        return null;
    }

    function primary() as Void {
        openKeyboard();
    }

    // Progress preview: the collected characters in canonical grouping, e.g.
    // "a123456a-1rw4-42…" — one glance shows what has been typed so far.
    function preview() as String {
        var core = mBuffer;
        var out = "";
        var groups = [8, 4, 4, 4, 12];
        var pos = 0;
        for (var g = 0; g < groups.size() && pos < core.length(); g++) {
            if (g > 0) { out += "-"; }
            var end = pos + groups[g];
            if (end > core.length()) { end = core.length(); }
            out += core.substring(pos, end);
            pos = end;
        }
        return out;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;
        var started = mBuffer.length() > 0;

        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        var appName = WatchUi.loadResource(Rez.Strings.AppName) as String;
        var af = Theme.bestFont(dc, appName, (mW * 0.72).toNumber(),
            [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        dc.drawText(cx, (mH * 0.17).toNumber(), af, appName,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.29).toNumber(), Graphics.FONT_TINY,
            WatchUi.loadResource(started ? Rez.Strings.SetupTyping : Rez.Strings.SetupNeedKey) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.375).toNumber(), Graphics.FONT_XTINY,
            started ? (mBuffer.length() + " / 32 " + (WatchUi.loadResource(Rez.Strings.SetupChars) as String))
                    : (WatchUi.loadResource(Rez.Strings.SetupHint) as String),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (started) {
            var pv = preview();
            dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 0.46).toNumber(), Graphics.FONT_XTINY,
                Theme.fit(dc, pv, (mW * 0.8).toNumber(), Graphics.FONT_XTINY),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Primary button.
        var h = mBtnY1 - mBtnY0;
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mBtnX0, mBtnY0, mBtnX1 - mBtnX0, h, h / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mBtnY0 + mBtnY1) / 2, Graphics.FONT_SMALL,
            WatchUi.loadResource(started ? Rez.Strings.SetupMoreBtn : Rez.Strings.SetupEnterBtn) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!mError.equals("")) {
            dc.setColor(Theme.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 0.755).toNumber(), Graphics.FONT_XTINY,
                Theme.fit(dc, mError, (mW * 0.7).toNumber(), Graphics.FONT_XTINY),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        // Secondary action stays visible (and tappable) even while an error
        // shows, so the drawn UI always matches the hit zones.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mSecY0 + mSecY1) / 2, Graphics.FONT_XTINY,
            WatchUi.loadResource(started ? Rez.Strings.SetupReset : Rez.Strings.StartDemo) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class SetupDelegate extends WatchUi.InputDelegate {
    private var mView as SetupView;

    function initialize(view as SetupView) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var zone = mView.hit(c[0], c[1]);
        if (zone == :key) { mView.openKeyboard(); }
        else if (zone == :demo) { mView.startDemo(); }
        else if (zone == :reset) { mView.reset(); }
        return true;
    }

    // Physical select button = primary action (ADR-0003 convention).
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { mView.primary(); return true; }
        return false;
    }
}

// Receives one keyboard round's text.
class KeyPickerDelegate extends WatchUi.TextPickerDelegate {
    private var mView as SetupView;

    function initialize(view as SetupView) {
        TextPickerDelegate.initialize();
        mView = view;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        mView.appendEntry(text);
        return true;   // pop the keyboard; SetupView.onShow handles the rest
    }

    function onCancel() as Boolean {
        return true;
    }
}
